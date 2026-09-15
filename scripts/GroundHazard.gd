extends Node2D
## 지속 장판(불바다 등): 지정 위치에 일정 시간 남아 반경 내 좀비에게 주기적으로 피해.
## 월드(current_scene)에 스폰되며 수명이 끝나면 자기 자신을 해제한다. 지면 효과라 유닛 아래에 깔린다.

const TICK := 0.5   # 이 간격마다 반경 내 전원에게 dps 피해

var radius: float = 80.0
var dps: int = 2
var color: Color = Color(1.0, 0.5, 0.15)
var _life: float = 3.0
var _t: float = 0.0
var _age: float = 0.0
var _flames: CPUParticles2D
var _embers: CPUParticles2D


func setup(pos: Vector2, r: float, damage: int, life: float, tint: Color) -> void:
	global_position = pos
	radius = r
	dps = damage
	_life = life
	color = tint
	if is_instance_valid(_flames):
		_flames.queue_free()
		_embers.queue_free()
	_create_fire()


func _create_fire() -> void:
	# Native particles share a soft texture; fixed budgets keep overlapping pools bounded.
	var soft := Gradient.new()
	soft.set_color(0, Color.WHITE)
	soft.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = soft
	texture.width = 32
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 1.0])
	ramp.colors = PackedColorArray([Color(1, 0.9, 0.4, 0), Color(1, 0.85, 0.25, 0.95), Color(1, 0.25, 0.025, 0.8), Color(0.6, 0.06, 0.01, 0)])
	_flames = CPUParticles2D.new()
	_flames.amount = 64
	_flames.lifetime = 0.85
	_flames.preprocess = 0.25
	_flames.texture = texture
	_flames.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_flames.emission_sphere_radius = radius * 0.86
	_flames.direction = Vector2.UP
	_flames.spread = 16.0
	_flames.gravity = Vector2(0, -20)
	_flames.initial_velocity_min = 12.0
	_flames.initial_velocity_max = 35.0
	_flames.scale_amount_min = 0.45
	_flames.scale_amount_max = 0.95
	_flames.color_ramp = ramp
	add_child(_flames)
	_embers = CPUParticles2D.new()
	_embers.amount = 16
	_embers.lifetime = 0.7
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_embers.emission_sphere_radius = radius * 0.75
	_embers.direction = Vector2.UP
	_embers.spread = 28.0
	_embers.gravity = Vector2(10, -25)
	_embers.initial_velocity_min = 35.0
	_embers.initial_velocity_max = 65.0
	_embers.scale_amount_min = 1.0
	_embers.scale_amount_max = 2.0
	_embers.color_ramp = ramp
	add_child(_embers)


func _ready() -> void:
	z_index = -1   # 지면 위(좀비·플레이어 아래)


func _physics_process(delta: float) -> void:
	_age += delta
	_life -= delta
	if is_instance_valid(_flames):
		_flames.emitting = _life > 0.65
		_embers.emitting = _life > 0.65
		var opacity := clampf(_life / 0.6, 0.0, 1.0)
		_flames.modulate.a = opacity
		_embers.modulate.a = opacity
	if _life <= 0.0:
		queue_free()
		return
	_t += delta
	if _t >= TICK:
		_t = 0.0
		var r_sq := radius * radius
		for z in Events.live_zombies():
			if is_instance_valid(z) and z.is_in_group("zombies") \
					and global_position.distance_squared_to(z.global_position) < r_sq:
				z.take_damage(dps)
	queue_redraw()


func _draw() -> void:
	# 수명 말기에 옅어지며 사라진다. 불규칙한 일렁임.
	var fade := clampf(_life / 0.6, 0.0, 1.0) * clampf(_age / 0.16, 0.0, 1.0)
	var flick := 1.0 + 0.05 * sin(_age * 16.0)
	QuadDraw.disc(self, Vector2.ZERO, radius * flick, Color(color.r, color.g, color.b, 0.16 * fade))
	QuadDraw.disc(self, Vector2.ZERO, radius * 0.6 * flick, Color(color.r, min(1.0, color.g + 0.2), color.b, 0.20 * fade))
	# Scalloped hot patches break up the perfectly circular outline.
	for i in 13:
		var angle := float(i) * 2.39996
		var p := Vector2.from_angle(angle) * radius * sqrt(float(i) / 13.0) * 0.8
		var pulse := 0.8 + 0.2 * sin(_age * 9.0 + float(i) * 2.1)
		QuadDraw.disc(self, p, radius * 0.23 * pulse, Color(1, 0.23, 0.025, 0.2 * fade))
