extends Node

var world: SuburbWorld
var center := Vector2.INF
var transferring := false
var _notice: HUDTimedNotice
var _layer: CanvasLayer
var _clock := 0.0
var _marker: Node2D

func _ready() -> void:
	world = get_tree().get_first_node_in_group("suburb_world")
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	_notice = HUDTimedNotice.new()
	_notice.boss = true
	_layer.add_child(_notice)
	_marker = Node2D.new()
	_marker.z_index = -1
	world.add_child(_marker)
	_marker.draw.connect(func() -> void:
		_marker.draw_arc(Vector2.ZERO,250,0,TAU,64,Color(0.25,0.8,1,0.75),4)
		_marker.draw_circle(Vector2.ZERO,20,Color(0.25,0.8,1,0.5)))
	_marker.hide()
	Events.player_died.connect(func() -> void:
		center = Vector2.INF
		_notice.clear()
		_marker.hide()
		world.destination = Vector2.INF)

func guide(player: Node2D, remaining: float) -> void:
	if transferring:
		return
	if center == Vector2.INF:
		center = world.nearest_arena(player.global_position)
	world.destination = center
	world.ensure_chunk(SuburbLayout.cell(center))
	_clock -= get_process_delta_time()
	if _clock>0:
		return
	_clock = 0.15
	var direction := world.direction(player.global_position,center)
	var arrived := player.global_position.distance_to(center)<250
	var message := Locale.t("suburb_boss_ready") if arrived else Locale.t("suburb_boss_move") % int(player.global_position.distance_to(center)/80)
	_notice.update_notice(message,("%ds" % maxi(0,ceili(remaining))) if arrived else Locale.t("suburb_transfer") % maxi(0,ceili(remaining)),remaining,arrived,direction.angle())
	_marker.global_position = center
	_marker.show()


func enter(player: Node2D) -> void:
	transferring = true
	_notice.clear()
	_marker.hide()
	if center == Vector2.INF:
		center = world.nearest_arena(player.global_position)
	world.ensure_chunk(SuburbLayout.cell(center))
	if player.global_position.distance_to(center)>250:
		var fade := ColorRect.new()
		fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		fade.color = Color(0,0,0,0)
		_layer.add_child(fade)
		Events.pause_push(self,"suburb_transfer")
		var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(fade,"color:a",1.0,0.2)
		await tw.finished
		for z in get_tree().get_nodes_in_group("zombies"):
			if not z.is_in_group("boss"):
				Pool.release(z)
		for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
			Pool.release(projectile)
		for hazard in get_tree().get_nodes_in_group("district_hazards"):
			hazard.queue_free()
		var index := 0
		for group in ["suburb_drops","item_pickups"]:
			for drop in get_tree().get_nodes_in_group(group):
				drop.global_position = center + Vector2.from_angle(index*2.4)*(75+index%5*10)
				index += 1
		player.global_position = center
		var camera := player.get_viewport().get_camera_2d()
		if camera != null:
			camera.reset_smoothing()
		player.set("_hurt_timer",maxf(float(player.get("_hurt_timer")),1.0))
		await get_tree().process_frame
		tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(fade,"color:a",0.0,0.2)
		await tw.finished
		fade.queue_free()
		Events.pause_pop(self)
	transferring = false

func finish() -> void:
	center = Vector2.INF
	world.destination = Vector2.INF
	_notice.clear()
	_marker.hide()

func _exit_tree() -> void:
	Events.pause_pop(self)
