extends Node2D
## 마늘 오라(무기): 플레이어를 둘러싼 반경 안의 좀비에게 주기적으로 지속 피해.
## Player 의 자식으로 항상 플레이어 위치에 있으며, 레벨(upgrade_garlic)로 반경·피해가 커진다.
## 지면 효과처럼 유닛 아래에 깔린다(z_index=-1).

const BASE_RADIUS := 92.0
const RADIUS_PER_LV := 13.0
const TICK := 0.5          # 이 간격마다 반경 내 전원에게 1회 피해

var _t: float = 0.0
var _pulse: float = 0.0


func _ready() -> void:
	z_index = -1   # 좀비·플레이어 아래(지면 위)에 그려지는 오라


func _radius() -> float:
	return BASE_RADIUS + RADIUS_PER_LV * float(maxi(1, Events.upgrade_garlic) - 1)


func _physics_process(delta: float) -> void:
	_pulse += delta
	_t += delta
	if _t >= TICK:
		_t = 0.0
		var lv := maxi(1, Events.upgrade_garlic)
		var dmg := 1 + int(lv / 2)
		var r := _radius()
		var r_sq := r * r
		for z in Events.live_zombies():
			if is_instance_valid(z) and z.is_in_group("zombies") \
					and global_position.distance_squared_to(z.global_position) < r_sq:
				z.take_damage(dmg)
	queue_redraw()


func _draw() -> void:
	var r := _radius()
	var breathe := 1.0 + 0.03 * sin(_pulse * 3.0)
	draw_circle(Vector2.ZERO, r * breathe, Color(0.62, 0.30, 0.92, 0.10))
	draw_arc(Vector2.ZERO, r * breathe, 0.0, TAU, 48, Color(0.72, 0.42, 1.0, 0.35), 2.0, true)
