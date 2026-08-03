extends Node
## 끝없는 과제(퀘스트) 시스템 (Autoload "QuestManager").
## 여러 트랙(처치/보스/웨이브)마다 "현재 과제"가 하나씩 있고, 달성하면 즉시 메타 골드 보상을 주고
## 다음 티어 과제를 자동 생성한다 — 목표치도, 보상도 티어마다 커진다(끝없이 반복·성장).
## 진행/티어는 user://quests.save 에 보존. 완료 시 Events.quest_completed 로 HUD 토스트 알림.

const SAVE_PATH := "user://quests.save"

## 트랙 정의(구조는 고정, 티어는 공식으로 무한 생성).
##  metric: 누적 지표 / base_goal·goal_mul: 티어별 목표 / base_reward·reward_mul: 티어별 보상.
const TRACKS := [
	{"id": "kills",  "metric": "kills",  "title": "Zombie Hunter", "verb": "Kill",   "unit": "zombies",
		"base_goal": 120, "goal_mul": 1.65, "base_reward": 60,  "reward_mul": 1.5},
	{"id": "bosses", "metric": "bosses", "title": "Boss Breaker",  "verb": "Defeat", "unit": "bosses",
		"base_goal": 2,   "goal_mul": 1.8,  "base_reward": 120, "reward_mul": 1.6},
	{"id": "waves",  "metric": "waves",  "title": "Wave Rider",    "verb": "Clear",  "unit": "waves",
		"base_goal": 8,   "goal_mul": 1.6,  "base_reward": 80,  "reward_mul": 1.5},
]

var _tier: Dictionary = {}      # track id -> 현재 티어(0-based, 완료한 과제 수)
var _count: Dictionary = {}     # track id -> 현재 과제 진행 카운터(완료 시 목표만큼 차감)
var _dirty: bool = false


func _ready() -> void:
	for t in TRACKS:
		_tier[t["id"]] = 0
		_count[t["id"]] = 0
	_load()
	Events.zombie_killed.connect(func(): _advance("kills", 1))
	Events.boss_died.connect(func(): _advance("bosses", 1))
	Events.wave_complete.connect(func(_w: int): _advance("waves", 1))
	Events.player_died.connect(_flush)


## 티어별 목표치 / 보상(공식). 티어가 오를수록 둘 다 커진다.
func _goal(t: Dictionary, tier: int) -> int:
	return int(round(float(t["base_goal"]) * pow(t["goal_mul"], tier)))


func _reward(t: Dictionary, tier: int) -> int:
	return int(round(float(t["base_reward"]) * pow(t["reward_mul"], tier)))


func _track(id: String) -> Dictionary:
	for t in TRACKS:
		if t["id"] == id:
			return t
	return {}


## 지표 증가 → 현재 과제 목표 도달분을 모두 완료 처리(연쇄 완료 대비 while).
func _advance(id: String, n: int) -> void:
	var t := _track(id)
	if t.is_empty():
		return
	_count[id] = int(_count[id]) + n
	_dirty = true
	while int(_count[id]) >= _goal(t, int(_tier[id])):
		_complete(t)


func _complete(t: Dictionary) -> void:
	var id: String = t["id"]
	var tier: int = int(_tier[id])
	var goal := _goal(t, tier)
	var reward := _reward(t, tier)
	_count[id] = int(_count[id]) - goal
	_tier[id] = tier + 1
	MetaManager.reward_gold(reward)   # 메타 은행에 즉시 적립
	# 완료한 과제 이름 + 보상 통지(HUD 토스트).
	Events.quest_completed.emit("%s %s" % [t["title"], _roman(tier + 1)], reward)
	_save()   # 보상 유실 방지 — 완료 즉시 저장


## 현재 활성 과제 목록(메인 메뉴 표시용): [{title, desc, current, goal, reward}].
func active_quests() -> Array:
	var out: Array = []
	for t in TRACKS:
		var id: String = t["id"]
		var tier: int = int(_tier[id])
		var goal := _goal(t, tier)
		out.append({
			"title": "%s %s" % [t["title"], _roman(tier + 1)],
			"desc": "%s %d %s" % [t["verb"], goal, t["unit"]],
			"current": mini(int(_count[id]), goal),
			"goal": goal,
			"reward": _reward(t, tier),
		})
	return out


## 간단 로마 숫자(티어 라벨용). 범위를 벗어나면 숫자로.
func _roman(n: int) -> String:
	const R := ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
		"XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX"]
	return R[n] if n >= 0 and n < R.size() else str(n)


func _flush() -> void:
	if _dirty:
		_save()


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"tier": _tier, "count": _count}))
	f.close()
	_dirty = false


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
	var tier = parsed.get("tier", {})
	var count = parsed.get("count", {})
	for t in TRACKS:
		var id: String = t["id"]
		if typeof(tier) == TYPE_DICTIONARY and tier.has(id):
			_tier[id] = int(tier[id])
		if typeof(count) == TYPE_DICTIONARY and count.has(id):
			_count[id] = int(count[id])
