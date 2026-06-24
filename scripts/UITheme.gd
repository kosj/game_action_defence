extends Node
## 전역 UI 테마 (Autoload "UITheme").
## 루트 윈도우에 Theme 를 설치해 모든 컨트롤의 기본 폰트/크기/버튼·패널 스타일·색을 통일한다.
## (개별 위젯의 add_theme_*_override 는 그대로 우선 적용되므로 기존 강조 스타일은 유지된다.)

# 공용 팔레트 — 다른 UI 코드에서도 참조해 톤을 맞출 수 있다.
const BG_DEEP   := Color(0.06, 0.07, 0.10)
const BG_PANEL  := Color(0.11, 0.12, 0.17, 0.98)
const BTN_BG    := Color(0.17, 0.19, 0.26)
const BTN_LINE  := Color(0.38, 0.42, 0.52)
const ACCENT    := Color(1.00, 0.82, 0.25)   # 금색 강조
const TEXT      := Color(0.90, 0.92, 0.96)
const TEXT_DIM  := Color(0.66, 0.70, 0.78)

const FONT_PATH := "res://assets/fonts/NotoSansCJK-Subset.otf"


func _ready() -> void:
	# 루트(Window)는 이미 트리에 있으나, 안전하게 다음 프레임에 설치한다.
	call_deferred("_install")


func _install() -> void:
	var root := get_tree().root
	if root:
		root.theme = build()


func build() -> Theme:
	var t := Theme.new()
	var font := _font()
	if font:
		t.default_font = font
	t.default_font_size = 19

	# ── Button ────────────────────────────────────────────────
	t.set_stylebox("normal",   "Button", _btn(BTN_BG, BTN_LINE))
	t.set_stylebox("hover",    "Button", _btn(BTN_BG.lightened(0.12), BTN_LINE.lightened(0.12)))
	t.set_stylebox("pressed",  "Button", _btn(BTN_BG.darkened(0.18), ACCENT))
	t.set_stylebox("disabled", "Button", _btn(Color(0.14, 0.15, 0.18), Color(0.26, 0.27, 0.31)))
	t.set_stylebox("focus",    "Button", _empty())
	t.set_color("font_color",          "Button", TEXT)
	t.set_color("font_hover_color",    "Button", Color.WHITE)
	t.set_color("font_pressed_color",  "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.55))
	t.set_font_size("font_size", "Button", 20)

	# ── Panel / PanelContainer ────────────────────────────────
	t.set_stylebox("panel", "Panel", _panel())
	t.set_stylebox("panel", "PanelContainer", _panel())

	# ── Label ─────────────────────────────────────────────────
	t.set_color("font_color", "Label", TEXT)

	# ── HSeparator ────────────────────────────────────────────
	var sep := StyleBoxLine.new()
	sep.color = Color(1, 1, 1, 0.10)
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)

	return t


func _btn(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	return sb


func _panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_PANEL
	sb.border_color = Color(0.32, 0.36, 0.46)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 12
	return sb


func _empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


## 세로 그라데이션 배경(TextureRect, 전체 앵커). 메뉴/상점 등 단색 배경 대체용.
static func make_gradient_bg(top: Color, bottom: Color) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 256
	var tr := TextureRect.new()
	tr.texture = tex
	tr.anchor_right = 1.0
	tr.anchor_bottom = 1.0
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## 화면 가장자리를 부드럽게 어둡게 하는 비네트 오버레이.
static func make_vignette() -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load("res://assets/ui/vignette.png")
	tr.anchor_right = 1.0
	tr.anchor_bottom = 1.0
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _font() -> Font:
	if ResourceLoader.exists(FONT_PATH):
		var f = load(FONT_PATH)
		if f is Font:
			return f
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray([
		"Noto Sans CJK KR", "Noto Sans KR", "Malgun Gothic", "Apple SD Gothic Neo",
		"Noto Sans CJK JP", "Hiragino Sans", "Yu Gothic", "sans-serif"])
	sf.allow_system_fallback = true
	return sf
