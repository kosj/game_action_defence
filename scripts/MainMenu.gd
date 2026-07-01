extends CanvasLayer
## 메인 메뉴: 새로하기 / 이어하기 / 언어 선택. 이어하기는 로컬 저장 데이터가 있을 때만 활성화.
## 표시 문구는 Locale 에서 가져오며, 언어 변경 시 즉시 다시 번역된다.

const _UIStyle := preload("res://scripts/UIStyle.gd")
const _IntroStory := preload("res://scripts/IntroStory.gd")

## 난이도 인덱스 → Locale 키
const _DIFF_KEYS: Array = ["diff_easy", "diff_normal", "diff_hard"]

var _best_label: Label
var _diff_title: Label
var _new_game_btn: Button
var _continue_btn: Button
var _lang_title: Label
var _sound_title: Label
var _sound_btn: Button
var _options_btn: Button
var _options_dim: ColorRect
var _options_panel: PanelContainer
var _options_title: Label
var _close_btn: Button
var _diff_buttons: Array = []
var _lang_buttons: Array = []   # [{ "btn": Button, "lang": String }]

# ── 랭킹 오버레이 ──
var _rank_btn: Button
var _rank_dim: ColorRect
var _rank_panel: PanelContainer
var _rank_title: Label
var _rank_note: Label
var _rank_rows: Array = []       # [{ "name": Label, "score": Label, "mode": String }]
var _rank_online_btn: Button
var _rank_close_btn: Button


func _ready() -> void:
	get_tree().paused = false   # 게임오버/상점에서 정지된 채 메뉴로 돌아와도 메뉴가 멈추지 않도록
	_build_ui()
	_apply_language()
	Locale.language_changed.connect(_on_language_changed)


## 타이틀 화면과 같은 핏빛 방사 글로우 + 떠오르는 잔불 — 메뉴 뒤 배경 분위기.
func _build_backdrop() -> void:
	var glow := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.72, 0.10, 0.10, 0.42))
	grad.set_color(1, Color(0.72, 0.10, 0.10, 0.0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	gtex.width = 256
	gtex.height = 256
	glow.texture = gtex
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.size = Vector2(700, 520)
	glow.position = Vector2(360.0 - 350.0, 330.0 - 260.0)
	add_child(glow)

	var p := CPUParticles2D.new()
	p.amount = 42
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
	p.initial_velocity_max = 32.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.4
	p.color = Color(1.0, 0.45, 0.18, 0.5)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.5, 0.2, 0.0))
	ramp.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	ramp.add_point(0.25, Color(1.0, 0.5, 0.2, 0.55))
	p.color_ramp = ramp
	p.emitting = true
	add_child(p)


func _build_ui() -> void:
	# 타이틀 화면과 같은 분위기를 메뉴 배경으로 — 핏빛 그라데이션 + 붉은 글로우 + 잔불.
	add_child(UITheme.make_gradient_bg(Color(0.12, 0.03, 0.04), Color(0.02, 0.02, 0.03)))
	_build_backdrop()
	var vig := UITheme.make_vignette()
	vig.modulate = Color(1, 1, 1, 0.80)
	add_child(vig)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	# 게임 타이틀(브랜드) — 타이틀 화면 로고와 동일한 룩(아웃라인 + 핏빛). 번역하지 않는다.
	var title := Label.new()
	title.text = "DeadLine"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 66)
	title.add_theme_color_override("font_color", Color(0.97, 0.94, 0.90))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0.35, 0.02, 0.03, 1.0))
	UITheme.heading(title)
	box.add_child(title)

	_best_label = Label.new()
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_label.add_theme_font_size_override("font_size", 22)
	_best_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	box.add_child(_best_label)

	# 난이도 선택 (Easy / Normal / Hard) — 선택 즉시 디스크에 보존되며 New Game/Continue 모두에 적용.
	_diff_title = Label.new()
	_diff_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_diff_title.add_theme_font_size_override("font_size", 18)
	_diff_title.add_theme_color_override("font_color", Color(0.75, 0.80, 0.90))
	box.add_child(_diff_title)

	var diff_row := HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_row.add_theme_constant_override("separation", 10)
	box.add_child(diff_row)
	_diff_buttons.clear()
	for i in Events.DIFFICULTY_NAMES.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(96, 50)
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(_on_difficulty_pressed.bind(i))
		diff_row.add_child(b)
		_diff_buttons.append(b)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)

	_new_game_btn = Button.new()
	_new_game_btn.custom_minimum_size = Vector2(300, 70)
	_new_game_btn.add_theme_font_size_override("font_size", 26)
	_UIStyle.apply_button_style(_new_game_btn, Color(0.14, 0.40, 0.20), Color(0.4, 0.85, 0.45))
	_new_game_btn.pressed.connect(_on_new_game_pressed)
	box.add_child(_new_game_btn)

	_continue_btn = Button.new()
	_continue_btn.custom_minimum_size = Vector2(300, 70)
	_continue_btn.add_theme_font_size_override("font_size", 26)
	_UIStyle.apply_button_style(_continue_btn, Color(0.16, 0.24, 0.42), Color(0.4, 0.6, 0.95))
	_continue_btn.disabled = not SaveManager.has_save()
	_continue_btn.pressed.connect(_on_continue_pressed)
	box.add_child(_continue_btn)

	# ── 옵션 버튼 (언어 / 사운드 설정은 옵션 패널 하위로) ─────────────────────
	var opt_spacer := Control.new()
	opt_spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(opt_spacer)

	_rank_btn = Button.new()
	_rank_btn.custom_minimum_size = Vector2(300, 56)
	_rank_btn.add_theme_font_size_override("font_size", 22)
	_UIStyle.apply_button_style(_rank_btn, Color(0.26, 0.20, 0.08), Color(1.0, 0.82, 0.35))
	_rank_btn.pressed.connect(_on_ranking_pressed)
	box.add_child(_rank_btn)

	_options_btn = Button.new()
	_options_btn.custom_minimum_size = Vector2(300, 56)
	_options_btn.add_theme_font_size_override("font_size", 22)
	_UIStyle.apply_button_style(_options_btn, Color(0.20, 0.20, 0.28), Color(0.55, 0.58, 0.70))
	_options_btn.pressed.connect(_on_options_pressed)
	box.add_child(_options_btn)

	# 버전 표시(하단)
	var ver := Label.new()
	ver.text = Events.VERSION
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 14)
	ver.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65, 0.8))
	box.add_child(ver)

	_build_options_panel()
	_build_ranking_panel()


