extends SceneTree
var failures := 0
var theme_id := "suburb"
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)
func _run() -> void:
	seed(42)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--theme="):
			theme_id = arg.trim_prefix("--theme=")
	check(theme_id in ["suburb","city","lab"],"Invalid test theme")
	root.get_node("ThemeManager")._bought[theme_id] = true
	root.get_node("ThemeManager")._selected_id = theme_id
	root.get_node("Events").reset()
	if "--mobile-preview" in OS.get_cmdline_user_args():
		root.content_scale_size = Vector2i(720,1280)
		root.size = Vector2i(360,640)
	var layout = load("res://scripts/SuburbLayout.gd")
	for seed_value in 100:
		var c := Vector2i(seed_value-50,seed_value%11-5)
		for i in layout.LOTS.size():
			var r: Rect2 = layout.footprint(c,i)
			var center: Vector2 = layout.center(c)
			var nearest := center.clamp(r.position,r.end)
			check(nearest.distance_to(center)>780,"Arena intersects house")
			check(not layout.inside(layout.safe(r.get_center())),"Unsafe spawn")
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(1.5).timeout
	var world: Node = get_first_node_in_group("suburb_world")
	check(world != null,"Missing world")
	check(main.get_node_or_null("PropField") == null,"Legacy props still active")
	check(main.get_node_or_null("Ground") == null,"Legacy ground still active")
	if theme_id != "suburb":
		check(world.get("_district") != null,"Missing district dressing")
		for texture in world.get("_district").buildings:
			check(texture != null and texture.get_width()<=512,"Missing or oversized building texture")
	# Native house collision and fade must agree with the player position.
	var house: Node2D = get_first_node_in_group("suburb_houses")
	var actor: Node2D = get_first_node_in_group("player")
	actor.global_position = house.global_position+Vector2(0,-250)
	house.set("_check",0.0)
	house.call("_process",0.2)
	check(house.get("_sprite").modulate.a<0.5,"Building did not fade over actor")
	actor.global_position = Vector2.ZERO
	if theme_id != "suburb":
		var hazards: Node = main.get_node("GimmickSpawner")
		actor.global_position = house.global_position+Vector2(0,140)
		for sample in 12:
			hazards.call("_spawn")
		for hazard in get_nodes_in_group("district_hazards"):
			check(not layout.inside(hazard.global_position,80),"Hazard spawned inside structure")
			hazard.queue_free()
		actor.global_position = Vector2.ZERO
	for variant in 4:
		check(world.call("_road_offset",-1280.0,variant)==0.0 and world.call("_road_offset",1280.0,variant)==0.0,"Disconnected street socket")
	var player: Node2D = get_first_node_in_group("player")
	player.global_position = Vector2(600,-700) if "--north-street" in OS.get_cmdline_user_args() else Vector2(600,700)
	await create_timer(0.3).timeout
	await capture("suburb-street")
	if "--block-preview" in OS.get_cmdline_user_args():
		main.get_node("HUD").hide()
		root.size = Vector2i(1400,1000)
		root.content_scale_size = Vector2i(3584,2560)
		player.global_position = Vector2.ZERO
		player.get_viewport().get_camera_2d().reset_smoothing()
		await create_timer(0.3).timeout
		await capture("suburb-block")
		quit()
		return
	if "--thumbnail" in OS.get_cmdline_user_args():
		main.get_node("HUD").hide()
		root.size = Vector2i(512,332)
		root.content_scale_size = Vector2i(1400,908)
		player.global_position = Vector2(780,1030)
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://output/validation/theme_"+theme_id+".png")
		quit()
		return
	var r: Rect2 = layout.footprint(Vector2i.ZERO,3)
	var a := r.get_center()+Vector2(-300,0)
	var b := r.get_center()+Vector2(300,0)
	var path := NavigationServer2D.map_get_path(root.world_2d.navigation_map,a,b,true)
	check(path.size()>2,"Navigation must route around house")
	check(not layout.inside(world.motion(a,b)),"Swept motion penetrated house")
	var spawner := main.get_node("ZombieSpawner")
	await verify_movers(world, main, spawner, layout)
	var guide: Node = spawner.get("_suburb")
	guide.guide(player,10)
	await create_timer(0.3).timeout
	await capture("suburb-guide")
	var expected: Vector2 = guide.center
	player.global_position = expected+Vector2(950,0)
	var drop: Node2D = root.get_node("Pool").acquire(load("res://scenes/Gold.tscn"),main)
	drop.global_position = player.global_position+Vector2(100,0)
	var hazard := Node2D.new()
	main.add_child(hazard)
	hazard.add_to_group("district_hazards")
	var xp: int = root.get_node("Events").xp
	await guide.enter(player)
	check(is_instance_valid(drop) and drop.global_position.distance_to(expected)<160,"Drop lost during transfer")
	check(root.get_node("Events").xp == xp,"Transfer granted XP")
	check(player.global_position.distance_to(expected)<1,"Transfer did not arrive")
	check(not paused,"Transfer left tree paused")
	check(not is_instance_valid(hazard),"Old hazard survived transfer")
	player.global_position = expected+Vector2(120,0)
	await guide.enter(player)
	check(player.global_position.distance_to(expected+Vector2(120,0))<1,"Early arrival should not teleport")
	spawner.call("_spawn_boss")
	await create_timer(0.8).timeout
	await capture("suburb-boss")
	var arena: Node2D = get_first_node_in_group("boss_arena")
	check(arena != null and arena.global_position == expected,"Wrong arena center")
	root.get_node("SaveManager").save_game(player)
	var saved: Dictionary = root.get_node("SaveManager").load_save()
	check(saved.suburb.encounter.active,"Active boss missing from save")
	arena.queue_free()
	for boss in get_nodes_in_group("boss"):
		boss.queue_free()
	spawner.set_process(false)
	for k in 12:
		player.global_position = Vector2(k*2560,0)
		await physics_frame
		await process_frame
	check(world.chunks.size()<=10,"Unbounded chunks")
	check(get_nodes_in_group("suburb_houses").size()<=80,"House nodes leaked across chunks")
	main.queue_free()
	await process_frame
	root.get_node("SaveManager").apply_to_events(saved)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(0.5).timeout
	spawner = main.get_node("ZombieSpawner")
	check(float(spawner.get("_next_boss_at"))-float(spawner.get("_elapsed"))<=15.0,"Continue skipped pending boss")
	var pause_owner := Node.new()
	main.add_child(pause_owner)
	var before: float = spawner.get("_elapsed")
	root.get_node("Events").pause_push(pause_owner,"suburb_test")
	await create_timer(0.15,true).timeout
	check(float(spawner.get("_elapsed"))==before,"Encounter clock advanced while paused")
	root.get_node("Events").pause_pop(pause_owner)
	root.get_node("Events").player_died.emit()
	check(spawner.get("_suburb").center == Vector2.INF,"Death did not cancel guidance")
	print("DISTRICT CHECK theme=",theme_id," failures=",failures)
	quit(failures)
