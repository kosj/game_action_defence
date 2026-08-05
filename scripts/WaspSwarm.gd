extends Node2D
## 교외 기믹: 말벌 떼. 플레이어를 느리게 추적하며 침 범위 안의 플레이어·좀비에게 지속 피해.
## 이동을 강요하는 압박형 위험 — 플레이어보다 느려 벗어날 수 있다(공정).

const SPEED := 82.0
const STING_R := 38.0
const TICK := 0.45
const PLAYER_DMG := 1
const ZOMBIE_DMG := 3
const LIFE := 9.0

var _player: Node2D = null
var _age: float = 0.0
var _life: float = LIFE
var _t: float = 0.0


func _ready() -> void:
	z_index = 1   # 유닛 위를 떠다니는 벌레 떼
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	_age += delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if is_instance_valid(_player):
		var to: Vector2 = _player.global_position - global_position
		if to.length() > 1.0:
			global_position += to.normalized() * SPEED * delta
	_t += delta
	if _t >= TICK:
		_t = 0.0
		var r_sq := STING_R * STING_R
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
	draw_circle(Vector2.ZERO, STING_R, Color(0.6, 0.55, 0.1, 0.10 * fade))   # 옅은 경고 아우라
	for i in 9:   # 윙윙대는 말벌 점들
		var a := _age * 6.0 + TAU * float(i) / 9.0
		var rr := STING_R * (0.35 + 0.5 * absf(sin(_age * 3.0 + float(i) * 1.7)))
		var p := Vector2.from_angle(a) * rr
		draw_circle(p, 2.6, Color(0.15, 0.12, 0.05, fade))
		draw_circle(p + Vector2(0.6, -0.6), 1.3, Color(0.95, 0.82, 0.2, fade))
