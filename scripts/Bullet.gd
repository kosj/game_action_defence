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
	damage = 1 + Events.upgrade_damage


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
	draw_circle(Vector2.ZERO, 14.0, Color(1.0, 0.80, 0.15, 0.20))
	draw_circle(Vector2.ZERO,  8.0, Color(1.0, 0.92, 0.35, 0.55))
	draw_circle(Vector2.ZERO,  3.5, Color(1.0, 1.0,  0.85, 0.90))


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
