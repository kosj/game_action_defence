extends Node2D
## 터렛(설치물): 바닥에 설치되어 수명 동안 사거리 내 최근접 적을 자동 사격한다. 수명이 다하면 자기 해제.
## 월드(current_scene)에 스폰. 총알은 기존 Bullet 풀을 재사용한다.
## 외형: 방향 스프라이트 시트(3x3)를 조준 방향(8분할)에 맞춰 선택, 발사는 포신 끝에서 나간다.

const BULLET := preload("res://scenes/Bullet.tscn")
const FIRE_INTERVAL := 0.5   # 터렛 자체 발사 간격
const MUZZLE_LEN := 15.0     # 발사 위치(포신 끝) — 조준 방향으로 이만큼 앞에서 탄이 나간다
const SPR_SCALE := 0.3

## 방향 스프라이트(3x3 시트에서 잘라낸 셀). 시트가 8방향을 완벽히 담진 않아 실제 그려진 방향에
## 맞춰 매핑: up=idx0, up-right=idx2, left=idx3, down=idx4, right=idx5. (없는 대각은 근접/미러 대체)
const _TEX := [
	preload("res://assets/sprites/turret/turret_0.png"),  # [0] 위(N)
	preload("res://assets/sprites/turret/turret_2.png"),  # [1] 우상(NE)
	preload("res://assets/sprites/turret/turret_3.png"),  # [2] 좌(W)
	preload("res://assets/sprites/turret/turret_4.png"),  # [3] 아래(S)
	preload("res://assets/sprites/turret/turret_5.png"),  # [4] 우(E)
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
var _oct: int = -1


func setup(pos: Vector2, dmg: int, bspeed: float, rng: float, life: float, tint: Color) -> void:
	global_position = pos
	damage = dmg
	bullet_speed = bspeed
	range = rng
	_life = life
	color = tint


func _ready() -> void:
	z_index = -1   # 지면 설치물 — 유닛 아래
	_spr = Sprite2D.new()
	_spr.scale = Vector2(SPR_SCALE, SPR_SCALE)
	add_child(_spr)
	_update_sprite()


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	_spr.modulate.a = clampf(_life / 0.8, 0.0, 1.0)   # 수명 종료 직전 서서히 사라짐
	var target := _nearest_zombie()
	if target != null:
		_aim = (target.global_position - global_position).normalized()
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


func _fire(target: Node2D) -> void:
	_aim = (target.global_position - global_position).normalized()
	var b := Pool.acquire(BULLET, get_tree().current_scene)
	b.global_position = global_position + _aim * MUZZLE_LEN   # 포신 끝에서 발사
	b.direction = _aim
	b.rotation = _aim.angle() + PI / 2
	b.speed = bullet_speed
	b.damage = damage
	b.is_crit = false
	b.scale = Vector2.ONE * 0.9
	b.trail_color = color
	b.pierce = 0
	b.knockback = 0.0
	b.splash_radius = 0.0
	b.queue_redraw()
	SoundManager.play("shoot", 0.08, 1.15)


func _nearest_zombie() -> Node2D:
	var nearest: Node2D = null
	var min_d := range * range
	for z in Events.live_zombies():
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		var d := global_position.distance_squared_to(z.global_position)
		if d < min_d:
			min_d = d
			nearest = z
	return nearest