## 옵션 패널(언어 / 사운드 On/Off) — Option 버튼으로 열고 닫는 오버레이.
func _build_options_panel() -> void:
	_options_dim = ColorRect.new()
	_options_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options_dim.color = Color(0, 0, 0, 0.6)
	_options_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_options_dim.visible = false
	_options_dim.gui_input.connect(_on_dim_input)   # 바깥 영역 탭 시 닫기
	add_child(_options_dim)

	_options_panel = PanelContainer.new()
	_options_panel.anchor_left = 0.5
	_options_panel.anchor_right = 0.5
	_options_panel.anchor_top = 0.5
	_options_panel.anchor_bottom = 0.5
	_options_panel.offset_left = -210.0
	_options_panel.offset_right = 210.0
	_options_panel.offset_top = -240.0
	_options_panel.offset_bottom = 240.0
	_options_panel.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.10, 0.11, 0.16, 0.98), Color(0.35, 0.38, 0.5)))
	_options_panel.visible = false
	add_child(_options_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_options_panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	margin.add_child(vb)

	_options_title = Label.new()
	_options_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_options_title.add_theme_font_size_override("font_size", 30)
	_options_title.add_theme_color_override("font_color", Color(0.95, 0.92, 0.98))
	UITheme.heading(_options_title)
	vb.add_child(_options_title)

	vb.add_child(HSeparator.new())

	# 언어 설정
	_lang_title = Label.new()
	_lang_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lang_title.add_theme_font_size_override("font_size", 18)
	_lang_title.add_theme_color_override("font_color", Color(0.72, 0.76, 0.85))
	vb.add_child(_lang_title)

	var lang_row := HBoxContainer.new()
	lang_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lang_row.add_theme_constant_override("separation", 8)
	vb.add_child(lang_row)
	_lang_buttons.clear()
	for lang in Locale.SUPPORTED:
		var lb := Button.new()
		lb.text = Locale.native_name(lang)
		lb.custom_minimum_size = Vector2(92, 46)
		lb.add_theme_font_size_override("font_size", 17)
		lb.pressed.connect(_on_language_pressed.bind(lang))
		lang_row.add_child(lb)
		_lang_buttons.append({"btn": lb, "lang": lang})

	# 사운드 On/Off
	_sound_title = Label.new()
	_sound_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sound_title.add_theme_font_size_override("font_size", 18)
	_sound_title.add_theme_color_override("font_color", Color(0.72, 0.76, 0.85))
	vb.add_child(_sound_title)

	var snd_row := HBoxContainer.new()
	snd_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(snd_row)
	_sound_btn = Button.new()
	_sound_btn.custom_minimum_size = Vector2(180, 50)
	_sound_btn.add_theme_font_size_override("font_size", 19)
	_sound_btn.pressed.connect(_on_sound_pressed)
	snd_row.add_child(_sound_btn)

	vb.add_child(HSeparator.new())

	_close_btn = Button.new()
	_close_btn.custom_minimum_size = Vector2(0, 56)
	_close_btn.add_theme_font_size_override("font_size", 22)
	_UIStyle.apply_button_style(_close_btn, Color(0.14, 0.40, 0.20), Color(0.4, 0.85, 0.45))
	_close_btn.pressed.connect(_on_close_options)
	vb.add_child(_close_btn)


func _on_options_pressed() -> void:
	_options_dim.visible = true
	_options_panel.visible = true


func _on_close_options() -> void:
	_options_dim.visible = false
	_options_panel.visible = false


## 랭킹 오버레이 — 모드(난이도)별 최고 점수. 온라인 백엔드(안드로이드 PGS)면 네이티브 리더보드
## 버튼도 노출한다. 로컬 빌드(웹/PC)에서는 이 기기의 모드별 최고점만 보여준다.
func _build_ranking_panel() -> void:
	_rank_dim = ColorRect.new()
	_rank_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rank_dim.color = Color(0, 0, 0, 0.6)
	_rank_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_rank_dim.visible = false
	_rank_dim.gui_input.connect(_on_rank_dim_input)
	add_child(_rank_dim)

	_rank_panel = PanelContainer.new()
	_rank_panel.anchor_left = 0.5
	_rank_panel.anchor_right = 0.5
	_rank_panel.anchor_top = 0.5
	_rank_panel.anchor_bottom = 0.5
	_rank_panel.offset_left = -210.0
	_rank_panel.offset_right = 210.0
	_rank_panel.offset_top = -230.0
	_rank_panel.offset_bottom = 230.0
	_rank_panel.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.10, 0.11, 0.16, 0.98), Color(0.45, 0.40, 0.20)))
	_rank_panel.visible = false
	add_child(_rank_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_rank_panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	margin.add_child(vb)

	_rank_title = Label.new()
	_rank_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_title.add_theme_font_size_override("font_size", 30)
	_rank_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	UITheme.heading(_rank_title)
	vb.add_child(_rank_title)

	_rank_note = Label.new()
	_rank_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_note.add_theme_font_size_override("font_size", 15)
	_rank_note.add_theme_color_override("font_color", Color(0.70, 0.74, 0.82))
	vb.add_child(_rank_note)

	vb.add_child(HSeparator.new())

	# 모드(난이도)별 최고점 행 — 난이도 강조색으로 모드명을 칠한다.
	var accents := [Color(0.40, 0.85, 0.45), Color(0.40, 0.60, 0.95), Color(0.95, 0.40, 0.35)]
	_rank_rows.clear()
	for i in RankingManager.MODES.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		vb.add_child(row)

		var name_lbl := Label.new()
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.add_theme_color_override("font_color", accents[i])
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var score_lbl := Label.new()
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_lbl.add_theme_font_size_override("font_size", 22)
		score_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 0.99))
		score_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(score_lbl)

		_rank_rows.append({"name": name_lbl, "score": score_lbl, "mode": RankingManager.MODES[i], "key": _DIFF_KEYS[i]})

	vb.add_child(HSeparator.new())

	# 온라인 리더보드 버튼(안드로이드 PGS 로그인 시에만 노출).
	_rank_online_btn = Button.new()
	_rank_online_btn.custom_minimum_size = Vector2(0, 52)
	_rank_online_btn.add_theme_font_size_override("font_size", 18)
	_UIStyle.apply_button_style(_rank_online_btn, Color(0.14, 0.28, 0.42), Color(0.4, 0.7, 0.95))
	_rank_online_btn.pressed.connect(_on_view_online_pressed)
	_rank_online_btn.visible = false
	vb.add_child(_rank_online_btn)

	_rank_close_btn = Button.new()
	_rank_close_btn.custom_minimum_size = Vector2(0, 56)
	_rank_close_btn.add_theme_font_size_override("font_size", 22)
	_UIStyle.apply_button_style(_rank_close_btn, Color(0.14, 0.40, 0.20), Color(0.4, 0.85, 0.45))
	_rank_close_btn.pressed.connect(_on_close_ranking)
	vb.add_child(_rank_close_btn)


