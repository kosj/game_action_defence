extends Node2D
## 지속 장판(불바다 등): 지정 위치에 일정 시간 남아 반경 내 좀비에게 주기적으로 피해.
## 월드(current_scene)에 스폰되며 수명이 끝나면 자기 자신을 해제한다. 지면 효과라 유닛 아래에 깔린다.

const TICK := 0.5   # 이 간격마다 반경 내 전원에게 dps 피해
const _POOL_SHADER := preload("res://assets/shaders/fire_pool.gdshader")
const _SMOKE_TEX := preload("res://assets/atlas/fx_smoke.tres")

var radius: float = 80.0
var dps: int = 2
var color: Color = Color(1.0, 0.5, 0.15)
var _life: float = 3.0
var _t: float = 0.0
var _age: float = 0.0
var _pool: ColorRect
var _flames: CPUParticles2D
var _core_flames: CPUParticles2D
var _embers: CPUParticles2D
var _smoke: CPUParticles2D

static var _flame_texture: ImageTexture
static var _ember_texture: ImageTexture


func setup(pos: Vector2, r: float, damage: int, life: float, tint: Color) -> void:
	global_position = pos
	radius = r
	dps = damage
	_life = life
	color = tint
	for fx in [_pool, _flames, _core_flames, _embers, _smoke]:
		if is_instance_valid(fx):
			fx.queue_free()
	_create_fire()


func _create_fire() -> void:
	# 바닥 열기와 위로 솟는 불꽃을 분리한다. 예전의 큰 방사형 타원은 불꽃이 아니라
	# 흐릿한 조명처럼 보였으므로, 바닥은 절차 셰이더로 그을리고 입자는 뾰족한 실루엣을 쓴다.
	_pool = ColorRect.new()
	_pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pool.position = Vector2.ONE * -radius * 1.08
	_pool.size = Vector2.ONE * radius * 2.16
	# GroundHazard 자체가 z=-1이라 여기서 다시 -1을 주면 유효 z=-2가 된다. 그 값은
	# 도로·잔디 TileMapLayer와 같아 청크/위치의 정렬 순서에 따라 바닥 셰이더가 가려졌다.
	# 부모와 같은 z에 두고 부모의 테두리보다 먼저 그리면 지면 위·유닛 아래가 항상 유지된다.
	_pool.z_index = 0
	_pool.show_behind_parent = true
	var pool_mat := ShaderMaterial.new()
	pool_mat.shader = _POOL_SHADER
	pool_mat.set_shader_parameter("tint", color)
	_pool.material = pool_mat
	add_child(_pool)

	if _flame_texture == null:
		_flame_texture = _make_flame_texture()
	if _ember_texture == null:
		_ember_texture = _make_ember_texture()
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.10, 0.42, 0.76, 1.0])
	ramp.colors = PackedColorArray([Color(1, 0.72, 0.08, 0), Color(1, 0.72, 0.08, 0.9), Color(1, 0.30, 0.025, 0.9), Color(0.68, 0.045, 0.008, 0.62), Color(0.12, 0.008, 0.003, 0)])
	_flames = CPUParticles2D.new()
	_flames.amount = 30
	_flames.lifetime = 0.68
	_flames.randomness = 0.48
	_flames.preprocess = 0.55
	_flames.texture = _flame_texture
	_flames.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_flames.emission_sphere_radius = radius * 0.72
	_flames.direction = Vector2.UP
	_flames.spread = 34.0
	_flames.gravity = Vector2(0, -42)
	_flames.initial_velocity_min = 24.0
	_flames.initial_velocity_max = 54.0
	_flames.scale_amount_min = 0.48
	_flames.scale_amount_max = 0.94
	_flames.angle_min = -18.0
	_flames.angle_max = 18.0
	_flames.angular_velocity_min = -28.0
	_flames.angular_velocity_max = 28.0
	var flame_scale := Curve.new()
	flame_scale.add_point(Vector2(0.0, 0.42))
	flame_scale.add_point(Vector2(0.16, 1.0))
	flame_scale.add_point(Vector2(0.72, 0.62))
	flame_scale.add_point(Vector2(1.0, 0.08))
	_flames.scale_amount_curve = flame_scale
	_flames.color_ramp = ramp
	add_child(_flames)

	# 작은 속불꽃은 바깥의 붉은 불꽃보다 짧고 밝다. 하나의 흰 입자층을 겹칠 때 생기던
	# 과노출 덩어리 없이, 실제 불처럼 노랑 중심 → 주황 외곽의 온도 차가 읽힌다.
	_core_flames = _flames.duplicate() as CPUParticles2D
	_core_flames.amount = 18
	_core_flames.lifetime = 0.46
	_core_flames.preprocess = 0.4
	_core_flames.emission_sphere_radius = radius * 0.52
	_core_flames.initial_velocity_min = 18.0
	_core_flames.initial_velocity_max = 38.0
	_core_flames.scale_amount_min = 0.28
	_core_flames.scale_amount_max = 0.58
	_core_flames.gravity = Vector2(0, -34)
	var core_ramp := Gradient.new()
	core_ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.58, 1.0])
	core_ramp.colors = PackedColorArray([Color(1,1,0.62,0),Color(1,0.96,0.48,0.95),Color(1,0.55,0.06,0.82),Color(0.9,0.12,0.01,0)])
	_core_flames.color_ramp = core_ramp
	add_child(_core_flames)

	_embers = CPUParticles2D.new()
	_embers.amount = 24
	_embers.lifetime = 1.15
	_embers.randomness = 0.7
	_embers.texture = _ember_texture
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_embers.emission_sphere_radius = radius * 0.68
	_embers.direction = Vector2.UP
	_embers.spread = 52.0
	_embers.gravity = Vector2(7, -18)
	_embers.initial_velocity_min = 42.0
	_embers.initial_velocity_max = 88.0
	_embers.scale_amount_min = 0.65
	_embers.scale_amount_max = 1.35
	var ember_ramp := Gradient.new()
	ember_ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.7, 1.0])
	ember_ramp.colors = PackedColorArray([Color(1,0.9,0.35,0),Color(1,0.82,0.18,1),Color(1,0.24,0.02,0.8),Color(0.5,0.04,0.01,0)])
	_embers.color_ramp = ember_ramp
	add_child(_embers)

	_smoke = CPUParticles2D.new()
	_smoke.amount = 7
	_smoke.lifetime = 1.5
	_smoke.randomness = 0.75
	_smoke.preprocess = 0.6
	_smoke.texture = _SMOKE_TEX
	_smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = radius * 0.58
	_smoke.direction = Vector2.UP
	_smoke.spread = 38.0
	_smoke.gravity = Vector2(5, -8)
	_smoke.initial_velocity_min = 12.0
	_smoke.initial_velocity_max = 25.0
	_smoke.scale_amount_min = 0.075
	_smoke.scale_amount_max = 0.14
	_smoke.color = Color(0.16, 0.12, 0.11, 0.22)
	add_child(_smoke)


