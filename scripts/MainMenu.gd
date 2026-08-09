extends CanvasLayer
## 메인 메뉴: 새로하기 / 이어하기 / 언어 선택. 이어하기는 로컬 저장 데이터가 있을 때만 활성화.
## 표시 문구는 Locale 에서 가져오며, 언어 변경 시 즉시 다시 번역된다.

const _UIStyle := preload("res://scripts/UIStyle.gd")
const _IntroStory := preload("res://scripts/IntroStory.gd")

## 난이도 인덱스 → Locale 키
const _DIFF_KEYS: Array = ["diff_easy", "diff_normal", "diff_hard"]

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

# ── 메타 성장(PowerUp) 오버레이 ──
var _power_btn: Button
var _power_dim: ColorRect
var _power_panel: PanelContainer
var _power_gold_label: Label
var _power_rows: Array = []      # [{ "btn": Button, "id": String }]

# ── 캐릭터 선택 오버레이 ──
var _char_btn: Button
var _char_dim: ColorRect
var _char_panel: PanelContainer
var _char_rows: Array = []       # [{ "btn": Button, "c": CharacterData }]
var _char_gold_label: Label

# ── 도전과제 오버레이 ──
var _ach_btn: Button
var _ach_dim: ColorRect
var _ach_panel: PanelContainer
var _ach_rows: Array = []        # [{ "label": Label, "a": AchievementData }]

var _quest_btn: Button
var _quest_dim: ColorRect
var _quest_panel: PanelContainer
var _quest_list: VBoxContainer

# 보상 보관함(REWARDS) — 퀘스트/도전과제 보상을 유저가 직접 수령하는 패널.
var _rewards_btn: Button
var _rewards_dim: ColorRect
var _rewards_panel: PanelContainer
var _rewards_list: VBoxContainer
var _rewards_total: Label

# ── 테마(아레나) 선택 오버레이 ──
var _theme_btn: Button
var _theme_dim: ColorRect
var _theme_panel: PanelContainer
var _theme_rows: Array = []      # [{ "btn": Button, "t": ThemeData }]
var _theme_gold_label: Label


