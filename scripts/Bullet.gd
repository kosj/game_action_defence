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

# 글랜싱(스치는) 명중 검출용 원 도형 질의 — 매 프레임 재할당을 피하려 1회만 만든다.
var _circle := CircleShape2D.new()
var _shape_q := PhysicsShapeQueryParameters2D.new()


func _ready() -> void:
	body_entered.connect(_on_body_entered)   # 시그널은 1회만 연결
	_shape_q.shape = _circle
	_shape_q.collision_mask = 2              # 좀비/보스 레이어
	_shape_q.collide_with_areas = false


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
	queue_redraw()


## 명중 누락 방지(특히 빠르거나 작은 총알): 두 방식을 함께 쓴다.
##   ① 레이(직전→현재): 한 프레임에 적을 건너뛰는 터널링 + 적 내부에서 출발하는 경우.
##   ② 원 도형 질의(현재 위치): 선분을 살짝 벗어나 스치는(글랜싱) 겹침.
func _check_swept_hit(from: Vector2, to: Vector2) -> void:
	var space := get_world_2d().direct_space_state

	if from != to:
		var rq := PhysicsRayQueryParameters2D.create(from, to, 2)
		rq.collide_with_areas = false
		rq.hit_from_inside = true   # 적 충돌 도형 안에서 출발해도 명중 인정
		var rhit := space.intersect_ray(rq)
		if not rhit.is_empty():
			var rc = rhit.get("collider")
			if rc and rc.is_in_group("zombies"):
				_resolve_hit(rc, rhit["position"])
				return

	# 총알 발자국(반경 = 충돌 도형 × 스케일 + 여유)만큼 겹친 좀비를 잡는다.
	_circle.radius = 5.0 * scale.x + 4.0
	_shape_q.transform = Transform2D(0.0, to)
	var hits := space.intersect_shape(_shape_q, 1)
	if hits.size() > 0:
		var sc = hits[0].get("collider")
		if sc and sc.is_in_group("zombies"):
			_resolve_hit(sc, to)


func _resolve_hit(c: Node, pos: Vector2) -> void:
	global_position = pos
	if splash_radius > 0.0:
		_splash_hit()
	elif c.has_method("take_damage"):
		c.take_damage(damage)
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
	for z in get_tree().get_nodes_in_group("zombies"):
		if global_position.distance_squared_to(z.global_position) <= r_sq and z.has_method("take_damage"):
			z.take_damage(damage)
	_FXBurst.spawn(get_tree().current_scene, global_position, trail_color, splash_radius, 0.3)


func _despawn() -> void:
	_alive = false
	Pool.release(self)
