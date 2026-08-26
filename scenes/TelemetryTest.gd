extends Node
## 텔레메트리 수집 회귀 테스트.
##
## 실행:
##   godot --headless --path . res://scenes/TelemetryTest.tscn
## 마지막 줄의 "RESULT ok=<통과>/<전체>" 가 전부 통과가 아니면 회귀다.
##
## 검사 항목
##   T1 판이 끝나면 기록 1줄이 남는다
##   T2 기록이 sim_balance 와 같은 키를 갖는다(같은 도구로 비교하기 위한 계약)
##   T3 피격 수와 첫 피격 시각이 실제 피해를 따라간다
##   T4 보스 조우·처치·전투 시간이 기록된다
##   T5 기록 상한(MAX_RECORDS)을 넘지 않는다
##   T6 개인 식별 정보를 담지 않는다
##   T7 enabled=false 면 아무것도 남기지 않는다
##   T8 치트를 쓴 판은 cheated=true 로 표시된다(사람 데이터와 섞이지 않게)
##   T9 이어하기로 시작한 판은 resumed=true 로 표시된다(수치가 재개 이후만 세어지므로)
##   T10 프리즈 진단(diag)이 기록되고 워치독 발동이 남는다 — 멈춘 뒤엔 못 남기므로 이게 유일한 단서다
##   T11 분당 샘플에 누수 계수기·fps·프레임 시간이 실린다(누수·성능 추이 판별용)
##   T12 메뉴 복귀 판이 기록에 남는다 + 끝맺지 못한 판이 새 판 시작 시 승격된다
##   T13 해석된 이속 합계(speed_lv)가 기록된다 — 후반 이속 밸런스 판정의 유일한 지표
##   T14 판 도중 Events.reset() 이 일어나도 기록이 0 으로 덮이지 않는다
##   T15 이어하기 판이 분당 샘플을 한 프레임에 몰아 쓰지 않는다
##   T16 죽은 지표(mem_mb)가 돌아오지 않는다 — 웹에서 항상 0 이라 "누수 없음"으로 오독된다
##       (30분 클리어 판이 "생존 0초 · 처치 1" 로 저장되던 버그)
##       (클리어 후 메뉴로 나간 판이 통째로 사라지던 버그)

var _ok := 0
var _total := 0

# sim_balance.gd 의 SIMRESULT 와 공유해야 하는 키 — 하나라도 빠지면 분석 도구가 깨진다.
const SHARED_KEYS := ["character", "theme", "survived_s", "died", "cleared", "level",
	"kills", "hits", "first_hit_s", "boss_spawns", "boss_kills", "boss_fight_s",
	"weapons", "passives", "speed_lv", "samples"]
# 있으면 안 되는 것 — 개인정보 수집으로 넘어가는 경계다.
const FORBIDDEN_KEYS := ["user_id", "device_id", "ip", "email", "uuid", "session_id", "name"]


func _check(label: String, cond: bool, detail: String = "") -> void:
	_total += 1
	if cond:
		_ok += 1
		print("  ok   %s" % label)
	else:
		print("  FAIL %s%s" % [label, ("  — " + detail) if detail != "" else ""])