func verify_movers(world: Node, main: Node, spawner: Node, layout: Script) -> void:
	var target := Node2D.new()
	main.add_child(target)
	target.global_position = Vector2(1300,940)
	for behavior in ["chase","weaver","spitter","bomber"]:
		var zombie: Node2D = root.get_node("Pool").acquire(load("res://scenes/Zombie.tscn"),main)
		zombie.call("setup",spawner.get("ZOMBIE_TYPES")[0])
		zombie.set_physics_process(false)
		zombie.set("player",target)
		zombie.set("_behavior",behavior)
		zombie.set("speed",500.0)
		zombie.set("_fire_timer",10000.0)
		zombie.global_position = Vector2(600,940)
		for step in 360:
			world.set("_budget",6)
			zombie.call("_physics_process",1.0/60.0)
			check(not layout.inside(zombie.global_position,0),behavior+" entered a house")
			if zombie.global_position.distance_to(target.global_position)<90:
				break
		check(zombie.global_position.distance_to(target.global_position)<280,behavior+" stuck at house corner: "+str(zombie.global_position))
		root.get_node("Pool").release(zombie)
		await process_frame
	target.queue_free()
	print("SUBURB MOVERS chase/weaver/spitter/bomber checked")

func capture(tag: String) -> void:
	if DisplayServer.get_name()=="headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/validation/"+tag.replace("suburb",theme_id)+("-mobile" if "--mobile-preview" in OS.get_cmdline_user_args() else "")+".png")