func _ready() -> void:
	get_tree().paused = false   # 게임오버/상점에서 정지된 채 메뉴로 돌아와도 메뉴가 멈추지 않도록
	Engine.time_scale = 1.0     # 히트스톱 등으로 배속이 낮게 남아 "멈춘 듯" 보이는 것 방지(복귀 시 정상화)
	# 타이틀에서 오면 같은 트랙이라 이어 재생, 게임에서 돌아오면 크로스페이드로 전환된다.
	SoundManager.play_music("title")
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
	# (가장자리 비네트 제거 — 화면 외곽 어둡게 처리하지 않음)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	# 게임 타이틀(브랜드) — 전용 로고 이미지("ZOMBIE BUSTER"). 번역하지 않는다.
	var title := TextureRect.new()
	title.texture = preload("res://assets/ui/logo_title.png")
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.custom_minimum_size = Vector2(400, 222)   # 로고 비율 1.8:1
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)

	# 최고점(스코어) 표시 제거 — 요청.
	# 난이도 모드 제거 — 단일 통합 모드(선택 UI 없음).

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

	_char_btn = Button.new()
	_char_btn.custom_minimum_size = Vector2(300, 56)
	_char_btn.add_theme_font_size_override("font_size", 20)
	_UIStyle.apply_button_style(_char_btn, Color(0.12, 0.24, 0.30), Color(0.45, 0.85, 0.95))
	_char_btn.pressed.connect(_on_character_pressed)
	box.add_child(_char_btn)

	_theme_btn = Button.new()
	_theme_btn.custom_minimum_size = Vector2(300, 56)
	_theme_btn.add_theme_font_size_override("font_size", 20)
	_UIStyle.apply_button_style(_theme_btn, Color(0.14, 0.20, 0.14), Color(0.55, 0.85, 0.55))
	_theme_btn.pressed.connect(_on_theme_pressed)
	box.add_child(_theme_btn)

	_ach_btn = Button.new()
	_ach_btn.text = "Achievements"
	_ach_btn.custom_minimum_size = Vector2(300, 56)
	_ach_btn.add_theme_font_size_override("font_size", 20)
	_UIStyle.apply_button_style(_ach_btn, Color(0.26, 0.22, 0.10), Color(0.95, 0.80, 0.35))
	_ach_btn.pressed.connect(_on_achievements_pressed)
	box.add_child(_ach_btn)

	_quest_btn = Button.new()
	_quest_btn.text = "Quests"
	_quest_btn.custom_minimum_size = Vector2(300, 56)
	_quest_btn.add_theme_font_size_override("font_size", 20)
	_UIStyle.apply_button_style(_quest_btn, Color(0.12, 0.22, 0.12), Color(0.55, 0.95, 0.55))
	_quest_btn.pressed.connect(_on_quests_pressed)
	box.add_child(_quest_btn)

	_rewards_btn = Button.new()
	_rewards_btn.custom_minimum_size = Vector2(300, 56)
	_rewards_btn.add_theme_font_size_override("font_size", 20)
	_UIStyle.apply_button_style(_rewards_btn, Color(0.26, 0.20, 0.06), Color(1.0, 0.85, 0.35))
	_rewards_btn.pressed.connect(_on_rewards_pressed)
	box.add_child(_rewards_btn)
	RewardInbox.changed.connect(_refresh_rewards_badge)
	_refresh_rewards_badge()

	_rank_btn = Button.new()
	_rank_btn.custom_minimum_size = Vector2(300, 56)
	_rank_btn.add_theme_font_size_override("font_size", 22)
	_UIStyle.apply_button_style(_rank_btn, Color(0.26, 0.20, 0.08), Color(1.0, 0.82, 0.35))
	_rank_btn.pressed.connect(_on_ranking_pressed)
	box.add_child(_rank_btn)

	_power_btn = Button.new()
	_power_btn.text = "PowerUp"
	_power_btn.custom_minimum_size = Vector2(300, 56)
	_power_btn.add_theme_font_size_override("font_size", 22)
	_UIStyle.apply_button_style(_power_btn, Color(0.24, 0.14, 0.30), Color(0.72, 0.5, 1.0))
	_power_btn.pressed.connect(_on_power_pressed)
	box.add_child(_power_btn)

	_options_btn = Button.new()
	_options_btn.custom_minimum_size = Vector2(300, 56)
	_options_btn.add_theme_font_size_override("font_size", 22)
	_UIStyle.apply_button_style(_options_btn, Color(0.20, 0.20, 0.28), Color(0.55, 0.58, 0.70))
	_options_btn.pressed.connect(_on_options_pressed)
	box.add_child(_options_btn)

	# 버전 표시(하단) — 배포 빌드 식별용 SHA·시각 포함(어떤 빌드가 라이브인지 확인)
	var ver := Label.new()
	ver.text = Events.build_label()
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 14)
	ver.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65, 0.8))
	box.add_child(ver)

	_build_options_panel()
	_build_ranking_panel()
	_build_power_panel()
	_build_character_panel()
	_refresh_char_button()
	_build_achievement_panel()
	_build_quest_panel()
	_build_rewards_panel()
	_build_theme_panel()
	_refresh_theme_button()


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


