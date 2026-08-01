extends Node
## 테마 기믹 스포너: 선택 테마(ThemeManager)의 gimmick_key 에 맞는 필드 위험물을 주기적으로 스폰한다.
## 교외=가스통 / 도심=낙석 / 연구소=독가스 웅덩이. 기믹 키가 없거나 알 수 없으면 아무것도 안 한다.

const _CLASSES := {
	"gas_can": preload("res://scripts/GasCan.gd"),
	"falling_debris": preload("res://scripts/FallingDebris.gd"),
	"toxic_pool": preload("res://scripts/ToxicPool.gd"),
}

const INTERVAL_MIN := 6.0
const INTERVAL_MAX := 10.0
const MAX_ACTIVE := 3
const SPAWN_MIN := 90.0    # 플레이어로부터 스폰 거리 범위
const SPAWN_MAX := 320.0

var _cls: GDScript = null
var player: Node2D = null
var _accum: float = 0.0
var _next: float = 0.0
var _start_delay: float = 8.0   # 초반 유예(첫 좀비 물결 이후부터)
var _game_over: bool = false
var _active: Array = []


func _ready() -> void:
	var t: ThemeData = ThemeManager.selected()
	var key: String = t.gimmick_key if t != null else ""
	_cls = _CLASSES.get(key)
	player = get_tree().get_first_node_in_group("player")
	Events.player_died.connect(func(): _game_over = true)
	Events.player_revived.connect(func(): _game_over = false)
	_next = randf_range(INTERVAL_MIN, INTERVAL_MAX)


func _process(delta: float) -> void:
	if _cls == null or _game_over:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	if _start_delay > 0.0:
		_start_delay -= delta
		return
	_active = _active.filter(func(h): return is_instance_valid(h))
	_accum += delta
	if _accum >= _next and _active.size() < MAX_ACTIVE:
		_accum = 0.0
		_next = randf_range(INTERVAL_MIN, INTERVAL_MAX)
		_spawn()


func _spawn() -> void:
	var h: Node2D = _cls.new()
	get_tree().current_scene.add_child(h)
	var dist := randf_range(SPAWN_MIN, SPAWN_MAX)
	h.global_position = player.global_position + Vector2.from_angle(randf() * TAU) * dist
	_active.append(h)
