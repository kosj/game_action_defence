extends Node2D
## 적 투사체(스피터 좀비가 발사): 직선 이동 + 플레이어 근접 시 피해. 풀로 재사용.
## 충돌 레이어 대신 플레이어와의 거리로 명중을 판정한다(Orb/Lightning 과 동일한 방식).

const _FXBurst := preload("res://scripts/FXBurst.gd")
const MAX_LIFE := 4.0
const HIT_RADIUS := 16.0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 250.0
var damage: int = 1
var color: Color = Color(0.7, 1.0, 0.4)

var _life: float = 0.0
var _alive: bool = false
var _player: Node2D = null


func on_spawn() -> void:
	_life = 0.0
	_alive = true
	_player = get_tree().get_first_node_in_group("player")
	queue_redraw()


func on_despawn() -> void:
	_alive = false


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	global_position += direction * speed * delta
	_life += delta
	if _life >= MAX_LIFE:
		_despawn()
		return
	if is_instance_valid(_player):
		if global_position.distance_squared_to(_player.global_position) < HIT_RADIUS * HIT_RADIUS:
			if _player.has_method("take_hit"):
				_player.take_hit(damage)
			_impact()
			return
	queue_redraw()


func _draw() -> void:
	if not _alive:
		return
	draw_circle(Vector2.ZERO, 9.0, Color(color.r, color.g, color.b, 0.20))
	draw_circle(Vector2.ZERO, 5.5, Color(color.r, color.g, color.b, 0.60))
	draw_circle(Vector2.ZERO, 2.5, Color(1.0, 1.0, 0.9, 0.95))


func _impact() -> void:
	_FXBurst.spawn(get_tree().current_scene, global_position, color, 22.0, 0.22)
	_despawn()


func _despawn() -> void:
	_alive = false
	Pool.release(self)