func _on_ranking_pressed() -> void:
	_refresh_ranking_rows()
	_rank_dim.visible = true
	_rank_panel.visible = true


func _on_close_ranking() -> void:
	_rank_dim.visible = false
	_rank_panel.visible = false


func _on_rank_dim_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_on_close_ranking()


func _on_view_online_pressed() -> void:
	RankingManager.show_leaderboard()   # 현재 난이도 모드의 네이티브 리더보드


## 각 모드의 최고점을 다시 읽어 행에 반영하고, 온라인 버튼 노출 여부를 갱신.
func _refresh_ranking_rows() -> void:
	var bests := RankingManager.all_bests()
	for r in _rank_rows:
		r["name"].text = Locale.t(r["key"])
		r["score"].text = "%d" % int(bests.get(r["mode"], 0))
	_rank_online_btn.visible = RankingManager.is_online() and RankingManager.is_signed_in()


func _on_dim_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_on_close_options()


## 현재 언어로 모든 라벨/버튼 텍스트를 갱신하고 선택 강조를 다시 칠한다.
func _apply_language() -> void:
	_refresh_best_label()
	_diff_title.text = Locale.t("menu_difficulty")
	_new_game_btn.text = Locale.t("menu_new_game")
	_continue_btn.text = Locale.t("menu_continue")
	_lang_title.text = Locale.t("menu_language")
	_sound_title.text = Locale.t("menu_sound")
	_options_btn.text = Locale.t("menu_options")
	_options_title.text = Locale.t("menu_options")
	_close_btn.text = Locale.t("menu_close")
	_rank_btn.text = Locale.t("menu_ranking")
	_rank_title.text = Locale.t("rank_title")
	_rank_note.text = Locale.t("rank_local_note")
	_rank_online_btn.text = Locale.t("rank_online")
	_rank_close_btn.text = Locale.t("menu_close")
	_refresh_ranking_rows()
	for i in _diff_buttons.size():
		_diff_buttons[i].text = Locale.t(_DIFF_KEYS[i])
	_refresh_difficulty_buttons()
	_refresh_language_buttons()
	_refresh_sound_button()


