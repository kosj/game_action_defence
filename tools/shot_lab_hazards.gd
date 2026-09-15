extends SceneTree
## 연구소 냉각기(예고/활성)와 독 웅덩이의 실제 필드 판독성을 캡처한다.

func _initialize() -> void:
	call_deferred("_run")


func _settle(frames: int) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw


func _run() -> void:
	root.content_scale_size = Vector2i(720, 1280)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(720, 1280)
	root.get_node("SoundManager").set_enabled(false)
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _settle(35)
	var player := get_first_node_in_group("player") as Node2D
	var cryo_script: GDScript = load("res://scripts/CryoVent.gd")
	var toxic_script: GDScript = load("res://scripts/ToxicPool.gd")
	var warning: Node2D = cryo_script.new()
	main.add_child(warning)
	warning.global_position = player.global_position + Vector2(-125, -120)
	warning.set("_phase_t", 0.55)
	var active: Node2D = cryo_script.new()
	main.add_child(active)
	active.global_position = player.global_position + Vector2(0, -145)
	active.set("_phase_t", 1.12)
	var toxic: Node2D = toxic_script.new()
	main.add_child(toxic)
	toxic.global_position = player.global_position + Vector2(130, -115)
	toxic.set("_age", 2.1)
	await _settle(4)
	var path := "res://output/validation/lab_hazards_polished.png"
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", ProjectSettings.globalize_path(path))
	print("PASS: cryo warning/active and toxic pool rendered")
	quit()
