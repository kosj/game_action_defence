extends Node2D
## Run this isolated scene headless. Selection/unlocks are changed only in memory.
const PLAYER = preload("res://scenes/Player.tscn")
const PROJECTILE = preload("res://scripts/ProjectileWeapon.gd")
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	call_deferred("verify")

func verify() -> void:
	var saved_id: String = CharacterManager._selected_id
	var saved_bought: Dictionary = CharacterManager._bought.duplicate()
	for id in ["hunter", "veteran", "engineer"]:
		CharacterManager._selected_id = id
		CharacterManager._bought[id] = true
		var p = PLAYER.instantiate()
		p.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(p)
		if id == "hunter":
			check(p._directional_walk, "hunter directional mode")
			check(p.body.texture.get_size() == Vector2(128, 1024), "idle texture dimensions")
			check(p.body.vframes == 8 and p.body.hframes == 1, "idle grid")
			var module = PROJECTILE.new()
			p.add_child(module)
			module.setup("crossbow")
			for d in range(8):
				var direction: Vector2 = p._WALK_DIRECTIONS[d].normalized()
				p.velocity = direction * 220.0
				p._update_facing()
				p._animate_walk(1.0)
				check(p._walk_direction == d, "direction row %d" % d)
				check(int(p.body.frame / 24) == d and p.body.vframes == 8, "walk atlas row %d" % d)
				check(p.body.scale.x > 0 and p.body.rotation == 0, "no double flip or procedural tilt")
				check(p.aim_direction().is_equal_approx(direction), "base aim %d" % d)
				check(module._aim_direction().is_equal_approx(direction), "crossbow aim %d" % d)
				var layer: Node = Events.fx_layer()
				var before_shot: int = layer.get_child_count()
				module._fire(1)
				var shot_count := 0
				for index in range(before_shot, layer.get_child_count()):
					var shot = layer.get_child(index)
					if shot.get_script() == load("res://scripts/Bullet.gd"):
						shot_count += 1
						check(shot.direction.is_equal_approx(direction), "actual bolt direction %d" % d)
						check(shot.global_position.is_equal_approx(p.muzzle_position()), "actual bolt origin %d" % d)
				check(shot_count > 0, "spawned bolt %d" % d)
				var muzzle_bob := 0.6875 * cos(4.0 * PI * float(p.body.frame % 24) / 24.0)
				var expected_muzzle: Vector2 = p.body.to_global(p._WALK_MUZZLES[d] + Vector2(0, muzzle_bob))
				check(p.muzzle_position().is_equal_approx(expected_muzzle), "muzzle transform %d" % d)
				var phase: float = p._walk_phase
				p.velocity = Vector2.ZERO
				p._update_facing()
				p._animate_walk(0.0)
				check(p.body.frame == d and p.body.hframes == 1, "stop preserves direction %d" % d)
				check(p._walk_phase == phase, "idle retains phase")
				p._animate_walk(1.0)
				check(p.body.hframes == 24 and not p._idle_shown, "resume restores grid")
			p._walk_phase = 0.0
			p._animate_walk(p._walk_cycle_distance * 0.5)
			check(p.body.frame % 24 == 12, "half cycle by distance")
			p._animate_walk(p._walk_cycle_distance * 0.5)
			check(p.body.frame % 24 == 0, "cycle wraps")
			check(absf(p.shadow.position.y - 35.88) < 0.01, "ground anchor preserved")
			check(p._sheet_tex.get_size() == Vector2(3072, 1024), "mobile atlas size")
		else:
			check(not p._directional_walk and p._run_frames == 0, "%s legacy mode" % id)
			p.velocity = Vector2(-220, 0)
			p._update_facing()
			p._animate_walk(1.0)
			check(p.body.scale.x < 0 and p.body.vframes == 1, "%s legacy flip" % id)
			check(p.aim_direction() == Vector2.LEFT, "%s legacy aim" % id)
		p.free()
	CharacterManager._selected_id = saved_id
	CharacterManager._bought = saved_bought
	for child in get_children():
		child.queue_free()
	Pool.clear()
	load("res://scripts/FXBurst.gd").reset_pool()
	for audio in SoundManager.get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
	await get_tree().create_timer(0.15).timeout
	print("DIRECTIONAL WALK: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	get_tree().quit(1 if failures else 0)
