extends SceneTree
## 일회성: 캐릭터 카탈로그 .tres 생성.  godot --headless --path . --script res://tools/gen_character_data.gd

func _c(id: String, disp: String, desc: String, color: Color, start_weapon: String, sig: String, trait_key: String, bonuses: Dictionary) -> CharacterData:
	var c := CharacterData.new()
	c.id = id; c.display = disp; c.desc = desc; c.color = color
	c.start_weapon = start_weapon; c.signature_passive = sig; c.trait_key = trait_key
	c.bonus_max_health = bonuses.get("max_health", 0)
	c.bonus_bullet_damage = bonuses.get("bullet_damage", 0)
	c.bonus_move_speed = bonuses.get("move_speed", 0)
	c.bonus_atk_speed = bonuses.get("atk_speed", 0)
	c.bonus_area = bonuses.get("area", 0)
	c.bonus_crit = bonuses.get("crit", 0)
	return c


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var db := CharacterDB.new()
	db.characters = [
		# 베테랑 — 근접 탱커: 못배트 시작 + 방탄조끼, 높은 체력.
		_c("veteran", "Veteran", "Melee tank. Starts with a Spiked Bat and heavy armor.",
			Color(0.85, 0.45, 0.35), "spikedbat", "armor", "veteran",
			{"max_health": 3, "move_speed": 1}),
		# 사냥꾼 — 원거리 딜러: 석궁 시작 + 조준경, 높은 피해/치명타.
		_c("hunter", "Hunter", "Ranged damage. Starts with a Crossbow and a Scope.",
			Color(0.45, 0.80, 1.00), "crossbow", "crit", "hunter",
			{"bullet_damage": 2, "crit": 2}),
		# 엔지니어 — 설치 디펜스: 터렛 시작 + 배터리, 넓은 효과/재화↑.
		_c("engineer", "Engineer", "Deploy defense. Starts with a Turret and a Battery.",
			Color(0.55, 0.90, 0.60), "turret", "battery", "engineer",
			{"area": 2, "atk_speed": 1}),
	]
	var err := ResourceSaver.save(db, "res://data/character_db.tres")
	print("gen_character_data: saved character_db.tres err=%d (chars=%d)" % [err, db.characters.size()])
	quit()
