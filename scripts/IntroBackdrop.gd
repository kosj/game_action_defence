extends Control
## 인트로 "The Last Beacon" 분위기 배경 — 외부 이미지 없이 코드로 그린 일러스트.
## 밤하늘 + 폐허가 된 도시 실루엣 + 홀로 구조 신호를 보내는 송신탑(맥동하는 비컨 불빛).
## 프로젝트의 코드 드로잉(UIIcon 등) 방식과 일관 — 라이선스/임포트 부담이 없다.

const BEACON_COL := Color(1.0, 0.36, 0.26)   # 구조 신호(붉은) 비컨 색
const TOWER_COL := Color(0.045, 0.05, 0.075)
const CITY_NEAR := Color(0.018, 0.022, 0.038)
const CITY_FAR := Color(0.05, 0.05, 0.085)

var _t: float = 0.0
var _stars: Array = []   # [Vector2(0..1), size, phase]


func _ready() -> void:
	_seed_stars()
	set_process(true)


func _seed_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 73101
	_stars.clear()
	for i in 64:
		_stars.append([Vector2(rng.randf(), rng.randf() * 0.62), rng.randf_range(0.7, 1.9), rng.randf() * TAU])


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	if s.x <= 1.0 or s.y <= 1.0:
		return
	_draw_moon(s)
	_draw_stars(s)
	_draw_skyline(s)
	_draw_beacon(s)


func _draw_moon(s: Vector2) -> void:
	var c := Vector2(s.x * 0.80, s.y * 0.18)
	var r := s.y * 0.55
	for i in 7:
		var f := float(i) / 7.0
		draw_circle(c, r * (1.0 - f), Color(0.46, 0.36, 0.44, 0.045))
	draw_circle(c, s.y * 0.05, Color(0.93, 0.91, 0.84, 0.9))
	draw_circle(c + Vector2(s.y * 0.018, -s.y * 0.012), s.y * 0.042, Color(0.05, 0.06, 0.12, 0.5))   # 초승달 음영


func _draw_stars(s: Vector2) -> void:
	for st: Array in _stars:
		var p := Vector2(st[0].x * s.x, st[0].y * s.y)
		var tw: float = 0.55 + 0.45 * sin(_t * 1.6 + st[2])
		draw_circle(p, st[1], Color(0.85, 0.9, 1.0, 0.22 + 0.45 * tw))


func _draw_skyline(s: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41011
	var horizon := s.y * 0.82
	_skyline_layer(s, rng, horizon + 10.0, 0.20, CITY_FAR, false)    # 뒤쪽 옅은 실루엣
	_skyline_layer(s, rng, horizon, 0.34, CITY_NEAR, true)           # 앞쪽 진한 실루엣
	draw_rect(Rect2(0, horizon, s.x, s.y - horizon), CITY_NEAR)      # 지면


func _skyline_layer(s: Vector2, rng: RandomNumberGenerator, base_y: float, max_frac: float, col: Color, windows: bool) -> void:
	var x := -12.0
	while x < s.x + 12.0:
		var w := rng.randf_range(s.x * 0.045, s.x * 0.11)
		var h := rng.randf_range(s.y * 0.06, s.y * max_frac)
		var top := base_y - h
		draw_rect(Rect2(x, top, w + 1.0, h), col)
		if windows:
			var cols := int(w / 15.0)
			var rows := int(h / 20.0)
			for cx in cols:
				for cy in rows:
					if rng.randf() < 0.05:
						draw_rect(Rect2(x + 7.0 + cx * 15.0, top + 9.0 + cy * 20.0, 4.0, 5.0), Color(1.0, 0.82, 0.42, 0.65))
		x += w + rng.randf_range(2.0, 9.0)


func _draw_beacon(s: Vector2) -> void:
	var bx := s.x * 0.70             # 중앙 텍스트와 겹치지 않게 약간 우측
	var base_y := s.y * 0.84
	var top_y := s.y * 0.32
	var hb := s.x * 0.024            # 아랫변 반폭
	var ht := s.x * 0.009            # 윗변 반폭

	# 탑 실루엣(사다리꼴) + 가로 지지대
	draw_colored_polygon(PackedVector2Array([
		Vector2(bx - hb, base_y), Vector2(bx - ht, top_y),
		Vector2(bx + ht, top_y), Vector2(bx + hb, base_y),
	]), TOWER_COL)
	for i in 3:
		var f := float(i + 1) / 4.0
		var fy := lerpf(top_y, base_y, f)
		var hw := lerpf(ht, hb, f)
		draw_line(Vector2(bx - hw, fy), Vector2(bx + hw, fy), TOWER_COL, 2.0)

	# 맥동하는 비컨 불빛
	var pulse: float = 0.5 + 0.5 * sin(_t * 2.3)
	var light := Vector2(bx, top_y - 6.0)

	# 위로 뻗는 가느다란 빛기둥
	var beam_h := s.y * 0.30
	var beam_w := s.x * 0.045 * (0.7 + 0.3 * pulse)
	draw_colored_polygon(PackedVector2Array([
		Vector2(bx, light.y),
		Vector2(bx - beam_w, light.y - beam_h),
		Vector2(bx + beam_w, light.y - beam_h),
	]), Color(BEACON_COL.r, BEACON_COL.g, BEACON_COL.b, 0.045 + 0.06 * pulse))

	# 광원 글로우
	for i in 6:
		var gf := float(i) / 6.0
		draw_circle(light, (s.y * 0.10) * (1.0 - gf) * (0.6 + 0.4 * pulse),
			Color(BEACON_COL.r, BEACON_COL.g, BEACON_COL.b, 0.05 + 0.05 * pulse))

	# 코어
	draw_circle(light, 4.0 + 2.0 * pulse, Color(1.0, 0.7, 0.5, 0.92))
	draw_circle(light, 2.0, Color(1.0, 0.96, 0.88, 1.0))
