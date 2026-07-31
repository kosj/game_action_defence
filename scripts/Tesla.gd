extends WeaponModule
## 테슬라 코일(연쇄 번개): 주기적으로 최근접 적을 때리고, 근처 적들로 번개가 연쇄된다.
## _data: fire_interval=방전 주기, area_radius=첫 표적 사거리, proj_damage/dmg_per_level=타격당 피해.
## 연쇄 수는 레벨로 늘어난다.

const CHAIN_RANGE := 170.0   # 다음 연쇄 대상까지 허용 거리
const ARC_FADE := 0.14       # 아크 잔상 지속

var _t: float = 0.0
var _arc_t: float = 0.0
var _arcs: Array = []   # Array[Array[Vector2, Vector2]] — 월드 좌표 아크 구간


func _chain_count(lvl: int) -> int:
	return 2 + int(lvl / 2)


func _physics_process(delta: float) -> void:
	if _data == null:
		return
	_t += delta
	if _t >= _data.fire_interval:
		_t = 0.0
		_zap()
	if _arc_t > 0.0:
		_arc_t -= delta
		if _arc_t <= 0.0:
			_arcs.clear()
		queue_redraw()


func _zap() -> void:
	var lvl := _level()
	var first := _nearest_zombie(_data.area_radius * Events.area_mult())
	if first == null:
		return
	var dmg: int = _data.proj_damage + _data.dmg_per_level * (lvl - 1)
	var chain := _chain_count(lvl)
	var hit: Dictionary = {}
	var prev: Vector2 = global_position
	var cur: Node2D = first
	_arcs.clear()
	for _i in range(chain):
		if cur == null:
			break
		hit[cur.get_instance_id()] = true
		cur.take_damage(dmg)
		var cp: Vector2 = cur.global_position
		_arcs.append([prev, cp])
		_FXBurst.spawn(get_tree().current_scene, cp, _data.color, 22.0, 0.16)
		prev = cp
		cur = _next_chain(cp, hit)
	_arc_t = ARC_FADE
	SoundManager.play("laser", 0.1, 1.0)
	queue_redraw()


## 마지막 타격 지점 근처의, 아직 안 맞은 최근접 좀비.
func _next_chain(from: Vector2, hit: Dictionary) -> Node2D:
	var nearest: Node2D = null
	var chain_r := CHAIN_RANGE * Events.area_mult()
	var min_d := chain_r * chain_r
	for z in Events.live_zombies():
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		if hit.has(z.get_instance_id()):
			continue
		var d := from.distance_squared_to(z.global_position)
		if d < min_d:
			min_d = d
			nearest = z
	return nearest


func _draw() -> void:
	if _arc_t <= 0.0 or _arcs.is_empty():
		return
	var a := clampf(_arc_t / ARC_FADE, 0.0, 1.0)
	for seg in _arcs:
		# 월드 좌표 → 로컬(모듈은 플레이어 원점, 회전/스케일 없음).
		var p0: Vector2 = seg[0] - global_position
		var p1: Vector2 = seg[1] - global_position
		draw_line(p0, p1, Color(0.6, 0.88, 1.0, a * 0.5), 6.0, true)
		draw_line(p0, p1, Color(1.0, 1.0, 1.0, a), 2.5, true)
		draw_circle(p1, 5.0, Color(0.7, 0.9, 1.0, a * 0.8))
