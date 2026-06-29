extends Control
## "DeadLine" 시네마틱 타이틀 스크린 — 게임의 첫 화면.
## 핏빛 글로우 + 떠오르는 잔불 파티클 위로 큰 로고가 슬램 등장하고, 은은한 글로우 맥동·
## 부유·간헐적 깜빡임으로 분위기를 낸다. 화면을 탭하면 페이드아웃 후 메인 메뉴로 전환.

const TITLE_TEXT := "DeadLine"
const MENU_SCENE := "res://scenes/MainMenu.tscn"

const TITLE_Y := 330.0
const SLASH_Y := 470.0

var _t: float = 0.0
var _started: bool = false
var _intro_done: bool = false
var _flicker_cd: float = 3.0

var _title_holder: Control
var _glow: TextureRect
var _ghost: Label
var _main_label: Label
var _slash: ColorRect
var _tagline: Label
var _best: Label
var _tap_label: Label
var _flash: ColorRect
var _fade: ColorRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_play_intro()


func _build() -> void:
	# 깊은 핏빛-검정 그라데이션 배경
	add_child(UITheme.make_gradient_bg(Color(0.12, 0.03, 0.04), Color(0.02, 0.02, 0.03)))

	# 타이틀 뒤 핏빛 방사 글로우
	_glow = TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.78, 0.10, 0.10, 0.55))
	grad.set_color(1, Color(0.78, 0.10, 0.10, 0.0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	gtex.width = 256
	gtex.height = 256
	_glow.texture = gtex
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.size = Vector2(680, 480)
	_glow.position = Vector2(360.0 - 340.0, (TITLE_Y + 50.0) - 240.0)
	add_child(_glow)

	# 떠오르는 잔불(ember) 파티클 — 분위기
	_build_embers()

	# ── 타이틀 스택(고스트 / 그림자 / 본체 + 슬래시) ──────────────────────
	_title_holder = Control.new()
	_title_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_holder.pivot_offset = Vector2(360.0, TITLE_Y + 50.0)
	add_child(_title_holder)

	_ghost = _make_title_label(Color(0.85, 0.12, 0.12, 0.30), 0)          # 붉은 잔상
	_title_holder.add_child(_ghost)
	var shadow := _make_title_label(Color(0.0, 0.0, 0.0, 0.6), 0)         # 드롭 섀도
	shadow.offset_left = 5.0
	shadow.offset_right = 5.0
	shadow.offset_top = TITLE_Y + 7.0
	_title_holder.add_child(shadow)
	_main_label = _make_title_label(Color(0.97, 0.94, 0.90, 1.0), 13)     # 본체(아웃라인)
	_title_holder.add_child(_main_label)

	# 제목 아래 핏빛 슬래시
	_slash = ColorRect.new()
	_slash.color = Color(0.82, 0.12, 0.12, 0.95)
	_slash.anchor_left = 0.5
	_slash.anchor_right = 0.5
	_slash.offset_left = -180.0
	_slash.offset_right = 180.0
	_slash.offset_top = SLASH_Y
	_slash.offset_bottom = SLASH_Y + 3.0
	_slash.pivot_offset = Vector2(180.0, 1.5)
	_slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_holder.add_child(_slash)

	# 태그라인 / 최고점 / 탭 안내
	_tagline = _make_centered_label(Locale.t("title_tagline"), 22, Color(0.78, 0.34, 0.32, 1.0), SLASH_Y + 26.0)
	UITheme.heading(_tagline)
	_best = _make_centered_label("%s  %d" % [Locale.t("menu_best"), Events.high_score], 20, Color(0.72, 0.74, 0.80, 1.0), SLASH_Y + 70.0)
	_tap_label = _make_centered_label(Locale.t("title_tap"), 26, Color(0.95, 0.93, 0.95, 1.0), 1030.0)
	UITheme.heading(_tap_label)

	# 버전 표시(우하단)
	var ver := Label.new()
	ver.text = Events.VERSION
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = -130.0
	ver.offset_top = -34.0
	ver.offset_right = -14.0
	ver.offset_bottom = -10.0
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.add_theme_font_size_override("font_size", 16)
	ver.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68, 0.7))
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ver)

	# 가장자리 비네트(분위기 + 시인성)
	var vig := UITheme.make_vignette()
	vig.modulate = Color(1, 1, 1, 0.85)
	add_child(vig)

	# 슬램 순간 붉은 섬광 / 전환용 검정 페이드 (둘 다 입력 무시·전체화면)
	_flash = _overlay_rect(Color(0.9, 0.15, 0.12, 0.0))
	_fade = _overlay_rect(Color(0.0, 0.0, 0.0, 0.0))


