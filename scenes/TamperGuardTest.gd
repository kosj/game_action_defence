extends Node
## 클라이언트 변조 허들 회귀 테스트 (P2-29).
##
## 실행:
##   godot --headless --path . res://scenes/TamperGuardTest.tscn
## 마지막 줄의 "RESULT ok=<통과>/<전체>" 가 전부 통과가 아니면 회귀다.
##
## 검사 항목
##   T1  금고 왕복 — 넣은 값이 그대로 나오고, 저장 바이트에는 평문이 없다
##   T2  쓰기마다 키가 바뀌어 다른 칸의 저장 바이트도 함께 바뀐다(변함/안 변함 스캔 무력화)
##   T3  인코딩 칸을 직접 고치면(메모리 변조 시뮬레이션) 읽는 순간 tampered 가 선다.
##       rekey 가 변조된 칸을 재인코딩하며 흔적을 지우지 않는다
##   T4  Events 프로퍼티(골드·점수·경험치·레벨)가 금고를 거친다 · reset 이 변조 표시를 내린다
##   T5  변조된 판은 사망 시 랭킹에 제출되지 않는다(실시간 최고점 보존도 멈춘다)
##   T6  변조된 판은 MetaManager.bank 가 적립하지 않는다
##   T7  다른 금고(Player 체력)의 불일치가 Events 판 표시로 합산된다 · Player 배선이 살아 있다
##   T8  SaveGuard 왕복 — 서명본을 읽으면 OK
##   T9  payload 를 고치면 TAMPERED · 서명을 떼어낸 평문은 스탬프 이후 TAMPERED
##   T10 구버전 평문은 첫 실행(스탬프 전)에만 UNSIGNED 로 받아들이고, 매니저가 서명본으로 이관한다
##   T11 JSON 이 아닌 파일은 CORRUPT · 없는 파일은 MISSING
##   T12 MetaManager 가 변조된 meta.save 를 무시한다(잔액 유지)
##
## user:// 의 실제 파일(meta.save · ranking.json)을 건드리므로 시작 때 백업하고 끝에 되돌린다.

const TEST_PATH := "user://tamper_guard_test.save"

var _ok: int = 0
var _total: int = 0
var _backups: Dictionary = {}


func _ready() -> void:
	_run()


func _check(name: String, cond: bool) -> void:
	_total += 1
	if cond:
		_ok += 1
	print("%s %s" % ["PASS" if cond else "FAIL", name])