## 사운드 On/Off 토글 — 즉시 적용·저장하고 버튼 표시를 갱신.
func _on_sound_pressed() -> void:
	SoundManager.set_enabled(not SoundManager.is_enabled())
	_refresh_sound_button()


func _refresh_sound_button() -> void:
	var on := SoundManager.is_enabled()
	_sound_btn.text = "%s: %s" % [Locale.t("menu_sound"), Locale.t("sound_on") if on else Locale.t("sound_off")]
	if on:
		_UIStyle.apply_button_style(_sound_btn, Color(0.14, 0.34, 0.20), Color(0.4, 0.85, 0.45))
	else:
		_UIStyle.apply_button_style(_sound_btn, Color(0.30, 0.14, 0.14), Color(0.85, 0.4, 0.4))


func _on_language_pressed(lang: String) -> void:
	Locale.set_language(lang)


func _on_language_changed(_lang: String) -> void:
	_apply_language()


## 현재 선택된 언어 버튼만 강조.
func _refresh_language_buttons() -> void:
	for entry in _lang_buttons:
		var b: Button = entry["btn"]
		if entry["lang"] == Locale.current:
			_UIStyle.apply_button_style(b, Color(0.30, 0.26, 0.10), Color(1.0, 0.82, 0.25))
		else:
			_UIStyle.apply_button_style(b, Color(0.14, 0.15, 0.20), Color(0.30, 0.32, 0.40))


func _on_difficulty_pressed(idx: int) -> void:
	Events.difficulty = clampi(idx, 0, 2)
	SaveManager.save_difficulty()
	# 난이도가 곧 모드 — 선택한 모드의 최고점을 다시 불러와 표시(HUD/게임오버 기준점도 이 값).
	Events.set_high_score(RankingManager.current_best())
	_refresh_best_label()
	_refresh_difficulty_buttons()


## "최고 점수: N" — 현재 선택된 난이도(모드) 기준.
func _refresh_best_label() -> void:
	_best_label.text = "%s: %d" % [Locale.t("menu_best"), RankingManager.current_best()]


## 선택된 난이도만 강조색으로 표시(Easy=초록 / Normal=파랑 / Hard=빨강).
func _refresh_difficulty_buttons() -> void:
	var accents := [Color(0.40, 0.85, 0.45), Color(0.40, 0.60, 0.95), Color(0.95, 0.40, 0.35)]
	for i in _diff_buttons.size():
		var b: Button = _diff_buttons[i]
		if i == Events.difficulty:
			_UIStyle.apply_button_style(b, accents[i].darkened(0.25), accents[i])
		else:
			_UIStyle.apply_button_style(b, Color(0.14, 0.15, 0.20), Color(0.30, 0.32, 0.40))


func _on_new_game_pressed() -> void:
	# 새 게임은 서사 인트로를 먼저 보여준 뒤(완료/건너뛰기 시) 실제로 시작한다.
	_IntroStory.play(self, _start_new_game)


func _start_new_game() -> void:
	SaveManager.delete_save()
	SaveManager.pending_continue = false
	Events.reset()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_continue_pressed() -> void:
	var data := SaveManager.load_save()
	if data.is_empty():
		return
	SaveManager.apply_to_events(data)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
