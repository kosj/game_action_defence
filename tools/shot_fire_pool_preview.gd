@tool
extends SceneTree
## 필드 터렛의 실제 크기·그림자·방향 실루엣을 720x1280 렌더에서 확인한다.

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
	await _settle(45)
	var player := get_first_node_in_group("player") as Node2D
	var turret_script: GDScript = load("res://scripts/TurretUnit.gd")
	for entry in [[Vector2(-105, 65), Vector2.RIGHT], [Vector2(0, 105), Vector2.UP], [Vector2(105, 65), Vector2(-1, -1).normalized()]]:
		var turret: Node2D = turret_script.new()
		turret.setup(player.global_position + entry[0], 8, 700.0, 300.0, 20.0, Color(0.6, 0.75, 0.95))
		main.add_child(turret)
		turret.set("_aim", entry[1])
		turret.call("_update_sprite")
	var fire: Node2D = load("res://scripts/GroundHazard.gd").new()
	main.add_child(fire)
	fire.setup(player.global_position + Vector2(0, -125), 82.0, 2, 3.2, Color(1, 0.42, 0.1))
	await _settle(45)
	var path := "res://output/validation/fire_pool_turret.png"
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", ProjectSettings.globalize_path(path))
	quit()

