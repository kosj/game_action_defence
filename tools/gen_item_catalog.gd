extends SceneTree
## 일회성: 무기/패시브/진화 카탈로그 .tres 생성(기존 ItemDB 하드코딩 값과 동일 — 회귀 없음).
##   godot --headless --path . --script res://tools/gen_item_catalog.gd

const C_ATK := Color(1.00, 0.75, 0.20)
const C_ORB := Color(0.45, 0.82, 1.00)
const C_LIGHT := Color(0.65, 0.55, 1.00)
const C_SURV := Color(0.45, 0.85, 0.50)
const C_UTIL := Color(0.72, 0.72, 0.85)


func _w(id: String, disp: String, desc: String, color: Color, max_level: int, evolved: bool) -> WeaponData:
	var w := WeaponData.new()
	w.id = id; w.display = disp; w.desc = desc; w.color = color; w.max_level = max_level; w.evolved = evolved
	return w


func _p(id: String, disp: String, desc: String, color: Color, max_level: int) -> PassiveData:
	var p := PassiveData.new()
	p.id = id; p.display = disp; p.desc = desc; p.color = color; p.max_level = max_level
	return p


func _e(base_id: String, passive_id: String, into_id: String) -> EvolutionData:
	var e := EvolutionData.new()
	e.base_id = base_id; e.passive_id = passive_id; e.into_id = into_id
	return e


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var db := ItemCatalogDB.new()

	db.weapons = [
		_w("gun",       "Auto Gun",   "Damage & extra bullets",     C_ATK,   8, false),
		_w("orb",       "Orb Shield", "Orbiting blades",            C_ORB,   8, false),
		_w("lightning", "Lightning",  "Strikes nearby foes",        C_LIGHT, 8, false),
		_w("garlic",    "Garlic Aura","Damages foes around you",    C_ORB,   8, false),
		_w("holy",      "Holy Water", "Blasts random nearby spots", C_LIGHT, 8, false),
		_w("railgun",      "Railgun",      "Evolved Auto Gun",    C_ATK,   5, true),
		_w("sawstorm",     "Saw Storm",    "Evolved Orb Shield",  C_ORB,   5, true),
		_w("thunderstorm", "Thunderstorm", "Evolved Lightning",   C_LIGHT, 5, true),
		_w("sanctuary",    "Sanctuary",    "Evolved Garlic Aura", C_ORB,   5, true),
		_w("crucifix",     "Crucifix",     "Evolved Holy Water",  C_LIGHT, 5, true),
	]

	db.passives = [
		_p("haste",  "Haste",       "-15% fire delay / lvl", C_ATK,  8),
		_p("crit",   "Crit Chance", "+8% double damage",     C_ATK,  7),
		_p("swift",  "Swift Boots", "+30 move speed",        C_UTIL, 8),
		_p("armor",  "Armor",       "+1 max HP (heals)",     C_SURV, 8),
		_p("regen",  "Regen",       "Heal over time",        C_SURV, 6),
		_p("magnet", "Magnet",      "+30% pickup range",     C_UTIL, 6),
	]

	db.evolutions = [
		_e("gun",       "crit",  "railgun"),
		_e("orb",       "swift", "sawstorm"),
		_e("lightning", "crit",  "thunderstorm"),
		_e("garlic",    "armor", "sanctuary"),
		_e("holy",      "haste", "crucifix"),
	]

	var err := ResourceSaver.save(db, "res://data/item_catalog.tres")
	print("gen_item_catalog: saved item_catalog.tres err=%d (w=%d p=%d e=%d)" % [err, db.weapons.size(), db.passives.size(), db.evolutions.size()])
	quit()
