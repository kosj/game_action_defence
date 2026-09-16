extends SceneTree
## Deterministic real-render captures; use an isolated APPDATA when running.
## --script res://tools/shot_tactical_ui.gd -- before|after ko|en|ja
var prefix := "after"
var lang := "ko"
var small := false
var states := false
var output := "res://output/tactical_ui/"

func _initialize() -> void:
	call_deferred("_run")

func _wait() -> void:
	for i in 100: await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _shot(tag: String) -> void:
	var path := output + prefix + "_" + lang + ("_small" if small else "") + "_" + tag + ".png"
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", ProjectSettings.globalize_path(path))

func _run() -> void:
	seed(42)
	for arg in OS.get_cmdline_user_args():
		if arg == "small": small = true
		if arg == "states": states = true
		if arg in ["before", "after"]: prefix = arg
		if arg.begins_with("prefix="): prefix = arg.trim_prefix("prefix=")
		if arg in ["ko", "en", "ja"]: lang = arg
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.content_scale_size = Vector2i(720,1280)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(360,640) if small else Vector2i(720,1280)
	root.get_node("Locale").current = lang
	root.get_node("SoundManager").set_enabled(false)
	var menu = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await _wait()
	_shot("lobby")
	menu.free()
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _wait()
	var ev := root.get_node("Events")
	ev.weapons = {"gun":3, "shotgun":2, "boomerang":4, "tesla":1, "garlic":2, "railgun":2}
	ev.passives = {"swift":3, "gunpowder":4, "armor":2, "magnet":3, "crit":2, "regen":1}
	ev.inventory_changed.emit()
	ev.gold_changed.emit(1240)
	ev.kills_changed.emit(386)
	ev.elapsed_time = 522.0
	ev.run_progress.emit(522.0,1800.0)
	ev.update_player_health(4,5)
	ev.level = 12
	ev.xp_changed.emit(65,100,12)
	await _wait()
	_shot("hud")
	if states:
		var hud = main.get_node("HUD")
		hud._on_player_health_changed(1,5)
		ev.boss_display_name = "PRIME MUTATION"
		hud._on_boss_spawned(100)
		for i in 30: await process_frame
		await RenderingServer.frame_post_draw
		_shot("boss_lowhp")
		hud._on_boss_died()
		hud._on_player_health_changed(4,5)
	ev.bonus_level()
	await _wait()
	_shot("levelup")
	if states:
		var panel = main.get_node("LevelUpPanel")
		panel._evo_mode = true
		panel._evo_rules = [{"base":"gun","into":"railgun"}]
		panel._refresh()
		await _wait()
		_shot("evolution")
	main.queue_free()
	await process_frame
	await process_frame
	quit()
