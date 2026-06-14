extends Node
## 좀비 스포너: 시간 기반 웨이브 테이블로 스폰 간격·종류·난이도를 단계적으로 상승.

const ZOMBIE := preload("res://scenes/Zombie.tscn")

@export var spawn_margin: float = 80.0   # 화면 가장자리 바깥 여유 거리

## 웨이브 테이블: from(초) 이후 이 행이 적용됨.
## weights = [기본, 빠른, 탱커] 정수 비중 (총합 기준 rng)
const WAVES: Array = [
	{"from": 0,   "interval": 0.8,  "max_z": 30,  "weights": [10, 0, 0]},
	{"from": 30,  "interval": 0.6,  "max_z": 50,  "weights": [8,  2, 0]},
	{"from": 60,  "interval": 0.45, "max_z": 70,  "weights": [6,  3, 1]},
	{"from": 90,  "interval": 0.35, "max_z": 90,  "weights": [5,  3, 2]},
	{"from": 120, "interval": 0.25, "max_z": 110, "weights": [4,  4, 2]},
	{"from": 180, "interval": 0.2,  "max_z": 120, "weights": [3,  4, 3]},
]

## 인덱스 0=기본(흰색), 1=빠른(노란색), 2=탱커(보라색)
const ZOMBIE_TYPES: Array = [
	{"speed": 65,  "max_health": 3, "modulate": Color(1.0, 1.0, 1.0)},
	{"speed": 130, "max_health": 1, "modulate": Color(1.0, 0.9, 0.3)},
	{"speed": 40,  "max_health": 8, "modulate": Color(0.75, 0.5, 1.0)},
]

var player: Node2D = null
var _accum: float = 0.0
var _elapsed: float = 0.0
var _wave_idx: int = 0
var _last_second: int = -1
var _game_over: bool = false


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	Events.player_died.connect(func(): _game_over = true)


func _process(delta: float) -> void:
	if _game_over:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	_elapsed += delta
	_tick_elapsed()
	_update_wave()

	_accum += delta
	if _accum >= WAVES[_wave_idx]["interval"]:
		_accum = 0.0
		_try_spawn()


func _tick_elapsed() -> void:
	var sec := int(_elapsed)
	if sec != _last_second:
		_last_second = sec
		Events.elapsed_time = _elapsed
		Events.elapsed_changed.emit(_elapsed)


func _update_wave() -> void:
	var next := _wave_idx + 1
	if next < WAVES.size() and _elapsed >= WAVES[next]["from"]:
		_wave_idx = next
		Events.current_wave = _wave_idx + 1
		Events.wave_changed.emit(_wave_idx + 1)


func _try_spawn() -> void:
	var wave: Dictionary = WAVES[_wave_idx]
	if get_tree().get_nodes_in_group("zombies").size() >= wave["max_z"]:
		return
	var z := Pool.acquire(ZOMBIE, get_tree().current_scene)
	z.global_position = _random_spawn_pos()
	z.setup(_pick_type(wave["weights"]))


func _pick_type(weights: Array) -> Dictionary:
	var total: int = 0
	for w in weights:
		total += w
	var roll := randi() % total
	var cum := 0
	for i in weights.size():
		cum += weights[i]
		if roll < cum:
			return ZOMBIE_TYPES[i]
	return ZOMBIE_TYPES[0]


func _random_spawn_pos() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	var radius := vp.length() * 0.5 + spawn_margin
	var angle := randf() * TAU
	return player.global_position + Vector2.from_angle(angle) * radius
