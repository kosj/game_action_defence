extends Node
## 도감(Codex) 회귀 테스트 — HANDOFF P1-13.
##
## 실행:
##   godot --headless --path . res://scenes/CodexTest.tscn
## 마지막 줄의 "RESULT ok=<통과>/<전체>" 가 전부 통과가 아니면 회귀다.
##
## 검사 항목
##   T1 발견 기록이 남는다 / 중복 발견은 새 기록이 아니다
##   T2 재시작(_load)해도 기록이 유지된다
##   T3 카탈로그에서 사라진 id 가 저장에 남아 있어도 크래시 없이 읽힌다
##   T4 무기와 진화가 갈려 기록된다(진화 결과만 evolution 절로 간다)
##   T5 궁극기는 진화가 아니라 무기로 분류된다(evolved=true 지만 진화 규칙에 없다)
##   T6 판 시작이 아레나를 기록한다
##   T7 미발견 항목은 이름을 노출하지 않는다(패널이 `???` 로 덮는다)
##   T8 캐릭터는 저장하지 않고 해금 상태에서 파생된다

const _CodexPanel := preload("res://scripts/CodexPanel.gd")

var _ok: int = 0
var _total: int = 0


func _ready() -> void:
	_run()


func _check(name: String, cond: bool) -> void:
	_total += 1
	if cond:
		_ok += 1
	print("%s %s" % ["PASS" if cond else "FAIL", name])


func _run() -> void:
	CodexManager.clear_all()

	# --- T1: 발견 기록 ---
	_check("T1 새 발견은 true", CodexManager.discover("zombie", "walker"))
	_check("T1 기록됨", CodexManager.has("zombie", "walker"))
	_check("T1 중복 발견은 false", not CodexManager.discover("zombie", "walker"))
	_check("T1 빈 id 는 기록하지 않음", not CodexManager.discover("zombie", ""))
	_check("T1 모르는 분류는 기록하지 않음", not CodexManager.discover("nope", "walker"))
	_check("T1 개수 = 1", CodexManager.found_count("zombie") == 1)

	# --- T2: 재시작 후에도 남는가(저장 파일에서 다시 읽는다) ---
	CodexManager.discover("boss", "wrecker")
	_reload()
	_check("T2 재시작 후 좀비 기록 유지", CodexManager.has("zombie", "walker"))
	_check("T2 재시작 후 보스 기록 유지", CodexManager.has("boss", "wrecker"))

	# --- T3: 카탈로그에서 사라진 id 가 남아 있어도 안전한가 ---
	CodexManager.discover("zombie", "no_such_zombie")
	_reload()
	_check("T3 사라진 id 가 있어도 살아있는 기록은 유지", CodexManager.has("zombie", "walker"))

	# --- T4/T5: 인벤토리 스캔이 무기/진화를 가르는가 ---
	CodexManager.clear_all()
	Events.weapons = {"gun": 8, "napalm": 1, "ult_quake": 1}
	Events.passives = {"armor": 2}
	Events.inventory_changed.emit()
	_check("T4 기본 무기는 weapon", CodexManager.has("weapon", "gun"))
	_check("T4 진화 무기는 evolution", CodexManager.has("evolution", "napalm"))
	_check("T4 진화 무기가 weapon 으로 새지 않음", not CodexManager.has("weapon", "napalm"))
	_check("T4 패시브는 passive", CodexManager.has("passive", "armor"))
	_check("T5 궁극기는 weapon(진화 아님)",
		CodexManager.has("weapon", "ult_quake") and not CodexManager.has("evolution", "ult_quake"))

	# --- T6: 판 시작이 아레나를 남기는가 ---
	var arena := ThemeManager.selected_id()
	CodexManager.on_run_start(arena)
	_check("T6 플레이한 아레나가 기록됨", CodexManager.has("arena", arena))

	# --- T7: 미발견은 이름을 노출하지 않는가 ---
	CodexManager.clear_all()
	Events.weapons = {}
	Events.passives = {}
	var panel := _CodexPanel.new()
	panel.build(self, func() -> void: pass)
	panel.refresh()
	_check("T7 미발견 항목이 이름 대신 ??? 를 보여줌", _all_hidden(panel))
	_check("T7 미발견 개수가 진행도에 반영됨", _progress_found(panel) == _unlocked_chars())

	CodexManager.discover("zombie", "walker")
	panel.refresh()
	_check("T7 발견 후에는 이름이 보임", _name_of(panel, "zombie", "walker") == "Walker")

	# --- T8: 캐릭터는 저장이 아니라 해금 상태에서 온다 ---
	_check("T8 캐릭터는 도감 저장 분류에 없음", not CodexManager.KINDS.has("character"))
	_check("T8 해금된 캐릭터는 발견으로 보임", _unlocked_chars() >= 1)

	CodexManager.clear_all()
	print("RESULT ok=%d/%d" % [_ok, _total])
	await get_tree().process_frame
	get_tree().quit(0 if _ok == _total else 1)


## 저장 파일만 남기고 메모리 기록을 버린 뒤 다시 읽는다(앱 재시작과 같은 경로).
func _reload() -> void:
	for k in CodexManager.KINDS:
		CodexManager._found[k] = {}
	CodexManager._load()


func _section(panel: RefCounted, kind: String) -> Dictionary:
	for sec in panel._sections:
		if sec["kind"] == kind:
			return sec
	return {}


func _name_of(panel: RefCounted, kind: String, id: String) -> String:
	for tile in _section(panel, kind).get("tiles", []):
		if String(tile["id"]) == id:
			return tile["name_lbl"].text
	return ""


## 캐릭터 절만 예외다 — 기본 해금 캐릭터가 있어 항상 하나는 보인다.
func _all_hidden(panel: RefCounted) -> bool:
	for sec in panel._sections:
		if sec["kind"] == "character":
			continue
		for tile in sec["tiles"]:
			if tile["name_lbl"].text != _CodexPanel.UNKNOWN_TEXT:
				return false
	return true


func _progress_found(panel: RefCounted) -> int:
	var n := 0
	for sec in panel._sections:
		for tile in sec["tiles"]:
			if tile["name_lbl"].text != _CodexPanel.UNKNOWN_TEXT:
				n += 1
	return n


func _unlocked_chars() -> int:
	var n := 0
	for c in GameData.characters:
		if CharacterManager.is_unlocked(c):
			n += 1
	return n
