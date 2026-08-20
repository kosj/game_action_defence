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

const _Gem := preload("res://scripts/Gold.gd")

const PATH := "user://telemetry.jsonl"
const PARTIAL_PATH := "user://telemetry_partial.json"
const MAX_RECORDS := 300        # 이 개수를 넘으면 오래된 것부터 버린다(무한 증가 방지)
## 진행 중 스냅샷 주기. 두 가지를 동시에 한다 —
##  ① 중도 종료 지점 기록(이 주기만큼 실제 플레이 시간을 과소보고한다)
##  ② **프리즈 직전 상태 보존**(P0-4). 라이브 빌드에서 7분경 게임이 멈춘 사례가 나왔는데,
##     레벨업 카드도 없이 멈췄다 — 즉 일시정지 워치독조차 못 도는 상태(무한 루프/크래시)다.
##     멈춘 뒤에는 아무것도 기록할 수 없으므로, 멈추기 직전 상태를 촘촘히 남기는 수밖에 없다.
## tools/analyze_telemetry.py 의 PARTIAL_SNAPSHOT_S 와 같은 값이어야 한다.
const PARTIAL_INTERVAL := 10.0
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
## 이어하기로 시작한 판인가. 이어하기는 세이브에서 elapsed_time 만 복원하고 피격·보스 조우·
## 분당 스냅샷은 새로 세므로, 그대로 두면 "20분 살았는데 피격 3회" 같은 왜곡된 기록이 남는다.
## 표시해 두고 분석 도구가 기본 제외한다.
##
## 판별에 SaveManager.pending_continue 를 쓸 수 없다 — Godot 은 자식의 _ready() 를 부모보다
## 먼저 부르므로, Main._ready() 가 begin_run() 을 호출하는 시점엔 Player._ready() 가 이미
## 그 플래그를 지웠다. 대신 경과 시간을 본다(새 게임은 Events.reset() 으로 0 이다).
var _resumed: bool = false
var _samples: Array = []
var _next_sample: float = SAMPLE_INTERVAL
var _partial_accum: float = 0.0
## 마지막으로 관측한 경과 시간. **경과가 뒤로 가면 그 사이에 Events.reset() 이 일어난 것**이고,
## 그 시점의 Events 값은 이 판의 것이 아니다(P0-9). 자세한 이유는 `_run_was_reset()` 참고.
var _last_elapsed: float = 0.0

# ── 프리즈 진단 (P0-4) ───────────────────────────────────────────────
## 스냅샷 구간 안에서 관측된 최악의 프레임 시간(ms). 성능 붕괴(느려짐)와 로직 정지(멈춤)를
## 가른다 — 붕괴라면 이 값이 먼저 치솟고, 정지라면 정상값을 유지하다 기록이 끊긴다.
var _frame_ms_max: float = 0.0
## 일시정지 워치독이 무엇을 몇 번 복구했나. 프리즈 직전에 반복 발동했다면 그게 단서다.
var _watchdog_log: Array = []


func _ready() -> void:
	Events.player_died.connect(end_run.bind("died"))
	Events.pause_watchdog_fired.connect(func(reason: String, detail: String):
		if _watchdog_log.size() < 20:      # 무한 증가 방지 — 앞쪽 20건이면 원인 파악에 충분하다
			_watchdog_log.append("%s@%.0fs %s" % [reason, Events.elapsed_time, detail]))
	Events.run_cleared.connect(func(): _cleared = true)
	Events.player_health_changed.connect(_on_hp)
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.boss_died.connect(_on_boss_died)
	_promote_abandoned()   # 지난번에 끝맺지 못한 판이 있으면 '이탈'로 승격


## 판 시작 — `Main._ready()` 가 호출한다. 이어하기도 같은 진입점을 쓴다.
func begin_run() -> void:
	# 이전 판이 끝맺지 못한 채 남아 있으면 **먼저 기록한다.** 여기서 안 건지면 아래 초기화 뒤
	# 진행 스냅샷이 그 파일을 덮어써 그 판이 영구히 사라진다 — 실제로 30분 클리어 판이 그렇게
	# 소실됐다(클리어 후 메뉴로 나가고 새 게임을 시작한 경우).
	_promote_abandoned()
	_active = enabled
	_resumed = float(Events.elapsed_time) > 1.0
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
	_last_elapsed = float(Events.elapsed_time)   # 이어하기는 0 이 아닌 값에서 시작한다
	_frame_ms_max = 0.0
	_watchdog_log = []
	Cheats.used_this_run = false   # 치트 사용 여부는 판 단위로 센다


