extends Node
## 좀비 스포너: 킬카운트 기반 웨이브. 웨이브 총 킬수 달성 시 wave_complete 신호 발생.

const ZOMBIE := preload("res://scenes/Zombie.tscn")

@export var spawn_margin: float = 80.0

## 웨이브 테이블: total=이 웨이브에서 처치해야 할 총 좀비 수, max_z=최대 동시 출현 수
const WAVES: Array = [
	{"total": 20,  "max_z": 8,  "interval": 0.9,  "weights": [10, 0, 0]},
	{"total": 30,  "max_z": 12, "interval": 0.70, "weights": [8,  2, 0]},
	{"total": 45,  "max_z": 16, "interval": 0.55, "weights": [6,  3, 1]},
	{"total": 60,  "max_z": 20, "interval": 0.45, "weights": [5,  3, 2]},
	{"total": 80,  "max_z": 25, "interval": 0.35, "weights": [4,  4, 2]},
	{"total": 100, "max_z": 30, "interval": 0.25, "weights": [3,  4, 3]},
]

## 인덱스 0=기본(흰색), 1=빠른(노란색), 2=탱커(보라색). score=처치 점수.
const ZOMBIE_TYPES: Array = [
	{"speed": 65,  "max_health": 3, "modulate": Color(1.0, 1.0, 1.0), "score": 10},
	{"speed": 130, "max_health": 1, "modulate": Color(1.0, 0.9, 0.3), "score": 15},
	{"speed": 40,  "max_health": 8, "modulate": Color(0.75, 0.5, 1.0), "score": 30},
]

var player: Node2D = null
var _accum: float = 0.0
var _elapsed: float = 0.0
var _last_second: int = -1
var _wave_idx: int = 0     # 설정 테이블 인덱스 (최대 WAVES.size()-1 로 고정)
var _wave_num: int = 1     # 표시용 웨이브 번호 (계속 증가)
var _spawned: int = 0      # 현재 웨이브에서 스폰한 수
var _killed: int = 0       # 현재 웨이브에서 처치한 수
var _wave_active: bool = false
var _game_over: bool = false
var _start_delay: float = 5.0   # first-wave spawn delay matches player grace period


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	Events.player_died.connect(func(): _game_over = true)
	Events.zombie_killed.connect(_on_zombie_killed)
	Events.shop_closed.connect(_start_wave)
	# 이어하기 시 저장된 웨이브/경과시간부터 재개 (새 게임은 Events.reset() 직후라 1 / 0.0).
	_elapsed = Events.elapsed_time
	_wave_num = Events.current_wave
	_wave_idx = mini(_wave_num - 1, WAVES.size() - 1)
	_start_wave()


func _start_wave() -> void:
	_spawned = 0
	_killed = 0
	_accum = 0.0
	_wave_active = true
	var total: int = WAVES[_wave_idx]["total"]
	Events.current_wave = _wave_num
	Events.wave_kill_progress = 0
	Events.wave_kill_total = total
	Events.wave_changed.emit(_wave_num)
	Events.wave_progress_changed.emit(0, total)


func _process(delta: float) -> void:
	if _game_over:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	_elapsed += delta
	_tick_elapsed()

	if not _wave_active:
		return

	var wave: Dictionary = WAVES[_wave_idx]

	# 아직 스폰할 좀비가 남아있으면 스폰 시도
	if _spawned < wave["total"]:
		if _start_delay > 0.0:
			_start_delay -= delta
		else:
			_accum += delta
			if _accum >= wave["interval"]:
				var alive := get_tree().get_nodes_in_group("zombies").size()
				if alive < wave["max_z"]:
					_accum = 0.0
					_try_spawn()

	# 총 처치 수 달성 → 웨이브 클리어
	if _killed >= wave["total"]:
		_wave_complete()


func _tick_elapsed() -> void:
	var sec := int(_elapsed)
	if sec != _last_second:
		_last_second = sec
		Events.elapsed_time = _elapsed
		Events.elapsed_changed.emit(_elapsed)


func _on_zombie_killed() -> void:
	if not _wave_active:
		return
	_killed += 1
	Events.total_kills += 1
	Events.wave_kill_progress = _killed
	Events.wave_progress_changed.emit(_killed, WAVES[_wave_idx]["total"])


func _wave_complete() -> void:
	_wave_active = false
	Events.wave_complete.emit(_wave_num)
	_wave_num += 1
	_wave_idx = mini(_wave_idx + 1, WAVES.size() - 1)


func _try_spawn() -> void:
	if not is_instance_valid(player):
		return
	var wave: Dictionary = WAVES[_wave_idx]
	var z := Pool.acquire(ZOMBIE, get_tree().current_scene)
	z.global_position = _random_spawn_pos()
	z.setup(_pick_type(wave["weights"]))
	_spawned += 1


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
