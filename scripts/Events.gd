extends Node
## 전역 이벤트 버스 / 재화·체력·웨이브·업그레이드 관리 (Autoload 싱글톤: "Events")

signal gold_changed(total: int)
signal player_health_changed(health: int, max_health: int)
signal player_died
signal wave_changed(wave: int)
signal elapsed_changed(seconds: float)
signal wave_complete(wave: int)
signal wave_progress_changed(killed: int, total: int)
signal zombie_killed
signal shop_closed

var total_gold: int = 0
var player_health: int = 0
var player_max_health: int = 0
var current_wave: int = 1
var elapsed_time: float = 0.0
var wave_kill_progress: int = 0
var wave_kill_total: int = 0

# 업그레이드 레벨 (0 = 미구매)
var upgrade_speed: int = 0
var upgrade_atk_speed: int = 0
var upgrade_bullet_damage: int = 0
var upgrade_orb_damage: int = 0
var upgrade_lightning_damage: int = 0
var upgrade_max_health: int = 0
var upgrade_multi_bullet: int = 0
var upgrade_orbs: int = 0
var upgrade_lightning: int = 0


func add_gold(amount: int = 1) -> void:
	total_gold += amount
	gold_changed.emit(total_gold)


func spend_gold(amount: int) -> bool:
	if total_gold < amount:
		return false
	total_gold -= amount
	gold_changed.emit(total_gold)
	return true


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
	wave_kill_progress = 0
	wave_kill_total = 0
	upgrade_speed = 0
	upgrade_atk_speed = 0
	upgrade_bullet_damage = 0
	upgrade_orb_damage = 0
	upgrade_lightning_damage = 0
	upgrade_max_health = 0
	upgrade_multi_bullet = 0
	upgrade_orbs = 0
	upgrade_lightning = 0
	gold_changed.emit(total_gold)
