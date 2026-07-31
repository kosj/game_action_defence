class_name ItemDB
extends RefCounted
## 무기/패시브 아이템 카탈로그 + 인벤토리→스탯 재계산 (뱀서식 슬롯 성장의 데이터 레이어).
##
## 설계: 전투 코드(Bullet/Orb/Lightning/Player)는 그대로 두고, 인벤토리(아이템 레벨)를
## 기존 Events.upgrade_* 카운터로 "재계산"만 한다. 아이템 레벨이 진실의 원천이며,
## 효과는 검증된 기존 코드가 처리한다(저리스크). 무기=슬롯6, 패시브=슬롯6.

const MAX_WEAPON_SLOTS := 6
const MAX_PASSIVE_SLOTS := 6

## 카탈로그는 데이터 에셋(res://data/item_catalog.tres)에서 온다(스펙: 하드코딩 금지).
## 다운스트림 코드(LevelUpPanel/HUD)는 dict 형태를 기대하므로 WeaponData/PassiveData 를
## dict {id,name,desc,color,max,evolved} 로 어댑팅해 제공한다(형태 유지, 회귀 없음).

static func _w_dict(w: WeaponData) -> Dictionary:
	return {"id": w.id, "name": w.display, "desc": w.desc, "color": w.color, "max": w.max_level, "evolved": w.evolved}


static func _p_dict(p: PassiveData) -> Dictionary:
	return {"id": p.id, "name": p.display, "desc": p.desc, "color": p.color, "max": p.max_level, "evolved": false}


## 무기 카탈로그(dict 배열). gun 은 시작 시 보유(Lv1). evolved=true 는 진화로만 획득.
static func weapons() -> Array:
	var out: Array = []
	for w in GameData.weapon_defs:
		out.append(_w_dict(w))
	return out


## 패시브 카탈로그(dict 배열).
static func passives() -> Array:
	var out: Array = []
	for p in GameData.passive_defs:
		out.append(_p_dict(p))
	return out


## 진화 규칙(dict 배열): base 무기 만렙 + passive 보유(Lv1+) → into 진화 무기(원본을 대체).
static func evolutions() -> Array:
	var out: Array = []
	for e in GameData.evolution_defs:
		out.append({"base": e.base_id, "passive": e.passive_id, "into": e.into_id})
	return out


static func meta(id: String) -> Dictionary:
	var w: WeaponData = GameData.weapon_def(id)
	if w != null:
		return _w_dict(w)
	var p: PassiveData = GameData.passive_def(id)
	if p != null:
		return _p_dict(p)
	return {}


static func is_weapon(id: String) -> bool:
	return GameData.weapon_def(id) != null


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

	# 진화 무기 — 원본을 대체하며 강화된 수치로 덮어쓴다(원본은 인벤토리에서 제거됨).
	if weapons.has("railgun"):
		var rg: int = int(weapons["railgun"])
		Events.upgrade_bullet_damage = 10 + rg * 2
		Events.upgrade_multi_bullet = 3 + int(rg / 2)
	if weapons.has("sawstorm"):
		var sw: int = int(weapons["sawstorm"])
		Events.upgrade_orbs = 6
		Events.upgrade_orb_damage = 4 + sw
		Events.upgrade_orb_speed = 3 + int(sw / 2)
	if weapons.has("thunderstorm"):
		var th: int = int(weapons["thunderstorm"])
		Events.upgrade_lightning_count = 4 + int(th / 2)
		Events.upgrade_lightning_damage = 4 + th
	if weapons.has("sanctuary"):
		Events.upgrade_garlic = 9 + int(weapons["sanctuary"])
	if weapons.has("crucifix"):
		Events.upgrade_holy = 9 + int(weapons["crucifix"])

	MetaManager.add_bonuses()   # 메타 영구 강화(시작 데미지·체력·이속)를 인벤토리 위에 더한다

	# 패시브 효과 — 데이터 구동(PassiveData.effect/per_level). effect 별로 per_level×레벨을 합산.
	var acc: Dictionary = {}
	for pd in GameData.passive_defs:
		if pd == null:
			continue
		var lv: int = int(passives.get(pd.id, 0))
		if lv <= 0 or pd.effect == "":
			continue
		acc[pd.effect] = float(acc.get(pd.effect, 0.0)) + pd.per_level * float(lv)
	# 패시브 전용 스탯: SET(기존 동작 보존 — atk_speed/crit/speed/max_health/regen/pickup).
	Events.upgrade_atk_speed = int(acc.get("atk_speed", 0.0))
	Events.upgrade_crit = int(acc.get("crit", 0.0))
	Events.upgrade_speed = int(acc.get("move_speed", 0.0))
	Events.upgrade_max_health = int(acc.get("max_health", 0.0))
	Events.upgrade_regen = int(acc.get("regen", 0.0))
	Events.upgrade_pickup_range = int(acc.get("pickup", 0.0))
	Events.upgrade_area = int(acc.get("area", 0.0))
	Events.upgrade_greed = int(acc.get("greed", 0.0))
	# 무기와 공유하는 스탯: ADD(무기/진화/메타 값 위에 얹음) — 신규 패시브 탄약벨트/화약.
	Events.upgrade_multi_bullet += int(acc.get("multishot", 0.0))
	Events.upgrade_bullet_damage += int(acc.get("bullet_damage", 0.0))

	CharacterManager.add_bonuses()   # 캐릭터 시작 스탯 보정(패시브 SET 이후 += 로 얹음)
