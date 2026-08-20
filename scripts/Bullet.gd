extends Node2D
## 총알: 직선 이동 + 좀비 명중 시 데미지(스플래시 무기는 범위 피해). 수명/명중 시 풀로 반납(재사용).
## 외형(색/크기)과 스플래시 반경은 장착 무기에 따라 Player._shoot_at() 에서 매 발 주입된다.
##
## 물리 노드가 아니다: 명중은 아래 _check_swept_hit() 의 스윕 판정 + 공간 해시로만 처리한다.
## Area2D 였을 때는 동시 수십~수백 발이 매 프레임 물리 broadphase 를 갱신하는 비용을 냈지만,
## 실제 판정에 쓰이지 않는 죽은 비용이었다(좀비 씬에는 충돌 도형이 아예 없다).

@export var speed: float = 700.0
@export var damage: int = 1
@export var lifetime: float = 1.5

const _FXBurst := preload("res://scripts/FXBurst.gd")
const _SpriteFX := preload("res://scripts/SpriteFX.gd")
const _FX_HITSPARK := preload("res://assets/atlas/fx_hitspark.tres")
const _FX_EXPLOSION := preload("res://assets/atlas/fx_explosion.tres")

var direction: Vector2 = Vector2.RIGHT
var trail_color: Color = Color(1.0, 0.30, 0.10)
## 탄 모양 — 쏘는 캐릭터의 그림 속 무기에 맞춘다("bullet"/"bolt"/"nail"). 색은 무기 색을
## 그대로 쓰므로 무기 구분(색)과 캐릭터 개성(모양)이 함께 읽힌다.
var style: String = "bullet"
## 자전 각속도(rad/s). 톱날처럼 방향과 무관하게 도는 탄이 쓴다. 노드 rotation 만 돌리므로
## 매 프레임 다시 그릴 필요가 없다(_draw 는 발사 시 1회).
var spin: float = 0.0
## 유도 선회 속도(rad/s). 0이면 직진. 전방 호 안의 적만 쫓는다.
var homing: float = 0.0
var homing_arc: float = PI / 4.0  # 진행 방향 기준 반각(무기별로 주입)

const HOMING_RANGE := 420.0       # 이 거리 안의 적만 유도 대상 — 빠른 탄이 일찍 물도록 넉넉히

