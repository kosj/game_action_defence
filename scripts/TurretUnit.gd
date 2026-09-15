extends Node2D
## 터렛(설치물): 이동 표적을 선행 조준해 유도탄을 쏜다.
## 수명 동안 설치 지점에서 사거리 내 최근접 적을 자동 사격하며 수명이 다하면 자기 해제.
## 월드(current_scene)에 스폰. 총알은 기존 Bullet 풀을 재사용한다.
## 외형: 방향 스프라이트 시트(3x3)를 조준 방향(8분할)에 맞춰 선택, 발사는 포신 끝에서 나간다.

const BULLET := preload("res://scenes/Bullet.tscn")
const FIRE_INTERVAL := 0.5   # 터렛 자체 발사 간격
const SPR_SCALE := 0.56      # 128px 원본을 약 72px로 표시한다.
const GUIDANCE_TURN := 5.2       # rad/s — 선행 조준 오차만 보정하는 약한 유도
const GUIDANCE_ARC := PI * 0.70
const VELOCITY_RESPONSE := 12.0
const MAX_TRACKED_SPEED := 720.0  # 순간이동/풀 재사용을 이동 속도로 오인하지 않게 제한
const MAX_LEAD_TIME := 0.65

## 방향 스프라이트(3x3 시트에서 잘라낸 셀). 시트가 8방향을 완벽히 담진 않아 실제 그려진 방향에
## 맞춰 매핑: up=idx0, up-right=idx2, left=idx3, down=idx4, right=idx5. (없는 대각은 근접/미러 대체)
const _TEX := [
	preload("res://assets/atlas/turret_0.tres"),  # [0] 위(N)
	preload("res://assets/atlas/turret_2.tres"),  # [1] 우상(NE)
	preload("res://assets/atlas/turret_3.tres"),  # [2] 좌(W)
	preload("res://assets/atlas/turret_4.tres"),  # [3] 아래(S)
	preload("res://assets/atlas/turret_5.tres"),  # [4] 우(E)
]
# Visible barrel openings in the original 128x128 cells, before centering/mirroring.
const _MUZZLES := [
	[Vector2(71, 79), Vector2(90, 79)],
	[Vector2(18, 78), Vector2(34, 84)],
	[Vector2(32, 47), Vector2(37, 56)],
	[Vector2(55, 82), Vector2(74, 82)],
	[Vector2(95, 45), Vector2(92, 55)],
]
## 조준 8분할(0=E,1=SE,2=S,3=SW,4=W,5=NW,6=N,7=NE) → [_TEX 인덱스, 좌우반전].
const _DIR := [
	[4, false],  # E  우
	[4, false],  # SE (근접: 우)
	[3, false],  # S  아래
	[2, false],  # SW (근접: 좌)
	[2, false],  # W  좌
	[1, true],   # NW (우상 미러 → 좌상)
	[0, false],  # N  위
	[1, false],  # NE 우상
]

var damage: int = 2
var bullet_speed: float = 700.0
var range: float = 300.0
var color: Color = Color(0.7, 0.8, 1.0)
var _life: float = 6.0
var _t: float = 0.0
var _aim: Vector2 = Vector2.RIGHT
var _spr: Sprite2D
var _shadow: Sprite2D
var _oct: int = -1
var _barrel: int = 0
var _tracked_target: Node2D = null
var _tracked_pos := Vector2.ZERO
var _target_velocity := Vector2.ZERO

const _SHADOW_TEX := preload("res://assets/atlas/shadow.tres")


func setup(pos: Vector2, dmg: int, bspeed: float, rng: float, life: float, tint: Color) -> void:
	global_position = pos
	damage = dmg
	bullet_speed = bspeed
	range = rng
	_life = life
	color = tint


