extends WeaponModule
## 체인소(근접 지속): 조준 방향 짧은 원호를 매우 빠르게 갈아, 근접한 좀비를 지속적으로 썬다.
## 못배트가 "한 방 스윙"이라면 체인소는 "밀착 그라인더"(짧은 사거리·초고연사·약넉백).
## _data: fire_interval=피해 틱 간격, spread=원호 반각, area_radius=사거리(짧게),
## proj_damage/dmg_per_level=틱 피해, knockback=약넉백.

var _t: float = 0.0
var _spin: float = 0.0
var _aim: Vector2 = Vector2.RIGHT


func _ready() -> void:
	z_index = -1   # 밀착 이펙트는 유닛 아래에 옅게 깔아 가독성 유지


func _reach() -> float:
	return _data.area_radius * (1.0 + 0.04 * float(_level() - 1))


func _physics_process(delta: float) -> void:
	if _data == null:
		return
	_spin += delta * 26.0
	_aim = _aim_dir(_reach())
	rotation = _aim.angle()
	_t += delta
	if _t >= _data.fire_interval:
		_t = 0.0
		_grind()
	queue_redraw()


func _grind() -> void:
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
			if _data.knockback > 0.0 and z.has_method("apply_knockback"):
				z.apply_knockback(to.normalized(), _data.knockback)


## 로컬 +X(조준 방향) 끝에서 회전하는 톱날 + 짧은 원호 그라인드 존.
func _draw() -> void:
	var reach := _reach()
	var half := _data.spread
	# 그라인드 존(짧은 부채꼴)
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var steps := 8
	for i in range(steps + 1):
		var a := -half + 2.0 * half * float(i) / float(steps)
		pts.append(Vector2.from_angle(a) * reach)
	draw_colored_polygon(pts, Color(0.85, 0.85, 0.90, 0.10))
	# 회전 톱날(원 끝쪽)
	var hub := Vector2(reach * 0.7, 0.0)
	var teeth := 8
	for i in range(teeth):
		var a := _spin + TAU * float(i) / float(teeth)
		var outer := hub + Vector2.from_angle(a) * 14.0
		var inner := hub + Vector2.from_angle(a) * 9.0
		draw_line(inner, outer, Color(0.95, 0.95, 1.0, 0.9), 2.0, true)
	draw_circle(hub, 9.0, Color(0.55, 0.58, 0.65, 0.95))
	draw_circle(hub, 4.0, Color(0.9, 0.9, 0.95, 1.0))