func _ready() -> void:
	Telemetry.clear_records()
	Telemetry.enabled = true

	# ── T1/T2/T3 기본 수집 ──────────────────────────────────────────
	Events.reset()
	Telemetry.begin_run()
	Events.elapsed_time = 42.0
	Events.total_kills = 130
	Events.update_player_health(10, 10)
	Events.update_player_health(7, 10)    # 피격 1
	Events.elapsed_time = 61.0
	Events.update_player_health(4, 10)    # 피격 2
	Events.player_died.emit()

	var raw := Telemetry.load_records_raw()
	_check("T1 판 종료 시 기록 1줄", raw.size() == 1, "실제 %d" % raw.size())
	var rec: Dictionary = JSON.parse_string(raw[0]) if raw.size() > 0 else {}
	var missing: Array = []
	for k in SHARED_KEYS:
		if not rec.has(k):
			missing.append(k)
	_check("T2 sim_balance 와 같은 키", missing.is_empty(), "빠진 키 %s" % str(missing))
	_check("T3 피격 2회 · 첫 피격 42초",
		int(rec.get("hits", 0)) == 2 and abs(float(rec.get("first_hit_s", -1)) - 42.0) < 0.01,
		"hits=%s first=%s" % [rec.get("hits"), rec.get("first_hit_s")])

	# ── T4 보스 ────────────────────────────────────────────────────
	Telemetry.clear_records()
	Events.reset()
	Telemetry.begin_run()
	Events.elapsed_time = 600.0
	Events.boss_spawned.emit(500)
	Events.elapsed_time = 630.0
	Events.boss_died.emit()
	Events.player_died.emit()
	var r2: Dictionary = JSON.parse_string(Telemetry.load_records_raw()[0])
	_check("T4 보스 조우 1 · 처치 1 · 전투 30초",
		int(r2.get("boss_spawns", 0)) == 1 and int(r2.get("boss_kills", 0)) == 1
			and r2.get("boss_fight_s", []).size() == 1
			and abs(float(r2["boss_fight_s"][0]) - 30.0) < 0.01,
		str(r2.get("boss_fight_s")))

	# ── T5 상한 ────────────────────────────────────────────────────
	Telemetry.clear_records()
	for i in range(Telemetry.MAX_RECORDS + 12):
		Events.reset()
		Telemetry.begin_run()
		Events.player_died.emit()
	_check("T5 기록 상한 유지", Telemetry.record_count() == Telemetry.MAX_RECORDS,
		"실제 %d" % Telemetry.record_count())

	# ── T6 개인정보 미수집 ─────────────────────────────────────────
	var text := Telemetry.export_text().to_lower()
	var leaked: Array = []
	for k in FORBIDDEN_KEYS:
		if text.find('"%s"' % k) >= 0:
			leaked.append(k)
	_check("T6 개인 식별 정보 없음", leaked.is_empty(), "발견 %s" % str(leaked))

	# ── T7 끄면 안 남는다 ──────────────────────────────────────────
	Telemetry.clear_records()
	Telemetry.enabled = false
	Events.reset()
	Telemetry.begin_run()
	Events.player_died.emit()
	_check("T7 enabled=false 면 미수집", Telemetry.record_count() == 0)
	Telemetry.enabled = true
	Telemetry.clear_records()

	# ── T8 치트 판 표시 ────────────────────────────────────────────
	Telemetry.enabled = true
	Telemetry.clear_records()
	Events.reset()
	Telemetry.begin_run()
	var was := Cheats.enabled
	Cheats.enabled = true
	Cheats.request_spawn_boss()          # 게이트가 열린 상태에서 실제 발동
	Events.player_died.emit()
	var r3: Dictionary = JSON.parse_string(Telemetry.load_records_raw()[0])
	Telemetry.clear_records()
	Events.reset()
	Telemetry.begin_run()                 # 새 판 — 플래그가 초기화돼야 한다
	Events.player_died.emit()
	var r4: Dictionary = JSON.parse_string(Telemetry.load_records_raw()[0])
	Cheats.enabled = was
	_check("T8 치트 판만 cheated=true",
		bool(r3.get("cheated", false)) and not bool(r4.get("cheated", true)),
		"치트판=%s 다음판=%s" % [r3.get("cheated"), r4.get("cheated")])
	Telemetry.clear_records()

	# ── T9 이어하기 판 표시 ────────────────────────────────────────
	# 이어하기는 세이브에서 elapsed_time 을 복원한 뒤 씬에 들어간다 — 그 상태를 흉내낸다.
	Telemetry.clear_records()
	Events.reset()
	Events.elapsed_time = 420.0        # 세이브 복원 상당
	Telemetry.begin_run()
	Events.player_died.emit()
	var r5: Dictionary = JSON.parse_string(Telemetry.load_records_raw()[0])
	Telemetry.clear_records()
	Events.reset()                      # 새 게임(elapsed_time=0)
	Telemetry.begin_run()
	Events.player_died.emit()
	var r6: Dictionary = JSON.parse_string(Telemetry.load_records_raw()[0])
	_check("T9 이어하기 판만 resumed=true",
		bool(r5.get("resumed", false)) and not bool(r6.get("resumed", true)),
		"이어하기=%s 새게임=%s" % [r5.get("resumed"), r6.get("resumed")])
	Telemetry.clear_records()

	# ── T10 프리즈 진단 ────────────────────────────────────────────
	Telemetry.clear_records()
	Events.reset()
	Telemetry.begin_run()
	Events.pause_watchdog_fired.emit("orphan_pause", "level=3 elapsed=42.0")
	Events.player_died.emit()
	var r7: Dictionary = JSON.parse_string(Telemetry.load_records_raw()[0])
	var dg: Dictionary = r7.get("diag", {})
	var need := ["fps", "frame_ms_max", "time_scale", "paused", "pause_owners",
		"watchdog", "zombies", "pickups", "gems", "nodes", "objects", "res",
		"orphans", "vram"]   # mem_mb 는 뺐다 — 웹에서 항상 0 이었다(P0-10, T16 참고)
	var miss: Array = []
	for k in need:
		if not dg.has(k):
			miss.append(k)
	_check("T10 진단 필드 + 워치독 기록",
		miss.is_empty() and dg.get("watchdog", []).size() == 1,
		"빠진 필드 %s · 워치독 %s" % [str(miss), str(dg.get("watchdog"))])
	Telemetry.clear_records()

	# ── T11 분당 샘플의 누수 계수기 ─────────────────────────────────
	Telemetry.clear_records()
	Events.reset()
	Telemetry.begin_run()
	Events.elapsed_time = 65.0
	Telemetry._process(0.016)          # 분당 샘플 1개 적재
	Events.player_died.emit()
	var r8: Dictionary = JSON.parse_string(Telemetry.load_records_raw()[0])
	var sm: Array = r8.get("samples", [])
	# fps·프레임 시간이 없으면 "언제부터 느려졌나"를 못 본다 — P1-18 이 그것 때문에 막혔다.
	# 누수 계수기는 넷 다 있어야 한다 — 하나만 봐서는 "무엇이" 새는지 못 좁힌다(P0-10).
	var s11_keys := ["nodes", "objects", "res", "orphans", "vram",
		"fps", "frame_ms", "zombies"]
	var s11_missing: Array = []
	if sm.size() >= 1:
		for k in s11_keys:
			if not sm[0].has(k):
				s11_missing.append(k)
	_check("T11 분당 샘플에 누수 계수기·프레임",
		sm.size() >= 1 and s11_missing.is_empty()
			and int(sm[0]["objects"]) > 0 and int(sm[0]["nodes"]) > 0,
		("빠진 키 %s · %s" % [s11_missing, sm[0]]) if sm.size() > 0 else "샘플 없음")

	# ── T16 죽은 지표가 돌아오지 않는다 ─────────────────────────────
	# `Performance.MEMORY_STATIC` 은 **웹 export 에서만 항상 0** 이다(네이티브 헤드리스는
	# 30MB 를 정상 반환한다). 그래서 이 테스트도 데스크톱에서는 통과했고, 웹에서만 깨진 채
	# 크래시 기록 3회를 흘려보냈다 — `mem_mb: 0` 이 "메모리가 안 늘었다 = 누수 없음"으로
	# 읽혔기 때문이다. 값이 아니라 **오독의 원인**이었으므로 되살리면 안 된다.
	# (wasm 힙은 잴 방법이 없다는 것을 실제 웹 빌드에서 확인했다 — Telemetry._leak_counters 주석)
	var d16: Dictionary = r8.get("diag", {})
	var d16_missing: Array = []
	for k in ["nodes", "objects", "res", "orphans", "vram"]:
		if not d16.has(k):
			d16_missing.append(k)
	_check("T16 diag 에 누수 계수기 · 죽은 mem 지표는 없음",
		d16_missing.is_empty() and not d16.has("mem_mb") and not sm[0].has("mem"),
		"빠진 키 %s · mem_mb=%s · sample.mem=%s"
			% [d16_missing, d16.has("mem_mb"), sm[0].has("mem")])
	Telemetry.clear_records()

	# ── T12 메뉴 복귀 · 미완 판 승격 ────────────────────────────────
	Telemetry.clear_records()
	Events.reset()
	Telemetry.begin_run()
	Events.elapsed_time = 1800.0
	Events.run_cleared.emit()          # 30분 클리어
	Telemetry.end_run("left")          # 메뉴로 나감
	var raw12 := Telemetry.load_records_raw()
	var rl: Dictionary = JSON.parse_string(raw12[0]) if raw12.size() > 0 else {}
	_check("T12a 메뉴 복귀 판이 기록됨 (클리어 포함)",
		raw12.size() == 1 and String(rl.get("outcome", "")) == "left"
			and bool(rl.get("cleared", false)),
		"%d건 · outcome=%s · cleared=%s" % [raw12.size(), rl.get("outcome"), rl.get("cleared")])

	# 끝맺지 못한 판(진행 스냅샷만 있는 상태)에서 새 판을 시작하면 그 판이 먼저 기록돼야 한다.
	Telemetry.clear_records()
	Events.reset()
	Telemetry.begin_run()
	Events.elapsed_time = 300.0
	Telemetry._write_json(Telemetry.PARTIAL_PATH, Telemetry._snapshot("abandoned"))
	Events.reset()
	Telemetry.begin_run()              # 새 판 — 이전 판을 건져야 한다
	var raw12b := Telemetry.load_records_raw()
	_check("T12b 미완 판이 새 판 시작 시 승격됨", raw12b.size() == 1,
		"%d건" % raw12b.size())
	Telemetry.clear_records()

	# ── T13 이속 합계 ──────────────────────────────────────────────
	# 운동화 패시브만 봐서는 그 판이 얼마나 빨랐는지 알 수 없다 — 메타 신속과 캐릭터 보정이
	# 같은 스탯에 얹히기 때문이다. 후반 이속 밸런스(P1-5)는 이 합계로만 판정된다.
	Telemetry.clear_records()
	Events.reset()
	Telemetry.begin_run()
	Events.upgrade_speed = 5
	Events.player_died.emit()
	var r13: Dictionary = JSON.parse_string(Telemetry.load_records_raw()[0])
	_check("T13 해석된 이속 합계가 기록됨", int(r13.get("speed_lv", -1)) == 5,
		"speed_lv=%s" % r13.get("speed_lv"))
	Telemetry.clear_records()

	# ── T14 판 도중 Events.reset() 이 일어나도 기록이 0 으로 덮이지 않는다 ──
	# "다시하기"가 end_run 없이 Events.reset() 을 부르면, 그 뒤의 진행 스냅샷이 리셋된 값으로
	# 덮인다. Telemetry 자체 변수(cleared·samples·보스)는 리셋되지 않아 두 시점이 섞인다 —
	# 실제로 30분 클리어 판이 "생존 0초 · 처치 1 · 레벨 2" 로 저장됐다(P0-9).
	Telemetry.clear_records()
	Events.reset()
	Telemetry.begin_run()
	Events.elapsed_time = 1800.0
	Events.total_kills = 10731
	Events.level = 182
	Events.run_cleared.emit()
	Telemetry._partial_accum = Telemetry.PARTIAL_INTERVAL   # 진행 스냅샷 1회 강제
	Telemetry._process(0.016)                               # 정상 값으로 기록됨
	Events.reset()                                          # ← end_run 없이 리셋
	Telemetry._partial_accum = Telemetry.PARTIAL_INTERVAL
	Telemetry._process(0.016)                               # 여기서 덮이면 회귀다
	Telemetry.begin_run()                                   # 새 판 — 이전 판을 승격
	var raw14 := Telemetry.load_records_raw()
	var r14: Dictionary = JSON.parse_string(raw14[0]) if raw14.size() > 0 else {}
	_check("T14 판 도중 리셋돼도 기록이 0 으로 안 덮임",
		raw14.size() == 1 and int(r14.get("kills", -1)) == 10731
			and int(r14.get("level", -1)) == 182 and bool(r14.get("cleared", false)),
		"%d건 · kills=%s level=%s cleared=%s"
			% [raw14.size(), r14.get("kills"), r14.get("level"), r14.get("cleared")])
	Telemetry.clear_records()

	# ── T15 이어하기 판이 분당 샘플을 몰아 쓰지 않는다 ────────────────
	# begin_run 이 _next_sample 을 60초로 고정하면, 재개 직후 한 프레임에 한 줄씩
	# 수십 줄이 쏟아진다(좀비 0 · 처치/레벨 고정). 실제 기록에서 29줄 중 26줄이 그랬고,
	# 프리즈 진단에 쓰려던 fps 곡선이 통째로 못 쓰게 됐다(P0-11).
	Telemetry.clear_records()
	Events.reset()
	Events.elapsed_time = 1500.0        # 25분 지점에서 이어하기
	Telemetry.begin_run()
	for i in 5:
		Telemetry._process(0.016)       # 재개 직후 몇 프레임
	var burst: int = Telemetry._samples.size()
	Events.elapsed_time = 1561.0        # 1분 경과
	Telemetry._process(0.016)
	var after: int = Telemetry._samples.size()
	_check("T15 이어하기 직후 샘플을 몰아 쓰지 않는다",
		burst == 0 and after == 1,
		"재개 직후 %d행 · 1분 뒤 %d행" % [burst, after])
	Telemetry.clear_records()

	print("RESULT ok=%d/%d" % [_ok, _total])
	get_tree().quit(0 if _ok == _total else 1)
