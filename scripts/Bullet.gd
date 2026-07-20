extends Area2D
## 총알: 직선 이동 + 좀비 명중 시 데미지(스플래시 무기는 범위 피해). 수명/명중 시 풀로 반납(재사용).
## 외형(색/크기)과 스플래시 반경은 장착 무기에 따라 Player._shoot_at() 에서 매 발 주입된다.

@export var speed: float = 700.0
@export var damage: int = 1
@export var lifetime: float = 1.5

const _FXBurst := preload("res://scripts/FXBurst.gd")

var direction: Vector2 = Vector2.RIGHT
var trail_color: Color = Color(1.0, 0.30, 0.10)
var splash_radius: float = 0.0
var _age: float = 0.0
var _alive: bool = false

const _ZOMBIE_RADIUS := 14.0   # Zombie.tscn 충돌 반경
const _BOSS_RADIUS := 38.0     # Boss.tscn 충돌 반경
const _KNOCKBACK := 135.0      # 직격 시 좀비를 진행 방향으로 살짝 밀어내는 세기(타격감)


func _ready() -> void:
	body_entered.connect(_on_body_entered)   # 시그널은 1회만 연결(보조 경로)


func on_spawn() -> void:
	_age = 0.0
	_alive = true
	scale = Vector2.ONE
	trail_color = Color(1.0, 0.30, 0.10)
	splash_radius = 0.0


func on_despawn() -> void:
	_alive = false
	_age = 0.0


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	var from := global_position
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
	for z in Events.live_zombies():
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
			return


func _resolve_hit(c: Node, pos: Vector2) -> void:
	global_position = pos
	if splash_radius > 0.0:
		_splash_hit()
	elif c.has_method("take_damage"):
		c.take_damage(damage)
		if c.has_method("apply_knockback"):   # 좀비만 넉백(보스는 메서드가 없어 면역)
			c.apply_knockback(direction, _KNOCKBACK)
	_despawn()


func _draw() -> void:
	if not _alive:
		return
	# 골드(노란 동전)와 헷갈리지 않도록 총알은 무기 색조의 트레일로 표현.
	# 로컬 +Y가 진행 방향의 반대쪽(꼬리) — Player._shoot_at() 의 회전식 참고.
	var mid := trail_color.lightened(0.25)
	var tail := Vector2(0.0, 16.0)
	draw_line(Vector2.ZERO, tail, Color(trail_color.r, trail_color.g, trail_color.b, 0.50), 5.0, true)
	draw_circle(Vector2.ZERO, 10.0, Color(trail_color.r, trail_color.g, trail_color.b, 0.20))
	draw_circle(Vector2.ZERO,  6.0, Color(mid.r, mid.g, mid.b, 0.55))
	draw_circle(Vector2.ZERO,  3.0, Color(1.0, 0.95, 0.85, 0.95))


func _on_body_entered(body: Node) -> void:
	if not _alive:
		return
	if body.is_in_group("zombies"):
		if splash_radius > 0.0:
			_splash_hit()
		elif body.has_method("take_damage"):
			body.take_damage(damage)
		_despawn()


## 폭발형 무기: 명중 지점 주변의 모든 좀비에게 피해 + 확산 이펙트.
func _splash_hit() -> void:
	var r_sq := splash_radius * splash_radius
	for z in Events.live_zombies():
		if not is_instance_valid(z):
			continue
		if global_position.distance_squared_to(z.global_position) <= r_sq and z.has_method("take_damage"):
			z.take_damage(damage)
	_FXBurst.spawn(get_tree().current_scene, global_position, trail_color, splash_radius, 0.3)


func _despawn() -> void:
	_alive = false
	Pool.release(self)
