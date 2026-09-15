extends SceneTree
## 터렛 선행 조준·유도 표적 고정·레벨 성장·고정 설치를 결정론적으로 검증한다.

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(label: String, ok: bool, detail: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + label + ("  " + detail if detail != "" else ""))
	if not ok:
		_failures += 1


func _closest_miss(origin: Vector2, aim: Vector2, target_start: Vector2,
		target_velocity: Vector2, shot_speed: float) -> float:
	var direction := (aim - origin).normalized()
	var closest := 1.0e20
	for i in 181:
		var t := float(i) / 180.0
		var shot := origin + direction * shot_speed * t
		var target := target_start + target_velocity * t
		closest = minf(closest, shot.distance_to(target))
	return closest


func _run() -> void:
	root.get_node("SoundManager").set_enabled(false)
	var stage := Node2D.new()
	root.add_child(stage)
	current_scene = stage

	var turret_script: GDScript = load("res://scripts/TurretUnit.gd")
	var turret: Node2D = turret_script.new()
	stage.add_child(turret)
	turret.set_physics_process(false)
	turret.set("bullet_speed", 700.0)
	turret.global_position = Vector2.ZERO
	var target := Node2D.new()
	stage.add_child(target)
	target.global_position = Vector2(260.0, -120.0)
	var target_velocity := Vector2(0.0, 420.0)
	var dt := 1.0 / 60.0
	turret.call("_track_target", target, dt)
	for i in 18:
		target.global_position += target_velocity * dt
		turret.call("_track_target", target, dt)
	var current := target.global_position
	var lead: Vector2 = turret.call("_lead_position", target, Vector2.ZERO)
	var direct_miss := _closest_miss(Vector2.ZERO, current, current, target_velocity, 700.0)
	var lead_miss := _closest_miss(Vector2.ZERO, lead, current, target_velocity, 700.0)
	_check("lead aim beats direct aim against 420 px/s target", lead_miss < 8.0 and direct_miss > 60.0,
		"direct=%.1f lead=%.1f" % [direct_miss, lead_miss])

	var bullet_script: GDScript = load("res://scripts/Bullet.gd")
	var bullet: Node2D = bullet_script.new()
	bullet.call("on_spawn")
	bullet.set("homing", 5.2)
	bullet.call("lock_homing_target", target)
	_check("guided round keeps turret-selected target", bullet.get("_target") == target)

	var module_script: GDScript = load("res://scripts/Turret.gd")
	var module: Node2D = module_script.new()
	stage.add_child(module)
	module.set_physics_process(false)
	module.call("setup", "turret")
	module.call("_deploy", 1)
	module.call("_deploy", 8)
	var deployed: Array = module.get("_turrets")
	var level_one: Node2D = deployed[0]
	var level_eight: Node2D = deployed[1]
	_check("base turret covers a full combat screen", float(level_one.get("range")) >= 380.0)
	_check("turret projectile speed grows with level",
		float(level_eight.get("bullet_speed")) > float(level_one.get("bullet_speed")))
	_check("turret range grows with level", float(level_eight.get("range")) > float(level_one.get("range")))
	_check("turret lifetime grows with level", float(level_eight.get("_life")) > float(level_one.get("_life")))

	var fixed_position := level_one.global_position
	for i in 3:
		await physics_frame
	_check("turret remains at its installed position", level_one.global_position.is_equal_approx(fixed_position))

	print("RESULT: failures=", _failures)
	quit(_failures)
