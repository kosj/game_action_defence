extends SceneTree
## UI 아이콘 검증 (P2-4).
##   godot --headless --path . --script res://tools/verify_ui_icons.gd
## 종료 코드 = 실패 개수.
##
## 무엇을 지키는가: 잠금·완료 표시가 한때 아스키 대체였다 — 이름 앞의 `"[-] "` 와 소문자 `"v"`.
## 폰트 서브셋에 글자를 늘리지 않으려던 회피책인데, 자물쇠가 아니라 대괄호로, 체크가 아니라
## 알파벳으로 읽혀 완성도를 깎았다(HANDOFF P2-4). 아이콘은 글리프가 필요 없어 서브셋과도
## 언어와도 무관하다 — 그래서 되돌아갈 이유가 없고, 되돌아가지 않는지 여기서 못박는다.
##
## 아이콘이 "보이는가"는 헤드리스로 알 수 없다(_draw 는 불려도 덮였는지 모른다).
## 실제 픽셀은 tools/shot_menu_popups.gd 로 확인한다 — CLAUDE.md §3 참고.

var _fails := 0
var _done := false


func _ok(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("  FAIL %s%s" % [label, ("  — " + detail) if detail != "" else ""])


## 주석을 뺀 실제 코드 줄에서만 찾는다 — 왜 지웠는지 설명하는 주석까지 잡으면 기록을 못 남긴다.
func _code_has(path: String, needle: String) -> bool:
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var t := String(line).strip_edges()
		if t.begins_with("#") or t.begins_with("##"):
			continue
		if t.contains(needle):
			return true
	return false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var icon: GDScript = load("res://scripts/UIIcon.gd")

	print("── 아이콘 종류 ──────────────────────────────────")
	var kinds: Array = icon.get("_KINDS")
	for k in ["lock", "check"]:
		_ok("UIIcon 에 %s 종류가 있다" % k, kinds.has(k), str(kinds))

	# make() 가 실제로 노드를 만들고 그 종류를 들고 있는가(오타로 폴백 원이 그려지는 것 방지).
	for k in ["lock", "check"]:
		var n = icon.make(k, 24, Color.WHITE)
		_ok("UIIcon.make(\"%s\") 가 노드를 만든다" % k, n != null and n.kind == k)
		if n != null:
			n.free()

	print("── 아스키 대체가 되살아나지 않았는가 ─────────────")
	_ok("MainMenu 가 잠금 표시로 \"[-]\" 를 쓰지 않는다",
		not _code_has("res://scripts/MainMenu.gd", "[-]"))
	_ok("UIListRow 가 완료 표시로 \"v\" 를 쓰지 않는다",
		not _code_has("res://scripts/UIListRow.gd", '.text = "v"'))

	print("──────────────────────────────────────────────────")
	print("실패 %d건" % _fails)
	quit(_fails)
	return true