func _ready() -> void:
	z_index = -1   # 지면 설치물 — 유닛 아래
	# 발밑 그림자(설치물에도 존재감) — 스프라이트보다 먼저 추가해 아래에 깔린다.
	_shadow = Sprite2D.new()
	_shadow.texture = _SHADOW_TEX
	_shadow.z_index = -1
	_shadow.modulate = Color(0.03, 0.05, 0.07, 0.72)
	add_child(_shadow)
	_spr = Sprite2D.new()
	_spr.scale = Vector2(SPR_SCALE, SPR_SCALE)
	add_child(_spr)
	_update_sprite()
	_fit_shadow()
	# 설치 순간 바닥에서 묵직하게 올라온다. 노드 전체를 키워 그림자와 본체가 함께 안착한다.
	scale = Vector2.ONE * 0.72
	modulate.a = 0.0
	var deploy := create_tween()
	deploy.set_parallel(true)
	deploy.tween_property(self, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	deploy.tween_property(self, "modulate:a", 1.0, 0.12)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	_spr.modulate.a = clampf(_life / 0.8, 0.0, 1.0)   # 수명 종료 직전 서서히 사라짐
	var target := _nearest_zombie()
	_track_target(target, delta)
	if target != null:
		_aim = (_lead_position(target, global_position) - global_position).normalized()
		_update_sprite()
	_t += delta
	if _t >= FIRE_INTERVAL and target != null:
		_t = 0.0
		_fire(target)


## 조준 각도를 8분할해 방향 스프라이트를 고르고, 필요 시 좌우 반전한다.
func _update_sprite() -> void:
	var oct := int(round(_aim.angle() / (PI / 4.0)))
	oct = ((oct % 8) + 8) % 8
	if oct == _oct:
		return
	_oct = oct
	var e: Array = _DIR[oct]
	_spr.texture = _TEX[int(e[0])]
	_spr.scale.x = SPR_SCALE * (-1.0 if e[1] else 1.0)


## 터렛 스프라이트 폭에 맞춘 납작한 타원 그림자를 발밑에 배치(shadow.png 128x72).
func _fit_shadow() -> void:
	if _spr.texture == null:
		return
	var tex: Vector2 = _spr.texture.get_size()
	var sx: float = (tex.x * SPR_SCALE * 1.28) / 128.0
	_shadow.scale = Vector2(sx, sx * 0.46)
	_shadow.position = Vector2(0.0, tex.y * SPR_SCALE * 0.40)


func _fire(target: Node2D) -> void:
	_aim = (_lead_position(target, global_position) - global_position).normalized()
	_update_sprite()
	var texture_index := int(_DIR[_oct][0])
	var muzzle_local: Vector2 = _MUZZLES[texture_index][_barrel] - _spr.texture.get_size() * 0.5
	var muzzle_world := _spr.to_global(muzzle_local)
	var shot_direction := (_lead_position(target, muzzle_world) - muzzle_world).normalized()
	_barrel = 1 - _barrel
	var b := Pool.acquire(BULLET, Events.fx_layer())
	b.global_position = muzzle_world
	b.direction = shot_direction
	b.rotation = shot_direction.angle() + PI / 2
	b.speed = bullet_speed
	b.damage = damage
	b.is_crit = false
	b.scale = Vector2.ONE * 0.9
	b.trail_color = color
	b.pierce = 0
	b.knockback = 0.0
	b.splash_radius = 0.0
	# 선행 조준이 대부분의 이동을 해결하고, 유도는 지그재그·가속으로 생긴 오차만 좁은 범위에서 보정한다.
	b.homing = GUIDANCE_TURN
	b.homing_arc = GUIDANCE_ARC
	b.lock_homing_target(target)
	b.queue_redraw()
	# 포신이 발사 반대 방향으로 짧게 밀렸다 돌아와 작은 화면에서도 발사 주체가 보인다.
	_spr.position = -_aim * 3.5
	var recoil := _spr.create_tween()
	recoil.tween_property(_spr, "position", Vector2.ZERO, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	SoundManager.play("shoot", 0.08, 1.15)


## 같은 표적의 프레임 간 위치 차이로 실제 이동 속도를 추정한다. Zombie는 물리 velocity를 쓰지 않고
## 위치를 직접 갱신하므로 CharacterBody2D.velocity를 읽어서는 선행 조준할 수 없다.
func _track_target(target: Node2D, delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_tracked_target = null
		_target_velocity = Vector2.ZERO
		return
	if target != _tracked_target:
		_tracked_target = target
		_tracked_pos = target.global_position
		_target_velocity = Vector2.ZERO
		return
	var raw := (target.global_position - _tracked_pos) / maxf(delta, 0.001)
	_tracked_pos = target.global_position
	if raw.length_squared() > MAX_TRACKED_SPEED * MAX_TRACKED_SPEED:
		raw = raw.normalized() * MAX_TRACKED_SPEED
	_target_velocity = _target_velocity.lerp(raw, clampf(delta * VELOCITY_RESPONSE, 0.0, 1.0))


## 탄과 표적의 등속 운동 교차 시간을 풀어 표적이 도착할 지점을 반환한다.
func _lead_position(target: Node2D, muzzle: Vector2) -> Vector2:
	var target_pos := target.global_position
	if target != _tracked_target or bullet_speed <= 0.0:
		return target_pos
	var rel := target_pos - muzzle
	var vel := _target_velocity
	var a := vel.length_squared() - bullet_speed * bullet_speed
	var b := 2.0 * rel.dot(vel)
	var c := rel.length_squared()
	var hit_t := -1.0
	if absf(a) < 0.001:
		if absf(b) > 0.001:
			hit_t = -c / b
	else:
		var disc := b * b - 4.0 * a * c
		if disc >= 0.0:
			var root := sqrt(disc)
			var t0 := (-b - root) / (2.0 * a)
			var t1 := (-b + root) / (2.0 * a)
			if t0 > 0.0 and t1 > 0.0:
				hit_t = minf(t0, t1)
			else:
				hit_t = maxf(t0, t1)
	if hit_t <= 0.0:
		hit_t = rel.length() / bullet_speed
	return target_pos + vel * minf(hit_t, MAX_LEAD_TIME)


## 터렛은 매 물리 프레임 조준하고 동시에 여러 대가 설치될 수 있다 — 전수 스캔 대신 반경 질의.
func _nearest_zombie() -> Node2D:
	var nearest: Node2D = null
	var min_d := range * range
	for z in Events.zombies_in_radius(global_position, range):
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		var d := global_position.distance_squared_to(z.global_position)
		if d < min_d:
			min_d = d
			nearest = z
	return nearest