func _make_title_label(col: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = TITLE_TEXT
	l.anchor_right = 1.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.offset_top = TITLE_Y
	l.add_theme_font_size_override("font_size", 96)
	l.add_theme_color_override("font_color", col)
	UITheme.heading(l)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0.35, 0.02, 0.03, 1.0))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _make_centered_label(txt: String, size: int, col: Color, y: float) -> Label:
	var l := Label.new()
	l.text = txt
	l.anchor_right = 1.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.offset_top = y
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _overlay_rect(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _build_embers() -> void:
	var p := CPUParticles2D.new()
	p.amount = 48
	p.lifetime = 7.0
	p.preprocess = 4.0
	p.lifetime_randomness = 0.6
	p.position = Vector2(360.0, 1300.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(380.0, 8.0)
	p.direction = Vector2(0, -1)
	p.spread = 16.0
	p.gravity = Vector2(0, -7.0)
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 34.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.6
	p.color = Color(1.0, 0.45, 0.18, 0.55)
	# 수명 동안 서서히 나타났다 사라지도록 알파 램프
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.5, 0.2, 0.0))
	ramp.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	ramp.add_point(0.25, Color(1.0, 0.5, 0.2, 0.6))
	p.color_ramp = ramp
	p.emitting = true
	add_child(p)


func _play_intro() -> void:
	_title_holder.scale = Vector2(1.22, 1.22)
	_title_holder.modulate.a = 0.0
	_slash.scale.x = 0.0
	_tagline.modulate.a = 0.0
	_best.modulate.a = 0.0
	_tap_label.modulate.a = 0.0

	var tw := create_tween()
	tw.tween_interval(0.2)
	tw.set_parallel(true)
	tw.tween_property(_title_holder, "modulate:a", 1.0, 0.4)
	tw.tween_property(_title_holder, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_callback(_slam)
	tw.tween_property(_slash, "scale:x", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(_tagline, "modulate:a", 1.0, 0.5)
	tw.tween_property(_best, "modulate:a", 0.85, 0.5)
	tw.set_parallel(false)
	tw.tween_property(_tap_label, "modulate:a", 1.0, 0.4)
	tw.tween_callback(func(): _intro_done = true)


func _slam() -> void:
	_flash.color = Color(0.9, 0.15, 0.12, 0.45)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.5)


func _process(delta: float) -> void:
	_t += delta
	# 글로우 맥동
	if _glow:
		_glow.modulate.a = 0.75 + 0.25 * sin(_t * 1.8)
	# 타이틀 부유 + 붉은 잔상 드리프트
	if _title_holder and not _started:
		_title_holder.position.y = sin(_t * 1.1) * 4.0
	if _ghost:
		_ghost.position = Vector2(sin(_t * 0.9) * 4.0, cos(_t * 1.3) * 3.0)

	if not _intro_done or _started:
		return
	# 탭 안내 맥동
	if _tap_label:
		_tap_label.modulate.a = 0.35 + 0.45 * (0.5 + 0.5 * sin(_t * 3.2))
	# 간헐적 깜빡임(호러 연출)
	_flicker_cd -= delta
	if _flicker_cd <= 0.0:
		_flicker_cd = randf_range(2.6, 5.2)
		_flicker()


func _flicker() -> void:
	if not is_instance_valid(_main_label):
		return
	var tw := create_tween()
	tw.tween_property(_main_label, "modulate:a", 0.35, 0.05)
	tw.tween_property(_main_label, "modulate:a", 1.0, 0.05)
	tw.tween_interval(0.04)
	tw.tween_property(_main_label, "modulate:a", 0.55, 0.04)
	tw.tween_property(_main_label, "modulate:a", 1.0, 0.08)


func _input(event: InputEvent) -> void:
	if _started:
		return
	var go := false
	if event is InputEventScreenTouch and event.pressed:
		go = true
	elif event is InputEventMouseButton and event.pressed:
		go = true
	elif event is InputEventKey and event.pressed and not event.echo:
		go = true
	if go:
		_start_game()


func _start_game() -> void:
	_started = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.4)
	tw.tween_callback(func(): get_tree().change_scene_to_file(MENU_SCENE))
