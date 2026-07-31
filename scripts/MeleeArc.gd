extends WeaponModule
## 못 박은 배트(근접 원호): 주기적으로 조준 방향으로 넓은 부채꼴을 휘둘러 그 안의 좀비를
## 한 번에 강타(강한 넉백). _data: fire_interval=휘두르기 주기, spread=원호 반각(rad),
## area_radius=사거리, proj_damage/dmg_per_level=피해, knockback=넉백 세기.

const SWING_DUR := 0.18   # 휘두르기 애니메이션(스윕) 지속

var _t: float = 0.0
var _swing_t: float = -1.0   # >=0 이면 스윙 연출 진행 중
var _aim: Vector2 = Vector2.RIGHT


func _reach() -> float:
	return _data.area_radius * (1.0 + 0.04 * float(_level() - 1))


func _physics_process(delta: float) -> void:
	if _data == null:
		return
	if _swing_t >= 0.0:
		_swing_t += delta
		if _swing_t >= SWING_DUR:
			_swing_t = -1.0
	_t += delta
	var interval: float = maxf(_data.fire_interval * 0.6, _data.fire_interval * pow(0.95, float(_level() - 1)))
	if _t >= interval:
		_t = 0.0
		_aim = _aim_dir(_reach())
		_swing()
		_swing_t = 0.0
	rotation = _aim.angle()
	queue_redraw()


func _swing() -> void:
	var lvl := _level()
	var dmg: int = _data.proj_damage + _data.dmg_per_level * (lvl - 1)
	var reach := _reach()
	var reach_sq := reach * reach
	var half := _data.spread
	for z in Events.live_zombies():
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		var to: Vector2 = z.global_position - global_position
		if to.length_squared() > reach_sq:
			continue
		if absf(to.angle_to(_aim)) <= half:
			z.take_damage(dmg)
			if z.has_method("apply_knockback"):
				z.apply_knockback(to.normalized(), _data.knockback)
	_FXBurst.spawn(get_tree().current_scene, global_position + _aim * reach * 0.6, _data.color, reach * 0.4, 0.14)


## 스윙 연출: 로컬 +X(=조준 방향) 기준으로 원호가 -half→+half 로 쓸고 지나가며 옅어진다.
func _draw() -> void:
	if _swing_t < 0.0:
		return
	var reach := _reach()
	var half := _data.spread
	var p := clampf(_swing_t / SWING_DUR, 0.0, 1.0)
	var fade := 1.0 - p
	# 칼끝 각도: -half 에서 +half 로 스윕
	var a := -half + 2.0 * half * p
	var tip := Vector2.from_angle(a) * reach
	draw_arc(Vector2.ZERO, reach, -half, -half + 2.0 * half * p, 20, Color(_data.color.r, _data.color.g, _data.color.b, 0.30 * fade), 4.0, true)
	draw_line(Vector2.ZERO, tip, Color(1.0, 1.0, 1.0, 0.6 * fade), 3.0, true)
	draw_circle(tip, 5.0, Color(_data.color.r, _data.color.g, _data.color.b, 0.7 * fade))
