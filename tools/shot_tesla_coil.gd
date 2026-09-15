extends SceneTree
## 폭주 테슬라 코일의 충전/방전 판독성을 실제 게임 배경에서 캡처한다.


func _initialize() -> void:
	call_deferred("_run")


func _settle(frames: int) -> void:
	for i in frames:
		await process_frame
	RenderingServer.force_draw(false)


func _run() -> void:
	print("START: tesla coil render")
	root.content_scale_size = Vector2i(720, 1280)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(720, 1280)
	root.get_node("SoundManager").set_enabled(false)
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _settle(35)
	var player := get_first_node_in_group("player") as Node2D
	var tesla_script: GDScript = load("res://scripts/TeslaCoil.gd")
	var charging: Node2D = tesla_script.new()
	main.add_child(charging)
	charging.global_position = player.global_position + Vector2(-110.0, -125.0)
	charging.set("_age", 1.6)
	charging.set("_phase_t", 0.62)
	var firing: Node2D = tesla_script.new()
	main.add_child(firing)
	firing.global_position = player.global_position + Vector2(110.0, -125.0)
	firing.set("_age", 1.72)
	firing.set("_phase_t", 0.88)
	firing.set("_fired", true)
	firing.set("_arcs", [Vector2(-72.0, 54.0)])
	await _settle(3)
	var path := "res://output/validation/tesla_coil_polished.png"
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", ProjectSettings.globalize_path(path))
	print("PASS: tesla charging and discharge states rendered")
	quit()
