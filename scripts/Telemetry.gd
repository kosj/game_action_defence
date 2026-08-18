extends Node
## 런 기록 수집 (Autoload "Telemetry") — **기기 밖으로 아무것도 보내지 않는다.**
##
## 왜 필요한가
## -----------
## 지금 밸런스 판단의 근거는 전부 오토플레이(`tools/sim_balance.*`)다. AI 는 보스 접촉을 피하는
## 데 특히 서툴고, 그건 사람이 학습으로 해결하는 기술이다 — 그래서 모든 결론에 "AI 기준"이라는
## 단서가 붙어 있다. 사람이 실제로 어디서 죽고 어디서 그만두는지는 재 보기 전엔 알 수 없다.
##
## 무엇을 남기나
## -------------
## 한 판이 끝날 때 요약 1줄을 `user://telemetry.jsonl` 에 덧붙인다. **스키마는 sim_balance 의
## 출력과 같다** — 그래야 사람 데이터와 AI 데이터를 같은 도구(`tools/analyze_telemetry.py`)로
## 나란히 볼 수 있다.
##
## 개인정보
## --------
## 기기 식별자·계정·위치·IP 를 수집하지 않는다. 남기는 것은 이 판의 게임 진행 수치뿐이고,
## 파일은 이 기기의 `user://` 에만 있다. 네트워크 코드는 이 파일에 없다 —
## 원격 전송은 백엔드·개인정보처리방침·동의 절차가 정해진 뒤 별도 작업으로 붙인다
## (`LAUNCH_CHECKLIST.md` D·E).

const PATH := "user://telemetry.jsonl"
const PARTIAL_PATH := "user://telemetry_partial.json"
const MAX_RECORDS := 300        # 이 개수를 넘으면 오래된 것부터 버린다(무한 증가 방지)
const PARTIAL_INTERVAL := 60.0  # 진행 중 스냅샷 주기 — 중도 이탈을 잡는 유일한 수단
const SAMPLE_INTERVAL := 60.0   # 분당 스냅샷

var enabled: bool = true

var _active: bool = false
var _hits: int = 0
var _first_hit: float = -1.0
var _last_hp: int = -1
var _boss_spawn_t: float = -1.0
var _boss_fights: Array = []
var _boss_spawns: int = 0
var _boss_kills: int = 0
var _cleared: bool = false
var _samples: Array = []
var _next_sample: float = SAMPLE_INTERVAL
var _partial_accum: float = 0.0


func _ready() -> void:
	Events.player_died.connect(_on_run_end.bind("died"))
	Events.run_cleared.connect(func(): _cleared = true)
	Events.player_health_changed.connect(_on_hp)
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.boss_died.connect(_on_boss_died)
	_promote_abandoned()   # 지난번에 끝맺지 못한 판이 있으면 '이탈'로 승격


## 판 시작 — `Main._ready()` 가 호출한다. 이어하기도 같은 진입점을 쓴다.
func begin_run() -> void:
	_active = enabled
	_hits = 0
	_first_hit = -1.0
	_last_hp = -1
	_boss_spawn_t = -1.0
	_boss_fights = []
	_boss_spawns = 0
	_boss_kills = 0
	_cleared = false
	_samples = []
	_next_sample = SAMPLE_INTERVAL
	_partial_accum = 0.0


func _process(delta: float) -> void:
	if not _active:
		return
	var el := float(Events.elapsed_time)
	if el >= _next_sample:
		_samples.append({"min": int(round(_next_sample / 60.0)), "kills": Events.total_kills,
			"level": Events.level, "hp": Events.player_health})
		_next_sample += SAMPLE_INTERVAL
	# 진행 중 스냅샷 — 웹 탭을 닫거나 앱을 죽이면 완료 기록이 남지 않는다.
	# 그 판이야말로 "어디서 그만뒀는지"라 오히려 더 중요하다.
	_partial_accum += delta
	if _partial_accum >= PARTIAL_INTERVAL:
		_partial_accum = 0.0
		_write_json(PARTIAL_PATH, _snapshot("abandoned"))


func _on_hp(health: int, _mx: int) -> void:
	if not _active:
		return
	if _last_hp >= 0 and health < _last_hp:
		_hits += 1
		if _first_hit < 0.0:
			_first_hit = float(Events.elapsed_time)
	_last_hp = health


func _on_boss_spawned(_mx: int) -> void:
	if not _active:
		return
	_boss_spawns += 1
	_boss_spawn_t = float(Events.elapsed_time)


func _on_boss_died() -> void:
	if not _active:
		return
	_boss_kills += 1
	if _boss_spawn_t >= 0.0:
		_boss_fights.append(snappedf(float(Events.elapsed_time) - _boss_spawn_t, 0.1))
		_boss_spawn_t = -1.0


func _on_run_end(outcome: String) -> void:
	if not _active:
		return
	_active = false
	_append(_snapshot(outcome))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PARTIAL_PATH))


## sim_balance.gd 의 SIMRESULT 와 같은 키를 쓴다 — 두 출처를 한 도구로 비교하기 위함이다.
func _snapshot(outcome: String) -> Dictionary:
	var c: CharacterData = CharacterManager.selected()
	var t: ThemeData = ThemeManager.selected()
	return {
		"source": "human",
		"persona": "human",
		"outcome": outcome,                 # "died" | "abandoned"
		"version": Events.VERSION,
		"build": Events.build_sha(),
		"character": (c.id if c != null else ""),
		"theme": (t.id if t != null else ""),
		"survived_s": snappedf(float(Events.elapsed_time), 0.1),
		"died": outcome == "died",
		"cleared": _cleared,
		"level": Events.level,
		"kills": Events.total_kills,
		"score": Events.score,
		"gold": Events.total_gold,
		"hits": _hits,
		"first_hit_s": snappedf(_first_hit, 0.1),
		"boss_spawns": _boss_spawns,
		"boss_kills": _boss_kills,
		"boss_fight_s": _boss_fights,
		"weapons": Events.weapons.duplicate(),
		"passives": Events.passives.duplicate(),
		"samples": _samples,
	}


## 지난 실행에서 끝맺지 못한 판(웹 탭 닫힘·앱 강제 종료)을 '이탈' 기록으로 올린다.
func _promote_abandoned() -> void:
	if not FileAccess.file_exists(PARTIAL_PATH):
		return
	var f := FileAccess.open(PARTIAL_PATH, FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(parsed) == TYPE_DICTIONARY:
			_append(parsed)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PARTIAL_PATH))


func _append(rec: Dictionary) -> void:
	var lines := load_records_raw()
	lines.append(JSON.stringify(rec))
	if lines.size() > MAX_RECORDS:
		lines = lines.slice(lines.size() - MAX_RECORDS)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	for l in lines:
		f.store_line(l)
	f.close()


func _write_json(path: String, rec: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(rec))
	f.close()


## 저장된 기록의 원문(JSON 문자열) 목록. 비어 있으면 빈 배열.
func load_records_raw() -> Array:
	if not FileAccess.file_exists(PATH):
		return []
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return []
	var out: Array = []
	while not f.eof_reached():
		var l := f.get_line()
		if l.strip_edges() != "":
			out.append(l)
	f.close()
	return out


func record_count() -> int:
	return load_records_raw().size()


## 전체 기록을 JSONL 한 덩어리로. 개발 빌드의 내보내기(클립보드)와 분석 도구가 쓴다.
func export_text() -> String:
	return "\n".join(PackedStringArray(load_records_raw()))


func clear_records() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PARTIAL_PATH))
