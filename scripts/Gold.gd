extends Area2D
## 골드: 플레이어가 자석 범위 안에 들어오면 빨려 들어가며, 가까워질수록 가속.
## 거리 계산만 사용(충돌 콜백 없음). 수집 시 풀로 반납(재사용).

@export var magnet_radius: float = 130.0
@export var collect_radius: float = 22.0
@export var move_speed: float = 420.0
@export var value: int = 1

var player: Node2D = null
var _alive: bool = false


func _ready() -> void:
	monitoring = false
	monitorable = false


func on_spawn() -> void:
	_alive = true
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")


func on_despawn() -> void:
	_alive = false


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	var dist := global_position.distance_to(player.global_position)
	if dist <= collect_radius:
		_collect()
		return
	if dist <= magnet_radius:
		var dir := (player.global_position - global_position).normalized()
		var t := 1.0 - (dist / magnet_radius)   # 가까울수록 가속
		global_position += dir * move_speed * (0.3 + t) * delta


func _collect() -> void:
	_alive = false
	Events.add_gold(value)
	Pool.release(self)
