extends SceneTree
## 일회성: 도전과제 카탈로그 .tres 생성.  godot --headless --path . --script res://tools/gen_achievement_data.gd

func _a(id: String, disp: String, desc: String, metric: String, threshold: int, reward: int) -> AchievementData:
	var a := AchievementData.new()
	a.id = id; a.display = disp; a.desc = desc
	a.metric = metric; a.threshold = threshold; a.reward_gold = reward
	return a


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var db := AchievementDB.new()
	db.achievements = [
		_a("kills_100",   "First Blood",   "Kill 100 zombies (total)",     "total_kills", 100,   50),
		_a("kills_1k",    "Slayer",        "Kill 1,000 zombies (total)",   "total_kills", 1000,  150),
		_a("kills_10k",   "Exterminator",  "Kill 10,000 zombies (total)",  "total_kills", 10000, 500),
		_a("boss_5",      "Boss Hunter",   "Defeat 5 bosses (total)",      "boss_kills",  5,     100),
		_a("boss_25",     "Boss Slayer",   "Defeat 25 bosses (total)",     "boss_kills",  25,    300),
		_a("survive_5",   "Survivor",      "Survive 5 minutes in one run", "best_time",   300,   80),
		_a("survive_15",  "Hardened",      "Survive 15 minutes in one run","best_time",   900,   200),
		_a("survive_30",  "Deadline Beaten","Survive 30 minutes (CLEAR)",  "best_time",   1800,  500),
		_a("level_20",    "Veteran Blood", "Reach level 20 in one run",    "best_level",  20,    100),
		_a("level_40",    "Ascended",      "Reach level 40 in one run",    "best_level",  40,    250),
	]
	var err := ResourceSaver.save(db, "res://data/achievements.tres")
	print("gen_achievement_data: saved achievements.tres err=%d (n=%d)" % [err, db.achievements.size()])
	quit()
