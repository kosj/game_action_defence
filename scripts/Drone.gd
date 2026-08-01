extends WeaponModule
## 드론(추종 설치물): 플레이어를 공전하는 드론 편대가 각자 최근접 적을 자동 사격한다.
## 드론 수는 레벨로 늘어난다. _data: fire_interval=드론별 발사 간격, area_radius=공전 반경,
## proj_damage/dmg_per_level=탄 피해, proj_speed=탄속.

const BULLET := preload("res://scenes/Bullet.tscn")

const ORBIT_SPEED := 1.4    # 공전 각속도(rad/s)
const FIRE_RANGE := 420.0

var _orbit: float = 0.0
var _t: float = 0.0


func _count(lvl: int) -> int:
	var eng := CharacterManager.install_boost() > 1.0   # 엔지니어: 드론 +1, 상한 +1
	var extra := 1 if eng else 0
	return clampi(1 + int((lvl - 1) / 3) + extra, 1, 4 + extra)


func _physics_process(delta: float) -> void:
	if _data == null:
		return
	_orbit += delta * ORBIT_SPEED
	_t += delta
	if _t >= _data.fire_interval:
		_t = 0.0
		_fire_all()
	queue_redraw()


## 각 드론의 로컬 위치(플레이어 중심 공전).
func _positions() -> Array:
	var lvl := _level()
	var n := _count(lvl)
	var out: Array = []
	for i in range(n):
		var a := _orbit + TAU * float(i) / float(n)
		out.append(Vector2.from_angle(a) * _data.area_radius)
	return out


func _fire_all() -> void:
	var lvl := _level()
	var dmg: int = _data.proj_damage + _data.dmg_per_level * (lvl - 1) + Events.upgrade_bullet_damage
	for local_pos in _positions():
		var world: Vector2 = global_position + local_pos
		var target := _nearest_to(world, FIRE_RANGE)
		if target == null:
			continue
		var dir: Vector2 = (target.global_position - world).normalized()
		var b := Pool.acquire(BULLET, get_tree().current_scene)
		b.global_position = world
		b.direction = dir
		b.rotation = dir.angle() + PI / 2
		b.speed = _data.proj_speed
		b.damage = dmg
		b.is_crit = false
		b.scale = Vector2.ONE * 0.7
		b.trail_color = _data.color
		b.pierce = 0
		b.knockback = 0.0
		b.splash_radius = 0.0
		b.queue_redraw()


## 특정 지점(드론 위치) 기준 최근접 좀비.
func _nearest_to(from: Vector2, rng: float) -> Node2D:
	var nearest: Node2D = null
	var min_d := rng * rng
	for z in Events.live_zombies():
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		var d := from.distance_squared_to(z.global_position)
		if d < min_d:
			min_d = d
			nearest = z
	return nearest


func _draw() -> void:
	for p in _positions():
		draw_circle(p, 7.0, Color(_data.color.r, _data.color.g, _data.color.b, 0.95))
		draw_circle(p, 3.5, Color(1.0, 1.0, 1.0, 0.9))
		draw_arc(p, 10.0, 0.0, TAU, 12, Color(_data.color.r, _data.color.g, _data.color.b, 0.4), 1.5, true)
