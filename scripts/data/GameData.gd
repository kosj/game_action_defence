extends Node
## 데이터 레지스트리 (Autoload "GameData").
## res://data/ 의 데이터 에셋(.tres)을 로드해 코드에 제공한다. 수치는 전부 .tres 에 있고,
## 코드는 여기서 읽어 동작한다(스펙: 하드코딩 금지, 데이터로 분리).
## 웹 빌드 호환을 위해 디렉터리 스캔 대신 단일 인덱스 리소스(ZombieDB 등)를 load 한다.

const ZOMBIE_DB_PATH := "res://data/zombies.tres"
const META_DB_PATH := "res://data/meta_upgrades.tres"
const DIFFICULTY_PATH := "res://data/difficulty.tres"
const ITEM_CATALOG_PATH := "res://data/item_catalog.tres"

var zombie_list: Array[ZombieData] = []   # 정의 순서 유지(스포너 가중치 인덱스와 정렬)
var _zombie_by_id: Dictionary = {}

var meta_upgrades: Array[MetaUpgradeData] = []   # 상점 표시 순서

var difficulty: DifficultyData = null     # 시간 기반 난이도 곡선

# 무기/패시브/진화 카탈로그(뱀서식 아이템). 배열 순서 = 표시/뽑기 순서.
var weapon_defs: Array[WeaponData] = []
var passive_defs: Array[PassiveData] = []
var evolution_defs: Array[EvolutionData] = []
var _weapon_by_id: Dictionary = {}
var _passive_by_id: Dictionary = {}


func _ready() -> void:
	_load_zombies()
	_load_meta()
	_load_difficulty()
	_load_items()


func _load_items() -> void:
	if not ResourceLoader.exists(ITEM_CATALOG_PATH):
		push_warning("GameData: %s 없음 — 아이템 카탈로그 로드 실패" % ITEM_CATALOG_PATH)
		return
	var db = load(ITEM_CATALOG_PATH)
	if db is ItemCatalogDB:
		weapon_defs = db.weapons
		passive_defs = db.passives
		evolution_defs = db.evolutions
		for w in weapon_defs:
			if w != null and w.id != "":
				_weapon_by_id[w.id] = w
		for p in passive_defs:
			if p != null and p.id != "":
				_passive_by_id[p.id] = p


func weapon_def(id: String) -> WeaponData:
	return _weapon_by_id.get(id)


func passive_def(id: String) -> PassiveData:
	return _passive_by_id.get(id)


func _load_difficulty() -> void:
	if ResourceLoader.exists(DIFFICULTY_PATH):
		var d = load(DIFFICULTY_PATH)
		if d is DifficultyData:
			difficulty = d
	if difficulty == null:
		difficulty = DifficultyData.new()   # 폴백: 기본값(런 안정성 보장)
		push_warning("GameData: %s 없음 — 기본 난이도 사용" % DIFFICULTY_PATH)


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
