extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var mobile := "--mobile-preview" in OS.get_cmdline_user_args()
	if mobile:
		root.content_scale_size = Vector2i(720, 1280)
		root.size = Vector2i(360, 640)
	var title: Node = load("res://scenes/TitleScreen.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await create_timer(1.0).timeout
	await _capture("mobile-title" if mobile else "desktop-title")
	title.queue_free()
	await process_frame
	var menu: Node = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await create_timer(1.2).timeout
	assert(not menu.has_method("_on_ranking_pressed"))
	assert(not menu.has_method("_on_copy_log_pressed"))
	await _capture("mobile-menu" if mobile else "desktop-menu")
	menu.call("_on_options_pressed")
	await create_timer(0.5).timeout
	var panel: Control = menu.get("_options_panel")
	assert(panel.get_global_rect().size.x <= 961)
	assert(root.get_visible_rect().encloses(panel.get_global_rect()))
	await _capture("mobile-options" if mobile else "desktop-options")
	menu.queue_free()
	await process_frame
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await create_timer(2.0).timeout
	await _capture("mobile-game" if mobile else "desktop-game")
	print("EDITION LAYOUT PASS: ", root.content_scale_size)
	game.queue_free()
	await process_frame
	await process_frame
	quit()

func _capture(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/validation/" + tag + ".png")

