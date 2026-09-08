extends SceneTree
## 상단바 위젯 배치 검증 (P2-30).
##   godot --headless --path . --script res://tools/verify_hud_layout.gd
## 종료 코드 = 실패 개수.
##
## 왜 필요한가: 위협 뱃지(y72~92)와 타임라인 바(y84~92)가 **8px 겹쳐 있었다.** 둘 다
## HUD 의 자식이고 z_index 가 같아서 나중에 만들어진 타임라인이 위에 그려졌고, 결과는
## **뱃지 글자의 아래가 잘린 화면**이었다(사용자 스크린샷으로 발견).
##
## 이 종류는 세 겹으로 안 잡힌다:
##   - 헤드리스 테스트는 겹침을 모른다(둘 다 정상적으로 만들어진다).
##   - `check_text_fit` 도 모른다 — 글자는 제 상자 안에 들어가 있었다. 상자끼리 겹친 것이다.
##   - 스크린샷을 찍어도 "글자가 반쯤 지워졌네" 로 보여, 배치 문제인 줄 알기 어렵다.
##
## 그래서 **자리를 상수로 꺼내 놓고 여기서 사각형끼리 겹치는지 본다.** 코드와 검사가
## 같은 값(`HUD._THREAT_RECT` · `HUD._TIMELINE_RECT`)을 보므로 서로 어긋날 수 없다.
##
## 실제 픽셀은 `tools/shot_hud_layers.gd` 로 본다(CLAUDE.md §3).

const _HUD := "res://scripts/HUD.gd"
## 상단바 배경(HUD.tscn 의 TopBg)의 높이. 위젯이 이 밖으로 나가면 월드 위에 뜬다.
const _TOP_BAR_H := 96.0

var _fails := 0
var _done := false


func _ok(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("  FAIL %s%s" % [label, ("  — " + detail) if detail != "" else ""])


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	var hud: GDScript = load(_HUD)
	_ok("HUD.gd 를 읽는다", hud != null)
	var c: Dictionary = hud.get_script_constant_map()

	print("── 자리가 상수로 나와 있는가 ────────────────────")
	for key in ["_THREAT_RECT", "_TIMELINE_RECT"]:
		_ok("HUD 에 %s 가 있다" % key, c.has(key) and c[key] is Rect2, str(c.get(key, "없음")))
	if not (c.has("_THREAT_RECT") and c.has("_TIMELINE_RECT")):
		print("\n실패 %d건" % _fails)
		quit(_fails)
		return true

	var threat: Rect2 = c["_THREAT_RECT"]
	var timeline: Rect2 = c["_TIMELINE_RECT"]

	print("── 겹치지 않는가 ──────────────────────────────")
	_ok("위협 뱃지와 타임라인이 겹치지 않는다", not threat.intersects(timeline),
		"%s vs %s — 늦게 그려지는 쪽이 글자를 덮는다" % [threat, timeline])

	print("── 상단바 안에 있는가 ─────────────────────────")
	# 상단바 밖으로 나가면 배경 없이 월드 위에 떠서 대비가 무너진다.
	_ok("위협 뱃지가 상단바 안에 있다",
		threat.position.y >= 0.0 and threat.end.y <= _TOP_BAR_H, str(threat))
	_ok("타임라인이 상단바 안에 있다",
		timeline.position.y >= 0.0 and timeline.end.y <= _TOP_BAR_H, str(timeline))

	print("── 노치 보정에서 빠지지 않았는가 ────────────────")
	# 나머지 위젯만 아래로 내려가면 이 둘이 상단바 안쪽으로 파고들어 다시 겹친다.
	# 증상이 노치 기기에서만 나므로 데스크톱·웹 확인으로는 절대 안 걸린다.
	var src := FileAccess.get_file_as_string(_HUD)
	var safe := src.split("func _apply_safe_area()")
	_ok("_apply_safe_area 를 찾았다", safe.size() > 1)
	if safe.size() > 1:
		var body: String = String(safe[1]).split("\nfunc ")[0]
		_ok("노치 보정 목록에 _threat_badge 가 있다", body.contains("_threat_badge"))
		_ok("노치 보정 목록에 _timeline 이 있다", body.contains("_timeline"))

	print("\n실패 %d건" % _fails)
	quit(_fails)
	return true
