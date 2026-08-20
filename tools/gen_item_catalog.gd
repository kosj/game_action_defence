extends SceneTree
## 일회성: 무기/패시브/진화 카탈로그 .tres 생성(기존 ItemDB 하드코딩 값과 동일 — 회귀 없음).
##   godot --headless --path . --script res://tools/gen_item_catalog.gd
##
## ⚠ data/item_catalog.tres 는 생성 이후 손으로 조정됐다(못배트 → 톱날 교체 등).
## 다시 돌리기 전에 .tres 와 이 스크립트가 일치하는지 확인할 것.

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
func _wm(id: String, disp: String, desc: String, color: Color, params: Array,
		style: String = "", spin: float = 0.0, homing: float = 0.0,
		homing_arc_deg: float = 45.0) -> WeaponData:
	var w := _w(id, disp, desc, color, 8, false)
	w.module = "projectile"
	w.fire_interval = params[0]; w.pellets = params[1]; w.spread = params[2]
	w.pierce = params[3]; w.knockback = params[4]; w.proj_speed = params[5]
	w.proj_damage = params[6]; w.dmg_per_level = params[7]; w.proj_scale = params[8]
	w.proj_style = style; w.proj_spin = spin
	w.proj_homing = homing; w.proj_homing_arc = deg_to_rad(homing_arc_deg)
	return w


## 아이콘 조회 — 아틀라스가 있으면 그것을, 없으면 원본 PNG 를 준다.
## 순서가 중요하다: PNG 를 먼저 잡으면 배칭이 끊기고 CI(`check_atlas.gd`)가 막는다.
func _icon(name: String) -> Texture2D:
	var atlas := "res://assets/atlas/ui/%s.tres" % name
	if ResourceLoader.exists(atlas):
		return load(atlas)
	var png := "res://assets/ui/icons/%s.png" % name
	if ResourceLoader.exists(png):
		return load(png)
	return null


## 모듈·범위만 갈아끼우는 보정 — 발사체 파라미터를 그대로 쓰면서 전용 모듈로 넘기는 무기용.
func _mod(w: WeaponData, module: String, area_r: float, area_d: float) -> WeaponData:
	w.module = module
	w.area_radius = area_r
	w.area_duration = area_d
	return w


## 캐릭터 궁극기 — 24초 쿨다운, 화면 전체 타격. `evolved=true` 라 일반 카드로는 안 뜨고
## `LevelUpPanel._ult_choice()` 가 선택 캐릭터의 것 하나만 꺼내 준다(`CharacterData.ultimate_weapon`).
func _ult(id: String, disp: String, desc: String, color: Color) -> WeaponData:
	var w := _w(id, disp, desc, color, 8, true)
	w.module = "ultimate"
	w.fire_interval = 24.0
	w.pellets = 1
	w.proj_damage = 3
	w.dmg_per_level = 2
	w.proj_scale = 1.0
	w.proj_speed = 0.0        # 화면 전체 판정이라 날아가는 탄이 없다(기본값 700 이 들어가면 안 된다)
	w.area_radius = 720.0
	w.area_duration = 3.0
	return w


## 데이터 구동 광역 무기(화염/장판/지뢰 모듈). params = [fire_interval, proj_damage,
## dmg_per_level, area_radius, area_duration, spread(콘 반각), knockback]
func _wa(id: String, disp: String, desc: String, color: Color, module: String, params: Array) -> WeaponData:
	var w := _w(id, disp, desc, color, 8, false)
	w.module = module
	w.fire_interval = params[0]; w.proj_damage = params[1]; w.dmg_per_level = params[2]
	w.area_radius = params[3]; w.area_duration = params[4]; w.spread = params[5]; w.knockback = params[6]
	return w


func _p(id: String, disp: String, desc: String, color: Color, max_level: int, effect: String, per_level: float) -> PassiveData:
	var p := PassiveData.new()
	p.id = id; p.display = disp; p.desc = desc; p.color = color; p.max_level = max_level
	p.effect = effect; p.per_level = per_level
	return p


