extends SceneTree
## 상단 경고 띠 검증 (P2-26).
##   godot --headless --path . --script res://tools/verify_hud_alert.gd
## 종료 코드 = 실패 개수.
##
## 무엇을 지키는가 셋:
##
## 1. **위험도가 색 말고도 무언가를 바꾼다.** 이 작업의 이유가 그것이다 — 예전 배너는
##    스웜이든 보스든 같은 라벨에 글자색만 달랐다. 세 배열(색·머무는 시간·맥동 주기)이
##    전부 같은 값으로 채워지면 연출은 있으나마나가 된다.
## 2. **더 큰 위험이 이긴다.** 띠가 하나뿐이라, 낮은 위험이 덮어쓸 수 있으면 보스 등장
##    이름이 무리 경고에 지워진다. 눈으로는 "가끔 보스 이름이 안 보인다"로만 나타난다.
## 3. **소리가 띠와 같이 움직인다.** 경고음은 `flash` 안에서 나므로, 위 2번에 막혀 안 뜬
##    경고는 소리도 나지 않는다. 이게 깨지면 화면에 없는 경고가 소리만 낸다.
## 4. **안 보일 때는 렌더에서 빠진다.** 알파 0 인 720px 사각형을 남겨 두면 화면에는
##    아무것도 없는데 드로우 콜만 계속 나간다(CLAUDE.md §3 · HUD 가 드로우 콜의 절반이다).
##
## 실제로 어떻게 보이는지는 헤드리스로 알 수 없다 — `tools/shot_hud_layers.gd` 로 픽셀을 본다.

const _HUD := "res://scripts/HUD.gd"
const _LOCALE := "res://scripts/Locale.gd"

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

	var alert_cls: GDScript = load("res://scripts/HUDAlert.gd")
	_ok("HUDAlert 를 읽는다", alert_cls != null)
	var c: Dictionary = alert_cls.get_script_constant_map()

	print("── 위험도가 색 말고도 바꾸는가 ─────────────────")
	for key in ["ACCENT", "HOLD", "PULSE"]:
		_ok("%s 가 3단계다" % key, c.has(key) and (c[key] as Array).size() == 3,
			str(c.get(key, "없음")))
	if c.has("HOLD"):
		var hold: Array = c["HOLD"]
		_ok("보스가 무리보다 오래 머문다", float(hold[2]) > float(hold[0]), str(hold))
	if c.has("PULSE"):
		var pulse: Array = c["PULSE"]
		_ok("보스가 무리보다 빨리 맥동한다", float(pulse[2]) < float(pulse[0]), str(pulse))
	if c.has("ACCENT"):
		var acc: Array = c["ACCENT"]
		_ok("세 색이 서로 다르다",
			not (acc[0] as Color).is_equal_approx(acc[1] as Color)
			and not (acc[1] as Color).is_equal_approx(acc[2] as Color), str(acc))

	print("── 더 큰 위험이 이긴다 · 쉴 때는 숨는다 ─────────")
	# 트윈을 만들려면 트리 안에 있어야 한다. 임시 부모를 붙였다 지운다.
	var host := Control.new()
	host.size = Vector2(720, 1280)
	root.add_child(host)
	var alert = alert_cls.make(host, 232.0, 58.0)
	_ok("만든 직후에는 보이지 않는다", alert != null and not alert.visible)

	var lv_swarm: int = c.get("LV_SWARM", 0)
	var lv_boss: int = c.get("LV_BOSS", 2)
	_ok("보스 위험도가 무리보다 높다", lv_boss > lv_swarm)
	_ok("첫 경고는 뜬다", alert.flash("BOSS", lv_boss, 34))
	_ok("떠 있으면 보인다", alert.visible)
	_ok("낮은 위험은 보스를 덮지 못한다", not alert.flash("SWARM", lv_swarm, 30))
	_ok("덮이지 않아 글자가 그대로다", alert.label.text == "BOSS", alert.label.text)
	_ok("같은 위험도는 갱신한다", alert.flash("BOSS 30", lv_boss, 34))
	host.queue_free()

	print("── 경고음이 위험도마다 다른가 ──────────────────")
	var snd: Array = c.get("SOUND", [])
	_ok("경고음이 3단계다", snd.size() == 3, str(snd))
	_ok("세 키가 서로 다르다", snd.size() == 3 and snd[0] != snd[1] and snd[1] != snd[2],
		str(snd))
	# 키가 틀려도 play() 는 조용히 무시한다 — 증상이 "소리가 안 남" 뿐이라 눈으로는 못 잡는다.
	var sm := root.get_node_or_null("SoundManager")
	if sm != null:
		var sounds: Dictionary = sm.get_script().get_script_constant_map()["_SOUNDS"]
		for key in snd:
			_ok("_SOUNDS 에 %s 가 있다" % key, sounds.has(key))

	print("── 호출부가 옛 방식으로 돌아가지 않았는가 ───────")
	var hud := FileAccess.get_file_as_string(_HUD)
	# 보스 등장마다 Label 을 새로 만들어 붙이고 트윈 끝에 free 하던 방식으로의 회귀.
	_ok("보스 등장이 라벨을 새로 만들지 않는다",
		not hud.contains("banner.queue_free"), "예전 _announce_boss 방식이 돌아왔다")
	_ok("_show_banner 가 띠로 간다", hud.contains("_alert.flash"))
	# 보스 등장은 이미 boss_alarm 을 울린다 — 띠까지 소리를 내면 두 경보가 겹친다.
	_ok("보스 등장은 띠 소리를 끄고 부른다",
		hud.contains("_ALERT_FONT_BOSS, false"), "boss_alarm 과 warn_boss 가 겹친다")

	print("── 아스키 위험 표시가 되살아나지 않았는가 ───────")
	# 경고 삼각형이 하는 일을 글자로 한 번 더 하지 않는다(UI_POLISH_PLAN §A-2 의 원칙).
	var loc := FileAccess.get_file_as_string(_LOCALE)
	for line in loc.split("\n"):
		var t := String(line).strip_edges()
		if t.begins_with("\"hud_swarm\"") or t.begins_with("\"hud_elite\""):
			_ok("%s 에 !! 가 없다" % t.substr(0, 12), not t.contains("!!"), t)

	print("\n실패 %d건" % _fails)
	quit(_fails)
	return true
