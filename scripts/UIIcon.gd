extends Control
class_name UIIcon
## 코드로 그리는 단색 벡터 아이콘 위젯 — 외부 이미지/import 없이 일관된 아이콘을 제공한다.
## 사용:  add_child(UIIcon.make("clock", 22, Color(0.8,0.85,0.95)))

@export var kind: String = "star"
@export var color: Color = Color.WHITE

const _KINDS := ["coin", "star", "flag", "clock", "trophy", "skull", "heart", "bolt", "sword", "orb", "gear",
	"lock", "check", "book"]

## 전용 아트가 있는 종류는 절차적 드로잉 대신 텍스처를 그린다(색 modulate 없이 원색 사용).
## 파일이 있는 것만 배선 — 나머지는 아래 _draw 의 벡터 드로잉으로 폴백.
const _KIND_TEX := {
	"skull": preload("res://assets/atlas/ui/hud_skull.tres"),
	"clock": preload("res://assets/atlas/ui/hud_clock.tres"),
	"coin":  preload("res://assets/ui/ui_coin.png"),
}


static func make(kind: String, px: float, color: Color = Color.WHITE) -> UIIcon:
	var ic := UIIcon.new()
	ic.kind = kind
	ic.color = color
	ic.custom_minimum_size = Vector2(px, px)
	ic.size = Vector2(px, px)
	# 컨테이너(GridContainer 등)에서 셀 높이에 맞춰 늘어나 찌그러지지 않도록 최소크기로 고정·중앙정렬.
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


func _draw() -> void:
	var s := size
	# 전용 아트가 있으면 정사각(중앙)으로 그린다 — 컨트롤이 늘어나도 텍스처 비율 유지(찌그러짐 방지).
	if _KIND_TEX.has(kind):
		var side := minf(s.x, s.y)
		var off := (s - Vector2(side, side)) * 0.5
		draw_texture_rect(_KIND_TEX[kind], Rect2(off, Vector2(side, side)), false)
		return
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
		"gear":   _gear(c, r)
		"lock":   _lock(c, r)
		"check":  _check(c, r)
		"book":   _book(c, r)
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


## 톱니바퀴(설정) — 사다리꼴 톱니 8개 + 몸통 원 + 가운데 구멍.
func _gear(c: Vector2, r: float) -> void:
	const TEETH := 8
	for i in TEETH:
		var a := TAU * float(i) / float(TEETH)
		var dir := Vector2(cos(a), sin(a))
		var perp := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([
			c + dir * r * 0.58 + perp * r * 0.21,
			c + dir * r * 0.98 + perp * r * 0.13,
			c + dir * r * 0.98 - perp * r * 0.13,
			c + dir * r * 0.58 - perp * r * 0.21]), color)
	draw_circle(c, r * 0.66, color)
	draw_circle(c, r * 0.27, Color(0, 0, 0, 0.6))


## 자물쇠 — 잠긴 캐릭터/아레나 카드에 얹는다. 예전에는 이름 앞에 `"[-] "` 를 붙였는데,
## 폰트 서브셋에 글자를 늘리지 않으려던 아스키 대체였다(HANDOFF P2-4). 아이콘은 글리프가
## 필요 없으니 서브셋과 무관하고, 언어와도 무관하다.
func _lock(c: Vector2, r: float) -> void:
	var body := Rect2(c.x - r * 0.62, c.y - r * 0.10, r * 1.24, r * 0.92)
	# 고리(shackle) — 몸통 위로 반원. 두께를 몸통보다 얇게 해 자물쇠로 읽히게 한다.
	draw_arc(Vector2(c.x, body.position.y), r * 0.40, PI, TAU, 16, color, r * 0.22, true)
	draw_rect(body, color, true)
	# 열쇠 구멍 — 몸통 색을 뚫어 대비를 준다(작은 크기에서도 자물쇠임이 읽히는 유일한 디테일).
	draw_circle(Vector2(c.x, c.y + r * 0.30), r * 0.17, Color(0, 0, 0, 0.75))


## 체크 — 달성·수령 완료 표시. 슬롯 위에 얹히므로 어두운 밑선을 먼저 깔아 대비를 만든다
## (예전 Label 이 outline_size 로 하던 역할).
func _check(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array([
		c + Vector2(-r * 0.62, r * 0.02),
		c + Vector2(-r * 0.16, r * 0.50),
		c + Vector2(r * 0.66, -r * 0.52),
	])
	draw_polyline(pts, Color(0, 0, 0, 0.85), maxf(r * 0.52, 3.0), true)
	draw_polyline(pts, color, maxf(r * 0.30, 2.0), true)


## 책 — 도감(Codex) 메뉴 표식. 펼친 책은 24px 에서 뭉개지므로 **덮인 책**으로 그린다:
## 표지 한 장 + 왼쪽의 두꺼운 책등 + 오른쪽 면의 얇은 책배(페이지 단면).
## 책등을 어둡게 깔아야 작은 크기에서도 "판때기"가 아니라 책으로 읽힌다.
func _book(c: Vector2, r: float) -> void:
	var w := r * 1.44
	var h := r * 1.66
	var cover := Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h)
	draw_rect(cover, color, true)
	# 책등(왼쪽) — 표지보다 어둡게. 두께는 표지 폭의 약 1/4.
	draw_rect(Rect2(cover.position, Vector2(w * 0.26, h)), color.darkened(0.45), true)
	# 책배(오른쪽) — 페이지 단면을 밝은 얇은 띠로.
	draw_rect(Rect2(cover.position + Vector2(w * 0.86, h * 0.06), Vector2(w * 0.14, h * 0.88)),
		color.lightened(0.55), true)
