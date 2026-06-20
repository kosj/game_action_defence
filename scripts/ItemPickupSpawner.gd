extends Node
## 필드 아이템 스포너(골드 자석 등) — 무기 픽업보다 드물게 플레이어 주변에 등장시킨다.
## 동시에 존재하는 미수집 아이템 수를 제한한다("item_pickups" 그룹).

const ITEM_PICKUP := preload("res://scenes/ItemPickup.tscn")

@export var spawn_interval_min: float = 26.0
@export var spawn_interval_max: float = 40.0
@export var max_active: int = 1
@export var spawn_margin: float = 60.0

var player: Node2D = null
var _accum: float = 0.0
var _next_interval: float = 0.0
var _game_over: bool = false


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	Events.player_died.connect(func(): _game_over = true)
	_next_interval = randf_range(spawn_interval_min, spawn_interval_max)


func _process(delta: float) -> void:
	if _game_over:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	_accum += delta
	if _accum < _next_interval:
		return
	if get_tree().get_nodes_in_group("item_pickups").size() >= max_active:
		return

	_accum = 0.0
	_next_interval = randf_range(spawn_interval_min, spawn_interval_max)
	_spawn_item()


func _spawn_item() -> void:
	var p := Pool.acquire(ITEM_PICKUP, get_tree().current_scene)
	p.global_position = _random_spawn_pos()


## 화면 안쪽 ~ 살짝 바깥쪽 사이의 랜덤 위치.
func _random_spawn_pos() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	var dist := randf_range(vp.length() * 0.18, vp.length() * 0.55 + spawn_margin)
	var angle := randf() * TAU
	return player.global_position + Vector2.from_angle(angle) * dist
