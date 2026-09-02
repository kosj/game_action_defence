@tool
extends SceneTree

## 캐릭터 걷기 시트 검증 — `character_db` 의 `run_frames` 와 실제 시트 폭이 맞는지 본다.
## 폭이 칸 수로 나눠떨어지지 않으면 `Sprite2D.hframes` 가 칸을 어긋나게 잘라 걷기가 밀린다
## (7포즈를 8칸에 욱여넣으면 중복 프레임에서 스터터가 생긴다).
##
## 방향별 시트(P1-33)도 같이 본다 — 세 방향이 `run_frames` 하나를 공유하므로 **칸 수가
## 서로 달라도 안 된다.** 다르면 걷다가 방향을 바꿀 때 보폭이 튄다. 방향 시트가 아예 없는
## 것은 정상이다(측면으로 폴백하며, 그때는 지금까지와 동일하게 돈다).
##
##   godot --headless --path . --script res://tools/verify_character_sheets.gd
##
## 종료 코드 0 = 통과.

## 방향 키 → 파일명 접미사. 측면이 빈 문자열인 것은 기존 파일명을 그대로 쓰기 때문이다
## (`Player._DIR_SUFFIX` 와 같은 규약 — 한쪽을 바꾸면 다른 쪽도 바꿔야 한다).
const _DIRS := {"측면": "", "위": "_up", "아래": "_down"}


func _init() -> void:
	var db = load("res://data/character_db.tres")
	var fail := 0
	for c in db.characters:
		var n: int = c.run_frames
		var found := 0
		for dir_label in _DIRS:
			var suffix: String = _DIRS[dir_label]
			var path := "res://assets/sprites/run_%s%s.png" % [c.id, suffix]
			var idle := "res://assets/sprites/idle_%s%s.png" % [c.id, suffix]
			var has_idle := ResourceLoader.exists(idle)
			if not ResourceLoader.exists(path):
				if has_idle:
					found += 1
					print("  %-9s %-4s 시트 없음 · 대기 그림만 (절차 걷기)" % [c.id, dir_label])
				continue
			found += 1
			var tex: Texture2D = load(path)
			var w := int(tex.get_width())
			var h := int(tex.get_height())
			if n < 2:
				# 시트 파일은 있지만 데이터가 안 쓰겠다고 한 상태 — 그림 한 장 + 절차 걷기.
				print("  %-9s %-4s run_frames=%d  시트 미사용 (한 장 + 절차 걷기), 시트는 %dx%d 로 보관" % [
					c.id, dir_label, n, w, h])
				continue
			var ok: bool = (w % n == 0)
			if not ok:
				fail += 1
			print("  %-9s %-4s run_frames=%d  sheet=%dx%d  cell=%dx%d  %s" % [
				c.id, dir_label, n, w, h, w / n, h, ("OK" if ok else "FAIL — 폭이 칸 수로 안 나눠떨어진다")])
			if has_idle:
				var it: Texture2D = load(idle)
				print("                 idle=%dx%d" % [int(it.get_width()), int(it.get_height())])
			else:
				print("                 idle 없음 — 멈출 때 시트 0번 프레임 사용")
		if found == 0:
			print("  %-9s 방향 그림 없음 — sprite_path 한 장 + 절차 걷기" % c.id)
	print("결과: %s" % ("모두 통과" if fail == 0 else "%d건 실패" % fail))
	quit(1 if fail > 0 else 0)
