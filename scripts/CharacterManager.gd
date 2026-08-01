extends Node
## 캐릭터 선택 관리 (Autoload "CharacterManager").
## 선택한 캐릭터 id 를 디스크(user://character.save)에 보존하고, 런 시작 시 시작 무기·시그니처 패시브·
## 시작 스탯 보정을 제공한다. 데이터는 GameData.characters(character_db.tres).

const SAVE_PATH := "user://character.save"

var _selected_id: String = ""
var _bought: Dictionary = {}   # 구매 해금된 캐릭터 id 집합


func _ready() -> void:
	_load()


## 캐릭터 해금 여부 — ① 게이트 없음(무료) ② 짝꿍 도전과제 달성 ③ 메타 골드로 구매함.
func is_unlocked(c: CharacterData) -> bool:
	if c == null:
		return false
	if c.unlock_cost <= 0 and c.unlock_achievement == "":
		return true
	if c.unlock_achievement != "" and AchievementManager.is_unlocked(c.unlock_achievement):
		return true
	return _bought.has(c.id)


## 구매 해금 시도 — 구매 게이트(cost>0)이고 잔액 충분하면 메타 골드 차감 후 해금.
func try_buy(id: String) -> bool:
	var c: CharacterData = GameData.character(id)
	if c == null or is_unlocked(c) or c.unlock_cost <= 0:
		return false
	if not MetaManager.spend_meta(c.unlock_cost):
		return false
	_bought[id] = true
	_save()
	return true


## 현재 선택 캐릭터. 저장값이 무효/잠금이면 해금된 첫 캐릭터로 폴백(런 안정성).
func selected() -> CharacterData:
	var list := GameData.characters
	if list.is_empty():
		return null
	for c in list:
		if c != null and c.id == _selected_id and is_unlocked(c):
			return c
	for c in list:
		if c != null and is_unlocked(c):
			return c
	return list[0]


func selected_id() -> String:
	var c := selected()
	return c.id if c != null else ""


## 해금된 캐릭터만 선택 가능.
func select(id: String) -> bool:
	var c: CharacterData = GameData.character(id)
	if c == null or not is_unlocked(c):
		return false
	_selected_id = id
	_save()
	return true


func start_weapon() -> String:
	var c := selected()
	return c.start_weapon if c != null else ""


func signature_passive() -> String:
	var c := selected()
	return c.signature_passive if c != null else ""


## ItemDB.recompute 말미에 호출 — 캐릭터 시작 스탯 보정을 upgrade_* 에 더한다(패시브/무기 위에 얹힘).
func add_bonuses() -> void:
	var c := selected()
	if c == null:
		return
	Events.upgrade_max_health += c.bonus_max_health
	Events.upgrade_bullet_damage += c.bonus_bullet_damage
	Events.upgrade_speed += c.bonus_move_speed
	Events.upgrade_atk_speed += c.bonus_atk_speed
	Events.upgrade_area += c.bonus_area
	Events.upgrade_crit += c.bonus_crit
	Events.upgrade_greed += c.bonus_greed


## 설치물(터렛/드론/지뢰) 강화 배수 — 엔지니어 트레잇. 다른 캐릭터는 1.0.
func install_boost() -> float:
	var c := selected()
	return 1.5 if (c != null and c.trait_key == "engineer") else 1.0


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_selected_id = str(parsed.get("id", ""))
		var b = parsed.get("bought", [])
		if typeof(b) == TYPE_ARRAY:
			for id in b:
				_bought[str(id)] = true


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"id": _selected_id, "bought": _bought.keys()}))
		f.close()