## 메타 성장(PowerUp) 오버레이 — 은행 골드로 영구 강화를 구매한다.
func _build_power_panel() -> void:
	_power_dim = ColorRect.new()
	_power_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_power_dim.color = Color(0, 0, 0, 0.6)
	_power_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_power_dim.visible = false
	_power_dim.gui_input.connect(_on_power_dim_input)
	add_child(_power_dim)

	_power_panel = PanelContainer.new()
	_power_panel.anchor_left = 0.5
	_power_panel.anchor_right = 0.5
	_power_panel.anchor_top = 0.5
	_power_panel.anchor_bottom = 0.5
	_power_panel.offset_left = -235.0
	_power_panel.offset_right = 235.0
	_power_panel.offset_top = -300.0
	_power_panel.offset_bottom = 300.0
	_power_panel.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.12, 0.08, 0.16, 0.98), Color(0.6, 0.45, 0.9)))
	_power_panel.visible = false
	add_child(_power_panel)

	var margin := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + m, 22)
	_power_panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "PERMANENT UPGRADES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0))
	vb.add_child(title)

	_power_gold_label = Label.new()
	_power_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_gold_label.add_theme_font_size_override("font_size", 20)
	_power_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	vb.add_child(_power_gold_label)

	vb.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 350)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	_power_rows.clear()
	for u in MetaManager.upgrades():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(400, 62)
		btn.add_theme_font_size_override("font_size", 18)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_UIStyle.apply_button_style(btn, Color(0.22, 0.16, 0.28), Color(0.6, 0.45, 0.9))
		btn.pressed.connect(_on_power_buy.bind(String(u["id"])))
		list.add_child(btn)
		_power_rows.append({"btn": btn, "u": u})

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 52)
	close.add_theme_font_size_override("font_size", 22)
	_UIStyle.apply_button_style(close, Color(0.18, 0.20, 0.26), Color(0.5, 0.55, 0.65))
	close.pressed.connect(_on_power_close)
	vb.add_child(close)


func _on_power_pressed() -> void:
	_refresh_power()
	_power_dim.visible = true
	_power_panel.visible = true


func _on_power_close() -> void:
	_power_dim.visible = false
	_power_panel.visible = false


func _on_power_dim_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_on_power_close()


func _on_power_buy(id: String) -> void:
	if MetaManager.buy(id):
		SoundManager.play_ui("gold", 0.03, 1.25)
	_refresh_power()


# ── 캐릭터 선택 오버레이 ─────────────────────────────────────────────
func _build_character_panel() -> void:
	_char_dim = ColorRect.new()
	_char_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_char_dim.color = Color(0, 0, 0, 0.6)
	_char_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_char_dim.visible = false
	_char_dim.gui_input.connect(_on_char_dim_input)
	add_child(_char_dim)

	_char_panel = PanelContainer.new()
	_char_panel.anchor_left = 0.5
	_char_panel.anchor_right = 0.5
	_char_panel.anchor_top = 0.5
	_char_panel.anchor_bottom = 0.5
	_char_panel.offset_left = -250.0
	_char_panel.offset_right = 250.0
	_char_panel.offset_top = -280.0
	_char_panel.offset_bottom = 280.0
	_char_panel.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.07, 0.13, 0.16, 0.98), Color(0.4, 0.8, 0.95)))
	_char_panel.visible = false
	add_child(_char_panel)

	var margin := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + m, 22)
	_char_panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "CHOOSE YOUR SURVIVOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	vb.add_child(title)

	_char_gold_label = Label.new()
	_char_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_gold_label.add_theme_font_size_override("font_size", 18)
	_char_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	vb.add_child(_char_gold_label)

	vb.add_child(HSeparator.new())

	_char_rows.clear()
	for c in GameData.characters:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(430, 92)
		btn.add_theme_font_size_override("font_size", 18)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_char_pick.bind(String(c.id)))
		vb.add_child(btn)
		_char_rows.append({"btn": btn, "c": c})

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 52)
	close.add_theme_font_size_override("font_size", 22)
	_UIStyle.apply_button_style(close, Color(0.18, 0.20, 0.26), Color(0.5, 0.55, 0.65))
	close.pressed.connect(_on_character_close)
	vb.add_child(close)


## 현재 선택 캐릭터를 메뉴 버튼에 표시.
func _refresh_char_button() -> void:
	var c := CharacterManager.selected()
	_char_btn.text = "Survivor: %s" % (c.display if c != null else "-")


