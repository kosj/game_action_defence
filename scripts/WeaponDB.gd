extends RefCounted
## 무기 데이터베이스: 무기 종류(아키타입) + 희귀도(티어) 정의와 합성 로직.
## 맵에서 주운 무기는 즉시 장착되며, 상점 강화(대미지/다중발사)는 어떤 무기를 들어도 그대로 적용된다.

const WEAPONS: Array = [
	{"id": "pistol",  "name": "Pistol",          "shape": "circle",       "color": Color(1.00, 0.30, 0.10), "base_damage": 1, "cooldown_mult": 1.00, "bullet_speed_mult": 1.00, "pellet_count": 1, "spread": 0.22, "bullet_scale": 1.0, "splash_radius": 0.0},
	{"id": "shotgun", "name": "Shotgun",         "shape": "triangle",     "color": Color(1.00, 0.55, 0.15), "base_damage": 1, "cooldown_mult": 1.35, "bullet_speed_mult": 0.85, "pellet_count": 4, "spread": 0.50, "bullet_scale": 0.85, "splash_radius": 0.0},
	{"id": "smg",     "name": "SMG",             "shape": "diamond",      "color": Color(0.80, 0.95, 0.25), "base_damage": 1, "cooldown_mult": 0.42, "bullet_speed_mult": 1.25, "pellet_count": 1, "spread": 0.10, "bullet_scale": 0.65, "splash_radius": 0.0},
	{"id": "sniper",  "name": "Sniper Rifle",    "shape": "long_diamond", "color": Color(0.55, 0.85, 1.00), "base_damage": 4, "cooldown_mult": 2.30, "bullet_speed_mult": 2.00, "pellet_count": 1, "spread": 0.00, "bullet_scale": 1.3, "splash_radius": 0.0},
	{"id": "rocket",  "name": "Rocket Launcher", "shape": "pentagon",     "color": Color(1.00, 0.35, 0.15), "base_damage": 3, "cooldown_mult": 1.70, "bullet_speed_mult": 0.65, "pellet_count": 1, "spread": 0.00, "bullet_scale": 2.0, "splash_radius": 70.0},
	{"id": "plasma",  "name": "Plasma Cannon",   "shape": "hexagon",      "color": Color(0.75, 0.35, 1.00), "base_damage": 2, "cooldown_mult": 1.15, "bullet_speed_mult": 1.05, "pellet_count": 1, "spread": 0.00, "bullet_scale": 1.6, "splash_radius": 40.0},
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
	stats["splash_radius"] = archetype["splash_radius"] * mult + (mult - 1.0) * 14.0
	stats["color"] = base_color.lerp(tier["color"], 0.4)
	return stats
