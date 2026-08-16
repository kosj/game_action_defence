extends SceneTree
## 환경(시간 경과 + 날씨) 검증.
##   godot --headless --path . --fixed-fps 60 --script res://tools/verify_environment.gd
## 종료 코드 = 실패 개수.
##
## 주의: --script 메인 루프가 컴파일될 때는 아직 오토로드가 등록돼 있지 않다 —
## Events/GameData 를 맨 식별자로 쓰면 컴파일 에러다. root.get_node() 로 잡고, 검증 대상
## 스크립트는 런타임에 load() 로 불러온다(그쪽은 오토로드를 정상적으로 쓸 수 있다).

const EPS := 0.0001

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
	var game_data := root.get_node("GameData")

	var day_script: GDScript = load("res://scripts/DayNightCycle.gd")
	var weather_script: GDScript = load("res://scripts/WeatherSystem.gd")

	var day = day_script.new()
	root.add_child(day)
	day.set_process(false)

	print("── 시간 경과(낮/밤) ──────────────────────────────")
	_test_tint_continuity(day)
	_test_cycle_wrap(day, game_data)
	_test_luma_floor(day, weather_script)

	print("── 날씨 ─────────────────────────────────────────")
	_test_theme_data(game_data)
	var weather = weather_script.new()
	root.add_child(weather)
	weather.set_process(false)
	_test_schedule_envelope(weather)
	_test_determinism(weather, weather_script, events)
	_test_distribution(weather, events, game_data)
	_test_single_emitter(weather, events, game_data)
	_test_continue_reproduces(weather, weather_script, events, game_data)

	weather.queue_free()
	day.queue_free()
	print("──────────────────────────────────────────────────")
	print("실패 %d건" % _fails)
	quit(_fails)
	return true


## ── 시간 경과 ────────────────────────────────────────────────────────────

## 틴트가 어느 지점에서도 튀지 않는가(순환 이음매 포함). 30분 런 + 오버타임까지 훑는다.
func _test_tint_continuity(day) -> void:
	var step := 0.05
	var worst := 0.0
	var worst_t := 0.0
	var prev: Color = day.tint_at(0.0)
	var t := step
	while t <= 3600.0:
		var c: Color = day.tint_at(t)
		var d: float = maxf(maxf(absf(c.r - prev.r), absf(c.g - prev.g)), absf(c.b - prev.b))
		if d > worst:
			worst = d
			worst_t = t
		prev = c
		t += step
	# 0.05초에 채널당 0.01 이상 움직이면 눈에 띄는 계단/팝이다.
	_ok("틴트 연속성(0.05s 당 채널 변화 < 0.01)", worst < 0.01,
		"최대 %.5f @ t=%.2f" % [worst, worst_t])


## 순환 이음매(u=1 → u=0)가 같은 색이어야 보스 등장 순간에 화면이 번쩍이지 않는다.
## 그리고 가장 어두운 지점이 정확히 보스 등장 시각에 떨어져야 한다.
func _test_cycle_wrap(day, game_data) -> void:
	var cycle: float = game_data.difficulty.boss_seconds
	var a: Color = day.tint_at(cycle - 0.001)
	var b: Color = day.tint_at(0.0)
	var d: float = maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))
	_ok("순환 이음매 동일 색", d < 0.002, "차이 %.5f" % d)

	var day_script: GDScript = load("res://scripts/DayNightCycle.gd")
	var min_l := 999.0
	var min_t := -1.0
	var t := 0.0
	while t < cycle:
		var l: float = day_script.luma(day.tint_at(t))
		if l < min_l:
			min_l = l
			min_t = t
		t += 0.25
	# 최저 휘도 지점 = 주기의 시작(=보스 등장 시각). 이음매 근처 0.25s 오차 허용.
	_ok("최저 휘도 = 보스 등장 시각", min_t < 0.5 or min_t > cycle - 0.5,
		"최저 t=%.2f (휘도 %.4f), 주기 %.0f" % [min_t, min_l, cycle])