## 오버레이 카드 갱신 — 선택/잠금/구매 상태를 반영.
func _refresh_character() -> void:
	if _char_gold_label:
		_char_gold_label.text = "Gold: %d" % MetaManager.meta_gold
	var sel := CharacterManager.selected_id()
	for row in _char_rows:
		var c: CharacterData = row["c"]
		var btn: Button = row["btn"]
		if CharacterManager.is_unlocked(c):
			btn.text = "%s%s\n%s" % ["> " if c.id == sel else "", c.display, c.desc]
			if c.id == sel:
				_UIStyle.apply_button_style(btn, Color(c.color.r * 0.30, c.color.g * 0.30, c.color.b * 0.30, 1.0), c.color)
			else:
				_UIStyle.apply_button_style(btn, Color(0.14, 0.16, 0.20), Color(0.35, 0.40, 0.48))
		else:
			btn.text = "[-] %s\n%s" % [c.display, _unlock_hint(c)]
			_UIStyle.apply_button_style(btn, Color(0.10, 0.10, 0.12), Color(0.30, 0.30, 0.34))


## 잠긴 캐릭터의 해금 조건 안내 문구.
func _unlock_hint(c: CharacterData) -> String:
	if c.unlock_cost > 0:
		return "Unlock: %d gold  (tap to buy)" % c.unlock_cost
	if c.unlock_achievement != "":
		var a: AchievementData = GameData.achievement(c.unlock_achievement)
		return "Locked — %s" % (a.desc if a != null else "complete an achievement")
	return "Locked"


func _on_char_pick(id: String) -> void:
	var c: CharacterData = GameData.character(id)
	if c == null:
		return
	if CharacterManager.is_unlocked(c):
		CharacterManager.select(id)
		SoundManager.play_ui("gold", 0.03, 1.2)
	elif c.unlock_cost > 0 and CharacterManager.try_buy(id):
		CharacterManager.select(id)   # 구매 성공 → 즉시 선택
		SoundManager.play_ui("gold", 0.02, 1.0)
	else:
		SoundManager.play_ui("player_hurt", 0.2, 1.0)   # 해금 불가(골드 부족/도전과제 미달)
	_refresh_character()
	_refresh_char_button()


func _on_character_pressed() -> void:
	_refresh_character()
	_char_dim.visible = true
	_char_panel.visible = true


func _on_character_close() -> void:
	_char_dim.visible = false
	_char_panel.visible = false


func _on_char_dim_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_on_character_close()


# ── 도전과제 오버레이 ─────────────────────────────────────────────────
func _build_achievement_panel() -> void:
	_ach_dim = ColorRect.new()
	_ach_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ach_dim.color = Color(0, 0, 0, 0.6)
	_ach_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_ach_dim.visible = false
	_ach_dim.gui_input.connect(_on_ach_dim_input)
	add_child(_ach_dim)

	_ach_panel = PanelContainer.new()
	_ach_panel.anchor_left = 0.5
	_ach_panel.anchor_right = 0.5
	_ach_panel.anchor_top = 0.5
	_ach_panel.anchor_bottom = 0.5
	_ach_panel.offset_left = -245.0
	_ach_panel.offset_right = 245.0
	_ach_panel.offset_top = -300.0
	_ach_panel.offset_bottom = 300.0
	_ach_panel.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.14, 0.11, 0.05, 0.98), Color(0.9, 0.75, 0.3)))
	_ach_panel.visible = false
	add_child(_ach_panel)

	var margin := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + m, 22)
	_ach_panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "ACHIEVEMENTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vb.add_child(title)

	vb.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	_ach_rows.clear()
	for a in GameData.achievements:
		var row := Label.new()
		row.custom_minimum_size = Vector2(420, 0)
		row.add_theme_font_size_override("font_size", 16)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(row)
		_ach_rows.append({"label": row, "a": a})

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 52)
	close.add_theme_font_size_override("font_size", 22)
	_UIStyle.apply_button_style(close, Color(0.18, 0.20, 0.26), Color(0.5, 0.55, 0.65))
	close.pressed.connect(_on_achievements_close)
	vb.add_child(close)


