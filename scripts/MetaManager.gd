extends Node
## 메타 성장(런 간 영구 강화) 매니저 (Autoload "MetaManager").
## 런에서 번 골드를 종료 시 은행(meta_gold)에 적립하고, 메인 메뉴에서 영구 강화를 구매한다.
## 영구 강화는 매 런 시작 시 자동 적용된다(시작 스탯 보정 + 골드/경험치 획득 배수).
## 디스크(user://meta.save)에 골드·강화 레벨을 보존한다.

const SAVE_PATH := "user://meta.save"

## 영구 강화 카탈로그. cost(level) = base_cost * cost_mul^level.
const UPGRADES: Array = [
	{"id": "power",    "name": "Might",     "desc": "+1 start bullet damage", "max": 10, "base_cost": 100, "cost_mul": 1.6},
	{"id": "vitality", "name": "Vitality",  "desc": "+1 start max HP",         "max": 10, "base_cost": 80,  "cost_mul": 1.6},
	{"id": "swift",    "name": "Swiftness", "desc": "+30 start move speed",    "max": 8,  "base_cost": 80,  "cost_mul": 1.6},
	{"id": "greed",    "name": "Greed",     "desc": "+10% gold gain",          "max": 8,  "base_cost": 120, "cost_mul": 1.7},
	{"id": "growth",   "name": "Growth",    "desc": "+8% XP gain",             "max": 8,  "base_cost": 150, "cost_mul": 1.7},
]

var meta_gold: int = 0
var _levels: Dictionary = {}   # id -> level


func _ready() -> void:
	_load()


func level(id: String) -> int:
	return int(_levels.get(id, 0))


func _meta(id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return {}


## 다음 레벨 비용. 만렙이면 -1.
func cost(id: String) -> int:
	var m := _meta(id)
	if m.is_empty():
		return -1
	var lv := level(id)
	if lv >= int(m["max"]):
		return -1
	return int(round(float(m["base_cost"]) * pow(float(m["cost_mul"]), lv)))


func buy(id: String) -> bool:
	var c := cost(id)
	if c < 0 or meta_gold < c:
		return false
	meta_gold -= c
	_levels[id] = level(id) + 1
	_save()
	return true


## 런 종료 시(게임오버 → 재시작/메뉴) 이번 판에서 번 골드를 은행에 적립.
func bank(run_gold: int) -> void:
	if run_gold <= 0:
		return
	meta_gold += run_gold
	_save()


## 런 시작 시(Events.reset) 호출 — 골드/경험치 획득 배수를 영구 강화로 설정.
func apply_run_start() -> void:
	Events.gold_mult = 1.0 + 0.10 * level("greed")
	Events.xp_mult = 1.0 + 0.08 * level("growth")


## ItemDB.recompute 말미에 호출 — 시작 스탯 보정을 upgrade_* 에 더한다(인벤토리 위에 얹힘).
func add_bonuses() -> void:
	Events.upgrade_bullet_damage += level("power")
	Events.upgrade_max_health += level("vitality")
	Events.upgrade_speed += level("swift")


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
	meta_gold = int(parsed.get("gold", 0))
	var lv = parsed.get("levels", {})
	if typeof(lv) == TYPE_DICTIONARY:
		for k in lv.keys():
			_levels[str(k)] = int(lv[k])


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"gold": meta_gold, "levels": _levels}))
		f.close()
