@tool
extends SceneTree

## 임시 검증 스크립트 — character_db 의 run_frames 와 실제 시트 폭이 맞는지 확인한다.
## godot --headless --script res://tools/_verify_sheets.gd

func _init() -> void:
	var db = load("res://data/character_db.tres")
	var fail := 0
	for c in db.characters:
		var path := "res://assets/sprites/run_%s.png" % c.id
		if not ResourceLoader.exists(path):
			print("  %-9s 시트 없음 (절차 걷기)" % c.id)
			continue
		var tex: Texture2D = load(path)
		var w := int(tex.get_width())
		var h := int(tex.get_height())
		var n: int = c.run_frames
		var ok: bool = (n > 0 and w % n == 0)
		if not ok:
			fail += 1
		print("  %-9s run_frames=%d  sheet=%dx%d  cell=%dx%d  %s" % [
			c.id, n, w, h, (w / n if n > 0 else 0), h, ("OK" if ok else "FAIL")])

		var idle := "res://assets/sprites/idle_%s.png" % c.id
		if ResourceLoader.exists(idle):
			var it: Texture2D = load(idle)
			print("            idle=%dx%d" % [int(it.get_width()), int(it.get_height())])
		else:
			print("            idle 없음 — 멈출 때 시트 0번 프레임 사용")
	print("결과: %s" % ("모두 통과" if fail == 0 else "%d건 실패" % fail))
	quit(1 if fail > 0 else 0)