func _refresh_achievements() -> void:
	for row in _ach_rows:
		var a: AchievementData = row["a"]
		var lbl: Label = row["label"]
		var done := AchievementManager.is_unlocked(a.id)
		var prog := mini(AchievementManager.progress(a.metric), a.threshold)
		if done:
			lbl.text = "[*]  %s — %s" % [a.display, a.desc]
			lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55))
		else:
			lbl.text = "[ ]  %s — %s  (%d/%d)" % [a.display, a.desc, prog, a.threshold]
			lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78))


func _on_achievements_pressed() -> void:
	_refresh_achievements()
	_ach_dim.visible = true
	_ach_panel.visible = true


func _on_achievements_close() -> void:
	_ach_dim.visible = false
	_ach_panel.visible = false


# ── 끝없는 과제(Quests) 패널 — 현재 활성 과제 + 진행 + 다음 보상 표시 ──────────
func _build_quest_panel() -> void:
	_quest_dim = ColorRect.new()
	_quest_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_quest_dim.color = Color(0, 0, 0, 0.6)
	_quest_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_quest_dim.visible = false
	_quest_dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventScreenTouch and e.pressed or e is InputEventMouseButton and e.pressed:
			_on_quests_close())
	add_child(_quest_dim)

	_quest_panel = PanelContainer.new()
	_quest_panel.anchor_left = 0.5
	_quest_panel.anchor_right = 0.5
	_quest_panel.anchor_top = 0.5
	_quest_panel.anchor_bottom = 0.5
	_quest_panel.offset_left = -245.0
	_quest_panel.offset_right = 245.0
	_quest_panel.offset_top = -260.0
	_quest_panel.offset_bottom = 260.0
	_quest_panel.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.06, 0.14, 0.07, 0.98), Color(0.45, 0.9, 0.5)))
	_quest_panel.visible = false
	add_child(_quest_panel)

	var margin := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + m, 22)
	_quest_panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "QUESTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	vb.add_child(title)

	var hint := Label.new()
	hint.text = "완료 보상은 REWARDS 보관함에 쌓입니다 → 다음 과제 자동 생성(목표·보상 상승)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(440, 0)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.78, 0.72))
	vb.add_child(hint)

	vb.add_child(HSeparator.new())

	_quest_list = VBoxContainer.new()
	_quest_list.add_theme_constant_override("separation", 14)
	vb.add_child(_quest_list)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 52)
	close.add_theme_font_size_override("font_size", 22)
	_UIStyle.apply_button_style(close, Color(0.18, 0.20, 0.26), Color(0.5, 0.55, 0.65))
	close.pressed.connect(_on_quests_close)
	vb.add_child(close)


