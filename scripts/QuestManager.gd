extends Node
## 끝없는 과제(퀘스트) 시스템 (Autoload "QuestManager").
## 여러 트랙(처치/보스/생존)마다 "현재 과제"가 하나씩 있고, 달성하면 즉시 메타 골드 보상을 주고
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
	## 웨이브 개념이 사라진 뒤로 구 "waves" 트랙은 영구히 0/8 이었다 — 메뉴에 *절대 진행되지 않는
	## 항목*이 상시 떠 있어 유저 눈에는 버그로 보였다(P0-2). 누적 생존 분으로 교체한다.
	## 보스 처치 수(Boss Breaker)와 측정 대상이 겹치지 않는 지표를 고른 것이 이 교체의 요점이다.
	## 목표 15분은 한 판(30분 클리어)의 절반 — 첫 티어를 한 세션 안에 닿게 잡았다.
	{"id": "survive", "metric": "survive", "title": "Survivor", "verb": "Survive", "unit": "minutes",
		"base_goal": 15,  "goal_mul": 1.6,  "base_reward": 80,  "reward_mul": 1.5},
]

var _tier: Dictionary = {}      # track id -> 현재 티어(0-based, 완료한 과제 수)
var _count: Dictionary = {}     # track id -> 현재 과제 진행 카운터(완료 시 목표만큼 차감)
var _dirty: bool = false
## 생존 트랙 적산용. elapsed_changed 는 "이 판의 경과 시간"이라 판마다 0 으로 돌아간다 —
## 값이 아니라 **증가분**을 더해야 누적이 된다.
var _last_elapsed: float = -1.0   # 직전에 본 런 경과 시간(-1 = 아직 기준점 없음)
var _survive_frac: float = 0.0    # 1분에 못 미친 잔여 분. 저장에 포함해 판 사이에도 이어진다


func _ready() -> void:
	for t in TRACKS:
		_tier[t["id"]] = 0
		_count[t["id"]] = 0
	_load()
	Events.zombie_killed.connect(func(): _advance("kills", 1))
	Events.boss_died.connect(func(): _advance("bosses", 1))
	Events.elapsed_changed.connect(_on_elapsed)
	# 주기 저장 — 런 중 강제 종료(웹 탭 닫힘) 대비. 이 연결이 P0-2 의 핵심이다:
	# 예전에는 발신자가 없는 wave_complete 에 물려 있어 저장 시점이 player_died 하나뿐이었고,
	# 모바일 웹에서 흔한 "탭 닫기"로 끝내면 그 판의 퀘스트 진행이 통째로 사라졌다.
	Events.milestone_reached.connect(func(_i: int): _flush())
	Events.player_died.connect(_flush)


## 누적 생존 분 적산. 판이 바뀌면(경과 시간이 뒤로 감) 기준점만 다시 잡고 넘어간다 —
## 이어하기로 900초부터 시작하는 경우에도 그 900초를 새로 세지 않는다.
func _on_elapsed(sec: float) -> void:
	if _last_elapsed < 0.0 or sec < _last_elapsed:
		_last_elapsed = sec
		return
	_survive_frac += (sec - _last_elapsed) / 60.0
	_last_elapsed = sec
	var whole := int(floor(_survive_frac))
	if whole <= 0:
		return
	_survive_frac -= float(whole)
	_advance("survive", whole)


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
	var title := "%s %s" % [t["title"], _roman(tier + 1)]
	RewardInbox.push_reward(title, reward, "quest")   # 자동 지급 대신 보관함 적립 — 메뉴에서 직접 수령
	# 완료한 과제 이름 + 보상 통지(HUD 토스트).
	Events.quest_completed.emit(title, reward)
	_save()   # 보상 유실 방지 — 완료 즉시 저장


## 현재 활성 과제 목록(메인 메뉴 표시용): [{title, desc, current, goal, reward}].
func active_quests() -> Array:
	var out: Array = []
	for t in TRACKS:
		var id: String = t["id"]
		var tier: int = int(_tier[id])
		var goal := _goal(t, tier)
		out.append({
			"id": id,   # UI 가 종류별 아이콘을 고르는 데 쓴다(kills/bosses/survive)
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
	f.store_string(JSON.stringify({"tier": _tier, "count": _count, "frac": _survive_frac}))
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
	_survive_frac = float(parsed.get("frac", 0.0))
	# 구 "waves" 키는 TRACKS 에 없으므로 아래 루프가 그냥 지나친다 — 마이그레이션 불필요.
	for t in TRACKS:
		var id: String = t["id"]
		if typeof(tier) == TYPE_DICTIONARY and tier.has(id):
			_tier[id] = int(tier[id])
		if typeof(count) == TYPE_DICTIONARY and count.has(id):
			_count[id] = int(count[id])
