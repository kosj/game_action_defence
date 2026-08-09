extends Node
## 보상 보관함 (Autoload "RewardInbox"): 퀘스트/도전과제 보상은 자동 지급하지 않고 여기에 쌓이며,
## 메인 메뉴의 REWARDS 패널에서 유저가 직접 "CLAIM"을 눌러 수령한다(수령 시 메타 골드 적립).
## 목록은 user://reward_inbox.save 에 보존되어 앱을 껐다 켜도 유지된다.

signal changed   # 항목 추가/수령 — 배지·패널 갱신용

const SAVE_PATH := "user://reward_inbox.save"

var entries: Array = []   # [{"title": String, "gold": int, "src": "quest"|"achievement"}]


func _ready() -> void:
	_load()


## 보상 적립(퀘스트 완료·도전과제 해금 시 호출). 즉시 저장해 유실을 막는다.
func push_reward(title: String, gold: int, src: String) -> void:
	entries.append({"title": title, "gold": gold, "src": src})
	_save()
	changed.emit()


func count() -> int:
	return entries.size()


## index 항목 수령 — 메타 골드 적립 후 목록에서 제거. 반환: 받은 골드(실패 시 0).
func claim(index: int) -> int:
	if index < 0 or index >= entries.size():
		return 0
	var gold := int(entries[index]["gold"])
	entries.remove_at(index)
	MetaManager.reward_gold(gold)
	_save()
	changed.emit()
	return gold


## 전부 수령 — 합산 1회 적립. 반환: 받은 총 골드.
func claim_all() -> int:
	var total := 0
	for e in entries:
		total += int(e["gold"])
	entries.clear()
	if total > 0:
		MetaManager.reward_gold(total)
	_save()
	changed.emit()
	return total


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"entries": entries}))
		f.close()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var arr = parsed.get("entries", [])
	if typeof(arr) != TYPE_ARRAY:
		return
	entries.clear()
	for e in arr:
		if typeof(e) == TYPE_DICTIONARY:
			entries.append({"title": str(e.get("title", "")), "gold": int(e.get("gold", 0)), "src": str(e.get("src", ""))})