## ── 보상 보관함(REWARDS) — 유저가 직접 "CLAIM"을 눌러 수령 ─────────────────
func _build_rewards_panel() -> void:
	_rewards_dim = ColorRect.new()
	_rewards_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rewards_dim.color = Color(0, 0, 0, 0.6)
	_rewards_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_rewards_dim.visible = false
	_rewards_dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventScreenTouch and e.pressed or e is InputEventMouseButton and e.pressed:
			_on_rewards_close())
	add_child(_rewards_dim)

	_rewards_panel = PanelContainer.new()
	_rewards_panel.anchor_left = 0.5
	_rewards_panel.anchor_right = 0.5
	_rewards_panel.anchor_top = 0.5
	_rewards_panel.anchor_bottom = 0.5
	_rewards_panel.offset_left = -245.0
	_rewards_panel.offset_right = 245.0
	_rewards_panel.offset_top = -280.0
	_rewards_panel.offset_bottom = 280.0
	_rewards_panel.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.15, 0.11, 0.04, 0.98), Color(1.0, 0.85, 0.35)))
	_rewards_panel.visible = false
	add_child(_rewards_panel)

	var margin := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + m, 22)
	_rewards_panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "REWARDS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	vb.add_child(title)

	var hint := Label.new()
	hint.text = "퀘스트·도전과제 보상은 여기에 쌓입니다. CLAIM 을 눌러 메타 골드로 받으세요."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(440, 0)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.82, 0.76, 0.62))
	vb.add_child(hint)

	vb.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 260)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	_rewards_list = VBoxContainer.new()
	_rewards_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rewards_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_rewards_list)

	_rewards_total = Label.new()
	_rewards_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rewards_total.add_theme_font_size_override("font_size", 16)
	_rewards_total.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	vb.add_child(_rewards_total)

	var claim_all := Button.new()
	claim_all.text = "CLAIM ALL"
	claim_all.custom_minimum_size = Vector2(0, 54)
	claim_all.add_theme_font_size_override("font_size", 22)
	_UIStyle.apply_button_style(claim_all, Color(0.45, 0.32, 0.06), Color(1.0, 0.88, 0.4))
	claim_all.pressed.connect(_on_claim_all_pressed)
	vb.add_child(claim_all)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 48)
	close.add_theme_font_size_override("font_size", 20)
	_UIStyle.apply_button_style(close, Color(0.18, 0.20, 0.26), Color(0.5, 0.55, 0.65))
	close.pressed.connect(_on_rewards_close)
	vb.add_child(close)


## 대기 보상 개수를 버튼 라벨에 배지로 표시.
func _refresh_rewards_badge() -> void:
	if _rewards_btn == null:
		return
	var n: int = RewardInbox.count()
	_rewards_btn.text = "Rewards (%d)" % n if n > 0 else "Rewards"


