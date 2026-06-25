extends Node
## 무기 픽업 스포너: 일정 주기로 플레이어 주변 랜덤 위치에 무기 아이템을 등장시킨다.
## 동시에 존재하는 미수집 픽업 수를 제한해 화면이 어수선해지지 않게 한다.

const WEAPON_PICKUP := preload("res://scenes/WeaponPickup.tscn")
const _WeaponDB := preload("res://scripts/WeaponDB.gd")

@export var spawn_interval_min: float = 14.0
@export var spawn_interval_max: float = 22.0
@export var max_active: int = 2
@export var spawn_margin: float = 60.0

var player: Node2D = null
var _accum: float = 0.0
var _next_interval: float = 0.0
var _game_over: bool = false


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	Events.player_died.connect(func(): _game_over = true)
	Events.player_revived.connect(func(): _game_over = false)   # 부활 시 스폰 재개
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
	if get_tree().get_nodes_in_group("weapon_pickups").size() >= max_active:
		return

	_accum = 0.0
	_next_interval = randf_range(spawn_interval_min, spawn_interval_max)
	_spawn_pickup()


func _spawn_pickup() -> void:
	var p := Pool.acquire(WEAPON_PICKUP, get_tree().current_scene)
	p.global_position = _random_spawn_pos()
	p.setup(_WeaponDB.roll_pickup())


## 화면 안쪽 ~ 살짝 바깥쪽 사이의 랜덤 위치 — 탐색 동기는 주되 너무 멀지 않게.
func _random_spawn_pos() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	var dist := randf_range(vp.length() * 0.18, vp.length() * 0.55 + spawn_margin)
	var angle := randf() * TAU
	return player.global_position + Vector2.from_angle(angle) * dist
