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
var _diff_buttons: Array = []
var _lang_buttons: Array = []   # [{ "btn": Button, "lang": String }]


func _ready() -> void:
	_build_ui()
	_apply_language()
	Locale.language_changed.connect(_on_language_changed)


func _build_ui() -> void:
	# 그라데이션 배경 + 비네트로 단색 대비 깊이감 부여
	add_child(UITheme.make_gradient_bg(Color(0.10, 0.12, 0.16), Color(0.04, 0.05, 0.07)))
	var vig := UITheme.make_vignette()
	vig.modulate = Color(1, 1, 1, 0.55)
	add_child(vig)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	# 게임 타이틀(브랜드) — 번역하지 않는다.
	var title := Label.new()
	title.text = "DeadLine"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
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

	# ── 언어 선택 ──────────────────────────────────────────────────────────
	var lang_spacer := Control.new()
	lang_spacer.custom_minimum_size = Vector2(0, 14)
	box.add_child(lang_spacer)

	_lang_title = Label.new()
	_lang_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lang_title.add_theme_font_size_override("font_size", 16)
	_lang_title.add_theme_color_override("font_color", Color(0.70, 0.74, 0.82))
	box.add_child(_lang_title)

	var lang_row := HBoxContainer.new()
	lang_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lang_row.add_theme_constant_override("separation", 8)
	box.add_child(lang_row)
	_lang_buttons.clear()
	for lang in Locale.SUPPORTED:
		var lb := Button.new()
		lb.text = Locale.native_name(lang)   # 각 언어를 자기 이름으로 표시(English / 한국어 / 日本語)
		lb.custom_minimum_size = Vector2(92, 44)
		lb.add_theme_font_size_override("font_size", 17)
		lb.pressed.connect(_on_language_pressed.bind(lang))
		lang_row.add_child(lb)
		_lang_buttons.append({"btn": lb, "lang": lang})

	# ── 사운드 On/Off (옵션) ────────────────────────────────────────────────
	var snd_spacer := Control.new()
	snd_spacer.custom_minimum_size = Vector2(0, 12)
	box.add_child(snd_spacer)

	_sound_title = Label.new()
	_sound_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sound_title.add_theme_font_size_override("font_size", 16)
	_sound_title.add_theme_color_override("font_color", Color(0.70, 0.74, 0.82))
	box.add_child(_sound_title)

	var snd_row := HBoxContainer.new()
	snd_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(snd_row)
	_sound_btn = Button.new()
	_sound_btn.custom_minimum_size = Vector2(160, 46)
	_sound_btn.add_theme_font_size_override("font_size", 18)
	_sound_btn.pressed.connect(_on_sound_pressed)
	snd_row.add_child(_sound_btn)

	# 버전 표시(하단)
	var ver := Label.new()
	ver.text = Events.VERSION
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 14)
	ver.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65, 0.8))
	box.add_child(ver)


## 현재 언어로 모든 라벨/버튼 텍스트를 갱신하고 선택 강조를 다시 칠한다.
func _apply_language() -> void:
	_best_label.text = "%s: %d" % [Locale.t("menu_best"), Events.high_score]
	_diff_title.text = Locale.t("menu_difficulty")
	_new_game_btn.text = Locale.t("menu_new_game")
	_continue_btn.text = Locale.t("menu_continue")
	_lang_title.text = Locale.t("menu_language")
	_sound_title.text = Locale.t("menu_sound")
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
	_refresh_difficulty_buttons()


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