func _refresh_rewards() -> void:
	for c in _rewards_list.get_children():
		c.queue_free()
	var entries: Array = RewardInbox.entries
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "받을 보상이 없습니다"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", Color(0.6, 0.58, 0.5))
		_rewards_list.add_child(empty)
		_rewards_total.text = ""
		return
	var total := 0
	for i in entries.size():
		var e: Dictionary = entries[i]
		total += int(e["gold"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var name_box := VBoxContainer.new()
		name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_box.add_theme_constant_override("separation", 1)
		var head := Label.new()
		head.text = String(e["title"])
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.add_theme_font_size_override("font_size", 16)
		head.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
		name_box.add_child(head)
		var sub := Label.new()
		sub.text = "%s   +%d gold" % ["Quest" if e["src"] == "quest" else "Achievement", int(e["gold"])]
		sub.add_theme_font_size_override("font_size", 13)
		sub.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		name_box.add_child(sub)
		row.add_child(name_box)

		var btn := Button.new()
		btn.text = "CLAIM"
		btn.custom_minimum_size = Vector2(96, 44)
		btn.add_theme_font_size_override("font_size", 16)
		_UIStyle.apply_button_style(btn, Color(0.14, 0.36, 0.16), Color(0.5, 0.95, 0.5))
		btn.pressed.connect(_on_claim_pressed.bind(i))
		row.add_child(btn)
		_rewards_list.add_child(row)
	_rewards_total.text = "Total waiting:  +%d gold" % total


func _on_claim_pressed(index: int) -> void:
	var got: int = RewardInbox.claim(index)
	if got > 0:
		SoundManager.play_ui("gold", 0.03, 1.25)
	_refresh_rewards()
	_refresh_meta_gold_labels()


func _on_claim_all_pressed() -> void:
	var got: int = RewardInbox.claim_all()
	if got > 0:
		SoundManager.play_ui("gold", 0.03, 1.1)
		SoundManager.play_ui("gold", 0.03, 1.4)
	_refresh_rewards()
	_refresh_meta_gold_labels()


## 파워업/캐릭터/테마 패널의 메타 골드 라벨을 갱신(열려 있지 않아도 안전).
func _refresh_meta_gold_labels() -> void:
	for lbl in [_power_gold_label, _char_gold_label, _theme_gold_label]:
		if lbl != null and lbl.text != "":
			lbl.text = "Gold: %d" % MetaManager.meta_gold


func _on_rewards_pressed() -> void:
	_refresh_rewards()
	_rewards_dim.visible = true
	_rewards_panel.visible = true


func _on_rewards_close() -> void:
	_rewards_dim.visible = false
	_rewards_panel.visible = false


## 활성 과제를 매번 새로 그린다(티어가 바뀌므로 재생성이 간단·정확).
func _refresh_quests() -> void:
	for c in _quest_list.get_children():
		c.queue_free()
	for q in QuestManager.active_quests():
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 3)

		var head := Label.new()
		head.text = "%s   +%d gold" % [q["title"], int(q["reward"])]
		head.add_theme_font_size_override("font_size", 18)
		head.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
		row.add_child(head)

		var desc := Label.new()
		desc.text = "%s   (%d / %d)" % [q["desc"], int(q["current"]), int(q["goal"])]
		desc.add_theme_font_size_override("font_size", 14)
		desc.add_theme_color_override("font_color", Color(0.78, 0.82, 0.78))
		row.add_child(desc)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(440, 12)
		bar.max_value = maxf(1.0, float(q["goal"]))
		bar.value = float(q["current"])
		bar.show_percentage = false
		row.add_child(bar)

		_quest_list.add_child(row)


func _on_quests_pressed() -> void:
	_refresh_quests()
	_quest_dim.visible = true
	_quest_panel.visible = true


func _on_quests_close() -> void:
	_quest_dim.visible = false
	_quest_panel.visible = false


func _on_ach_dim_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_on_achievements_close()


# ── 테마(아레나) 선택 오버레이 ────────────────────────────────────────
func _build_theme_panel() -> void:
	_theme_dim = ColorRect.new()
	_theme_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_theme_dim.color = Color(0, 0, 0, 0.6)
	_theme_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_theme_dim.visible = false
	_theme_dim.gui_input.connect(_on_theme_dim_input)
	add_child(_theme_dim)

	_theme_panel = PanelContainer.new()
	_theme_panel.anchor_left = 0.5
	_theme_panel.anchor_right = 0.5
	_theme_panel.anchor_top = 0.5
	_theme_panel.anchor_bottom = 0.5
	_theme_panel.offset_left = -250.0
	_theme_panel.offset_right = 250.0
	_theme_panel.offset_top = -280.0
	_theme_panel.offset_bottom = 280.0
	_theme_panel.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.08, 0.12, 0.08, 0.98), Color(0.5, 0.85, 0.5)))
	_theme_panel.visible = false
	add_child(_theme_panel)

	var margin := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + m, 22)
	_theme_panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "CHOOSE ARENA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	vb.add_child(title)

	_theme_gold_label = Label.new()
	_theme_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_theme_gold_label.add_theme_font_size_override("font_size", 18)
	_theme_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	vb.add_child(_theme_gold_label)

	vb.add_child(HSeparator.new())

	_theme_rows.clear()
	for t in GameData.themes:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(430, 84)
		btn.add_theme_font_size_override("font_size", 18)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_theme_pick.bind(String(t.id)))
		vb.add_child(btn)
		_theme_rows.append({"btn": btn, "t": t})

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 52)
	close.add_theme_font_size_override("font_size", 22)
	_UIStyle.apply_button_style(close, Color(0.18, 0.20, 0.26), Color(0.5, 0.55, 0.65))
	close.pressed.connect(_on_theme_close)
	vb.add_child(close)


