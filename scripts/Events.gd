extends Node
## 전역 이벤트 버스 / 재화·체력·웨이브 관리 (Autoload 싱글톤: "Events")

signal gold_changed(total: int)
signal player_health_changed(health: int, max_health: int)
signal player_died
signal wave_changed(wave: int)
signal elapsed_changed(seconds: float)

var total_gold: int = 0
var player_health: int = 0
var player_max_health: int = 0
var current_wave: int = 1
var elapsed_time: float = 0.0


func add_gold(amount: int = 1) -> void:
	total_gold += amount
	gold_changed.emit(total_gold)


func update_player_health(health: int, max_health: int) -> void:
	player_health = health
	player_max_health = max_health
	player_health_changed.emit(health, max_health)


func reset() -> void:
	total_gold = 0
	player_health = 0
	player_max_health = 0
	current_wave = 1
	elapsed_time = 0.0
	gold_changed.emit(total_gold)
