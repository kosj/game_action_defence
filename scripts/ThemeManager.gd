extends Node
## 아레나 테마 선택/해금 관리 (Autoload "ThemeManager").
## 선택 테마 id 와 구매 해금 상태를 user://theme.save 에 보존한다. 데이터는 GameData.themes(themes.tres).
## 해금 규칙은 캐릭터와 동일: 게이트 없음 ∨ 짝꿍 도전과제 ∨ 구매.

const SAVE_PATH := "user://theme.save"

var _selected_id: String = ""
var _bought: Dictionary = {}


func _ready() -> void:
	_load()


func is_unlocked(t: ThemeData) -> bool:
	if t == null:
		return false
	if t.unlock_cost <= 0 and t.unlock_achievement == "":
		return true
	if t.unlock_achievement != "" and AchievementManager.is_unlocked(t.unlock_achievement):
		return true
	return _bought.has(t.id)


func try_buy(id: String) -> bool:
	var t: ThemeData = _by_id(id)
	if t == null or is_unlocked(t) or t.unlock_cost <= 0:
		return false
	if not MetaManager.spend_meta(t.unlock_cost):
		return false
	_bought[id] = true
	_save()
	return true


## 현재 선택 테마. 무효/잠금이면 해금된 첫 테마로 폴백.
func selected() -> ThemeData:
	var list := GameData.themes
	if list.is_empty():
		return null
	for t in list:
		if t != null and t.id == _selected_id and is_unlocked(t):
			return t
	for t in list:
		if t != null and is_unlocked(t):
			return t
	return list[0]


func selected_id() -> String:
	var t := selected()
	return t.id if t != null else ""


func select(id: String) -> bool:
	var t: ThemeData = _by_id(id)
	if t == null or not is_unlocked(t):
		return false
	_selected_id = id
	_save()
	return true


func _by_id(id: String) -> ThemeData:
	for t in GameData.themes:
		if t != null and t.id == id:
			return t
	return null


func _load() -> void:
	var r := SaveGuard.read_json(SAVE_PATH)   # 서명 검증(P2-29) — 불일치 파일은 없는 것으로 본다
	var parsed = r["data"]
	if typeof(parsed) == TYPE_DICTIONARY:
		_selected_id = str(parsed.get("id", ""))
		var b = parsed.get("bought", [])
		if typeof(b) == TYPE_ARRAY:
			for id in b:
				_bought[str(id)] = true
		if r["status"] == SaveGuard.Status.UNSIGNED:
			_save()   # 구버전 평문 파일 → 첫 실행에 서명본으로 이관


func _save() -> void:
	SaveGuard.write_json(SAVE_PATH, {"id": _selected_id, "bought": _bought.keys()})   # 서명본(P2-29)
