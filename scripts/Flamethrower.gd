extends WeaponModule
## 화염방사기: 조준 방향으로 부채꼴(콘) 지속 피해. 투사체 없이 매 틱마다 콘 안의 좀비를 태운다.
## _data: spread=콘 반각(rad), area_radius=콘 길이, proj_damage/dmg_per_level=틱 피해, fire_interval=틱 간격.

const _FXBurst2 := preload("res://scripts/FXBurst.gd")

var _t: float = 0.0
var _aim: Vector2 = Vector2.RIGHT
var _pulse: float = 0.0


func _ready() -> void:
	z_index = -1   # 지면 위(유닛 아래)에 깔리는 화염


func _length() -> float:
	return _data.area_radius * (1.0 + 0.05 * float(_level() - 1))


func _physics_process(delta: float) -> void:
	if _data == null:
		return
	_pulse += delta
	_aim = _aim_dir(_length())
	_t += delta
	var interval: float = maxf(_data.fire_interval * 0.6, _data.fire_interval * pow(0.96, float(_level() - 1)))
	if _t >= interval:
		_t = 0.0
		_burn()
	rotation = _aim.angle()
	queue_redraw()


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


## 콘은 로컬 +X(=조준 방향, rotation 으로 정렬) 기준으로 그린다.
func _draw() -> void:
	var reach := _length()
	var half := _data.spread
	var flick := 1.0 + 0.06 * sin(_pulse * 22.0)
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var steps := 10
	for i in range(steps + 1):
		var a := -half + (2.0 * half) * float(i) / float(steps)
		pts.append(Vector2.from_angle(a) * reach * flick)
	draw_colored_polygon(pts, Color(1.0, 0.55, 0.12, 0.16))
	# 안쪽 더 뜨거운 코어
	var pts2 := PackedVector2Array()
	pts2.append(Vector2.ZERO)
	for i in range(steps + 1):
		var a := -half * 0.6 + (1.2 * half) * float(i) / float(steps)
		pts2.append(Vector2.from_angle(a) * reach * 0.62 * flick)
	draw_colored_polygon(pts2, Color(1.0, 0.80, 0.30, 0.20))
