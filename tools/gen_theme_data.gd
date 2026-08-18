extends SceneTree
## 일회성: 아레나 테마 카탈로그 .tres 생성.  godot --headless --path . --script res://tools/gen_theme_data.gd
## 주의: 이 스크립트는 data/themes.tres 를 통째로 덮어쓴다 — 저장된 .tres 와 여기 값이 어긋나면
## 실행하는 순간 회귀한다. 테마 값을 바꿀 때는 반드시 양쪽을 함께 고칠 것.

func _t(id: String, disp: String, desc: String, style: String,
		bg: Color, ta: Color, tb: Color, mk: Color, gates: Dictionary) -> ThemeData:
	var t := ThemeData.new()
	t.id = id; t.display = disp; t.desc = desc; t.detail_style = style
	t.bg = bg; t.tile_a = ta; t.tile_b = tb; t.mark = mk
	t.unlock_cost = gates.get("unlock_cost", 0)
	t.unlock_achievement = gates.get("unlock_achievement", "")
	t.gimmick_key = gates.get("gimmick_key", "")
	t.gimmick_keys = gates.get("gimmick_keys", PackedStringArray())
	t.prop_keys = gates.get("prop_keys", PackedStringArray())
	t.weather_keys = gates.get("weather_keys", PackedStringArray())
	t.boss_key = gates.get("boss_key", "")
	return t


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var db := ArenaThemeDB.new()
	db.themes = [
		# 교외(입문) — 무료. 잔디/흙 톤. 기믹 없음(#180 이후 입문 아레나는 방해물 미배치).
		# 날씨: 온대 교외라 비.
		_t("suburb", "Suburb", "Quiet outskirts. The outbreak begins.", "grass",
			Color(0.10, 0.16, 0.08), Color(0.13, 0.20, 0.10), Color(0.16, 0.24, 0.13), Color(0.22, 0.31, 0.16),
			{"boss_key": "mutant_dog",
			 "weather_keys": PackedStringArray(["rain"])}),
		# 도심(중급) — 메타 골드 400. 아스팔트/콘크리트 톤.
		# 날씨: 비 + 무너진 도시의 먼지바람.
		_t("city", "Downtown", "Concrete jungle. Danger everywhere.", "stone",
			Color(0.09, 0.09, 0.11), Color(0.18, 0.18, 0.22), Color(0.23, 0.23, 0.28), Color(0.30, 0.30, 0.36),
			{"unlock_cost": 400, "gimmick_key": "falling_debris", "boss_key": "wrecker",
			 "gimmick_keys": PackedStringArray(["falling_debris", "steam_vent", "burning_car", "fly_swarm"]),
			 "weather_keys": PackedStringArray(["rain", "dust"])}),
		# 연구소(최종) — 'Hardened'(15분 생존) 달성 해금. 냉랭한 청백 톤.
		# 날씨: 냉각 설비가 터진 한랭 구역이라 눈.
		_t("lab", "Lab", "Where it all started. No way out.", "frozen",
			Color(0.06, 0.10, 0.12), Color(0.10, 0.17, 0.20), Color(0.13, 0.22, 0.25), Color(0.30, 0.55, 0.55),
			{"unlock_achievement": "survive_15", "gimmick_key": "toxic_pool", "boss_key": "mutation",
			 "gimmick_keys": PackedStringArray(["toxic_pool", "cryo_vent", "tesla_coil"]),
			 "weather_keys": PackedStringArray(["snow"])}),
	]
	var err := ResourceSaver.save(db, "res://data/themes.tres")
	print("gen_theme_data: saved themes.tres err=%d (n=%d)" % [err, db.themes.size()])
	quit()
