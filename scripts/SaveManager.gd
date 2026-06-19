extends Node
## 로컬 저장 관리 (Autoload 싱글톤: "SaveManager").
## 체크포인트(웨이브 시작 지점) 기준으로 저장 — 진행 중인 좀비/투사체 상태는 저장하지 않는다.
## 이어하기는 마지막 체크포인트의 골드/업그레이드/체력/장착 무기로 새 웨이브를 시작한다.

const SAVE_PATH := "user://save.json"
const HIGHSCORE_PATH := "user://highscore.save"   # 체크포인트와 분리 — 사망해도 유지
const DIFFICULTY_PATH := "user://difficulty.save" # 난이도 설정 — 세션 간 보존

var pending_continue: bool = false
var pending_player_health: int = 1
var pending_weapon_id: String = "pistol"
var pending_weapon_tier_id: String = "common"


func _ready() -> void:
	# 시작 시 최고 점수를 불러와 Events 에 주입 (autoload 순서상 Events 는 이미 준비됨)
	Events.set_high_score(_read_high_score())
	# 저장된 난이도 설정 복원 (없으면 Normal)
	Events.difficulty = _read_difficulty()
	# 사망/판 종료 시 최고 점수를 디스크에 보존
	Events.player_died.connect(save_high_score)


func save_difficulty() -> void:
	var f := FileAccess.open(DIFFICULTY_PATH, FileAccess.WRITE)
	if f:
		f.store_string(str(Events.difficulty))
		f.close()


func _read_difficulty() -> int:
	if not FileAccess.file_exists(DIFFICULTY_PATH):
		return 1   # 기본값: Normal
	var f := FileAccess.open(DIFFICULTY_PATH, FileAccess.READ)
	if not f:
		return 1
	var text := f.get_as_text().strip_edges()
	f.close()
	return clampi(int(text), 0, 2) if text.is_valid_int() else 1


func save_high_score() -> void:
	var f := FileAccess.open(HIGHSCORE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(str(Events.high_score))
		f.close()


func _read_high_score() -> int:
	if not FileAccess.file_exists(HIGHSCORE_PATH):
		return 0
	var f := FileAccess.open(HIGHSCORE_PATH, FileAccess.READ)
	if not f:
		return 0
	var text := f.get_as_text().strip_edges()
	f.close()
	return int(text) if text.is_valid_int() else 0


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


## 웨이브 클리어/상점 종료/무기 획득 시점에 호출 — player 의 현재 체력·무기를 기록.
func save_game(player: Node) -> void:
	var data := {
		"total_gold": Events.total_gold,
		"total_kills": Events.total_kills,
		"score": Events.score,
		"current_wave": Events.current_wave,
		"elapsed_time": Events.elapsed_time,
		"player_health": player.health,
		"upgrade_speed": Events.upgrade_speed,
		"upgrade_atk_speed": Events.upgrade_atk_speed,
		"upgrade_bullet_damage": Events.upgrade_bullet_damage,
		"upgrade_orb_damage": Events.upgrade_orb_damage,
		"upgrade_lightning_damage": Events.upgrade_lightning_damage,
		"upgrade_max_health": Events.upgrade_max_health,
		"upgrade_multi_bullet": Events.upgrade_multi_bullet,
		"upgrade_orbs": Events.upgrade_orbs,
		"upgrade_lightning": Events.upgrade_lightning,
		"weapon_id": player.current_weapon.get("id", "pistol"),
		"weapon_tier_id": player.current_weapon.get("tier_id", "common"),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()


func load_save() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


## 씬 전환 전(MainMenu) 호출 — Events 전역 상태를 복원하고, Main 씬이 로드되면
## Player 가 소비할 보류 상태(체력/무기)를 채워둔다.
func apply_to_events(data: Dictionary) -> void:
	Events.reset()
	Events.total_gold = data.get("total_gold", 0)
	Events.total_kills = data.get("total_kills", 0)
	Events.score = data.get("score", 0)
	Events.current_wave = data.get("current_wave", 1)
	Events.elapsed_time = data.get("elapsed_time", 0.0)
	Events.upgrade_speed = data.get("upgrade_speed", 0)
	Events.upgrade_atk_speed = data.get("upgrade_atk_speed", 0)
	Events.upgrade_bullet_damage = data.get("upgrade_bullet_damage", 0)
	Events.upgrade_orb_damage = data.get("upgrade_orb_damage", 0)
	Events.upgrade_lightning_damage = data.get("upgrade_lightning_damage", 0)
	Events.upgrade_max_health = data.get("upgrade_max_health", 0)
	Events.upgrade_multi_bullet = data.get("upgrade_multi_bullet", 0)
	Events.upgrade_orbs = data.get("upgrade_orbs", 0)
	Events.upgrade_lightning = data.get("upgrade_lightning", 0)
	Events.gold_changed.emit(Events.total_gold)
	Events.score_changed.emit(Events.score)

	pending_continue = true
	pending_player_health = data.get("player_health", 1)
	pending_weapon_id = data.get("weapon_id", "pistol")
	pending_weapon_tier_id = data.get("weapon_tier_id", "common")
