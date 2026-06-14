extends Node
## 좀비 스포너: 카메라(=플레이어) 주변 화면 밖 원형 둘레에서 주기적으로 스폰.

const ZOMBIE := preload("res://scenes/Zombie.tscn")

@export var spawn_interval: float = 0.6    # 스폰 간격(초)
@export var max_zombies: int = 80          # 동시 최대 개체 수 (성능 상한)
@export var spawn_margin: float = 80.0     # 화면 가장자리 바깥 여유 거리

var player: Node2D = null
var _accum: float = 0.0


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	_accum += delta
	if _accum >= spawn_interval:
		_accum = 0.0
		_try_spawn()


func _try_spawn() -> void:
	# 상한을 넘으면 스폰 보류 → WebGL 프레임 보호
	if get_tree().get_nodes_in_group("zombies").size() >= max_zombies:
		return
	var z := Pool.acquire(ZOMBIE, get_tree().current_scene)
	z.global_position = _random_spawn_pos()


## 플레이어 기준 화면 대각선 절반 + 여유 만큼 떨어진 원 둘레의 임의 지점
func _random_spawn_pos() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	var radius := vp.length() * 0.5 + spawn_margin
	var angle := randf() * TAU
	return player.global_position + Vector2.from_angle(angle) * radius
