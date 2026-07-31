extends SceneTree
## 일회성 데이터 생성 도구: 현재 하드코딩 값과 "동일하게" 좀비 .tres 를 생성한다(회귀 방지).
## 실행:  godot --headless --path . --script res://tools/gen_zombie_data.gd
## (사전에 --import 로 프로젝트를 임포트해 class_name 이 등록돼 있어야 한다.)

const DEFS := [
	{"id": "walker",   "speed": 65.0,  "hp": 3,  "mod": Color(0.70, 0.95, 0.55), "score": 10, "scale": 1.00, "contact": 1, "behavior": "chase",   "tex": "res://assets/sprites/zombie_walker.png"},
	{"id": "sprinter", "speed": 150.0, "hp": 2,  "mod": Color(1.00, 0.35, 0.35), "score": 18, "scale": 0.95, "contact": 1, "behavior": "chase",   "tex": "res://assets/sprites/zombie_sprinter.png"},
	{"id": "bloater",  "speed": 36.0,  "hp": 20, "mod": Color(0.60, 0.90, 0.50), "score": 55, "scale": 1.15, "contact": 3, "behavior": "chase",   "tex": "res://assets/sprites/zombie_bloater.png"},
	{"id": "gaunt",    "speed": 85.0,  "hp": 3,  "mod": Color(0.80, 0.90, 0.95), "score": 18, "scale": 0.95, "contact": 1, "behavior": "weaver",  "tex": "res://assets/sprites/zombie_gaunt.png"},
	{"id": "foreman",  "speed": 58.0,  "hp": 7,  "mod": Color(1.00, 0.60, 0.25), "score": 28, "scale": 1.05, "contact": 2, "behavior": "chase",   "tex": "res://assets/sprites/zombie_foreman.png"},
	{"id": "toxic",    "speed": 72.0,  "hp": 4,  "mod": Color(0.55, 0.95, 0.40), "score": 26, "scale": 1.00, "contact": 2, "behavior": "chase",   "tex": "res://assets/sprites/zombie_toxic.png"},
	{"id": "screamer", "speed": 145.0, "hp": 1,  "mod": Color(0.80, 0.95, 0.80), "score": 16, "scale": 0.95, "contact": 1, "behavior": "chase",   "tex": "res://assets/sprites/zombie_screamer.png"},
	{"id": "cop",      "speed": 80.0,  "hp": 6,  "mod": Color(0.45, 0.65, 1.00), "score": 30, "scale": 1.05, "contact": 2, "behavior": "chase",   "tex": "res://assets/sprites/zombie_cop.png"},
	{"id": "soldier",  "speed": 60.0,  "hp": 5,  "mod": Color(0.60, 0.80, 0.40), "score": 40, "scale": 1.00, "contact": 1, "behavior": "spitter", "tex": "res://assets/sprites/zombie_soldier.png"},
	{"id": "longneck", "speed": 50.0,  "hp": 3,  "mod": Color(0.50, 1.00, 0.30), "score": 34, "scale": 1.05, "contact": 1, "behavior": "spitter", "tex": "res://assets/sprites/zombie_longneck.png"},
	{"id": "suit",     "speed": 78.0,  "hp": 3,  "mod": Color(0.72, 0.78, 0.85), "score": 20, "scale": 1.00, "contact": 1, "behavior": "chase",   "tex": "res://assets/sprites/zombie_suit.png"},
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/zombies")
	var db := ZombieDB.new()
	for d in DEFS:
		var z := ZombieData.new()
		z.id = d["id"]
		z.speed = d["speed"]
		z.max_health = d["hp"]
		z.modulate = d["mod"]
		z.score = d["score"]
		z.scale = d["scale"]
		z.contact = d["contact"]
		z.behavior = d["behavior"]
		z.texture = load(d["tex"])
		var path: String = "res://data/zombies/%s.tres" % d["id"]
		ResourceSaver.save(z, path)
		z.take_over_path(path)   # DB 가 ext_resource 로 참조하도록 경로 확정
		db.zombies.append(z)
	var err := ResourceSaver.save(db, "res://data/zombies.tres")
	print("gen_zombie_data: saved %d zombies, db err=%d" % [db.zombies.size(), err])
	quit()