## 시간 × 날씨를 곱한 "최종" 색이 가독성 하한 아래로 내려가지 않는가.
## 하한이 실제로 작동하는지도 함께 본다(하한이 한 번도 안 걸리면 테스트가 무의미하다).
func _test_luma_floor(day, weather_script: GDScript) -> void:
	var day_script: GDScript = load("res://scripts/DayNightCycle.gd")
	var floor_v: float = day_script.LUMA_FLOOR
	var defs: Dictionary = weather_script._DEF
	var tints: Array = [Color.WHITE]
	for k in defs:
		tints.append(defs[k]["tint"])
	var worst := 999.0
	var worst_desc := ""
	var over_one := false
	var clamped_any := false
	for w in tints:
		var t := 0.0
		while t < 600.0:
			var c: Color = day.composed_at(t, w)
			var l: float = day_script.luma(c)
			if l < worst:
				worst = l
				worst_desc = "t=%.1f w=%s" % [t, str(w)]
			if maxf(maxf(c.r, c.g), c.b) > 1.0:
				over_one = true
			if day_script.luma(day.tint_at(t) * w) < floor_v - EPS:
				clamped_any = true
			t += 0.5
	_ok("가독성 하한 준수(휘도 >= %.2f)" % floor_v, worst >= floor_v - EPS,
		"최저 %.5f @ %s" % [worst, worst_desc])
	_ok("하한 보정이 실제로 발동함", clamped_any, "한 번도 안 걸리면 테스트가 무의미")
	_ok("최종 틴트 채널 <= 1.0", not over_one, "CanvasModulate 로 하이라이트가 날아감")


## ── 날씨 ─────────────────────────────────────────────────────────────────

func _test_theme_data(game_data) -> void:
	var known := ["rain", "snow", "fog", "dust"]
	var all_ok := true
	var detail := ""
	for th in game_data.themes:
		if th == null:
			continue
		if th.weather_keys.is_empty():
			all_ok = false
			detail += "%s=비어있음 " % th.id
		for k in th.weather_keys:
			if not known.has(k):
				all_ok = false
				detail += "%s:%s=미정의 " % [th.id, k]
	_ok("모든 테마에 유효한 weather_keys", all_ok, detail)


## 슬롯 봉투: 경계에서 0, 중앙에서 1, 항상 [0,1].
func _test_schedule_envelope(weather) -> void:
	var slot: float = weather.SLOT
	var in_range := true
	var t := 0.0
	while t < slot * 6.0:
		var s: float = weather.strength_at(t)
		if s < -EPS or s > 1.0 + EPS:
			in_range = false
		t += 0.05
	_ok("세기 항상 [0,1]", in_range)
	_ok("슬롯 경계에서 세기 0", absf(weather.strength_at(0.0)) < EPS
		and absf(weather.strength_at(slot)) < EPS
		and weather.strength_at(slot - 0.001) < 0.001)
	_ok("슬롯 중앙에서 세기 1", absf(weather.strength_at(slot * 0.5) - 1.0) < EPS)


## 같은 시드 → 같은 시퀀스, 다른 시드 → 다른 시퀀스.
func _test_determinism(weather, weather_script: GDScript, events) -> void:
	weather._keys = PackedStringArray(["rain", "dust", "fog"])
	events.env_seed = 123456789
	var first: Array = []
	for s in range(300):
		first.append(weather.weather_for_slot(s))
	var again: Array = []
	for s in range(300):
		again.append(weather.weather_for_slot(s))
	_ok("같은 시드 재호출 = 동일 시퀀스", first == again)

	# 새 인스턴스도 같은 결과여야 한다(상태가 아니라 시드만으로 결정).
	var other = weather_script.new()
	root.add_child(other)
	other.set_process(false)
	other._keys = PackedStringArray(["rain", "dust", "fog"])
	var fresh: Array = []
	for s in range(300):
		fresh.append(other.weather_for_slot(s))
	_ok("새 인스턴스도 동일 시퀀스", first == fresh)

	events.env_seed = 987654321
	var diff: Array = []
	for s in range(300):
		diff.append(weather.weather_for_slot(s))
	_ok("다른 시드 = 다른 시퀀스", diff != first)
	other.queue_free()


