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
signal weapon_equipped(stats: Dictionary)
signal score_changed(score: int)
signal high_score_changed(high_score: int)
signal boss_spawned(max_health: int)
signal boss_health_changed(health: int, max_health: int)
signal boss_died

var total_gold: int = 0
var total_kills: int = 0
var player_health: int = 0
var player_max_health: int = 0
var current_wave: int = 1
var elapsed_time: float = 0.0
var wave_kill_progress: int = 0
var wave_kill_total: int = 0

# 점수: score=이번 판 점수, high_score=저장된 최고점, _prev_high=이번 판 시작 시점 최고점(갱신 판정용)
var score: int = 0
var high_score: int = 0
var _prev_high: int = 0

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


## 좀비 처치 등으로 점수 획득. 최고점 초과 시 즉시(실시간) 최고점도 갱신.
func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)
	if score > high_score:
		high_score = score
		high_score_changed.emit(high_score)


## 디스크에서 불러온 최고점을 주입(시작 시 SaveManager 가 호출).
func set_high_score(value: int) -> void:
	high_score = value
	_prev_high = value
	high_score_changed.emit(high_score)


## 이번 판이 기존 최고점을 새로 갱신했는지(신기록 여부).
func is_new_record() -> bool:
	return score > _prev_high and score > 0


func reset() -> void:
	total_gold = 0
	total_kills = 0
	player_health = 0
	player_max_health = 0
	current_wave = 1
	elapsed_time = 0.0
	wave_kill_progress = 0
	wave_kill_total = 0
	score = 0
	_prev_high = high_score   # 이번 판이 깨야 할 기준점 = 현재 최고점 (high_score 는 유지)
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
	score_changed.emit(score)
