extends Area2D
## 골드: 플레이어가 자석 범위 안에 들어오면 빨려 들어가며, 가까워질수록 가속.
## 충돌 콜백 대신 거리 계산으로 처리 → Area 모니터링 비용 제거.

@export var magnet_radius: float = 130.0   # 이 거리부터 끌려오기 시작
@export var collect_radius: float = 22.0   # 이 거리에서 수집
@export var move_speed: float = 420.0
@export var value: int = 1

var player: Node2D = null


func _ready() -> void:
	monitoring = false
	monitorable = false
	player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	var dist := global_position.distance_to(player.global_position)
	if dist <= collect_radius:
		_collect()
		return

	if dist <= magnet_radius:
		var dir := (player.global_position - global_position).normalized()
		# 가까울수록 빨라지는 자석 감각 (0.3 ~ 1.3 배)
		var t := 1.0 - (dist / magnet_radius)
		global_position += dir * move_speed * (0.3 + t) * delta


func _collect() -> void:
	Events.add_gold(value)
	queue_free()