## 탄 그림은 전부 텍스처다. 예전에는 draw_line/draw_circle/draw_polygon 으로 그렸는데,
## 이 엔진에서는 **draw_* 호출 하나가 draw call 하나로 그대로 나가 배칭되지 않는다** —
## 탄 400개 기준 예광탄 3콜(4.6ms), 유도표식까지 8콜(11.3ms) 였다. 텍스처는 사각형 하나라
## 2콜(2.9ms)이고, 글로우까지 그림에 구우면 1콜이 된다.
## 그림은 무채색(흰~회색)으로 만들고 무기 색을 modulate 로 입힌다 — 그래야 무기별 색 구분이
## 유지된다. 검은 외곽선은 곱셈에도 검게 남아 밝은 바닥 위에서 실루엣을 잡아준다.
## 아트는 오른쪽(+X)을 향해 그려져 있고, 진행 방향은 로컬 -Y 라 그릴 때 -90° 돌린다.
const _TEX := {
	"bullet": preload("res://assets/atlas/proj_tracer.tres"),
	"bullet_guided": preload("res://assets/atlas/proj_tracer_guided.tres"),
	"bolt": preload("res://assets/atlas/proj_bolt.tres"),
	"bolt_guided": preload("res://assets/atlas/proj_bolt_guided.tres"),
	"nail": preload("res://assets/atlas/proj_nail.tres"),
	"nail_guided": preload("res://assets/atlas/proj_nail_guided.tres"),
	"blade": preload("res://assets/atlas/weapon_sawblade.tres"),
}
## 스타일별 화면 크기(긴 변, px). 원본 해상도와 무관하게 여기로 정규화한다.
## 직진 볼트는 그림이 유난히 납작해서(가로:세로 ≈ 9:1) 같은 값을 주면 세로가 4px 남짓이라
## 배경에 묻힌다 — 그래서 혼자 크게 잡는다.
const _TEX_SIDE := {
	"bullet": 34.0, "bullet_guided": 34.0,
	"bolt": 52.0, "bolt_guided": 42.0,
	"nail": 30.0, "nail_guided": 32.0,
	"blade": 30.0,
}
var splash_radius: float = 0.0
var is_crit: bool = false          # 이 탄이 크리티컬인지(Player._shoot_at 에서 주입) — 명중 시 강조 피드백
var pierce: int = 0                # 관통 가능 적 수(0=첫 명중에 소멸). 석궁 등 관통 무기가 주입.
var knockback: float = 0.0         # 직격 넉백 세기(0=기본 _KNOCKBACK). 산탄총 등이 크게 준다.
var _pierced: int = 0              # 지금까지 관통한 적 수
var _hit_ids: Dictionary = {}      # 이미 명중한 적(중복 타격 방지) — 관통 시에만 의미
var _age: float = 0.0
var _alive: bool = false
## 명중 판정용 탄 반경(= 5px × scale.x)을 스폰 직후 1회만 계산해 들고 있는다.
## `Node2D.scale` 은 필드가 아니라 **변환 행렬을 분해해 만드는 값**이라(atan2/sqrt) 읽을
## 때마다 비용이 든다 — 매 프레임 읽던 것을 없애면 탄 1발당 약 0.4µs 가 빠진다.
## 크기는 발사 측이 on_spawn() **뒤에** 주입하므로, 첫 물리 틱에서 지연 계산한다.
var _hit_r: float = -1.0
## 유도 조준을 몇 물리 프레임마다 다시 할지. **선회 속도는 그대로 두고 갱신 빈도만 낮춘다** —
## 건너뛴 프레임의 delta 를 모아서 한 번에 적용하므로 초당 최대 선회각은 동일하다.
##
## 왜 필요한가: 조준은 `Events.zombies_in_radius(pos, 420)` 이고, 이 비용은 **탄 × 좀비의 곱**에
## 비례한다. 통제 실험(유도탄 200발, 표본 720틱)에서 좀비를 0 → 150 으로 세우자
## 1.85ms → 12.19ms 로 **6.6배**가 됐다(탄 1발당 9.3 → 61.0µs). 자료구조 문제가 아니다 —
## 좀비 300 에서 셀 경로(13.47ms)와 전수 스캔(12.19ms)이 거의 같았다. 줄일 수 있는 것은 **횟수**뿐이다.
const STEER_EVERY := 3
var _steer_phase: int = 0   # 개체마다 위상을 달리해 한 프레임에 몰리지 않게 한다
var _steer_accum: float = 0.0

const _ZOMBIE_RADIUS := 14.0   # Zombie.tscn 충돌 반경
const _BOSS_RADIUS := 38.0     # Boss.tscn 충돌 반경
const _KNOCKBACK := 135.0      # 직격 시 좀비를 진행 방향으로 살짝 밀어내는 세기(타격감)


func on_spawn() -> void:
	_age = 0.0
	_alive = true
	scale = Vector2.ONE
	trail_color = Color(1.0, 0.30, 0.10)
	style = "bullet"
	spin = 0.0
	homing = 0.0
	homing_arc = PI / 4.0
	splash_radius = 0.0
	is_crit = false
	# 풀 재사용 대비: 관통/넉백은 발사 측이 매 발 주입하므로 여기서 기본값으로 되돌린다.
	pierce = 0
	knockback = 0.0
	_pierced = 0
	_hit_r = -1.0          # 발사 측이 scale 을 주입한 뒤 첫 틱에서 다시 잰다
	_steer_phase = randi() % STEER_EVERY
	_steer_accum = 0.0
	_hit_ids.clear()


