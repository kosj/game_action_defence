extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	var profile: Node = root.get_node("BuildProfile")
	# Browser dimensions can change before Godot's Window size/signal catches up.
	root.size = Vector2i(1280,720)
	for extent in [Vector2i(390,844),Vector2i(844,390),Vector2i(390,844)]:
		profile.apply_browser_sample(extent,true)
		check(root.content_scale_size==(Vector2i(720,1280) if extent.y>extent.x else Vector2i(2272,1278)),"Browser rotation missed with stale engine size")
	profile.apply_browser_sample(Vector2i.ZERO,true)
	check(root.content_scale_size==Vector2i(720,1280),"Transient zero browser size changed orientation")
	profile.apply_browser_sample(Vector2i(390,844),false)
	check(root.content_scale_size==Vector2i(2272,1278),"Touch capability change missed")
	for extent in [Vector2i(390,844),Vector2i(360,800),Vector2i(768,1024),Vector2i(844,390),Vector2i(390,844)]:
		root.size = extent
		profile.apply_browser_layout(root,true)
		await process_frame
		await process_frame
		var portrait: bool = extent.y>extent.x
		check(root.content_scale_size==(Vector2i(720,1280) if portrait else Vector2i(2272,1278)),"Incorrect orientation layout")
		if portrait:
			var logical := root.get_visible_rect().size
			check(absf(logical.x/logical.y-float(extent.x)/extent.y)<0.003,"Portrait viewport has letterboxing")
	profile.apply_browser_layout(root,false)
	check(root.content_scale_size==Vector2i(2272,1278),"Desktop layout changed")
	profile.apply_browser_layout(root,true)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await create_timer(0.5).timeout
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://output/validation/mobile-web-full.png")
	print("MOBILE WEB failures=",failures)
	quit(failures)
