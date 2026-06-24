extends Control
## 룰렛 휠: 섹터를 색으로 그리고 회전(rotation) 트윈으로 돌린다.
## 라벨/딤 처리는 setup() 으로 받은 데이터로 _draw 에서 직접 그린다.

var _sectors: Array = []   # [{ "color": Color, "label": String, "dim": bool }, ...]
var _font: Font


func setup(sectors: Array) -> void:
	_sectors = sectors
	if _font == null:
		_font = UITheme.bold_font()
	queue_redraw()


func _draw() -> void:
	var n := _sectors.size()
	if n == 0:
		return
	var center := size * 0.5
	var radius: float = min(size.x, size.y) * 0.5 - 4.0
	var step := TAU / n

	# 섹터 채우기
	for i in n:
		var a0 := i * step
		var a1 := a0 + step
		var col: Color = _sectors[i].get("color", Color.GRAY)
		if _sectors[i].get("dim", false):
			col = col.darkened(0.65)
			col.a = 0.55
		var pts := PackedVector2Array()
		pts.append(center)
		var segs := 16
		for s in segs + 1:
			var a: float = a0 + (a1 - a0) * (float(s) / segs)
			pts.append(center + Vector2(cos(a), sin(a)) * radius)
		draw_colored_polygon(pts, col)
		# 섹터 경계선
		draw_line(center, center + Vector2(cos(a0), sin(a0)) * radius, Color(0, 0, 0, 0.35), 2.0)

	# 라벨 (반경 방향으로 회전 — 실제 룰렛처럼)
	if _font:
		var fs := 13
		for i in n:
			var mid := (i + 0.5) * step
			var label: String = _sectors[i].get("label", "")
			var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var tcol := Color(1, 1, 1, 0.96)
			if _sectors[i].get("dim", false):
				tcol = Color(1, 1, 1, 0.4)
			draw_set_transform(center, mid, Vector2.ONE)
			draw_string(_font, Vector2(radius * 0.92 - tw, fs * 0.35), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tcol)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 테두리 링 + 가운데 허브
	draw_arc(center, radius, 0, TAU, 72, Color(0.92, 0.92, 0.98, 0.95), 3.0)
	draw_circle(center, radius * 0.13, Color(0.14, 0.15, 0.22))
	draw_arc(center, radius * 0.13, 0, TAU, 32, Color(0.92, 0.92, 0.98, 0.95), 3.0)
