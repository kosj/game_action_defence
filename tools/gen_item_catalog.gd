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


## 데이터 구동 발사체 무기(ProjectileWeapon 모듈). params = [fire_interval, pellets, spread,
## pierce, knockback, proj_speed, proj_damage, dmg_per_level, proj_scale]
func _wm(id: String, disp: String, desc: String, color: Color, params: Array) -> WeaponData:
	var w := _w(id, disp, desc, color, 8, false)
	w.module = "projectile"
	w.fire_interval = params[0]; w.pellets = params[1]; w.spread = params[2]
	w.pierce = params[3]; w.knockback = params[4]; w.proj_speed = params[5]
	w.proj_damage = params[6]; w.dmg_per_level = params[7]; w.proj_scale = params[8]
	return w


## 데이터 구동 광역 무기(화염/장판/지뢰 모듈). params = [fire_interval, proj_damage,
## dmg_per_level, area_radius, area_duration, spread(콘 반각), knockback]
func _wa(id: String, disp: String, desc: String, color: Color, module: String, params: Array) -> WeaponData:
	var w := _w(id, disp, desc, color, 8, false)
	w.module = module
	w.fire_interval = params[0]; w.proj_damage = params[1]; w.dmg_per_level = params[2]
	w.area_radius = params[3]; w.area_duration = params[4]; w.spread = params[5]; w.knockback = params[6]
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
		# 신규 발사체 무기(Phase 2-C 배치 1) — 자동 조준, 각자 독립 발사.
		_wm("shotgun",    "Shotgun",     "Wide spread + strong knockback", Color(1.00, 0.55, 0.15), [0.85, 5, 0.50, 0, 240.0, 620.0, 1, 1, 0.85]),
		_wm("machinegun", "Machine Gun", "Very fast, low damage",          Color(0.80, 0.95, 0.25), [0.16, 1, 0.12, 0, 0.0,   760.0, 1, 1, 0.60]),
		_wm("crossbow",   "Crossbow",    "Piercing high-damage bolt",      Color(0.55, 0.85, 1.00), [0.95, 1, 0.00, 2, 60.0,  900.0, 3, 2, 1.15]),
		# 광역 무기(Phase 2-C 배치 2) — 화염 콘 / 불바다 장판 / 설치 지뢰.
		_wa("flamethrower", "Flamethrower", "Cone of continuous fire",        Color(1.00, 0.50, 0.12), "flamethrower", [0.25, 1, 1, 165.0, 0.0,  0.50, 0.0]),
		_wa("molotov",      "Molotov",      "Throws a lingering fire pool",   Color(1.00, 0.42, 0.10), "molotov",      [2.60, 2, 1, 82.0,  3.2,  0.00, 0.0]),
		_wa("mine",         "Land Mine",    "Deploys mines that explode",     Color(1.00, 0.45, 0.15), "mine",         [1.90, 4, 2, 72.0,  9.0,  0.00, 210.0]),
		# 근접 원호 무기(Phase 2-C 배치 3) — 못배트(강타 스윙) / 체인소(밀착 그라인더).
		_wa("spikedbat",  "Spiked Bat", "Wide melee swing + knockback",  Color(0.90, 0.75, 0.35), "melee_arc", [1.00, 3, 2, 118.0, 0.0, 1.15, 270.0]),
		_wa("chainsaw",   "Chainsaw",   "Point-blank grinder",           Color(0.85, 0.88, 0.95), "chainsaw",  [0.16, 1, 1, 78.0,  0.0, 0.85, 40.0]),
		# 설치물 무기(Phase 2-C 배치 4) — 터렛(설치 자동사격) / 드론(추종 자동사격) / 테슬라(연쇄 번개).
		_wa("turret", "Turret", "Deploys auto-firing sentries", Color(0.60, 0.75, 0.95), "turret", [3.00, 2, 1, 300.0, 6.0, 0.0, 0.0]),
		_wa("drone",  "Drone",  "Orbiting auto-fire drones",    Color(0.40, 0.90, 0.85), "drone",  [0.60, 1, 1, 96.0,  0.0, 0.0, 0.0]),
		_wa("tesla",  "Tesla Coil", "Chain lightning",          Color(0.60, 0.85, 1.00), "tesla",  [0.90, 3, 2, 300.0, 0.0, 0.0, 0.0]),
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