func on_despawn() -> void:
	_alive = false
	_age = 0.0


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	if _hit_r < 0.0:
		_hit_r = 5.0 * scale.x   # 스폰 직후 1회 — 이후로는 scale 을 읽지 않는다
	var from := global_position
	if homing > 0.0:
		# 조준은 STEER_EVERY 프레임에 한 번. 그동안 쌓인 delta 를 넘겨 선회량을 보존한다.
		_steer_accum += delta
		if (Engine.get_physics_frames() + _steer_phase) % STEER_EVERY == 0:
			_steer(_steer_accum)
			_steer_accum = 0.0
		if spin == 0.0:
			# 휘었으면 그림도 같이 틀어야 한다 — 안 그러면 볼트가 옆으로 날아간다.
			# (자전하는 톱날은 방향이 의미 없으므로 제외)
			rotation = direction.angle() + PI / 2.0
	if spin != 0.0:
		rotation += spin * delta   # 톱날 자전 — 그림은 그대로 두고 노드만 돌린다
	# `global_position` 은 읽을 때마다 전역 변환을, 쓸 때마다 부모 변환의 역행렬을 만든다.
	# 예전에는 한 틱에 3읽기+1쓰기였다 — 목적지를 지역 변수로 계산해 1읽기+1쓰기로 줄인다.
	var to := from + direction * speed * delta
	global_position = to
	# 빠른 총알이 저프레임에서 좀비를 건너뛰는 터널링 방지: 이동 구간을 레이캐스트로 훑는다.
	_check_swept_hit(from, to)
	if not _alive:
		return
	_age += delta
	if _age >= lifetime:   # 화면 밖으로 날아간 총알 회수
		_despawn()
	# 트레일은 로컬 좌표에서 정적(색·크기는 발사 시 고정)이라 매 프레임 queue_redraw 가
	# 필요 없다 — 노드 이동은 transform 갱신만으로 반영된다(발사 시 1회 redraw).


## 명중 판정 — 물리 쿼리(Area2D/intersect_*) 대신 좀비 목록을 직접 순회한다.
## Orb/Lightning 과 동일한, 물리 엔진에 의존하지 않는 방식이라 렌더러·웹 빌드에서도 확실히 동작하고,
## 직전→현재 위치 선분과 적의 거리를 보므로 빠른 총알의 터널링도 막는다.
## 목록은 Events.live_zombies() 프레임 공유 스냅샷 — 총알마다 그룹 스캔(배열 할당)을 반복하지 않는다.
func _check_swept_hit(from: Vector2, to: Vector2) -> void:
	var seg := to - from
	var seg_len_sq := seg.length_squared()
	var bullet_r := _hit_r
	var max_r := _BOSS_RADIUS + bullet_r
	# 이동 구간 AABB(+최대 판정 반경) — 범위 밖 좀비를 값싼 비교만으로 조기 탈락.
	var lo_x := minf(from.x, to.x) - max_r
	var hi_x := maxf(from.x, to.x) + max_r
	var lo_y := minf(from.y, to.y) - max_r
	var hi_y := maxf(from.y, to.y) + max_r
	# 공간 해시로 근처 좀비 후보만 훑는다(전체 스캔 대신) — 대량 총알·좀비에서 핵심 최적화.
	for z in Events.zombies_near(to):
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue   # 같은 프레임에 이미 죽어 스냅샷에만 남은 좀비
		var zp: Vector2 = z.global_position
		if zp.x < lo_x or zp.x > hi_x or zp.y < lo_y or zp.y > hi_y:
			continue
		# 선분 위에서 적 중심에 가장 가까운 점
		var t := 0.0
		if seg_len_sq > 0.0:
			t = clampf((zp - from).dot(seg) / seg_len_sq, 0.0, 1.0)
		var closest := from + seg * t
		var target_r: float = (_BOSS_RADIUS if z.is_in_group("boss") else _ZOMBIE_RADIUS) + bullet_r
		if closest.distance_squared_to(zp) <= target_r * target_r:
			_resolve_hit(z, closest)
			# 관통탄은 한 프레임에 여러 적을 지나갈 수 있다 — 소멸했을 때만 순회를 멈춘다.
			# (예전에는 명중 즉시 return 이라 pierce 가 남아도 프레임당 1마리만 맞았다)
			if not _alive:
				return


