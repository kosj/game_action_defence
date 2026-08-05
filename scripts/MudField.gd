extends Node2D
## 교외 기믹: 스프링클러 진창. 밟으면 이동속도가 크게 느려지는 존(피해 없음 — 방해 변주).
## 동선을 강제하고 좀비 사이에서 발이 묶이게 만든다. 지면 효과라 유닛 아래.

const RADIUS := 74.0
const SLOW := 0.5      # 안에 있을 때 이동속도 배수
const LIFE := 11.0

var _player: Node2D = null
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
	if is_instance_valid(_player) and _player.has_method("slow_this_frame") \
			and _player.global_position.distance_squared_to(global_position) < RADIUS * RADIUS:
		_player.slow_this_frame(SLOW)
	queue_redraw()


func _draw() -> void:
	var fade := clampf(_life / 1.0, 0.0, 1.0)
	draw_circle(Vector2.ZERO, RADIUS, Color(0.30, 0.22, 0.12, 0.32 * fade))
	draw_circle(Vector2.ZERO, RADIUS * 0.7, Color(0.24, 0.17, 0.08, 0.30 * fade))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color(0.4, 0.3, 0.16, 0.5 * fade), 2.0, true)
	for i in 4:   # 물웅덩이 반짝임
		var a := TAU * float(i) / 4.0 + _age * 0.4
		draw_circle(Vector2.from_angle(a) * RADIUS * 0.45, 4.0, Color(0.5, 0.6, 0.55, 0.25 * fade))