## 진화 무기 표시(카드로 안 뜸, 진화로만 획득): evolved=true, max_level=5.
func _evo(w: WeaponData) -> WeaponData:
	w.evolved = true
	w.max_level = 5
	return w


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
		# 표기·색은 손으로 .tres 를 고쳐 쓰고 있던 값이다(P1-19 에서 발견) — 생성기 쪽을 맞춘다.
		_w("garlic",    "Sunlight Aura","Sunlight zombies hate",    Color(1.00, 0.85, 0.45), 8, false),
		# 신규 발사체 무기(Phase 2-C 배치 1) — 자동 조준, 각자 독립 발사.
		_wm("shotgun",    "Shotgun",     "Wide spread + strong knockback", Color(1.00, 0.55, 0.15), [0.85, 5, 0.50, 0, 240.0, 620.0, 1, 1, 0.85], "", 0.0, 1.6, 38.0),
		# 발사 간격 ×2 · 발당 위력 ×2 (P1-19). **모든 레벨에서 DPS 가 정확히 같고** 동시 탄 수만
		# 절반이 된다 — 만렙 기관총 하나가 화면에 100발을 띄우고 있었고, 그게 후반 프레임의 실측 1위였다.
		_wm("machinegun", "Machine Gun", "Fast, low damage",               Color(0.80, 0.95, 0.25), [0.32, 1, 0.12, 0, 0.0,   760.0, 2, 2, 0.72], "", 0.0, 3.0, 55.0),
		_wm("crossbow",   "Crossbow",    "Piercing high-damage bolt",      Color(0.55, 0.85, 1.00), [0.95, 1, 0.00, 2, 60.0,  900.0, 3, 2, 1.15], "", 0.0, 4.5, 65.0),
		# 광역 무기(Phase 2-C 배치 2) — 화염 콘 / 불바다 장판 / 설치 지뢰.
		_wa("flamethrower", "Flamethrower", "Cone of continuous fire",        Color(1.00, 0.50, 0.12), "flamethrower", [0.25, 1, 1, 165.0, 0.0,  0.50, 0.0]),
		_wa("molotov",      "Molotov",      "Throws a lingering fire pool",   Color(1.00, 0.42, 0.10), "molotov",      [2.60, 2, 1, 82.0,  3.2,  0.00, 0.0]),
		_wa("mine",         "Land Mine",    "Deploys mines that explode",     Color(1.00, 0.45, 0.15), "mine",         [1.90, 4, 2, 72.0,  9.0,  0.00, 210.0]),
		# 근접 원호 무기(Phase 2-C 배치 3) — 못배트(강타 스윙) / 체인소(밀착 그라인더).
		# 못배트(melee_arc)는 제거됨 — 근접 원호가 캐릭터 좌우 플립과 어긋나 등 뒤를 후려쳐서,
		# 전방으로 날아가는 회전 관통 톱날로 교체했다. 전용 모듈 없이 projectile + 모양만 지정.
		_wm("sawblade", "Buzz Blade", "Spinning blade that cuts through a line of foes",
			Color(0.90, 0.75, 0.35), [1.00, 1, 0.00, 3, 150.0, 430.0, 4, 2, 1.35], "blade", 14.0, 3.4, 45.0),
		_wa("chainsaw",   "Chainsaw",   "Point-blank grinder",           Color(0.85, 0.88, 0.95), "chainsaw",  [0.16, 1, 1, 78.0,  0.0, 0.85, 40.0]),
		# 설치물 무기(Phase 2-C 배치 4) — 터렛(설치 자동사격) / 드론(추종 자동사격) / 테슬라(연쇄 번개).
		_wa("turret", "Turret", "Deploys auto-firing sentries", Color(0.60, 0.75, 0.95), "turret", [3.00, 2, 1, 300.0, 6.0, 0.0, 0.0]),
		_wa("drone",  "Drone",  "Orbiting auto-fire drones",    Color(0.40, 0.90, 0.85), "drone",  [0.60, 1, 1, 96.0,  0.0, 0.0, 0.0]),
		_wa("tesla",  "Tesla Coil", "Chain lightning",          Color(0.60, 0.85, 1.00), "tesla",  [0.90, 3, 2, 300.0, 0.0, 0.0, 0.0]),
		_w("railgun",      "Railgun",      "Evolved Auto Gun",    C_ATK,   5, true),
		_w("sawstorm",     "Saw Storm",    "Evolved Orb Shield",  C_ORB,   5, true),
		_w("thunderstorm", "Thunderstorm", "Evolved Lightning",   C_LIGHT, 5, true),
		_w("sanctuary",    "Sanctuary",    "Evolved Garlic Aura", C_ORB,   5, true),
		# 신규 무기 진화체(Phase 3-B). 모듈 무기라 강화 파라미터만 다른 새 WeaponData — recompute 오버라이드 불필요.
		_evo(_wm("dragonsbreath", "Dragon's Breath", "Evolved Shotgun",     Color(1.00, 0.40, 0.10), [0.75, 8, 0.60, 1, 300.0, 660.0, 2, 2, 0.95], "", 0.0, 1.6, 38.0)),
		# 같은 처리(간격 ×2 · 위력 ×2, DPS 동일). 진화 무기라 더 심했다 —
		# 이것 하나가 동시 탄 113발로 다른 무기의 3~5배였다.
		_evo(_wm("gatling",       "Gatling Gun",     "Evolved Machine Gun", Color(0.90, 0.95, 0.20), [0.20, 2, 0.14, 1, 0.0,   820.0, 2, 4, 0.78], "", 0.0, 3.2, 55.0)),
		_evo(_wm("ballista",      "Ballista",        "Evolved Crossbow",    Color(0.45, 0.80, 1.00), [0.75, 1, 0.00, 5, 90.0,  1000.0, 5, 3, 1.40], "", 0.0, 5.0, 70.0)),
		_evo(_wa("inferno",  "Inferno",   "Evolved Flamethrower", Color(1.00, 0.42, 0.08), "flamethrower", [0.18, 2, 2, 210.0, 0.0, 0.62, 0.0])),
		_evo(_wa("napalm",   "Napalm",    "Evolved Molotov",      Color(1.00, 0.35, 0.08), "molotov",      [2.00, 3, 2, 100.0, 4.5, 0.00, 0.0])),
		_evo(_wa("claymore", "Claymore",  "Evolved Land Mine",    Color(1.00, 0.42, 0.12), "mine",         [1.50, 6, 3, 95.0,  9.0, 0.00, 260.0])),
		_evo(_wa("stormcoil","Storm Coil","Evolved Tesla Coil",   Color(0.55, 0.85, 1.00), "tesla",        [0.70, 4, 3, 340.0, 0.0, 0.00, 0.0])),
		# ⚠️ 아래 4종은 **생성기에 없고 data/item_catalog.tres 에만 손으로 들어가 있었다**(P1-19 에서 발견).
		# 그 상태에서 규약대로 재생성하면 조용히 사라진다 — 실제로 이번에 사라졌다가 되살렸다.
		# 궁극기 3종은 캐릭터마다 하나씩 묶인 정체성이라(`CharacterData.ultimate_weapon`) 없어지면
		# 그 캐릭터가 반쪽이 되고, 부메랑은 엔지니어 시작 무기 계열이다.
		_mod(_wm("boomerang", "Boomerang", "Returning blade, hits twice",
			Color(0.95, 0.70, 0.35), [1.35, 1, 0.00, 0, 110.0, 560.0, 3, 2, 1.00]),
			"boomerang", 250.0, 0.0),
		_ult("ult_quake",      "Seismic Wrath",   "Ultimate: quakes crush every enemy on screen", Color(0.95, 0.42, 0.30)),
		_ult("ult_arrowstorm", "Arrow Tempest",   "Ultimate: arrow rain pierces the whole field", Color(0.50, 0.85, 1.00)),
		_ult("ult_orbital",    "Orbital Barrage", "Ultimate: bombardment blankets the screen",    Color(0.55, 0.95, 0.60)),
	]

	# 스펙 패시브 10종. 기존 6종은 id 유지(진화 짝꿍·세이브 호환), 표시명만 스펙 플레이버로.
	# 신규 4종(탄약벨트·화약·배터리·토끼발)은 새 효과 knob(multishot/bullet_damage/area/greed).
	db.passives = [
		_p("armor",  "Body Armor",   "+1 max HP (heals)",      C_SURV, 8, "max_health",    1.0),
		_p("swift",  "Sneakers",     "+30 move speed / lvl",   C_UTIL, 8, "move_speed",    1.0),
		_p("haste",  "Energy Drink", "-15% fire delay / lvl",  C_ATK,  8, "atk_speed",     1.0),
		_p("crit",   "Scope",        "+8% crit (double dmg)",  C_ATK,  7, "crit",          1.0),
		_p("magnet", "Magnet",       "+30% pickup range",      C_UTIL, 6, "pickup",        1.0),
		_p("regen",  "First Aid",    "Heal over time",         C_SURV, 6, "regen",         1.0),
		_p("ammo_belt",    "Ammo Belt",     "Extra bullets",       C_ATK,  6, "multishot",     0.34),
		_p("gunpowder",    "Gunpowder",     "+1 bullet dmg / lvl", C_ATK,  8, "bullet_damage", 1.0),
		_p("battery",      "Battery",       "+8% effect area/lvl", C_UTIL, 6, "area",          1.0),
		_p("rabbits_foot", "Rabbit's Foot", "+8% gold & XP / lvl", C_SURV, 6, "greed",         1.0),
	]

	# 진화 12종: 베이스 만렙 + 짝꿍 패시브 보유 → 진화체(보물상자 개봉 시 선택).
	db.evolutions = [
		_e("gun",       "crit",  "railgun"),
		_e("orb",       "swift", "sawstorm"),
		_e("lightning", "crit",  "thunderstorm"),
		_e("garlic",    "armor", "sanctuary"),
		_e("shotgun",    "gunpowder", "dragonsbreath"),
		_e("machinegun", "ammo_belt", "gatling"),
		_e("crossbow",   "crit",      "ballista"),
		_e("flamethrower", "battery", "inferno"),
		_e("molotov",    "gunpowder", "napalm"),
		_e("mine",       "battery",   "claymore"),
		_e("tesla",      "haste",     "stormcoil"),
	]

	# 무기 아이콘 배선 — **아틀라스(AtlasTexture)를 먼저 찾는다.** PNG 를 직접 참조하면
	# 그 아이콘만 배칭이 끊기고 `check_atlas.gd` 가 CI 에서 막는다(ASSET_PIPELINE.md).
	# 예전에는 여기서 PNG 를 바로 물려 놓고 `.tres` 쪽만 손으로 아틀라스로 고쳐 두었던 탓에,
	# 재생성하면 CI 가 깨졌다(P1-19 에서 발견).
	# (아틀라스도 PNG 도 없는 무기는 icon=null → UI 가 색상 카드로 폴백.)
	for w in db.weapons:
		var tex := _icon("weapon_%s" % w.id)
		if tex != null:
			w.icon = tex
	# 패시브 아이콘 배선 — assets/ui/icons/passive_<id>.png 가 있으면 연결(없으면 색상 폴백).
	for p in db.passives:
		var ptex := _icon("passive_%s" % p.id)
		if ptex != null:
			p.icon = ptex

	var err := ResourceSaver.save(db, "res://data/item_catalog.tres")
	print("gen_item_catalog: saved item_catalog.tres err=%d (w=%d p=%d e=%d)" % [err, db.weapons.size(), db.passives.size(), db.evolutions.size()])
	quit()