func _resolve_hit(c: Node, pos: Vector2) -> void:
	if splash_radius > 0.0:      # 폭발형: 지점 이동 후 범위 피해, 즉시 소멸(관통 없음)
		global_position = pos
		_splash_hit()
		_despawn()
		return
	var id := c.get_instance_id()
	if _hit_ids.has(id):         # 관통 중 이미 때린 적은 그냥 통과
		return
	_hit_ids[id] = true
	if c.has_method("take_damage"):
		c.take_damage(damage, is_crit)
		if c.has_method("apply_knockback"):   # 좀비만 넉백(보스는 메서드가 없어 면역)
			c.apply_knockback(direction, knockback if knockback > 0.0 else _KNOCKBACK)
		# 피격 스파크 — 크리티컬은 더 크고 밝게 강조.
		var spark_col: Color = Color(1.0, 0.95, 0.7) if is_crit else trail_color.lightened(0.35)
		var spark_px: float = 26.0 if is_crit else 18.0
		_SpriteFX.spawn(get_tree().current_scene, pos, _FX_HITSPARK, spark_px, 0.16, \
			spark_col, direction.angle(), 6.0)
	# 관통: 남은 관통 수가 있으면 소멸하지 않고 계속 진행(위치 보정 안 함).
	if _pierced >= pierce:
		_despawn()
	else:
		_pierced += 1


func _draw() -> void:
	if not _alive:
		return
	# 사각형 하나로 끝낸다(draw call 1). 무채색 그림 × 무기 색 = 무기별로 구분되는 탄.
	# 톱날은 자전하므로 방향 보정이 필요 없고, 나머지는 아트가 +X 를 보므로 -90° 돌린다.
	var key: String = style if _TEX.has(style) else "bullet"
	if homing > 0.0 and _TEX.has(key + "_guided"):
		key += "_guided"
	var tex: Texture2D = _TEX[key]
	var side := maxf(tex.get_size().x, tex.get_size().y)
	var sz: Vector2 = tex.get_size() * (float(_TEX_SIDE[key]) / maxf(side, 1.0))
	if key != "blade":
		draw_set_transform(Vector2.ZERO, -PI / 2.0, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false, trail_color)
	if key != "blade":
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 전방 호 안에서 가장 가까운(=각도가 가장 잘 맞는) 적 쪽으로 진행 방향을 조금씩 튼다.
## 이미 지나친 적을 쫓아 되돌아오면 관통 무기의 '한 줄로 베고 지나간다'는 느낌이 깨지므로
## 후보를 전방 호로 제한한다.
func _steer(delta: float) -> void:
	var best: Node2D = null
	var best_d := HOMING_RANGE * HOMING_RANGE
	for z in Events.zombies_in_radius(global_position, HOMING_RANGE):
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		if _hit_ids.has(z.get_instance_id()):
			continue   # 이미 벤 적은 다시 쫓지 않는다
		var to: Vector2 = z.global_position - global_position
		if absf(direction.angle_to(to)) > homing_arc:
			continue
		var d := to.length_squared()
		if d < best_d:
			best_d = d
			best = z
	if best == null:
		return
	var want: Vector2 = (best.global_position - global_position).normalized()
	direction = direction.rotated(clampf(direction.angle_to(want), -homing * delta, homing * delta))


## 폭발형 무기: 명중 지점 주변의 모든 좀비에게 피해 + 확산 이펙트.
func _splash_hit() -> void:
	# 반경 질의(공간 해시)로 후보를 좁힌다 — 전체 좀비 스캔은 폭발마다 O(좀비 수)였다.
	# 바깥 명중 순회(zombies_near)와는 다른 버퍼를 쓰므로 중첩 호출이어도 안전하다.
	for z in Events.zombies_in_radius(global_position, splash_radius):
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		if z.has_method("take_damage"):
			z.take_damage(damage, is_crit)
	# 폭발 텍스처(반경에 맞춰 크게) + 잔광 링. 지름 = splash_radius*2 근사.
	_SpriteFX.spawn(get_tree().current_scene, global_position, _FX_EXPLOSION, splash_radius * 2.0, \
		0.32, trail_color.lightened(0.3))
	_FXBurst.spawn(get_tree().current_scene, global_position, trail_color, splash_radius * 0.7, 0.3)


func _despawn() -> void:
	_alive = false
	Pool.release(self)
