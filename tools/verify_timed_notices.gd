extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.get_node("Events").reset()
	root.get_node("Locale").current = "ko"
	if "--mobile-preview" in OS.get_cmdline_user_args():
		root.size = Vector2i(360,640)
		root.content_scale_size = Vector2i(720,1280)
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(0.4).timeout
	var spawner: Node = main.get_node("ZombieSpawner")
	spawner.set_process(false)
	var guide: Node = spawner.get("_suburb")
	var player: Node2D = get_first_node_in_group("player")
	player.global_position = Vector2(800,600)
	guide.guide(player,15)
	var boss: Control = guide.get("_notice")
	root.get_node("Events").gold_magnet_changed.emit(true,10)
	root.get_node("Events").achievement_unlocked.emit("First Blood")
	main.get_node("HUD").call("_show_toast","MAX BUILD   +50 gold",Color.GOLD,0.0,"layout-test")
	var magnet: Control = main.get_node("HUD").get("_magnet_notice")
	await create_timer(0.5).timeout
	check(boss.visible and magnet.visible,"Missing live cards")
	check(not boss.get_global_rect().intersects(magnet.get_global_rect()),"Cards overlap")
	for card in [boss,magnet]:
		check(card.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Input blocked")
		check(root.get_visible_rect().encloses(card.get_global_rect()),"Card outside viewport")
	if "--mobile-preview" in OS.get_cmdline_user_args():
		var hud: Node = main.get_node("HUD")
		var milestone: Control = hud.get("_milestones").get("_card")
		var toast: Label = hud.get("_toasts").get("_active")[0]["node"]
		var notices: Array[Control] = [boss, milestone, magnet, toast]
		var focus := Rect2(root.get_visible_rect().size*0.5-Vector2(12,140),Vector2(24,280))
		for notice in notices:
			check(not focus.intersects(notice.get_global_rect()),"Portrait notice covers play center: "+notice.name)
			check(root.get_visible_rect().encloses(notice.get_global_rect()),"Portrait notice outside viewport: "+notice.name)
		for i in notices.size():
			for j in range(i+1,notices.size()):
				check(not notices[i].get_global_rect().intersects(notices[j].get_global_rect()),
					"Portrait notices overlap: %s / %s" % [notices[i].name,notices[j].name])
	var phase: float = magnet.get("_phase")
	root.get_node("Events").pause_push(magnet,"timed_notice_test")
	await create_timer(0.2,true).timeout
	check(is_equal_approx(phase,magnet.get("_phase")),"Animation ran while paused")
	root.get_node("Events").pause_pop(magnet)
	await capture("active")
	root.get_node("Events").gold_magnet_changed.emit(true,3)
	check(magnet.get("_accent").r>0.9,"Expiry not emphasized")
	root.get_node("Events").gold_magnet_changed.emit(false,0)
	root.get_node("Events").gold_magnet_changed.emit(true,20)
	await create_timer(0.5).timeout
	check(magnet.visible and magnet.active and magnet.duration==20,"Refresh during fade lost")
	player.global_position = guide.center
	guide.set("_clock",0)
	guide.guide(player,3)
	check(boss.arrived,"Arrival state missing")
	await capture("arrived")
	guide.finish()
	check(not boss.visible,"Finished guidance remains")
	root.get_node("Events").player_died.emit()
	check(not magnet.visible,"Death left buff card visible")
	print("TIMED NOTICES failures=",failures)
	quit(failures)
func capture(tag: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/validation/timed-"+tag+("-mobile" if "--mobile-preview" in OS.get_cmdline_user_args() else "")+".png")
