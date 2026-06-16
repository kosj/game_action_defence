extends Area2D
## 총알: 직선 이동 + 좀비 명중 시 데미지. 수명/명중 시 풀로 반납(재사용).

@export var speed: float = 700.0
@export var damage: int = 1
@export var lifetime: float = 1.5

var direction: Vector2 = Vector2.RIGHT
var _age: float = 0.0
var _alive: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)   # 시그널은 1회만 연결


func on_spawn() -> void:
	_age = 0.0
	_alive = true
	damage = 1 + Events.upgrade_bullet_damage


func on_despawn() -> void:
	_alive = false
	_age = 0.0


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	global_position += direction * speed * delta
	_age += delta
	if _age >= lifetime:   # 화면 밖으로 날아간 총알 회수
		_despawn()
	queue_redraw()


func _draw() -> void:
	if not _alive:
		return
	# 골드(노란 동전)와 헷갈리지 않도록 총알은 적색 계열 트레일로 표현.
	# 로컬 +Y가 진행 방향의 반대쪽(꼬리) — Player._shoot_at() 의 회전식 참고.
	var tail := Vector2(0.0, 16.0)
	draw_line(Vector2.ZERO, tail, Color(1.0, 0.30, 0.10, 0.50), 5.0, true)
	draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.30, 0.10, 0.20))
	draw_circle(Vector2.ZERO,  6.0, Color(1.0, 0.45, 0.15, 0.55))
	draw_circle(Vector2.ZERO,  3.0, Color(1.0, 0.95, 0.75, 0.95))


func _on_body_entered(body: Node) -> void:
	if not _alive:
		return
	if body.is_in_group("zombies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		_despawn()


func _despawn() -> void:
	_alive = false
	Pool.release(self)
