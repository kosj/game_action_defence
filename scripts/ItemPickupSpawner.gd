extends Node
## 필드 아이템 스포너: 보물상자와 체력 회복 아이템을 플레이어 주변에 등장시킨다.
## 동시에 존재하는 미수집 아이템 수를 제한한다("item_pickups" 그룹).

const ITEM_PICKUP := preload("res://scenes/ItemPickup.tscn")

@export var spawn_interval_min: float = 24.0
@export var spawn_interval_max: float = 40.0
@export var max_active: int = 2
@export var spawn_margin: float = 60.0

var player: Node2D = null
var _accum: float = 0.0
var _next_interval: float = 0.0
var _game_over: bool = false
var _boss_active: bool = false


func _ready() -> void:
	# 스폰 주기/상한은 밸런스 테이블(res://data/balance.tres)에서.
	# 위협 등급이 주기를 늘린다(P1-12) — 상자가 귀해진다. 등급 1 은 1.0 배라 기존과 같다.
	var chest_mult := ThreatManager.chest_interval_mult()
	spawn_interval_min = GameData.balance.chest_interval_min * chest_mult
	spawn_interval_max = GameData.balance.chest_interval_max * chest_mult
	max_active = GameData.balance.chest_max_active
	player = get_tree().get_first_node_in_group("player")
	Events.player_died.connect(func(): _game_over = true)
	Events.player_revived.connect(func(): _game_over = false)   # 부활 시 스폰 재개
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.boss_died.connect(func(): _boss_active = false)
	Events.elite_pack.connect(_drop_evochest)                   # 엘리트 팩 → 진화 상자
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
	# 다친 상태에서 30% 확률로 회복 아이템. 만피일 때는 쓸 수 없는 아이템이 슬롯을 막지 않는다.
	var needs_heal := int(player.get("health")) < int(player.get("max_health"))
	p.kind = "heal" if needs_heal and randf() < 0.30 else "chest"
	p.global_position = _random_spawn_pos()


## 엘리트 팩 드롭 진화 상자 — 상시 상한(max_active)과 무관하게 항상 등장(보상 보장).
## 보스 보상은 Boss.gd의 대량 경험치 보석 분수로 일원화한다.
func _drop_evochest() -> void:
	if _game_over or _boss_active or not is_instance_valid(player):
		return
	var p := Pool.acquire(ITEM_PICKUP, get_tree().current_scene)
	p.kind = "evochest"
	p.global_position = _random_spawn_pos()


## 보스전에는 진화 상자를 제공하지 않는다. 전투 직전에 남아 있던 상자도 치워 보스 등장과
## 동시에 주워지는 경우를 막고, 전투가 끝날 때까지 엘리트 드롭 역시 위에서 차단한다.
func _on_boss_spawned(_max_health: int) -> void:
	_boss_active = true
	for pickup in get_tree().get_nodes_in_group("item_pickups"):
		if is_instance_valid(pickup) and String(pickup.get("kind")) == "evochest":
			pickup.call("_despawn")


## 화면 안쪽 ~ 살짝 바깥쪽 사이의 랜덤 위치.
func _random_spawn_pos() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	var dist := randf_range(vp.length() * 0.18, vp.length() * 0.55 + spawn_margin)
	var angle := randf() * TAU
	var pos := player.global_position + Vector2.from_angle(angle) * dist
	return SuburbLayout.safe(pos) if SuburbWorld.supports(ThemeManager.selected_id()) else pos
