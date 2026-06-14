extends Area2D
## 총알: 직선 이동 + 좀비 명중 시 데미지. 수명 지나면 자동 소멸.

@export var speed: float = 700.0
@export var damage: int = 1
@export var lifetime: float = 1.5

var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# 화면 밖으로 날아간 총알이 영원히 살지 않도록 수명 제한
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("zombies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