## 분포 감각: 맑음이 충분히 자주 나오고, 테마의 모든 날씨가 실제로 등장하는가.
func _test_distribution(weather, events, game_data) -> void:
	for th in game_data.themes:
		if th == null or th.weather_keys.is_empty():
			continue
		weather._keys = th.weather_keys
		events.env_seed = 42
		var counts := {}
		var repeats := 0
		var prev := "-"
		var n := 3000
		for s in range(n):
			var k: String = weather.weather_for_slot(s)
			counts[k] = int(counts.get(k, 0)) + 1
			if k != "" and k == prev:
				repeats += 1
			prev = k
		var clear_pct := 100.0 * float(counts.get("", 0)) / float(n)
		_ok("[%s] 맑음 비율 ~%d%%" % [th.id, weather.CLEAR_WEIGHT],
			absf(clear_pct - float(weather.CLEAR_WEIGHT)) < 6.0, "실측 %.1f%%" % clear_pct)
		var missing := ""
		for k in th.weather_keys:
			if int(counts.get(k, 0)) == 0:
				missing += String(k) + " "
		_ok("[%s] 모든 날씨가 등장" % th.id, missing == "", "미등장: " + missing)
		# 테마 날씨가 2종 이상이면 재롤이 항상 다른 날씨를 고르므로 연속 반복은 0이어야 한다.
		_ok("[%s] 같은 날씨 연속 반복 없음" % th.id, repeats == 0, "%d/%d" % [repeats, n])


## 실제로 시간을 흘려도 파티클 이미터가 절대 2개 이상 생기지 않는가(예산 하드 캡).
func _test_single_emitter(weather, events, game_data) -> void:
	var th = game_data.themes[1] if game_data.themes.size() > 1 else game_data.themes[0]
	weather._keys = th.weather_keys
	events.env_seed = 7
	var max_emitters := 0
	var seen := {}
	var t := 0.0
	while t < 1800.0:
		events.elapsed_time = t
		weather._process(1.0 / 60.0)
		var n := 0
		for c in weather.get_children():
			if c is CPUParticles2D:
				n += 1
		max_emitters = maxi(max_emitters, n)
		seen[weather._key] = true
		t += 0.5
	_ok("이미터 항상 1개", max_emitters == 1, "최대 %d개" % max_emitters)
	_ok("30분 동안 날씨가 여러 번 바뀜", seen.size() >= 3, "관측 %d종" % seen.size())
	var amt: int = weather._emitter.amount
	_ok("입자 수 예산(<= 90)", amt <= 90, "실측 %d" % amt)


## 이어하기: 중간 시점부터 시작한 인스턴스가 통짜로 흘러온 인스턴스와 같은 상태인가.
func _test_continue_reproduces(weather, weather_script: GDScript, events, game_data) -> void:
	var th = game_data.themes[0]
	events.env_seed = 20260817
	var resume_at := 941.0

	weather._keys = th.weather_keys
	events.elapsed_time = 0.0
	weather._slot = -1
	var t := 0.0
	while t <= resume_at:
		events.elapsed_time = t
		weather._process(1.0 / 60.0)
		t += 0.5
	var straight: String = weather._key

	var fresh = weather_script.new()
	root.add_child(fresh)
	fresh.set_process(false)
	fresh._keys = th.weather_keys
	events.elapsed_time = resume_at
	fresh._process(1.0 / 60.0)
	_ok("이어하기가 같은 날씨를 복원", fresh._key == straight,
		"통짜='%s' 이어하기='%s'" % [straight, fresh._key])
	_ok("이어하기가 같은 세기를 복원",
		absf(fresh.strength_at(resume_at) - weather.strength_at(resume_at)) < EPS)
	fresh.queue_free()
