extends CanvasLayer
## 메인 메뉴: 새로하기 / 이어하기. 이어하기는 로컬 저장 데이터가 있을 때만 활성화된다.

const _UIStyle := preload("res://scripts/UIStyle.gd")

var _continue_btn: Button
var _diff_buttons: Array = []


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.08, 0.10, 0.07, 1.0)
	add_child(bg)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var title := Label.new()
	title.text = "ACTION DEFENCE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	box.add_child(title)

	var best := Label.new()
	best.text = "Best Score: %d" % Events.high_score
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best.add_theme_font_size_override("font_size", 22)
	best.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	box.add_child(best)

	# 난이도 선택 (Easy / Normal / Hard) — 선택 즉시 디스크에 보존되며 New Game/Continue 모두에 적용.
	var diff_title := Label.new()
	diff_title.text = "Difficulty"
	diff_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_title.add_theme_font_size_override("font_size", 18)
	diff_title.add_theme_color_override("font_color", Color(0.75, 0.80, 0.90))
	box.add_child(diff_title)

	var diff_row := HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_row.add_theme_constant_override("separation", 10)
	box.add_child(diff_row)
	_diff_buttons.clear()
	for i in Events.DIFFICULTY_NAMES.size():
		var b := Button.new()
		b.text = Events.DIFFICULTY_NAMES[i]
		b.custom_minimum_size = Vector2(96, 50)
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(_on_difficulty_pressed.bind(i))
		diff_row.add_child(b)
		_diff_buttons.append(b)
	_refresh_difficulty_buttons()

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	box.add_child(spacer)

	var new_game_btn := Button.new()
	new_game_btn.text = "New Game"
	new_game_btn.custom_minimum_size = Vector2(300, 70)
	new_game_btn.add_theme_font_size_override("font_size", 26)
	_UIStyle.apply_button_style(new_game_btn, Color(0.14, 0.40, 0.20), Color(0.4, 0.85, 0.45))
	new_game_btn.pressed.connect(_on_new_game_pressed)
	box.add_child(new_game_btn)

	_continue_btn = Button.new()
	_continue_btn.text = "Continue"
	_continue_btn.custom_minimum_size = Vector2(300, 70)
	_continue_btn.add_theme_font_size_override("font_size", 26)
	_UIStyle.apply_button_style(_continue_btn, Color(0.16, 0.24, 0.42), Color(0.4, 0.6, 0.95))
	_continue_btn.disabled = not SaveManager.has_save()
	_continue_btn.pressed.connect(_on_continue_pressed)
	box.add_child(_continue_btn)


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
