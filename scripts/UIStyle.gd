class_name UIStyle
extends RefCounted
## 공용 UI 스타일 팩토리 — 코드로 생성/구성되는 UI 전반(HUD, 상점)에서 재사용.

# VARCO 생성 나인패치 패널 프레임(강철+골드 베벨 테두리). 320px 소스, 테두리 분할 40px.
const _PANEL_FRAME_TEX := preload("res://assets/ui/frames/panel_frame.png")
const _PANEL_FRAME_MARGIN := 40      # 나인패치 코너/에지 분할(화면상 테두리 두께)

# 버튼 플레이트 — 다크 건메탈 + 베벨 + 리벳 + 긁힘 그런지(tools/gen_menu_plates.py).
# 색은 modulate_color 가 입히므로(최종색 = 플레이트 × accent) 호출부의 강조색이 버튼 색이 된다.
#
# 이전 button_plate.png 는 평균 밝기 227 의 "거의 흰 광택면"이라 채도 높은 색을 곱하면
# 사탕/플라스틱 색이 됐다. 새 판은 평균 136 의 중간 톤 금속이라 같은 accent 로도 금속처럼 보인다.
const _BTN_PLATE_TEX := preload("res://assets/ui/frames/btn_plate_metal.png")
const _BTN_PLATE_MARGIN := 14
# 바탕이 이미 어두우므로 예전(0.42)만큼 낮출 필요가 없다. hover/pressed 가 범위를 벗어나지
# 않도록 여유를 두고 잡는다(hover = 0.02, pressed = 0.32).
const _BTN_DARKEN := 0.16

# 아이템 슬롯 프레임(황동 림 + 어두운 함몰부). 안쪽 빈 영역은 프레임의 약 71%.
const _SLOT_TEX := preload("res://assets/ui/frames/item_slot.png")
const _SLOT_INNER_INSET := 0.16      # 아이콘이 함몰부 안에 앉도록 하는 사방 여백 비율


# ── HUD 전용 텍스처 (Phase 2) ────────────────────────────────────────────
# assets/ui/hud/ 의 VARCO 생성 에셋. 아직 파일이 없을 수 있으므로 preload 대신
# 존재 확인 후 load — 호출부는 null 이면 기존 플랫 스타일로 폴백한다.
const _HUD_DIR := "res://assets/ui/hud/"


## HUD 텍스처 로드(없으면 null). 이름은 "hud_top_bar.png" 같은 파일명.
static func hud_tex(fname: String) -> Texture2D:
	var path := _HUD_DIR + fname
	if not ResourceLoader.exists(path):
		return null
	var t = load(path)
	return t if t is Texture2D else null


