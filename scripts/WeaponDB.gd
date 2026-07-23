extends RefCounted
## 무기 데이터베이스: 무기 종류(아키타입) + 희귀도(티어) 정의와 합성 로직.
## 맵에서 주운 무기는 즉시 장착되며, 상점 강화(대미지/다중발사)는 어떤 무기를 들어도 그대로 적용된다.

const WEAPONS: Array = [
	{"id": "pistol",  "name": "Pistol",          "shape": "circle",       "color": Color(1.00, 0.30, 0.10), "base_damage": 1, "cooldown_mult": 1.00, "bullet_speed_mult": 1.00, "pellet_count": 1, "spread": 0.22, "bullet_scale": 1.0, "splash_radius": 0.0, "sfx": "shoot", "sfx_pitch": 1.00},
	{"id": "shotgun", "name": "Shotgun",         "shape": "triangle",     "color": Color(1.00, 0.55, 0.15), "base_damage": 1, "cooldown_mult": 1.35, "bullet_speed_mult": 0.85, "pellet_count": 4, "spread": 0.50, "bullet_scale": 0.85, "splash_radius": 0.0, "sfx": "boom", "sfx_pitch": 1.05},
	{"id": "smg",     "name": "SMG",             "shape": "diamond",      "color": Color(0.80, 0.95, 0.25), "base_damage": 1, "cooldown_mult": 0.42, "bullet_speed_mult": 1.25, "pellet_count": 1, "spread": 0.10, "bullet_scale": 0.65, "splash_radius": 0.0, "sfx": "shoot", "sfx_pitch": 1.45},
	{"id": "sniper",  "name": "Sniper Rifle",    "shape": "long_diamond", "color": Color(0.55, 0.85, 1.00), "base_damage": 4, "cooldown_mult": 2.30, "bullet_speed_mult": 2.00, "pellet_count": 1, "spread": 0.00, "bullet_scale": 1.3, "splash_radius": 0.0, "sfx": "shoot", "sfx_pitch": 0.80},
	{"id": "rocket",  "name": "Rocket Launcher", "shape": "pentagon",     "color": Color(1.00, 0.35, 0.15), "base_damage": 3, "cooldown_mult": 1.70, "bullet_speed_mult": 0.65, "pellet_count": 1, "spread": 0.00, "bullet_scale": 2.0, "splash_radius": 70.0, "sfx": "boom", "sfx_pitch": 0.72},
	{"id": "plasma",  "name": "Plasma Cannon",   "shape": "hexagon",      "color": Color(0.75, 0.35, 1.00), "base_damage": 2, "cooldown_mult": 1.15, "bullet_speed_mult": 1.05, "pellet_count": 1, "spread": 0.00, "bullet_scale": 1.6, "splash_radius": 40.0, "sfx": "laser", "sfx_pitch": 1.00},
]

## 등급: 낮을수록 잘 나오고, 높을수록 희귀하며 대미지/발사체 크기/스플래시가 모두 강해진다.
const TIERS: Array = [
	{"id": "common",    "name": "Common",    "mult": 1.0, "color": Color(0.80, 0.80, 0.85), "weight": 50},
	{"id": "rare",      "name": "Rare",      "mult": 1.5, "color": Color(0.35, 0.65, 1.00), "weight": 30},
	{"id": "epic",      "name": "Epic",      "mult": 2.2, "color": Color(0.72, 0.35, 1.00), "weight": 15},
	{"id": "legendary", "name": "Legendary", "mult": 3.3, "color": Color(1.00, 0.65, 0.15), "weight": 5},
]


static func roll_pickup() -> Dictionary:
	var archetype: Dictionary = WEAPONS[randi() % WEAPONS.size()]
	var tier: Dictionary = _roll_tier()
	return _build_stats(archetype, tier)


static func default_weapon() -> Dictionary:
	return _build_stats(WEAPONS[0], TIERS[0])


## 저장 데이터(문자열 id)로부터 무기 스탯을 재구성 — Color 등은 직렬화하지 않고 id만 저장하기 위함.
static func build_from_ids(weapon_id: String, tier_id: String) -> Dictionary:
	var archetype: Dictionary = WEAPONS[0]
	for w in WEAPONS:
		if w["id"] == weapon_id:
			archetype = w
			break
	var tier: Dictionary = TIERS[0]
	for t in TIERS:
		if t["id"] == tier_id:
			tier = t
			break
	return _build_stats(archetype, tier)


static func _roll_tier() -> Dictionary:
	var total := 0
	for tier in TIERS:
		total += tier["weight"]
	var roll := randi() % total
	var cum := 0
	for tier in TIERS:
		cum += tier["weight"]
		if roll < cum:
			return tier
	return TIERS[0]


## 아키타입 기본 스탯에 티어 배율을 적용. 강력한 티어일수록 대미지뿐 아니라
## 발사체 크기·스플래시(피해 범위)·색조까지 함께 커져 시각적으로도 위력이 드러난다.
static func _build_stats(archetype: Dictionary, tier: Dictionary) -> Dictionary:
	var mult: float = tier["mult"]
	var base_color: Color = archetype["color"]
	var stats: Dictionary = archetype.duplicate()
	stats["tier_id"] = tier["id"]
	stats["tier_name"] = tier["name"]
	stats["tier_color"] = tier["color"]
	stats["tier_mult"] = mult
	stats["damage"] = maxi(1, int(round(archetype["base_damage"] * mult)))
	stats["bullet_scale"] = archetype["bullet_scale"] * (1.0 + (mult - 1.0) * 0.5)
	# 스플래시는 원래 폭발형 무기(로켓·플라스마)에만 부여한다. 과거엔 모든 무기에 (mult-1)*14 를
	# 더해, 비폭발 무기(권총·샷건 등)가 Common 외 티어에서 작은 스플래시(예: 레어 7px)를 얻었고,
	# Bullet 이 직격 대신 그 좁은 범위 피해로 처리해 정작 명중한 적에게 데미지가 0 이 되는 버그가 있었다.
	var base_splash: float = archetype["splash_radius"]
	stats["splash_radius"] = (base_splash * mult + (mult - 1.0) * 14.0) if base_splash > 0.0 else 0.0
	stats["color"] = base_color.lerp(tier["color"], 0.4)
	# 사용 시간: 기본 무기(권총·Common)는 무한(0), 그 외 필드 무기는 티어에 비례해 만료된다.
	# (기존 12~18초는 "줍자마자 사라지는" 느낌이라 상향 — 획득한 강력 무기를 충분히 즐기도록.)
	var is_basic: bool = archetype["id"] == "pistol" and tier["id"] == "common"
	stats["duration"] = 0.0 if is_basic else (20.0 + (mult - 1.0) * 10.0)
	return stats
