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
const _FX_HITSPARK := preload("res://assets/sprites/fx/fx_hitspark.png")
const _FX_EXPLOSION := preload("res://assets/sprites/fx/fx_explosion.png")

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
const _TEX_BLADE := preload("res://assets/ui/icons/weapon_sawblade.png")
const _BLADE_SIDE := 30.0         # 톱날 스프라이트 화면 크기(긴 변)
var splash_radius: float = 0.0
var is_crit: bool = false          # 이 탄이 크리티컬인지(Player._shoot_at 에서 주입) — 명중 시 강조 피드백
var pierce: int = 0                # 관통 가능 적 수(0=첫 명중에 소멸). 석궁 등 관통 무기가 주입.
var knockback: float = 0.0         # 직격 넉백 세기(0=기본 _KNOCKBACK). 산탄총 등이 크게 준다.
var _pierced: int = 0              # 지금까지 관통한 적 수
var _hit_ids: Dictionary = {}      # 이미 명중한 적(중복 타격 방지) — 관통 시에만 의미
var _age: float = 0.0
var _alive: bool = false

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
	_hit_ids.clear()


func on_despawn() -> void:
	_alive = false
	_age = 0.0


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	var from := global_position
	if homing > 0.0:
		_steer(delta)
		if spin == 0.0:
			# 휘었으면 그림도 같이 틀어야 한다 — 안 그러면 볼트가 옆으로 날아간다.
			# (자전하는 톱날은 방향이 의미 없으므로 제외)
			rotation = direction.angle() + PI / 2.0
	if spin != 0.0:
		rotation += spin * delta   # 톱날 자전 — 그림은 그대로 두고 노드만 돌린다
	global_position += direction * speed * delta
	# 빠른 총알이 저프레임에서 좀비를 건너뛰는 터널링 방지: 이동 구간을 레이캐스트로 훑는다.
	_check_swept_hit(from, global_position)
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
	var bullet_r := 5.0 * scale.x
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
	# 골드(노란 동전)와 헷갈리지 않도록 무기 색조를 유지하되, 모양은 쏜 캐릭터의 무기를 따른다.
	# 로컬 +Y가 진행 방향의 반대쪽(꼬리) — Player._shoot_dir() 의 회전식 참고.
	# 화면에서 탄은 20~35px 남짓이라 깃·못머리 같은 2~3px 디테일은 사라진다. 셋은 굵은
	# 실루엣(길이·두께·머리 모양)으로 갈라야 구분된다. 반투명 원을 몸통에 겹치면 그 실루엣이
	# 뭉개지므로 예광탄에만 남기고 볼트·못에서는 뺐다.
	var c := trail_color
	var mid := c.lightened(0.30)
	var body := Color(mid.r, mid.g, mid.b, 0.96)
	var hot := Color(1.0, 0.96, 0.88, 0.96)
	match style:
		"bolt":
			# 석궁 볼트 — 셋 중 가장 길고 가늘다. 뒤쪽 큰 V 깃으로 화살임을 못박는다.
			draw_line(Vector2(0, -10), Vector2(0, 18), Color(c.r, c.g, c.b, 0.43), 2.0, true)
			draw_line(Vector2(0, -14), Vector2(0, 13), body, 3.0, true)
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -22), Vector2(-3.5, -12), Vector2(3.5, -12)]), hot)
			var fletch := Color(mid.r, mid.g, mid.b, 0.90)
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, 4), Vector2(-7, 16), Vector2(0, 11)]), fletch)
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, 4), Vector2(7, 16), Vector2(0, 11)]), fletch)
		"blade":
			# 회전 톱날 — 전용 아트를 그대로 쓴다(무기 아이콘과 같은 그림이라 정체가 바로 읽힌다).
			# 자전은 노드 rotation 이 담당하므로 여기서는 중심 정렬만 하면 된다.
			var side := maxf(_TEX_BLADE.get_size().x, _TEX_BLADE.get_size().y)
			var sz: Vector2 = _TEX_BLADE.get_size() * (_BLADE_SIDE / maxf(side, 1.0))
			draw_circle(Vector2.ZERO, _BLADE_SIDE * 0.62, Color(c.r, c.g, c.b, 0.20))
			draw_texture_rect(_TEX_BLADE, Rect2(-sz * 0.5, sz), false)
		"nail":
			# 네일건 못 — 짧고 굵은 몸통 + 뒤쪽 넓은 납작 머리. 화살과 달리 T 자로 읽힌다.
			draw_line(Vector2(0, -7), Vector2(0, 9), body, 6.0, true)
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -12), Vector2(-3, -6), Vector2(3, -6)]), hot)
			draw_line(Vector2(-9, 10), Vector2(9, 10), body, 5.0, true)
			draw_line(Vector2(-9, 10), Vector2(9, 10), Color(hot.r, hot.g, hot.b, 0.47), 2.0, true)
		_:
			# 소총 예광탄 — 작고 뜨거운 탄심 + 길게 늘어지는 줄기. 화살·못과 달리 촉이 없다.
			draw_line(Vector2(0, 1), Vector2(0, 24), Color(c.r, c.g, c.b, 0.47), 3.0, true)
			draw_circle(Vector2.ZERO, 5.0, Color(c.r, c.g, c.b, 0.24))
			draw_circle(Vector2.ZERO, 3.4, hot)
	if homing > 0.0:
		_draw_guided(c)


## 유도탄 표식 — 직진탄과 한눈에 갈리게 한다. 같은 캐릭터가 쏘면 모양도 색도 비슷해서,
## 어떤 탄이 휘는지 모르면 조준 감각이 서지 않는다.
## 탄심을 감싼 얇은 링(추적 중이라는 신호) + 뒤로 젖혀진 유도 날개 한 쌍.
func _draw_guided(c: Color) -> void:
	draw_arc(Vector2.ZERO, 7.2, 0.0, TAU, 18, Color(1.0, 0.98, 0.90, 0.85), 1.3, true)
	var fin := Color(c.r, c.g, c.b, 1.0).lightened(0.45)
	fin.a = 0.95
	draw_colored_polygon(PackedVector2Array([
		Vector2(-1.5, 3.0), Vector2(-7.5, 10.5), Vector2(-1.5, 8.0)]), fin)
	draw_colored_polygon(PackedVector2Array([
		Vector2(1.5, 3.0), Vector2(7.5, 10.5), Vector2(1.5, 8.0)]), fin)


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
