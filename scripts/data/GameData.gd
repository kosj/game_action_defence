extends Node
## 데이터 레지스트리 (Autoload "GameData").
## res://data/ 의 데이터 에셋(.tres)을 로드해 코드에 제공한다. 수치는 전부 .tres 에 있고,
## 코드는 여기서 읽어 동작한다(스펙: 하드코딩 금지, 데이터로 분리).
## 웹 빌드 호환을 위해 디렉터리 스캔 대신 단일 인덱스 리소스(ZombieDB 등)를 load 한다.

const ZOMBIE_DB_PATH := "res://data/zombies.tres"
const META_DB_PATH := "res://data/meta_upgrades.tres"
const DIFFICULTY_PATH := "res://data/difficulty.tres"
const ITEM_CATALOG_PATH := "res://data/item_catalog.tres"
const CHARACTER_DB_PATH := "res://data/character_db.tres"
const ACHIEVEMENT_DB_PATH := "res://data/achievements.tres"
const THEME_DB_PATH := "res://data/themes.tres"

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

var characters: Array[CharacterData] = []   # 캐릭터 카탈로그(표시/기본 순서)
var _character_by_id: Dictionary = {}

var achievements: Array[AchievementData] = []   # 도전과제 카탈로그(표시 순서)
var _achievement_by_id: Dictionary = {}

var themes: Array[ThemeData] = []   # 아레나 테마 카탈로그(난이도/표시 순서)


func _ready() -> void:
	_load_zombies()
	_load_meta()
	_load_difficulty()
	_load_items()
	_load_characters()
	_load_achievements()
	_load_themes()


func _load_themes() -> void:
	if not ResourceLoader.exists(THEME_DB_PATH):
		push_warning("GameData: %s 없음 — 테마 데이터 로드 실패" % THEME_DB_PATH)
		return
	var db = load(THEME_DB_PATH)
	if db is ArenaThemeDB:
		themes = db.themes


func _load_achievements() -> void:
	if not ResourceLoader.exists(ACHIEVEMENT_DB_PATH):
		push_warning("GameData: %s 없음 — 도전과제 데이터 로드 실패" % ACHIEVEMENT_DB_PATH)
		return
	var db = load(ACHIEVEMENT_DB_PATH)
	if db is AchievementDB:
		achievements = db.achievements
		for a in achievements:
			if a != null and a.id != "":
				_achievement_by_id[a.id] = a


func achievement(id: String) -> AchievementData:
	return _achievement_by_id.get(id)


func _load_characters() -> void:
	if not ResourceLoader.exists(CHARACTER_DB_PATH):
		push_warning("GameData: %s 없음 — 캐릭터 데이터 로드 실패" % CHARACTER_DB_PATH)
		return
	var db = load(CHARACTER_DB_PATH)
	if db is CharacterDB:
		characters = db.characters
		for c in characters:
			if c != null and c.id != "":
				_character_by_id[c.id] = c


func character(id: String) -> CharacterData:
	return _character_by_id.get(id)


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
