extends SceneTree
## 이벤트 예고 UI 검증 (P1-4).
##   godot --headless --path . --script res://tools/verify_event_forecast.gd
## 종료 코드 = 실패 개수.
##
## 무엇을 지키는가: 이 UI 의 값어치는 전부 "정확한 시각"에 있다. 눈금이나 카운트다운이 실제
## 등장 시각과 어긋나면 없느니만 못하다 — 플레이어가 대비했는데 안 오거나, 안 왔는데 온다.
## 화면 없이 확인할 수 있는 것은 ① 눈금 시각 계산 ② 카운트다운 임계·중복 억제 ③ 스포너가
## 흘리는 예정 시각이 실제 예약과 같은가, 이 셋이다.

const DT := 1.0 / 60.0

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
	var events := root.get_node("Events")
	var tl: GDScript = load("res://scripts/TimelineBar.gd")

	print("── 눈금 시각 계산 ───────────────────────────────")
	# 보스 600초 주기, 30분 런에서 다음 보스가 600초라면 눈금은 600/1200/1800.
	var boss: Array = tl.series_times(600.0, 600.0, 1800.0)
	_ok("보스 눈금 3개(600·1200·1800)", boss == [600.0, 1200.0, 1800.0], str(boss))
	# 엘리트 300초 주기.
	var elite: Array = tl.series_times(300.0, 300.0, 1800.0)
	_ok("엘리트 눈금 6개", elite.size() == 6, str(elite))
	# 클리어를 넘는 눈금은 그리지 않는다 — 띠 밖으로 나가면 거짓 정보다.
	var late: Array = tl.series_times(1700.0, 600.0, 1800.0)
	_ok("클리어를 넘는 눈금은 없다", late == [1700.0], str(late))
	# 보스전 중에는 "다음 보스"가 정해지지 않았으므로 눈금을 그리지 않는다.
	_ok("예정 없음(-1)이면 눈금 0개", tl.series_times(-1.0, 600.0, 1800.0).is_empty())
	_ok("주기가 0 이어도 무한 루프에 빠지지 않는다",
		tl.series_times(600.0, 0.0, 1800.0).is_empty())

	print("── 스포너가 흘리는 예정 시각 ────────────────────")
	# HUD 가 주기 상수로 따로 계산하면 어긋난다(보스는 전투 중 미뤄지고 치트로도 밀린다).
	# 그래서 스포너의 실제 예약값이 그대로 나오는지 본다.
	var zs = (load("res://scripts/ZombieSpawner.gd") as GDScript).new()
	var got := {"boss": 0.0, "elite": 0.0, "n": 0}
	var on_fc := func(b: float, e: float) -> void:
		got["boss"] = b
		got["elite"] = e
		got["n"] += 1
	events.forecast_changed.connect(on_fc)

	zs._next_boss_at = 1234.0
	zs._next_elite_at = 567.0
	zs._boss_alive = false
	zs._emit_forecast()
	_ok("예약된 보스 시각이 그대로 나온다", is_equal_approx(got["boss"], 1234.0), "%f" % got["boss"])
	_ok("예약된 엘리트 시각이 그대로 나온다", is_equal_approx(got["elite"], 567.0), "%f" % got["elite"])

	# 보스가 살아 있는 동안 "다음 보스"는 아직 정해지지 않았다 — 눈금·카운트다운을 모두 꺼야 한다.
	zs._boss_alive = true
	zs._emit_forecast()
	_ok("보스전 중에는 보스 예정을 -1 로 끈다", got["boss"] < 0.0, "%f" % got["boss"])
	_ok("보스전 중에도 엘리트 예정은 계속 나온다", is_equal_approx(got["elite"], 567.0))
	events.forecast_changed.disconnect(on_fc)
	zs.free()

	print("── 카운트다운 배너 ──────────────────────────────")
	var hud = load("res://scenes/HUD.tscn").instantiate()
	root.add_child(hud)
	_ok("타임라인 바가 HUD 에 붙었다", hud._timeline != null)

	# --script 메인 루프는 오토로드 등록 전에 컴파일된다 — 맨 식별자로 쓰면 컴파일 에러다.
	var locale := root.get_node("Locale")
	var boss_txt: String = locale.t("hud_boss_in_fmt")
	var elite_txt: String = locale.t("hud_elite_in_fmt")

	# 임계 밖 — 아직 뜨지 않는다.
	events.elapsed_time = 500.0
	hud._swarm_banner.text = ""
	hud._on_forecast(600.0, 900.0)   # 보스 100초 뒤, 엘리트 400초 뒤
	_ok("임계 밖에서는 배너가 뜨지 않는다", hud._swarm_banner.text == "",
		"'%s'" % hud._swarm_banner.text)

	# 보스 60초 전 — 뜬다.
	events.elapsed_time = 545.0
	hud._on_forecast(600.0, 900.0)
	_ok("보스 60초 전에 예고가 뜬다", hud._swarm_banner.text == boss_txt % 55,
		"'%s'" % hud._swarm_banner.text)

	# 같은 회차는 다시 뜨지 않는다 — 매초 갱신이라 잠그지 않으면 배너가 깜박인다.
	hud._swarm_banner.text = ""
	events.elapsed_time = 550.0
	hud._on_forecast(600.0, 900.0)
	_ok("같은 보스 회차는 한 번만 뜬다", hud._swarm_banner.text == "",
		"'%s'" % hud._swarm_banner.text)

	# 다음 회차(예정 시각이 바뀜)에는 다시 뜬다.
	events.elapsed_time = 1150.0
	hud._on_forecast(1200.0, 1500.0)
	_ok("다음 보스 회차에는 다시 뜬다", hud._swarm_banner.text == boss_txt % 50,
		"'%s'" % hud._swarm_banner.text)

	# 엘리트는 20초 전.
	hud._swarm_banner.text = ""
	events.elapsed_time = 1470.0
	hud._on_forecast(-1.0, 1485.0)
	_ok("엘리트 20초 전에 예고가 뜬다", hud._swarm_banner.text == elite_txt % 15,
		"'%s'" % hud._swarm_banner.text)

	hud._swarm_banner.text = ""
	events.elapsed_time = 1460.0
	hud._on_forecast(-1.0, 1500.0)   # 40초 남음 — 임계 밖
	_ok("엘리트도 임계 밖에서는 뜨지 않는다", hud._swarm_banner.text == "",
		"'%s'" % hud._swarm_banner.text)

	# 보스전 중(-1)에는 보스 예고가 뜨지 않는다.
	hud._swarm_banner.text = ""
	hud._boss_warned_at = -99.0
	events.elapsed_time = 700.0
	hud._on_forecast(-1.0, 3000.0)
	_ok("보스 예정이 -1 이면 보스 예고가 없다", hud._swarm_banner.text == "",
		"'%s'" % hud._swarm_banner.text)

	hud.free()
	events.elapsed_time = 0.0

	print("──────────────────────────────────────────────────")
	print("실패 %d건" % _fails)
	quit(_fails)
	return true
