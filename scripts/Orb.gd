extends Node2D

const ORBIT_RADIUS := 90.0
const ORBIT_SPEED := 2.4   # rad/s
const HIT_COOLDOWN := 0.8  # per zombie
const HIT_RADIUS := 22.0   # distance to deal damage

const _FXBurst := preload("res://scripts/FXBurst.gd")

var _angle: float = 0.0
var _timers: Dictionary = {}

func init_angle(a: float) -> void:
	_angle = a

func _physics_process(delta: float) -> void:
	_angle += ORBIT_SPEED * delta
	position = Vector2.from_angle(_angle) * ORBIT_RADIUS

	# tick cooldowns
	for id in _timers.keys():
		_timers[id] -= delta
		if _timers[id] <= 0.0:
			_timers.erase(id)

	# damage nearby zombies
	var dmg := 1 + Events.upgrade_orb_damage
	for z in get_tree().get_nodes_in_group("zombies"):
		if not is_instance_valid(z):
			continue
		if global_position.distance_squared_to(z.global_position) < HIT_RADIUS * HIT_RADIUS:
			var id := z.get_instance_id()
			if not _timers.has(id):
				z.take_damage(dmg)
				_timers[id] = HIT_COOLDOWN
				_spawn_hit_fx(z.global_position)

	queue_redraw()

func _draw() -> void:
	# outer glow
	draw_circle(Vector2.ZERO, 20.0, Color(0.25, 0.65, 1.0, 0.18))
	# mid glow
	draw_circle(Vector2.ZERO, 13.0, Color(0.45, 0.82, 1.0, 0.45))
	# core
	draw_circle(Vector2.ZERO, 7.5, Color(0.75, 0.96, 1.0, 0.90))
	# bright center
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 1.0, 1.0, 1.0))

func _spawn_hit_fx(world_pos: Vector2) -> void:
	var fx := _FXBurst.new()
	fx.color = Color(0.45, 0.82, 1.0)
	fx.max_radius = 20.0
	fx.duration = 0.22
	get_tree().current_scene.add_child(fx)
	fx.global_position = world_pos
