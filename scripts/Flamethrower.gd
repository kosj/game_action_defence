extends WeaponModule
## 화염방사기: 조준 방향으로 부채꼴(콘) 지속 피해. 투사체 없이 매 틱마다 콘 안의 좀비를 태운다.
## 시각은 CPUParticles2D 불꽃 분사로 표현(밝은 바닥 위에서도 잘 보인다). inferno(진화)도 같은 모듈.
## _data: spread=콘 반각(rad), area_radius=콘 길이, proj_damage/dmg_per_level=틱 피해, fire_interval=틱 간격.

var _t: float = 0.0
var _aim: Vector2 = Vector2.RIGHT
var _fire: CPUParticles2D
var _core: CPUParticles2D


func _ready() -> void:
	z_index = 1   # 불꽃은 바닥 위, 유닛과 비슷한 높이로 확실히 보이게
	_fire = _make_emitter(70, Color(1.0, 0.55, 0.12), 0.9)    # 주 불길(주황)
	_core = _make_emitter(40, Color(1.0, 0.92, 0.55), 0.55)   # 안쪽 뜨거운 코어(밝은 노랑)
	add_child(_fire)
	add_child(_core)


## 부드러운 원형 텍스처 + 불꽃 컬러램프를 가진 콘 분사 파티클(로컬 +X = 조준 방향, rotation 으로 정렬).
func _make_emitter(amount: int, tint: Color, scale: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _soft_tex()
	p.local_coords = false           # 방출된 불꽃은 월드에 남아 흘러 스트림처럼 보인다
	p.amount = amount
	p.lifetime = 0.42
	p.direction = Vector2(1, 0)
	p.gravity = Vector2.ZERO
	p.scale_amount_min = scale * 0.7
	p.scale_amount_max = scale * 1.15
	var sc := Curve.new()            # 방출 직후 커졌다가 식으며 작아짐
	sc.add_point(Vector2(0.0, 0.5)); sc.add_point(Vector2(0.25, 1.0)); sc.add_point(Vector2(1.0, 0.15))
	p.scale_amount_curve = sc
	var ramp := Gradient.new()       # 흰노랑 → 주황 → 붉게 → 소멸
	ramp.set_color(0, Color(tint.r, tint.g, tint.b, 0.0))
	ramp.set_color(1, Color(0.7, 0.15, 0.06, 0.0))
	ramp.add_point(0.12, Color(1.0, 0.95, 0.7, 0.9))
	ramp.add_point(0.45, Color(tint.r, tint.g, tint.b, 0.75))
	ramp.add_point(0.8, Color(0.85, 0.25, 0.08, 0.35))
	p.color_ramp = ramp
	p.emitting = true
	return p


func _soft_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 32
	gt.height = 32
	return gt


func _length() -> float:
	return _data.area_radius * (1.0 + 0.05 * float(_level() - 1)) * Events.area_mult()


func _physics_process(delta: float) -> void:
	if _data == null:
		return
	_aim = _aim_dir(_length())
	rotation = _aim.angle()
	_update_emitters()
	_t += delta
	var interval: float = maxf(_data.fire_interval * 0.6, _data.fire_interval * pow(0.96, float(_level() - 1)))
	if _t >= interval:
		_t = 0.0
		_burn()


## 콘 길이/반각을 파티클 속도·확산에 반영(사거리가 커지면 불길도 길어짐). 속도×수명 ≈ 사거리.
func _update_emitters() -> void:
	var reach := _length()
	var spread_deg := rad_to_deg(_data.spread)
	var v := reach / 0.42
	_fire.spread = spread_deg
	_fire.initial_velocity_min = v * 0.75
	_fire.initial_velocity_max = v * 1.15
	_core.spread = spread_deg * 0.6
	_core.initial_velocity_min = v * 0.6
	_core.initial_velocity_max = v * 0.9


func _burn() -> void:
	var lvl := _level()
	var dmg: int = _data.proj_damage + _data.dmg_per_level * (lvl - 1)
	var reach := _length()
	var reach_sq := reach * reach
	var half := _data.spread
	for z in Events.live_zombies():
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		var to: Vector2 = z.global_position - global_position
		if to.length_squared() > reach_sq:
			continue
		if absf(to.angle_to(_aim)) <= half:   # 콘(부채꼴) 안에 있는가
			z.take_damage(dmg)