## 임의 텍스처를 나인패치 StyleBoxTexture 로 감싼다(게이지/바/슬롯 공용).
static func tex_box(tex: Texture2D, margin: int, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(margin)
	sb.modulate_color = tint
	sb.draw_center = true
	return sb


## 텍스처 상단바(하단 골드 라인 포함 플레이트). 없으면 null — 호출부가 bottom_bar 폴백.
static func hud_top_bar_box() -> StyleBoxTexture:
	var tex := hud_tex("hud_top_bar.png")
	if tex == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	# 마진은 tools/gen_hud_assets.py 의 나인패치 계약과 일치(리벳=좌우 30, 골드 라인=하단 14).
	sb.texture_margin_left = 30
	sb.texture_margin_right = 30
	sb.texture_margin_top = 6
	sb.texture_margin_bottom = 14
	sb.draw_center = true
	return sb


## 텍스처 나인패치 패널. bg/border/radius/border_w 인자는 하위 호환용으로 유지하되
## 프레임 아트가 시각을 담당하므로 무시된다(콘텐츠 여백만 프레임 안쪽으로 잡는다).
static func panel(_bg: Color, _border: Color, _radius: int = 18, _border_w: int = 3) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _PANEL_FRAME_TEX
	sb.set_texture_margin_all(_PANEL_FRAME_MARGIN)   # 코너는 원본 픽셀 크기로, 가운데는 늘어남
	sb.set_content_margin_all(18)                    # 자식이 프레임 안쪽 어두운 영역에 앉도록
	sb.draw_center = true
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


## 금속 플레이트 버튼 박스. accent(호출부의 강조색)로 틴트해 버튼별 의미 색을 유지한다.
static func button_box(accent: Color, darken: float = _BTN_DARKEN) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _BTN_PLATE_TEX
	sb.set_texture_margin_all(_BTN_PLATE_MARGIN)
	sb.modulate_color = accent.darkened(darken)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 11
	sb.content_margin_bottom = 11
	return sb


## 버튼에 normal/hover/pressed/disabled 4종 StyleBox 를 한 번에 적용.
## bg/radius 는 하위 호환용으로 남기며, 플레이트 아트가 형태를 담당하므로 무시된다.
## 색은 border(강조색)를 틴트로 써서 확인=초록·위험=빨강·잠금=진회색 같은 구분을 유지한다.
static func apply_button_style(btn: Button, _bg: Color, border: Color, _radius: int = 16) -> void:
	btn.add_theme_stylebox_override("normal", button_box(border))
	btn.add_theme_stylebox_override("hover", button_box(border, _BTN_DARKEN - 0.14))
	btn.add_theme_stylebox_override("pressed", button_box(border, _BTN_DARKEN + 0.16))
	btn.add_theme_stylebox_override("disabled", button_box(Color(0.40, 0.40, 0.45), 0.45))
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))
	# 포커스 시 그려지는 기본 흰색 아웃라인 제거(터치 UI 라 키보드 포커스 테두리가 불필요·거슬림).
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# 전역 버튼 탭 사운드 — 스타일이 여러 번 재적용돼도 1회만 연결(메타 가드).
	if not btn.has_meta("_click_snd"):
		btn.set_meta("_click_snd", true)
		btn.pressed.connect(func(): SoundManager.play_ui("ui_click", 0.06, 1.0))


## 버튼 4종 StyleBox 의 좌측 콘텐츠 여백을 한 번에 조정(좌측에 슬롯/띠를 놓을 자리 확보).
## 오버라이드된 StyleBox 만 건드린다 — 전역 테마의 인스턴스는 모든 버튼이 공유하므로
## 그대로 변형하면 관계없는 버튼까지 여백이 밀린다(apply_button_style 이후에 호출할 것).
static func set_button_content_margin_left(btn: Button, px: int) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		if not btn.has_theme_stylebox_override(state):
			continue
		var sb := btn.get_theme_stylebox(state)
		if sb:
			sb.set_content_margin(SIDE_LEFT, px)


## 좌측 세로 색상 띠 — 텍스처 스타일박스에는 테두리 색이 없으므로 카테고리 구분을 자식으로 그린다.
static func add_left_stripe(ctrl: Control, color: Color, width: int = 7) -> void:
	var stripe := ColorRect.new()
	stripe.color = color
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.anchor_top = 0.0
	stripe.anchor_bottom = 1.0
	stripe.offset_left = _BTN_PLATE_MARGIN + 2      # 베벨 안쪽 면 위에 올린다
	stripe.offset_right = _BTN_PLATE_MARGIN + 2 + width
	stripe.offset_top = _BTN_PLATE_MARGIN + 2
	stripe.offset_bottom = -(_BTN_PLATE_MARGIN + 2)
	ctrl.add_child(stripe)


## 아이템 슬롯 프레임 안에 아이콘을 앉힌 위젯. 입력은 통과시켜 부모 버튼이 계속 눌린다.
static func make_item_slot(icon: Texture2D, slot_px: int = 64) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(slot_px, slot_px)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := TextureRect.new()
	frame.texture = _SLOT_TEX
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)

	if icon:
		var pad := int(round(slot_px * _SLOT_INNER_INSET))
		var ic := TextureRect.new()
		ic.texture = icon
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = pad
		ic.offset_top = pad
		ic.offset_right = -pad
		ic.offset_bottom = -pad
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(ic)
	return root
