extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1000, 600)
	root.content_scale_size = Vector2i(1000, 600)
	root.get_node("SoundManager").set_enabled(false)
	var stage := Node2D.new()
	root.add_child(stage)
	current_scene = stage
	var turrets: Array[Node2D] = []
	for i in 8:
		var turret: Node2D = load("res://scripts/TurretUnit.gd").new()
		turret.setup(Vector2(130 + (i % 4) * 245, 160 + (i / 4) * 270), 2, 700, 300, 20, Color.ORANGE)
		stage.add_child(turret)
		turret.set_physics_process(false)
		turret.set("_aim", Vector2.from_angle(i * PI / 4))
		turret.call("_update_sprite")
		turrets.append(turret)
	await create_timer(0.3).timeout
	for i in 8:
		var turret := turrets[i]
		turret.scale = Vector2.ONE * 2.8
		var target := Node2D.new()
		stage.add_child(target)
		target.global_position = turret.global_position + Vector2.from_angle(i * PI / 4) * 500
		for barrel in 2:
			turret.call("_fire", target)
			var layer: Node = root.get_node("Events").fx_layer()
			var bullet := layer.get_child(layer.get_child_count() - 1) as Node2D
			bullet.set_physics_process(false)
			assert(bullet.global_position.distance_to(turret.global_position) < 100)
			assert(bullet.direction.dot((target.global_position - bullet.global_position).normalized()) > 0.999)
			var marker := Polygon2D.new()
			marker.polygon = PackedVector2Array([Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)])
			marker.color = Color.CYAN
			stage.add_child(marker)
			marker.global_position = bullet.global_position
			bullet.hide()
			turret.get("_spr").position = Vector2.ZERO
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/validation/turret_muzzles.png")
	print("PASS: 8 directions, both barrels, transformed spawn and target trajectory")
	quit()