func _process(delta: float) -> void:
	if not _active:
		return
	if _stop_if_reset():
		return
	_frame_ms_max = maxf(_frame_ms_max, delta * 1000.0)
	var el := float(Events.elapsed_time)
	_last_elapsed = el
	if el >= _next_sample:
		# 메모리·노드 수를 분당으로 함께 남긴다 — 크래시가 누수 때문이라면 이 곡선이 곧 증거다.
		# 진단(diag)은 마지막 시점만 알려주므로 "늘고 있었나"를 못 본다. 추이가 있어야 판별된다.
		_samples.append({"min": int(round(_next_sample / 60.0)), "kills": Events.total_kills,
			"level": Events.level, "hp": Events.player_health,
			"mem": _mem_mb(), "nodes": _node_count()})
		_next_sample += SAMPLE_INTERVAL
	# 진행 중 스냅샷 — 웹 탭을 닫거나 앱을 죽이면 완료 기록이 남지 않는다.
	# 그 판이야말로 "어디서 그만뒀는지"라 오히려 더 중요하다.
	_partial_accum += delta
	if _partial_accum >= PARTIAL_INTERVAL:
		_partial_accum = 0.0
		_write_json(PARTIAL_PATH, _snapshot("abandoned"))
		_frame_ms_max = 0.0   # 구간마다 새로 잰다 — 마지막 구간의 값이 프리즈 직전 상태다


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


## 경과 시간이 뒤로 갔나 = 판이 끝나기 전에 `Events.reset()` 이 먼저 일어났나.
##
## 그런 상태에서 스냅샷을 뜨면 **리셋된 값(경과 0 · 처치 1 · 레벨 2 · 시작 인벤토리)** 이
## 이 판의 기록을 덮어쓴다. Telemetry 자체 변수(`_cleared`·`_hits`·`_samples`·보스 카운터)는
## 리셋되지 않으므로, 두 시점이 섞인 — 30분치 샘플에 0점 요약이 붙은 — 레코드가 된다.
## 실제로 이 게임의 유일한 목표선인 **30분 클리어 판이 그렇게 저장됐다**(P0-9).
##
## 호출부에서 `end_run()` 을 먼저 부르는 것이 정석이고(그래야 실제 값이 남는다), 이건
## 그걸 빠뜨린 경로를 위한 안전망이다. **여기서는 아무것도 쓰지 않는다** —
## 마지막 정상 진행 스냅샷을 그대로 두면 다음 판 시작 때 그것이 승격된다(최대 10초 과소보고).
func _stop_if_reset() -> bool:
	if float(Events.elapsed_time) >= _last_elapsed:
		return false
	_active = false
	return true


## 판 종료 기록. 사망은 시그널로 자동이지만, **메뉴 복귀는 아무 신호도 오지 않으므로**
## HUD 가 직접 부른다(`_on_main_menu_pressed`). 이걸 안 부르면 그 판이 통째로 사라진다.
## outcome: "died" 사망 · "left" 메뉴로 나감(정상 종료) · "abandoned" 탭 닫힘·크래시.
func end_run(outcome: String) -> void:
	if not _active:
		return
	if _stop_if_reset():
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
		# 치트가 발동한 판은 사람 데이터가 아니다 — analyze_telemetry.py 가 기본 제외한다.
		"cheated": Cheats.used_this_run,
		# 이어하기 판은 피격·보스 수치가 재개 이후만 세어져 사람 데이터로 쓸 수 없다.
		"resumed": _resumed,
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
		# 해석된 이속 합계(패시브 운동화 + 메타 신속 + 캐릭터 보정). 후반 이속 밸런스(P1-5)는
		# "그 판이 얼마나 빨랐는가"로만 판정되는데, passives 만으로는 메타·캐릭터 몫이 안 보인다.
		"speed_lv": Events.upgrade_speed,
		"samples": _samples,
		"diag": _diag(),
	}


## 프리즈 직전 상태 (P0-4). 멈춘 뒤에는 기록할 수 없으니 매 스냅샷마다 현재 상태를 남긴다.
## 이 값들이 프리즈 원인을 세 갈래로 가른다:
##   · frame_ms_max 가 치솟음 → 성능 붕괴(개체·이펙트 폭증). 개체 수를 함께 본다.
##   · paused=true + pause_owners 가 남아 있음 → 모달이 정지를 쥔 채 갇힘.
##   · 전부 정상인데 기록이 끊김 → 무한 루프/크래시. 워치독조차 못 돈 것이다.
func _diag() -> Dictionary:
	var tree := get_tree()
	return {
		"fps": int(Engine.get_frames_per_second()),
		"frame_ms_max": snappedf(_frame_ms_max, 0.1),
		"time_scale": snappedf(Engine.time_scale, 0.001),
		"paused": (tree.paused if tree != null else false),
		"pause_owners": Array(Events.pause_owner_tags()),
		"watchdog": _watchdog_log.duplicate(),
		"zombies": (tree.get_nodes_in_group("zombies").size() if tree != null else -1),
		"pickups": (tree.get_nodes_in_group("item_pickups").size() if tree != null else -1),
		"gems": _Gem.live_gems().size(),
		"mem_mb": _mem_mb(),
		"nodes": _node_count(),
	}


## 정적 메모리(MB). 웹 빌드의 크래시는 대개 힙 고갈이라, 이 값이 우상향하면 누수다.
func _mem_mb() -> float:
	return snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1)


## 살아있는 노드 수. 메모리와 함께 보면 "무엇이" 새는지 좁혀진다 —
## 노드가 늘면 씬 트리 누수, 메모리만 늘면 리소스·배열 누수다.
func _node_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


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
