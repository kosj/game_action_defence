extends SceneTree

var failures := 0
func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func press(pos: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = pos
	root.push_input(event,true)

func drag(pos: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event,true)

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.get_node("Events").reset()
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(0.3).timeout
	var player: Node2D = get_first_node_in_group("player")
	player.set("_hurt_timer",1000.0)
	main.get_node("ZombieSpawner").set_process(false)
	var stick: Control = get_first_node_in_group("joystick")
	check(stick.get("_mouse_enabled") == (OS.has_feature("web") or root.get_node("BuildProfile").touch_controls()),"Wrong edition gate")
	stick.set("_mouse_enabled",true)
	var ui := CanvasLayer.new()
	ui.layer = 100
	main.add_child(ui)
	var button := Button.new()
	button.position = Vector2(100,500)
	button.size = Vector2(100,80)
	ui.add_child(button)
	await process_frame
	press(Vector2(140,540),true)
	drag(Vector2(260,540))
	check(not stick.get("_active"),"UI click started movement")
	press(Vector2(260,540),false)
	press(Vector2(400,500),true)
	drag(Vector2(550,500))
	check(stick.get_value().x>0.9,"Drag did not produce movement")
	var before := player.global_position
	for i in 12:
		await physics_frame
	check(player.global_position.x>before.x+15,"Mouse did not move player")
	Input.action_press("move_left")
	await physics_frame
	await physics_frame
	check(player.get("velocity").x<0,"Keyboard priority lost")
	Input.action_release("move_left")
	press(Vector2(140,540),false)
	check(stick.get_value()==Vector2.ZERO,"Release above UI did not stop")
	press(Vector2(400,500),true)
	drag(Vector2(550,500))
	paused = true
	await process_frame
	check(stick.get_value()==Vector2.ZERO,"Pause retained movement")
	paused = false
	press(Vector2(400,500),true)
	drag(Vector2(550,500))
	root.focus_exited.emit()
	check(stick.get_value()==Vector2.ZERO,"Focus loss retained movement")
	press(Vector2(400,500),true)
	drag(Vector2(550,500))
	root.mouse_exited.emit()
	check(stick.get_value()==Vector2.ZERO,"Leaving canvas retained movement")
	print("MOUSE MOVE failures=",failures)
	quit(failures)
