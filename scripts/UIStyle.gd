class_name UIStyle
extends RefCounted
## 공용 UI 스타일 팩토리 — 코드로 생성/구성되는 UI 전반(HUD, 상점)에서 재사용.


static func panel(bg: Color, border: Color, radius: int = 18, border_w: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 8            # 곡선 모서리를 더 매끈하게
	sb.anti_aliasing = true
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 5)
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


static func _button_box(bg: Color, border: Color, radius: int, border_w: int, shadow: int = 5) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.border_width_top = border_w + 1        # 상단 테두리를 살짝 두껍게 — 입체 베벨 느낌
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 8                       # 매끈한 곡선 모서리
	sb.anti_aliasing = true
	sb.shadow_color = Color(0, 0, 0, 0.38)
	sb.shadow_size = shadow                     # 부드러운 드롭 섀도로 버튼이 떠 보이게
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 11
	sb.content_margin_bottom = 11
	return sb


## 버튼에 normal/hover/pressed/disabled 4종 StyleBox 를 한 번에 적용.
static func apply_button_style(btn: Button, bg: Color, border: Color, radius: int = 16) -> void:
	var normal := _button_box(bg, border, radius, 2, 5)
	var hover := _button_box(bg.lightened(0.16), border.lightened(0.12), radius, 2, 7)
	var pressed := _button_box(bg.darkened(0.22), border, radius, 2, 1)   # 눌리면 섀도 줄여 가라앉는 느낌
	var disabled := _button_box(Color(0.16, 0.16, 0.19), Color(0.28, 0.28, 0.32), radius, 2, 0)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))
	# 포커스 시 그려지는 기본 흰색 아웃라인 제거(터치 UI 라 키보드 포커스 테두리가 불필요·거슬림).
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
