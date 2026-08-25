extends Node
## 위협 등급(Threat Rank) — 같은 콘텐츠를 다시 플레이할 이유. HANDOFF P1-12 / CONTENT_PLAN §2 Phase A.
##
## 규칙은 전부 `data/threat_ranks.tres`(생성기 산출물)에 있고, 여기서는 **고르고·해금하고·
## 기록을 남기는 것**만 한다. 적용은 각 소비처가 이 매니저의 접근자를 곱한다 —
## 밸런스 테이블(difficulty/balance.tres)을 대체하지 않는다.
##
## **등급 1 은 항등원이다**(배수 1.0 / 증감 0). 지금까지의 실측이 기준선으로 남는 유일한 조건이고
## scenes/ThreatTest.tscn 이 이걸 검사한다.
##
## ── 해금 조건을 계획에서 바꿨다 ─────────────────────────────────────────────
## `CONTENT_PLAN` 초안은 "클리어할 때마다 해금"이었다. 그런데 **클리어(30분)한 사람이 아직
## 없다** — 사람 최고 19.0분, 오토플레이 15.2분(BALANCE.md §3-6). 그대로 두면 등급 2가
## 영원히 안 열려, "만들어 놓고 아무도 못 보는 콘텐츠"라는 P1-13 과 똑같은 병이 된다.
## 그래서 **보스 1회 처치**(≈10분)를 조건으로 낮췄다. 사람 실측이 3/3 으로 넘은 벽이라
## 도달 가능하고, 등급이 오를수록 그 보스가 어려워지므로 난이도 사다리로도 성립한다.

const SAVE_PATH := "user://threat.save"
const DB_PATH := "res://data/threat_ranks.tres"

signal changed

var _ranks: Array = []          # ThreatRankData (등급 순)
var _max_rank: int = 1          # 해금된 최고 등급
var _selected: int = 1
var _best: Dictionary = {}      # "등급" -> 최고 생존 시간(초)
var _run_boss_kills: int = 0    # 이번 판 보스 처치 수(해금 판정용)


func _ready() -> void:
	var db = load(DB_PATH)
	if db != null and db is ThreatRankDB:
		_ranks = db.ranks
	if _ranks.is_empty():
		push_error("위협 등급 데이터를 불러오지 못했습니다: %s" % DB_PATH)
	_load()
	Events.boss_died.connect(func() -> void: _run_boss_kills += 1)
	Events.player_died.connect(_finish_run)
	Events.run_cleared.connect(_finish_run)


func count() -> int:
	return _ranks.size()


func max_rank() -> int:
	return _max_rank


func selected_rank() -> int:
	return _selected


## 해금된 등급만 고를 수 있다. 범위를 벗어나면 아무것도 하지 않고 false.
func select(rank: int) -> bool:
	if rank < 1 or rank > _max_rank or rank > count():
		return false
	if rank != _selected:
		_selected = rank
		_save()
		changed.emit()
	return true


func data(rank: int) -> ThreatRankData:
	var i := rank - 1
	return _ranks[i] if i >= 0 and i < _ranks.size() else null


## 이번 판에 적용 중인 등급. 데이터가 없으면 기본값(=등급 1과 같은 항등원)을 돌려주어
## 호출부가 null 검사를 흩뿌리지 않게 한다.
func active() -> ThreatRankData:
	var d := data(_selected)
	return d if d != null else ThreatRankData.new()


func best_seconds(rank: int) -> float:
	return float(_best.get(str(rank), 0.0))


# ── 소비처가 쓰는 접근자 ────────────────────────────────────────────────────
func enemy_hp_mult() -> float:      return active().enemy_hp_mult
func enemy_speed_mult() -> float:   return active().enemy_speed_mult
func boss_hp_mult() -> float:       return active().boss_hp_mult
func chest_interval_mult() -> float: return active().chest_interval_mult
func elite_interval_mult() -> float: return active().elite_interval_mult
func boss_heal_charges_add() -> int: return active().boss_heal_charges_add
func start_health_add() -> int:      return active().start_health_add


## 판 시작 — 해금 판정용 카운터를 연다. Main.gd 가 부른다.
func begin_run() -> void:
	_run_boss_kills = 0


## 판 종료(사망/클리어) — 기록 갱신 + 해금 판정. 두 시그널 모두 여기로 온다.
func _finish_run() -> void:
	var secs := Events.elapsed_time
	var key := str(_selected)
	if secs > float(_best.get(key, 0.0)):
		_best[key] = secs
	# 다음 등급 해금: 이번 판에서 보스를 잡았고, 지금 고른 등급이 최고 해금 등급일 때만.
	# (낮은 등급으로 돌아가 잡는 것으로는 열리지 않는다 — 사다리가 무의미해진다.)
	if _run_boss_kills > 0 and _selected == _max_rank and _max_rank < count():
		_max_rank += 1
	_run_boss_kills = 0
	_save()
	changed.emit()


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
	_max_rank = clampi(int(parsed.get("max_rank", 1)), 1, maxi(count(), 1))
	_selected = clampi(int(parsed.get("selected", 1)), 1, _max_rank)
	var b = parsed.get("best", {})
	if typeof(b) == TYPE_DICTIONARY:
		for k in b.keys():
			_best[str(k)] = float(b[k])


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"max_rank": _max_rank, "selected": _selected, "best": _best}))
		f.close()


## 테스트 전용 — 진행 상태를 초기화한다.
func reset_all() -> void:
	_max_rank = 1
	_selected = 1
	_best = {}
	_run_boss_kills = 0
	_save()
	changed.emit()