## 32×64 알파 마스크. 위로 갈수록 폭이 좁아지는 불꽃 혀라 원형 빛 입자와 구분된다.
func _make_flame_texture() -> ImageTexture:
	var image := Image.create(28, 60, false, Image.FORMAT_RGBA8)
	for y in 60:
		var v := float(y) / 59.0
		var half_width := lerpf(0.025, 0.43, pow(v, 0.68))
		# 밑동은 둥글게 닫고, 좌우에 작은 굴곡을 줘 촛불 타원처럼 보이지 않게 한다.
		half_width *= 1.0 - 0.34 * smoothstep(0.84, 1.0, v)
		half_width *= 0.90 + 0.10 * sin(v * 19.0)
		var bend := sin(v * 8.5) * 0.075 * (1.0 - v * 0.55)
		for x in 28:
			var u := absf(float(x) / 27.0 - 0.5 - bend)
			var edge := smoothstep(0.0, 0.075, half_width - u)
			var tip := smoothstep(0.0, 0.09, v)
			var base := 1.0 - smoothstep(0.91, 1.0, v)
			image.set_pixel(x, y, Color(1, 1, 1, edge * tip * base))
	return ImageTexture.create_from_image(image)


func _make_ember_texture() -> ImageTexture:
	var image := Image.create(4, 10, false, Image.FORMAT_RGBA8)
	for y in 10:
		var fade := sin(PI * float(y) / 9.0)
		for x in 4:
			var side := 1.0 - absf(float(x) - 1.5) / 2.0
			image.set_pixel(x, y, Color(1, 1, 1, clampf(fade * side * 1.5, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


func _ready() -> void:
	z_index = -1   # 지면 위(좀비·플레이어 아래)


func _physics_process(delta: float) -> void:
	_age += delta
	_life -= delta
	if is_instance_valid(_flames):
		_flames.emitting = _life > 0.65
		_core_flames.emitting = _life > 0.65
		_embers.emitting = _life > 0.65
		_smoke.emitting = _life > 0.85
		var opacity := clampf(_life / 0.6, 0.0, 1.0)
		_flames.modulate.a = opacity
		_core_flames.modulate.a = opacity
		_embers.modulate.a = opacity
		_smoke.modulate.a = opacity
		var pool_mat := _pool.material as ShaderMaterial
		pool_mat.set_shader_parameter("fade", opacity)
		pool_mat.set_shader_parameter("phase", _age)
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
	# 셰이더 바닥 아래에 얇은 잔열 테두리만 더한다. 큰 반투명 원은 불빛처럼 보여 제거했다.
	var fade := clampf(_life / 0.6, 0.0, 1.0) * clampf(_age / 0.16, 0.0, 1.0)
	var flick := 0.82 + 0.18 * sin(_age * 11.0)
	QuadDraw.ring(self, Vector2.ZERO, radius * (0.79 + 0.025 * flick),
		Color(1.0, 0.19 + 0.11 * flick, 0.015, 0.20 * fade), 2.0, 32)
