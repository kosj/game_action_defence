extends Node
## 도전과제 추적/해금 관리 (Autoload "AchievementManager").
## Events 시그널로 지표(누적 처치·보스·최고 생존시간·최고 레벨)를 갱신하고, 임계 도달 시 해금 →
## 메타 골드 보상 + achievement_unlocked 알림. 진행/해금 상태를 user://achievements.save 에 보존한다.

const SAVE_PATH := "user://achievements.save"

var stats: Dictionary = {"total_kills": 0, "boss_kills": 0, "best_time": 0, "best_level": 1}
var _unlocked: Dictionary = {}   # id -> true
var _dirty: bool = false


func _ready() -> void:
	_load()
	Events.zombie_killed.connect(func(): _add("total_kills", 1))
	Events.boss_died.connect(func(): _add("boss_kills", 1))
	Events.elapsed_changed.connect(func(sec: float): _set_max("best_time", int(sec)))
	Events.level_up.connect(func(lvl: int): _set_max("best_level", lvl))
	Events.player_died.connect(_flush)


func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)


func progress(metric: String) -> int:
	return int(stats.get(metric, 0))


## 누적 지표 증가.
func _add(metric: String, n: int) -> void:
	stats[metric] = int(stats.get(metric, 0)) + n
	_dirty = true
	_check(metric)


## 최고값 지표 갱신(단일 런 최고 생존/레벨 등).
func _set_max(metric: String, value: int) -> void:
	if value > int(stats.get(metric, 0)):
		stats[metric] = value
		_dirty = true
		_check(metric)


## 해당 지표를 쓰는 미해금 과제 중 임계 도달분을 해금한다.
func _check(metric: String) -> void:
	for a in GameData.achievements:
		if a == null or a.metric != metric or _unlocked.has(a.id):
			continue
		if int(stats.get(metric, 0)) >= a.threshold:
			_unlock(a)


func _unlock(a: AchievementData) -> void:
	_unlocked[a.id] = true
	if a.reward_gold > 0:
		MetaManager.reward_gold(a.reward_gold)   # 메타 은행에 즉시 적립
	Events.achievement_unlocked.emit(a.display)
	_save()   # 해금은 즉시 저장(보상 유실 방지)


## 런 종료 시(사망) 진행 저장 — 매 처치마다 디스크 쓰기를 피하기 위한 지연 저장.
func _flush() -> void:
	if _dirty:
		_save()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var st = parsed.get("stats", {})
	if typeof(st) == TYPE_DICTIONARY:
		for k in st.keys():
			stats[str(k)] = int(st[k])
	var un = parsed.get("unlocked", [])
	if typeof(un) == TYPE_ARRAY:
		for id in un:
			_unlocked[str(id)] = true


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"stats": stats, "unlocked": _unlocked.keys()}))
		f.close()
	_dirty = false
