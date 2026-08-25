extends Node2D
## 지속 장판(불바다 등): 지정 위치에 일정 시간 남아 반경 내 좀비에게 주기적으로 피해.
## 월드(current_scene)에 스폰되며 수명이 끝나면 자기 자신을 해제한다. 지면 효과라 유닛 아래에 깔린다.

const TICK := 0.5   # 이 간격마다 반경 내 전원에게 dps 피해

var radius: float = 80.0
var dps: int = 2
var color: Color = Color(1.0, 0.5, 0.15)
var _life: float = 3.0
var _t: float = 0.0
var _age: float = 0.0


func setup(pos: Vector2, r: float, damage: int, life: float, tint: Color) -> void:
	global_position = pos
	radius = r
	dps = damage
	_life = life
	color = tint


func _ready() -> void:
	z_index = -1   # 지면 위(좀비·플레이어 아래)


func _physics_process(delta: float) -> void:
	_age += delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	_t += delta
	if _t >= TICK:
		_t = 0.0
		var r_sq := radius * radius
		for z in Events.live_zombies():
			if is_instance_valid(z) and z.is_in_group("zombies") \
					and global_position.distance_squared_to(z.global_position) < r_sq:
				z.take_damage(dps)
	queue_redraw()


func _draw() -> void:
	# 수명 말기에 옅어지며 사라진다. 불규칙한 일렁임.
	var fade := clampf(_life / 0.6, 0.0, 1.0)
	var flick := 1.0 + 0.05 * sin(_age * 16.0)
	QuadDraw.disc(self, Vector2.ZERO, radius * flick, Color(color.r, color.g, color.b, 0.16 * fade))
	QuadDraw.disc(self, Vector2.ZERO, radius * 0.6 * flick, Color(color.r, min(1.0, color.g + 0.2), color.b, 0.20 * fade))
	QuadDraw.ring(self, Vector2.ZERO, radius * flick, Color(color.r, color.g, color.b, 0.35 * fade), 2.0, 40)
