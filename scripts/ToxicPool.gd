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


func _ready() -> void:
	z_index = -1
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	_age += delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	_t += delta
	if _t >= TICK:
		_t = 0.0
		var r_sq := RADIUS * RADIUS
		for z in Events.live_zombies():
			if is_instance_valid(z) and z.is_in_group("zombies") \
					and global_position.distance_squared_to(z.global_position) < r_sq:
				z.take_damage(ZOMBIE_DMG)
		if is_instance_valid(_player) and _player.global_position.distance_squared_to(global_position) < r_sq \
				and _player.has_method("take_hit"):
			_player.take_hit(PLAYER_DMG)
	queue_redraw()


func _draw() -> void:
	var fade := clampf(_life / 1.0, 0.0, 1.0)
	var bubble := 1.0 + 0.04 * sin(_age * 4.0)
	QuadDraw.disc(self, Vector2.ZERO, RADIUS * bubble, Color(0.35, 0.85, 0.25, 0.16 * fade))
	QuadDraw.disc(self, Vector2.ZERO, RADIUS * 0.62 * bubble, Color(0.5, 1.0, 0.35, 0.14 * fade))
	QuadDraw.ring(self, Vector2.ZERO, RADIUS * bubble, Color(0.55, 1.0, 0.4, 0.4 * fade), 2.0, 36)
	# 보글대는 독 방울 몇 개.
	for i in 5:
		var a := _age * 1.5 + TAU * float(i) / 5.0
		var rr := RADIUS * (0.3 + 0.4 * absf(sin(_age + float(i))))
		QuadDraw.disc(self, Vector2.from_angle(a) * rr, 3.0, Color(0.6, 1.0, 0.4, 0.5 * fade))
