extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.get_node("Events").reset()
	root.get_node("Locale").set("current", "ko")
	if "--mobile-preview" in OS.get_cmdline_user_args():
		root.size = Vector2i(360,640)
		root.content_scale_size = Vector2i(720,1280)
	root.get_node("CharacterManager")._bought["hunter"] = true
	root.get_node("CharacterManager")._selected_id = "hunter"
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(0.5).timeout
	main.get_node("ZombieSpawner").set_process(false)
	main.get_node("ZombieSpawner").set_physics_process(false)
	main.get_node("GimmickSpawner").set_process(false)
	for z in get_nodes_in_group("zombies"):
		root.get_node("Pool").release(z)
	var player: Node2D = get_first_node_in_group("player")
	player.global_position = Vector2(600,-700)
	player.set("velocity",Vector2(220,220))
	player.call("_update_facing")
	player.call("_animate_walk",15.0)
	var notice: Control = main.get_node("HUD").get("_milestones")
	check(notice != null,"Missing milestone UI")
	var gold_before: int = root.get_node("Events").total_gold
	root.get_node("Events").achievement_unlocked.emit("First Blood")
	root.get_node("Events").achievement_unlocked.emit("Survivor")
	root.get_node("Events").quest_completed.emit("Zombie Hunter IV",150)
	check(notice.current.title=="First Blood" and notice.pending.size()==2,"Completion overwritten or lost")
	check(notice.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Notification blocks controls")
	await create_timer(0.8).timeout
	var card: Control = notice.get("_card")
	check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(card.get_global_rect()),"Notice outside viewport")
	for field in ["_heading","_title","_detail"]:
		var label: Label = notice.get(field)
		check(card.get_global_rect().encloses(label.get_global_rect()),"Notice text outside card: "+field)
	var detail: Label = notice.get("_detail")
	check(detail.position.y+detail.size.y <= card.size.y-36.0,
		"Notice detail overlaps metal frame: detail_bottom=%s safe_bottom=%s" % [
			detail.position.y+detail.size.y, card.size.y-36.0])
	await capture("milestone-achievement")
	var before: float = notice.get("_progress")
	root.get_node("Events").pause_push(notice,"notice_test")
	await create_timer(0.2,true).timeout
	check(is_equal_approx(before,notice.get("_progress")),"Notice expired while paused")
	root.get_node("Events").pause_pop(notice)
	await create_timer(3.1).timeout
	check(notice.current.get("title")=="Survivor","Second achievement did not play")
	await create_timer(3.8).timeout
	check(notice.current.get("title")=="Zombie Hunter IV","Quest queue order incorrect")
	check(notice.get("_detail").text.contains("150"),"Quest reward missing")
	await capture("milestone-quest")
	check(root.get_node("Events").total_gold==gold_before,"Cosmetic notice granted gold")
	root.get_node("Events").player_died.emit()
	check(notice.pending.is_empty() and notice.current.is_empty() and not card.visible,"Death did not clear notice")
	print("MILESTONES failures=",failures)
	quit(failures)
func capture(tag: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/validation/"+tag+("-mobile" if "--mobile-preview" in OS.get_cmdline_user_args() else "")+".png")