func _refresh_theme_button() -> void:
	var t := ThemeManager.selected()
	_theme_btn.text = "Arena: %s" % (t.display if t != null else "-")


func _refresh_theme() -> void:
	if _theme_gold_label:
		_theme_gold_label.text = "Gold: %d" % MetaManager.meta_gold
	var sel := ThemeManager.selected_id()
	for row in _theme_rows:
		var t: ThemeData = row["t"]
		var btn: Button = row["btn"]
		if ThemeManager.is_unlocked(t):
			btn.text = "%s%s\n%s" % ["> " if t.id == sel else "", t.display, t.desc]
			if t.id == sel:
				_UIStyle.apply_button_style(btn, Color(t.tile_b.r, t.tile_b.g, t.tile_b.b, 1.0), t.mark)
			else:
				_UIStyle.apply_button_style(btn, Color(0.14, 0.16, 0.20), Color(0.35, 0.40, 0.48))
		else:
			btn.text = "[-] %s\n%s" % [t.display, _theme_unlock_hint(t)]
			_UIStyle.apply_button_style(btn, Color(0.10, 0.10, 0.12), Color(0.30, 0.30, 0.34))


func _theme_unlock_hint(t: ThemeData) -> String:
	if t.unlock_cost > 0:
		return "Unlock: %d gold  (tap to buy)" % t.unlock_cost
	if t.unlock_achievement != "":
		var a: AchievementData = GameData.achievement(t.unlock_achievement)
		return "Locked — %s" % (a.desc if a != null else "complete an achievement")
	return "Locked"


func _on_theme_pressed() -> void:
	_refresh_theme()
	_theme_dim.visible = true
	_theme_panel.visible = true


func _on_theme_close() -> void:
	_theme_dim.visible = false
	_theme_panel.visible = false


func _on_theme_dim_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_on_theme_close()


func _on_theme_pick(id: String) -> void:
	var t: ThemeData = null
	for row in _theme_rows:
		if row["t"].id == id:
			t = row["t"]
			break
	if t == null:
		return
	if ThemeManager.is_unlocked(t):
		ThemeManager.select(id)
		SoundManager.play_ui("gold", 0.03, 1.2)
	elif t.unlock_cost > 0 and ThemeManager.try_buy(id):
		ThemeManager.select(id)
		SoundManager.play_ui("gold", 0.02, 1.0)
	else:
		SoundManager.play_ui("player_hurt", 0.2, 1.0)
	_refresh_theme()
	_refresh_theme_button()


func _refresh_power() -> void:
	_power_gold_label.text = "Gold: %d" % MetaManager.meta_gold
	for row in _power_rows:
		var u: Dictionary = row["u"]
		var id: String = String(u["id"])
		var lv := MetaManager.level(id)
		var mx := int(u["max"])
		var btn: Button = row["btn"]
		if lv >= mx:
			btn.text = "%s  (MAX)\n%s" % [u["name"], u["desc"]]
			btn.disabled = true
		else:
			var c := MetaManager.cost(id)
			btn.text = "%s  (%d/%d)\n%s   -%d G" % [u["name"], lv, mx, u["desc"], c]
			btn.disabled = MetaManager.meta_gold < c


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


func _on_new_game_pressed() -> void:
	# 새 게임은 서사 인트로를 먼저 보여준 뒤(완료/건너뛰기 시) 실제로 시작한다.
	_IntroStory.play(self, _start_new_game)


func _start_new_game() -> void:
	SaveManager.delete_save()
	SaveManager.pending_continue = false
	Events.reset()
	Events.set_high_score(RankingManager.current_best())   # 이번 판 신기록 기준점(단일 모드)
	SceneFade.transition_to("res://scenes/Main.tscn")


func _on_continue_pressed() -> void:
	var data := SaveManager.load_save()
	if data.is_empty():
		return
	SaveManager.apply_to_events(data)
	SceneFade.transition_to("res://scenes/Main.tscn")
