class_name UIStyle
extends RefCounted
## 공용 UI 스타일 팩토리 — 코드로 생성/구성되는 UI 전반(HUD, 상점)에서 재사용.


static func panel(bg: Color, border: Color, radius: int = 18, border_w: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	return sb


## 화면 상단에 붙는 바: 아래쪽 모서리만 둥글게.
static func bottom_bar(bg: Color, radius: int = 24) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 8
	return sb


static func _button_box(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


## 버튼에 normal/hover/pressed/disabled 4종 StyleBox 를 한 번에 적용.
static func apply_button_style(btn: Button, bg: Color, border: Color, radius: int = 14) -> void:
	var normal := _button_box(bg, border, radius, 2)
	var hover := _button_box(bg.lightened(0.15), border.lightened(0.1), radius, 2)
	var pressed := _button_box(bg.darkened(0.2), border, radius, 2)
	var disabled := _button_box(Color(0.16, 0.16, 0.19), Color(0.28, 0.28, 0.32), radius, 2)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))
