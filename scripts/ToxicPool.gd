extends Node2D
## 연구소 기믹: 독가스/방사능 웅덩이. 일정 시간 지속되며 안에 들어온 좀비와 플레이어 모두에게 지속 피해.
## 지역 통제(zone denial) 요소 — 밟지 않도록 동선을 강요한다. 지면 효과라 유닛 아래에 깔린다.

const TICK := 0.7
const RADIUS := 66.0
const ZOMBIE_DMG := 4
const PLAYER_DMG := 1
const LIFE := 8.0

var _player: Node2D = null
var _t: float = 0.0
var _age: float = 0.0
var _life: float = LIFE
var _tick_flash: float = 0.0
var _player_inside: bool = false


func _ready() -> void:
	z_index = -1
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	_age += delta
	_life -= delta
	_tick_flash = maxf(0.0, _tick_flash - delta * 3.6)
	if _life <= 0.0:
		queue_free()
		return
	_t += delta
	if _t >= TICK:
		_t = 0.0
		var r_sq := RADIUS * RADIUS
		var touched := false
		for z in Events.live_zombies():
			if is_instance_valid(z) and z.is_in_group("zombies") \
					and global_position.distance_squared_to(z.global_position) < r_sq:
				z.take_damage(ZOMBIE_DMG)
				touched = true
		_player_inside = is_instance_valid(_player) \
			and _player.global_position.distance_squared_to(global_position) < r_sq
		if _player_inside and _player.has_method("take_hit"):
			_player.take_hit(PLAYER_DMG)
			touched = true
		if touched:
			_tick_flash = 1.0
	elif is_instance_valid(_player):
		_player_inside = _player.global_position.distance_squared_to(global_position) < RADIUS * RADIUS
	queue_redraw()


func _draw() -> void:
	var fade := clampf(_life / 1.0, 0.0, 1.0) * clampf(_age / 0.24, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_age * 5.5)
	var danger := 1.0 if _player_inside else 0.0
	# 완벽한 원 대신 서로 겹친 독성 슬러지 덩어리로 웅덩이의 물성을 만든다.
	QuadDraw.disc(self, Vector2(0, 4), RADIUS * 0.92,
		Color(0.055, 0.16, 0.055, 0.56 * fade))
	for i in 9:
		var a := TAU * float(i) / 9.0
		var lobe := Vector2.from_angle(a) * RADIUS * (0.48 + 0.05 * sin(float(i) * 3.1))
		var lobe_r := RADIUS * (0.30 + 0.045 * sin(float(i) * 2.3 + _age * 1.4))
		QuadDraw.disc(self, lobe, lobe_r,
			Color(0.20, 0.66 + 0.10 * pulse, 0.10, (0.19 + 0.08 * danger) * fade))
	QuadDraw.disc(self, Vector2.ZERO, RADIUS * 0.62,
		Color(0.36, 0.90, 0.13, (0.15 + 0.10 * _tick_flash) * fade))
	# 노랑-초록 구간 경계가 회전해 일반 장판이 아니라 피해야 할 독성 범위임을 알린다.
	QuadDraw.ring(self, Vector2.ZERO, RADIUS,
		Color(0.42, 1.0, 0.22, (0.52 + 0.26 * danger + 0.18 * _tick_flash) * fade), 3.0, 40)
	var sweep := _age * 0.55
	for i in 6:
		var sa := sweep + TAU * float(i) / 6.0
		QuadDraw.ring(self, Vector2.ZERO, RADIUS * 0.91,
			Color(0.86, 1.0, 0.18, (0.34 + 0.25 * pulse) * fade), 3.8, 7, sa, sa + 0.42)
	# 바닥에서 생성되어 위로 떠오르다 터지는 기포. 궤도를 도는 점보다 독 웅덩이로 읽힌다.
	for i in 8:
		var fi := float(i)
		var bt := fmod(_age * (0.42 + 0.025 * fi) + fi * 0.137, 1.0)
		var bx := sin(fi * 4.73) * RADIUS * 0.58 + sin(_age * 1.8 + fi) * 3.0
		var by := lerpf(RADIUS * 0.38, -RADIUS * 0.48, bt)
		var br := 2.0 + 4.5 * bt
		var ba := (1.0 - bt) * fade
		QuadDraw.disc(self, Vector2(bx, by), br,
			Color(0.56, 1.0, 0.20, 0.20 * ba))
		QuadDraw.ring(self, Vector2(bx, by), br,
			Color(0.78, 1.0, 0.36, 0.72 * ba), 1.4, 12)
		QuadDraw.disc(self, Vector2(bx - br * 0.28, by - br * 0.28), 1.1,
			Color(0.95, 1.0, 0.72, 0.82 * ba))
	# 독성 증기가 웅덩이 위로 피어올라 위험이 수직 공간에서도 보인다.
	for i in 4:
		var fi := float(i)
		var ft := fmod(_age * 0.28 + fi * 0.24, 1.0)
		var fp := Vector2(sin(_age * 1.7 + fi * 2.2) * RADIUS * 0.42,
			-RADIUS * (0.08 + 0.72 * ft))
		QuadDraw.disc(self, fp, 6.0 + 7.0 * ft,
			Color(0.30, 0.82, 0.12, 0.13 * (1.0 - ft) * fade))
