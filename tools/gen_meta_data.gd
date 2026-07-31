extends SceneTree
## 일회성 데이터 생성: 현재 MetaManager.UPGRADES 와 "동일하게" 메타 강화 .tres 생성(회귀 방지).
## 실행:  godot --headless --path . --script res://tools/gen_meta_data.gd  (사전 --import 필요)

## per(move_speed)=1.0 — Player 가 move_speed = base + 30*upgrade_speed 로 반영하므로 레벨당 +30 이속.
## (과거 30.0 은 recompute 순서상 패시브에 덮여 실효 없었음 — 순서 수정과 함께 1.0 로 정정.)
const DEFS := [
	{"id": "power",     "name": "Might",       "desc": "+1 start bullet damage", "max": 10, "base_cost": 100, "cost_mul": 1.6, "kind": "bullet_damage", "per": 1.0},
	{"id": "vitality",  "name": "Vitality",    "desc": "+1 start max HP",         "max": 10, "base_cost": 80,  "cost_mul": 1.6, "kind": "max_health",    "per": 1.0},
	{"id": "swift",     "name": "Swiftness",   "desc": "+30 start move speed",    "max": 8,  "base_cost": 80,  "cost_mul": 1.6, "kind": "move_speed",    "per": 1.0},
	{"id": "greed",     "name": "Greed",       "desc": "+10% gold gain",          "max": 8,  "base_cost": 120, "cost_mul": 1.7, "kind": "gold_mult",     "per": 0.10},
	{"id": "growth",    "name": "Growth",      "desc": "+8% XP gain",             "max": 8,  "base_cost": 150, "cost_mul": 1.7, "kind": "xp_mult",       "per": 0.08},
	# Phase 5-A 확장 — 치명타/재생/공속/범위 시작 보정 + 런당 무료 부활.
	{"id": "luck",      "name": "Luck",        "desc": "+8% start crit",          "max": 6,  "base_cost": 140, "cost_mul": 1.7, "kind": "crit",          "per": 1.0},
	{"id": "vigor",     "name": "Vigor",       "desc": "Start with regen",        "max": 5,  "base_cost": 130, "cost_mul": 1.7, "kind": "regen",         "per": 1.0},
	{"id": "adrenaline","name": "Adrenaline",  "desc": "+ start fire rate",       "max": 6,  "base_cost": 150, "cost_mul": 1.7, "kind": "atk_speed",     "per": 1.0},
	{"id": "reach",     "name": "Reach",       "desc": "+8% start effect area",   "max": 6,  "base_cost": 130, "cost_mul": 1.7, "kind": "area",          "per": 1.0},
	{"id": "revive",    "name": "Second Wind", "desc": "+1 free revive / run",    "max": 3,  "base_cost": 400, "cost_mul": 2.2, "kind": "revive",        "per": 1.0},
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/meta")
	var db := MetaUpgradeDB.new()
	for d in DEFS:
		var u := MetaUpgradeData.new()
		u.id = d["id"]
		u.name = d["name"]
		u.desc = d["desc"]
		u.max_level = d["max"]
		u.base_cost = d["base_cost"]
		u.cost_mul = d["cost_mul"]
		u.effect_kind = d["kind"]
		u.effect_per_level = d["per"]
		var path: String = "res://data/meta/%s.tres" % d["id"]
		ResourceSaver.save(u, path)
		u.take_over_path(path)
		db.upgrades.append(u)
	var err := ResourceSaver.save(db, "res://data/meta_upgrades.tres")
	print("gen_meta_data: saved %d upgrades, db err=%d" % [db.upgrades.size(), err])
	quit()
