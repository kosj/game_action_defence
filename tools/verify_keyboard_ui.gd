extends SceneTree
## 레벨업 방향키/WASD/Enter 선택과 보물상자 Enter 단계 진행을 실제 입력 이벤트로 검증한다.

var _failures := 0
var _applied := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(label: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _press_key(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


func _mark_applied() -> void:
	_applied += 1


func _run() -> void:
	root.get_node("SoundManager").set_enabled(false)
	var events := root.get_node("Events")
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(12)

	var level_panel := main.get_node("LevelUpPanel")
	events.set("level", 2)
	events.emit_signal("level_up", 2)
	await _frames(4)
	var card_box: Node = level_panel.get("_card_box")
	var cards: Array[Node] = card_box.get_children()
	_check("level-up cards opened", cards.size() >= 2)
	if cards.size() >= 2:
		_check("first level-up card focused", root.gui_get_focus_owner() == cards[0])
		await _press_key(KEY_DOWN)
		_check("Down moves focus to next card", root.gui_get_focus_owner() == cards[1])
		await _press_key(KEY_UP)
		_check("Up moves focus to previous card", root.gui_get_focus_owner() == cards[0])
		await _press_key(KEY_S)
		_check("S moves focus to next card", root.gui_get_focus_owner() == cards[1])
		await _press_key(KEY_W)
		_check("W moves focus to previous card", root.gui_get_focus_owner() == cards[0])
		await _press_key(KEY_D)
		_check("D moves focus to next card", root.gui_get_focus_owner() == cards[1])
		await _press_key(KEY_A)
		_check("A moves focus to previous card", root.gui_get_focus_owner() == cards[0])
		await _press_key(KEY_ENTER)
		_check("Enter confirms focused level-up card", bool(level_panel.get("_confirming")))
	await create_timer(0.36, true, false, true).timeout

	var chest_script: GDScript = load("res://scripts/ChestRewardPanel.gd")
	var chest = chest_script.new()
	chest.call("_setup", {
		"rarity": 0,
		"texts": ["Keyboard reward"],
		"icons": [null],
		"kinds": ["gold"],
		"applies": [Callable(self, "_mark_applied")],
	})
	main.add_child(chest)
	await _frames(3)
	_check("chest starts in anticipation phase", int(chest.get("_phase")) == 0)
	await _press_key(KEY_ENTER)
	_check("Enter skips chest anticipation", int(chest.get("_phase")) == 1)
	await _press_key(KEY_ENTER)
	_check("Enter finishes chest card flips", not chest.call("_flips_pending"))
	await _press_key(KEY_ENTER)
	_check("Enter closes chest and applies reward once", not is_instance_valid(chest) and _applied == 1)

	print("RESULT: failures=", _failures)
	quit(_failures)
