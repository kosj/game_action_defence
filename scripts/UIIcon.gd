extends Control
class_name UIIcon
## 코드로 그리는 단색 벡터 아이콘 위젯 — 외부 이미지/import 없이 일관된 아이콘을 제공한다.
## 사용:  add_child(UIIcon.make("clock", 22, Color(0.8,0.85,0.95)))

@export var kind: String = "star"
@export var color: Color = Color.WHITE

const _KINDS := ["coin", "star", "flag", "clock", "trophy", "skull", "heart", "bolt", "sword", "orb"]


static func make(kind: String, px: float, color: Color = Color.WHITE) -> UIIcon:
	var ic := UIIcon.new()
	ic.kind = kind
	ic.color = color
	ic.custom_minimum_size = Vector2(px, px)
	ic.size = Vector2(px, px)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


func _draw() -> void:
	var s := size
	var c := s * 0.5
	var r := minf(s.x, s.y) * 0.5
	match kind:
		"coin":   _coin(c, r)
		"star":   draw_colored_polygon(_star_pts(c, r), color)
		"flag":   _flag(c, r)
		"clock":  _clock(c, r)
		"trophy": _trophy(c, r)
		"skull":  _skull(c, r)
		"heart":  _heart(c, r)
		"bolt":   draw_colored_polygon(_bolt_pts(c, r), color)
		"sword":  _sword(c, r)
		"orb":    _orb(c, r)
		_:        draw_circle(c, r * 0.7, color)


func _star_pts(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(10):
		var ang := -PI / 2.0 + i * PI / 5.0
		var rad := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	return pts


func _bolt_pts(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([
		c + Vector2(r * 0.2, -r), c + Vector2(-r * 0.55, r * 0.15),
		c + Vector2(-r * 0.05, r * 0.15), c + Vector2(-r * 0.2, r),
		c + Vector2(r * 0.55, -r * 0.2), c + Vector2(r * 0.05, -r * 0.2)])


func _coin(c: Vector2, r: float) -> void:
	draw_circle(c, r * 0.88, color)
	draw_arc(c, r * 0.58, 0, TAU, 24, color.darkened(0.35), maxf(1.5, r * 0.12), true)


func _clock(c: Vector2, r: float) -> void:
	var w := maxf(2.0, r * 0.16)
	draw_arc(c, r * 0.85, 0, TAU, 32, color, w, true)
	draw_line(c, c + Vector2(0, -r * 0.55), color, w)
	draw_line(c, c + Vector2(r * 0.42, r * 0.05), color, w)


func _flag(c: Vector2, r: float) -> void:
	var w := maxf(2.0, r * 0.16)
	draw_line(c + Vector2(-r * 0.45, -r * 0.85), c + Vector2(-r * 0.45, r * 0.9), color, w)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.45, -r * 0.8), c + Vector2(r * 0.6, -r * 0.45),
		c + Vector2(-r * 0.45, -r * 0.1)]), color)


func _trophy(c: Vector2, r: float) -> void:
	var w := maxf(2.0, r * 0.14)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.5, -r * 0.75), c + Vector2(r * 0.5, -r * 0.75),
		c + Vector2(r * 0.3, r * 0.05), c + Vector2(-r * 0.3, r * 0.05)]), color)
	draw_arc(c + Vector2(-r * 0.5, -r * 0.4), r * 0.3, PI * 0.5, PI * 1.5, 10, color, w)
	draw_arc(c + Vector2(r * 0.5, -r * 0.4), r * 0.3, -PI * 0.5, PI * 0.5, 10, color, w)
	draw_line(c + Vector2(0, r * 0.05), c + Vector2(0, r * 0.5), color, w * 1.4)
	draw_line(c + Vector2(-r * 0.42, r * 0.7), c + Vector2(r * 0.42, r * 0.7), color, w * 1.8)


func _skull(c: Vector2, r: float) -> void:
	draw_circle(c + Vector2(0, -r * 0.15), r * 0.72, color)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.42, r * 0.3), c + Vector2(r * 0.42, r * 0.3),
		c + Vector2(r * 0.28, r * 0.8), c + Vector2(-r * 0.28, r * 0.8)]), color)
	var eye := Color(0, 0, 0, 0.55)
	draw_circle(c + Vector2(-r * 0.28, -r * 0.18), r * 0.18, eye)
	draw_circle(c + Vector2(r * 0.28, -r * 0.18), r * 0.18, eye)


func _heart(c: Vector2, r: float) -> void:
	draw_circle(c + Vector2(-r * 0.42, -r * 0.18), r * 0.44, color)
	draw_circle(c + Vector2(r * 0.42, -r * 0.18), r * 0.44, color)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.82, -r * 0.02), c + Vector2(r * 0.82, -r * 0.02),
		c + Vector2(0, r * 0.85)]), color)


func _sword(c: Vector2, r: float) -> void:
	var w := maxf(2.5, r * 0.2)
	draw_line(c + Vector2(-r * 0.5, r * 0.55), c + Vector2(r * 0.6, -r * 0.65), color, w)
	draw_line(c + Vector2(-r * 0.25, r * 0.05), c + Vector2(r * 0.05, r * 0.35), color, w)


func _orb(c: Vector2, r: float) -> void:
	var w := maxf(2.0, r * 0.16)
	draw_arc(c, r * 0.85, 0, TAU, 32, color, w, true)
	draw_circle(c, r * 0.3, color)
