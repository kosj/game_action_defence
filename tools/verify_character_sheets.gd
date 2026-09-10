@tool
extends SceneTree

## character_db 의 방향별 걷기/대기 시트 크기와 프레임 수를 확인한다.
## godot --headless --script res://tools/_verify_sheets.gd

func _init() -> void:
	var db = load("res://data/character_db.tres")
	var fail := 0
	for c in db.characters:
		if c.walk_texture == null:
			print("  %-9s 방향별 시트 없음 (절차 걷기)" % c.id)
			continue
		var tex: Texture2D = c.walk_texture
		var w := int(tex.get_width())
		var h := int(tex.get_height())
		var n: int = c.run_frames
		var ok: bool = n >= 2 and w % n == 0 and h % 8 == 0
		if not ok:
			fail += 1
		print("  %-9s run_frames=%d  sheet=%dx%d  cell=%dx%d  %s" % [
			c.id, n, w, h, w / maxi(1, n), h / 8, ("OK" if ok else "FAIL")])

		if c.walk_idle_texture != null:
			var it: Texture2D = c.walk_idle_texture
			print("            idle=%dx%d" % [int(it.get_width()), int(it.get_height())])
		else:
			print("            idle 없음 — 멈출 때 시트 0번 프레임 사용")
	print("결과: %s" % ("모두 통과" if fail == 0 else "%d건 실패" % fail))
	quit(1 if fail > 0 else 0)