func _run() -> void:
	for p in [MetaManager.SAVE_PATH, LocalRankingBackend.PATH, SaveManager.SAVE_PATH]:
		_backups[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null

	_test_vault()
	_test_events()
	_test_gates()
	_test_save_guard()
	_test_meta_migration()

	for p in _backups:
		_restore(p, _backups[p])
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	print("RESULT ok=%d/%d" % [_ok, _total])
	await get_tree().process_frame
	get_tree().quit(0 if _ok == _total else 1)


# ── T1~T3: 금고 자체 ───────────────────────────────────────────────────────────
func _test_vault() -> void:
	var v := TamperVault.new()
	v.set_int(&"a", 1234)
	v.set_int(&"b", 0)
	_check("T1 왕복 — 넣은 값이 그대로 나온다", v.get_int(&"a") == 1234 and v.get_int(&"b") == 0)
	_check("T1 저장 바이트에 평문이 없다", int(v._enc[&"a"]) != 1234 and int(v._enc[&"b"]) != 0)
	_check("T1 없는 칸은 0", v.get_int(&"nope") == 0 and not v.has(&"nope"))

	var enc_a_before: int = v._enc[&"a"]
	v.set_int(&"b", 9)
	_check("T2 다른 칸을 써도 a 의 저장 바이트가 바뀐다(키 교체)", int(v._enc[&"a"]) != enc_a_before)
	_check("T2 키 교체 뒤에도 값은 유지", v.get_int(&"a") == 1234 and v.get_int(&"b") == 9)
	_check("T2 rekey 는 값을 유지한다", _rekey_keeps(v))

	# 메모리 변조 시뮬레이션 — 인코딩 칸을 직접 뒤집는다(스캐너가 저장 바이트를 찾아 고친 상황).
	_check("T3 사전조건: 변조 전 tampered=false", not v.tampered)
	v._enc[&"a"] = int(v._enc[&"a"]) ^ 0x5A5A
	var seen: Array = []
	v.tamper_detected.connect(func(n: StringName) -> void: seen.append(n))
	v.get_int(&"a")
	_check("T3 인코딩 칸을 고치면 읽는 순간 tampered", v.tampered and seen == [&"a"])
	_check("T3 verify_all 도 false", not v.verify_all())

	var w := TamperVault.new()
	w.set_int(&"x", 42)
	w._enc[&"x"] = int(w._enc[&"x"]) ^ 1
	w.rekey()
	_check("T3 rekey 가 변조 흔적을 지우지 않는다", w.tampered)
	w.clear_tamper_flag()
	_check("T3 clear_tamper_flag 뒤 재검증은 깨끗(재인코딩된 값 기준)", w.verify_all())


func _rekey_keeps(v: TamperVault) -> bool:
	var a := v.get_int(&"a")
	var b := v.get_int(&"b")
	v.rekey()
	return v.get_int(&"a") == a and v.get_int(&"b") == b and not v.tampered


# ── T4: Events 프로퍼티 ────────────────────────────────────────────────────────
func _test_events() -> void:
	Events.reset()
	_check("T4 reset 직후 변조 표시 없음", not Events.tamper_detected())
	Events.total_gold = 77
	Events.total_gold += 3
	Events.score = 5
	Events.xp = 11
	Events.level = 4
	Events.xp_to_next = 30
	_check("T4 프로퍼티 왕복(골드 80 · 점수 5 · xp 11 · 레벨 4 · 다음 30)",
		Events.total_gold == 80 and Events.score == 5 and Events.xp == 11
		and Events.level == 4 and Events.xp_to_next == 30)
	_check("T4 금고 안에 평문 80 이 없다", int(Events._vault._enc[&"gold"]) != 80)
	var raw = JSON.parse_string('{"g": 12}')
	Events.total_gold = int(raw["g"])
	_check("T4 JSON(float) 값도 int 로 들어간다", Events.total_gold == 12)

	Events._vault._enc[&"gold"] = int(Events._vault._enc[&"gold"]) ^ 0xFF
	_check("T4 변조 뒤 tamper_detected=true", Events.tamper_detected())
	Events.reset()
	_check("T4 reset 이 변조 표시를 내리고 값을 초기화한다",
		not Events.tamper_detected() and Events.total_gold == 0 and Events.level == 1
		and Events.xp_to_next == 12)


# ── T5~T7: 관문(랭킹·적립·체력 합산) ────────────────────────────────────────
func _test_gates() -> void:
	Events.reset()
	SaveManager.delete_save()
	var mode := RankingManager.current_mode_id()
	Events.add_score(10)
	var best_before := RankingManager.best_for_mode(mode)
	# 점수 칸을 변조 — 디코딩되는 값은 엉뚱한 큰 수가 된다.
	Events._vault._enc[&"score"] = int(Events._vault._enc[&"score"]) ^ 0x7FFF0000
	var bogus := Events.score
	_check("T5 사전조건: 변조된 점수가 기존 최고점보다 크다", bogus > best_before)
	Events.player_died.emit()
	_check("T5 변조된 판은 사망 시 랭킹에 제출되지 않는다", RankingManager.best_for_mode(mode) == best_before)
	Events.high_score_changed.emit(bogus)
	_check("T5 실시간 최고점 보존도 멈춘다", RankingManager.best_for_mode(mode) == best_before)

	var gold_before := MetaManager.meta_gold
	MetaManager.bank(500)
	_check("T6 변조된 판은 bank 가 적립하지 않는다", MetaManager.meta_gold == gold_before)
	Events.reset()
	MetaManager.bank(500)
	_check("T6 깨끗한 판은 정상 적립", MetaManager.meta_gold == gold_before + 500)
	MetaManager.meta_gold = gold_before   # 잔액 원복(파일은 끝에 백업으로 되돌린다)

	# Player 체력 금고와 같은 배선 — 다른 금고의 불일치가 Events 판 표시로 합산된다.
	Events.reset()
	var hp := TamperVault.new()
	hp.tamper_detected.connect(func(_n: StringName) -> void: Events.report_tamper("player_health"))
	hp.set_int(&"hp", 50)
	hp._enc[&"hp"] = int(hp._enc[&"hp"]) ^ 0x10
	hp.get_int(&"hp")
	_check("T7 다른 금고의 불일치가 Events.tamper_detected 로 합산된다", Events.tamper_detected())
	Events.reset()
	_check("T7 reset 이 합산 표시도 내린다", not Events.tamper_detected())
	var src := FileAccess.get_file_as_string("res://scripts/Player.gd")
	_check("T7 Player.health 가 금고 프로퍼티다",
		src.contains("var health: int:") and src.contains("_hp_vault.get_int(&\"hp\")"))
	_check("T7 Player 가 금고 불일치를 Events 에 보고한다",
		src.contains("_hp_vault.tamper_detected.connect") and src.contains("Events.report_tamper("))


# ── T8~T11: SaveGuard ─────────────────────────────────────────────────────────
func _test_save_guard() -> void:
	var data := {"gold": 5, "levels": {"x": 2}}
	_check("T8 write_json 성공", SaveGuard.write_json(TEST_PATH, data))
	var r := SaveGuard.read_json(TEST_PATH)
	_check("T8 서명본 읽기 OK + 내용 일치", r["status"] == SaveGuard.Status.OK
		and typeof(r["data"]) == TYPE_DICTIONARY and int(r["data"]["gold"]) == 5
		and int(r["data"]["levels"]["x"]) == 2)
	var wrapped = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	_check("T8 파일은 {v, payload, sig} 포장이다", typeof(wrapped) == TYPE_DICTIONARY
		and wrapped.has("sig") and wrapped.has("payload") and int(wrapped.get("v", 0)) == 1)
	_check("T8 스탬프가 생겼다", FileAccess.file_exists(SaveGuard.STAMP_PATH))

	# payload 안의 숫자만 고친다(편집기로 세이브를 고친 상황).
	wrapped["payload"] = String(wrapped["payload"]).replace("\"gold\":5", "\"gold\":99999")
	_write_text(TEST_PATH, JSON.stringify(wrapped))
	SaveGuard.tamper_seen = false
	r = SaveGuard.read_json(TEST_PATH)
	_check("T9 payload 를 고치면 TAMPERED", r["status"] == SaveGuard.Status.TAMPERED and r["data"] == null)
	_check("T9 tamper_seen 이 선다", SaveGuard.tamper_seen)

	# 서명을 떼어낸 평문 — 스탬프 이후에는 변조다.
	SaveGuard._override_legacy_for_test(false)
	_write_text(TEST_PATH, JSON.stringify({"gold": 99999}))
	r = SaveGuard.read_json(TEST_PATH)
	_check("T9 서명을 떼어낸 평문은 스탬프 이후 TAMPERED", r["status"] == SaveGuard.Status.TAMPERED)

	# 같은 평문이 첫 실행(스탬프 전)이면 이관 대상.
	SaveGuard._override_legacy_for_test(true)
	r = SaveGuard.read_json(TEST_PATH)
	_check("T10 첫 실행에서는 평문을 UNSIGNED 로 받아들인다", r["status"] == SaveGuard.Status.UNSIGNED
		and typeof(r["data"]) == TYPE_DICTIONARY and int(r["data"]["gold"]) == 99999)

	_write_text(TEST_PATH, "not json {")
	_check("T11 JSON 이 아니면 CORRUPT", SaveGuard.read_json(TEST_PATH)["status"] == SaveGuard.Status.CORRUPT)
	_check("T11 없는 파일은 MISSING",
		SaveGuard.read_json("user://tamper_guard_nope.save")["status"] == SaveGuard.Status.MISSING)


# ── T10/T12: MetaManager 이관 · 변조 무시 ────────────────────────────────────
func _test_meta_migration() -> void:
	var path: String = MetaManager.SAVE_PATH
	# 첫 실행 시나리오: 구버전 평문 meta.save 를 읽고 서명본으로 다시 쓴다.
	SaveGuard._override_legacy_for_test(true)
	_write_text(path, JSON.stringify({"gold": 321, "levels": {"greed": 2}}))
	MetaManager._levels.clear()
	MetaManager._load()
	_check("T10 구버전 평문 meta.save 를 읽는다", MetaManager.meta_gold == 321 and MetaManager.level("greed") == 2)
	var after = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check("T10 읽은 즉시 서명본으로 이관된다", typeof(after) == TYPE_DICTIONARY and after.has("sig"))
	_check("T10 이관본을 다시 읽어도 같다", SaveGuard.read_json(path)["status"] == SaveGuard.Status.OK)

	# 이후 실행 시나리오: 편집한 평문 / 서명 불일치 파일은 무시되고 잔액이 유지된다.
	SaveGuard._override_legacy_for_test(false)
	_write_text(path, JSON.stringify({"gold": 999999, "levels": {}}))
	MetaManager._load()
	_check("T12 서명을 떼어낸 평문 meta.save 는 무시(잔액 321 유지)", MetaManager.meta_gold == 321)
	SaveGuard.write_json(path, {"gold": 321, "levels": {}})
	var wrapped = JSON.parse_string(FileAccess.get_file_as_string(path))
	wrapped["payload"] = String(wrapped["payload"]).replace("321", "888888")
	_write_text(path, JSON.stringify(wrapped))
	MetaManager._load()
	_check("T12 payload 를 고친 meta.save 도 무시(잔액 321 유지)", MetaManager.meta_gold == 321)


func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _restore(path: String, content: Variant) -> void:
	if content == null:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	_write_text(path, String(content))
