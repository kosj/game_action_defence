class_name ItemDB
extends RefCounted
## 무기/패시브 아이템 카탈로그 + 인벤토리→스탯 재계산 (뱀서식 슬롯 성장의 데이터 레이어).
##
## 설계: 전투 코드(Bullet/Orb/Lightning/Player)는 그대로 두고, 인벤토리(아이템 레벨)를
## 기존 Events.upgrade_* 카운터로 "재계산"만 한다. 아이템 레벨이 진실의 원천이며,
## 효과는 검증된 기존 코드가 처리한다(저리스크). 무기=슬롯6, 패시브=슬롯6.

const _C_ATK := Color(1.00, 0.75, 0.20)
const _C_ORB := Color(0.45, 0.82, 1.00)
const _C_LIGHT := Color(0.65, 0.55, 1.00)
const _C_SURV := Color(0.45, 0.85, 0.50)
const _C_UTIL := Color(0.72, 0.72, 0.85)

const MAX_WEAPON_SLOTS := 6
const MAX_PASSIVE_SLOTS := 6

## 무기: 각자 슬롯을 차지하고 Lv1~max 로 성장한다. gun 은 시작 시 보유(Lv1).
const WEAPONS: Array = [
	{"id": "gun",       "name": "Auto Gun",   "desc": "Damage & extra bullets", "color": _C_ATK,   "max": 8},
	{"id": "orb",       "name": "Orb Shield",  "desc": "Orbiting blades",        "color": _C_ORB,   "max": 8},
	{"id": "lightning", "name": "Lightning",   "desc": "Strikes nearby foes",    "color": _C_LIGHT, "max": 8},
	{"id": "garlic",    "name": "Garlic Aura", "desc": "Damages foes around you", "color": _C_ORB,  "max": 8},
	{"id": "holy",      "name": "Holy Water",  "desc": "Blasts random nearby spots", "color": _C_LIGHT, "max": 8},
]

## 패시브: 유틸/스탯 강화. 각자 슬롯을 차지한다.
const PASSIVES: Array = [
	{"id": "haste",  "name": "Haste",       "desc": "-15% fire delay / lvl", "color": _C_ATK,  "max": 8},
	{"id": "crit",   "name": "Crit Chance", "desc": "+8% double damage",     "color": _C_ATK,  "max": 7},
	{"id": "swift",  "name": "Swift Boots", "desc": "+30 move speed",        "color": _C_UTIL, "max": 8},
	{"id": "armor",  "name": "Armor",       "desc": "+1 max HP (heals)",     "color": _C_SURV, "max": 8},
	{"id": "regen",  "name": "Regen",       "desc": "Heal over time",        "color": _C_SURV, "max": 6},
	{"id": "magnet", "name": "Magnet",      "desc": "+30% pickup range",     "color": _C_UTIL, "max": 6},
]


static func meta(id: String) -> Dictionary:
	for w in WEAPONS:
		if w["id"] == id:
			return w
	for p in PASSIVES:
		if p["id"] == id:
			return p
	return {}


static func is_weapon(id: String) -> bool:
	for w in WEAPONS:
		if w["id"] == id:
			return true
	return false


## 인벤토리(무기/패시브 레벨) → Events.upgrade_* 재계산. 매 레벨업/로드/리셋 후 호출.
## 아이템 레벨만 바꾸면 나머지는 기존 효과 코드가 알아서 반영한다.
static func recompute(weapons: Dictionary, passives: Dictionary) -> void:
	var g: int = int(weapons.get("gun", 0))
	Events.upgrade_bullet_damage = maxi(0, g - 1)          # gun Lv1=기본, 레벨당 +1 데미지
	Events.upgrade_multi_bullet = int(maxi(0, g - 1) / 3)  # 3레벨마다 추가 발사 +1

	var o: int = int(weapons.get("orb", 0))
	Events.upgrade_orbs = clampi(1 + int(o / 2), 1, 6) if o > 0 else 0
	Events.upgrade_orb_damage = int(o / 2)
	Events.upgrade_orb_speed = int(o / 3)

	var l: int = int(weapons.get("lightning", 0))
	Events.upgrade_lightning_count = (1 + int(l / 2)) if l > 0 else 0
	Events.upgrade_lightning_damage = int(l / 2)

	Events.upgrade_garlic = int(weapons.get("garlic", 0))   # 마늘/성수는 레벨을 그대로 무기가 읽는다
	Events.upgrade_holy = int(weapons.get("holy", 0))

	Events.upgrade_atk_speed = int(passives.get("haste", 0))
	Events.upgrade_crit = int(passives.get("crit", 0))
	Events.upgrade_speed = int(passives.get("swift", 0))
	Events.upgrade_max_health = int(passives.get("armor", 0))
	Events.upgrade_regen = int(passives.get("regen", 0))
	Events.upgrade_pickup_range = int(passives.get("magnet", 0))
