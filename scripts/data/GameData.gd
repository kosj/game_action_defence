extends Node
## 데이터 레지스트리 (Autoload "GameData").
## res://data/ 의 데이터 에셋(.tres)을 로드해 코드에 제공한다. 수치는 전부 .tres 에 있고,
## 코드는 여기서 읽어 동작한다(스펙: 하드코딩 금지, 데이터로 분리).
## 웹 빌드 호환을 위해 디렉터리 스캔 대신 단일 인덱스 리소스(ZombieDB 등)를 load 한다.

const ZOMBIE_DB_PATH := "res://data/zombies.tres"
const META_DB_PATH := "res://data/meta_upgrades.tres"

var zombie_list: Array[ZombieData] = []   # 정의 순서 유지(스포너 가중치 인덱스와 정렬)
var _zombie_by_id: Dictionary = {}

var meta_upgrades: Array[MetaUpgradeData] = []   # 상점 표시 순서


func _ready() -> void:
	_load_zombies()
	_load_meta()


func _load_meta() -> void:
	if not ResourceLoader.exists(META_DB_PATH):
		push_warning("GameData: %s 없음 — 메타 강화 데이터 로드 실패" % META_DB_PATH)
		return
	var db = load(META_DB_PATH)
	if db is MetaUpgradeDB:
		meta_upgrades = db.upgrades


func _load_zombies() -> void:
	if not ResourceLoader.exists(ZOMBIE_DB_PATH):
		push_warning("GameData: %s 없음 — 좀비 데이터 로드 실패" % ZOMBIE_DB_PATH)
		return
	var db = load(ZOMBIE_DB_PATH)
	if db is ZombieDB:
		zombie_list = db.zombies
		for z in zombie_list:
			if z != null and z.id != "":
				_zombie_by_id[z.id] = z


func zombie(id: String) -> ZombieData:
	return _zombie_by_id.get(id)
