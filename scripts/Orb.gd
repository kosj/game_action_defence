extends Node2D
## 공전 칼날: 플레이어를 중심으로 "적당한 고정 거리"에서 회전만 한다(맥동 확장 없음).
## 외형은 빠르게 자전하는 이중 칼날. 회전속도는 orb_speed 업그레이드로 빨라진다.

const ORBIT_RADIUS := 120.0   # 캐릭터로부터의 고정 공전 반경(적당한 거리)
const ORBIT_SPEED := 2.6      # 기본 공전 각속도(rad/s)
const ORB_SPEED_STEP := 0.35  # orb_speed 업그레이드 1레벨당 공전 각속도 +35%
const SPIN_SPEED := 15.0      # 칼날 자전 각속도(rad/s) — 공격적인 회전 느낌
const HIT_COOLDOWN := 0.6     # 같은 적 재타격 간격
const HIT_RADIUS := 28.0      # 피해 판정 반경(칼날 리치)

const BLADE_LEN := 24.0
const BLADE_W := 7.5

const _FXBurst := preload("res://scripts/FXBurst.gd")

var _orbit_angle: float = 0.0
var _spin: float = 0.0
var _timers: Dictionary = {}


## 여러 칼날을 각도만 균등 분산 — 모두 고정 반경에서 같은 속도로 캐릭터를 중심으로 회전한다.
func init_angle(a: float) -> void:
	_orbit_angle = a


func _physics_process(delta: float) -> void:
	# 회전속도 업그레이드(orb_speed) 반영 — 레벨당 +35%.
	var orbit_speed := ORBIT_SPEED * (1.0 + ORB_SPEED_STEP * Events.upgrade_orb_speed)
	_orbit_angle += orbit_speed * delta
	_spin += SPIN_SPEED * delta

	position = Vector2.from_angle(_orbit_angle) * ORBIT_RADIUS
	rotation = _spin

	# 재타격 쿨다운 감쇠
	for id in _timers.keys():
		_timers[id] -= delta
		if _timers[id] <= 0.0:
			_timers.erase(id)

	# 칼날 리치 안의 좀비에게 피해
	var dmg := 1 + Events.upgrade_orb_damage
	var r_sq := HIT_RADIUS * HIT_RADIUS
	for z in get_tree().get_nodes_in_group("zombies"):
		if not is_instance_valid(z):
			continue
		if global_position.distance_squared_to(z.global_position) < r_sq:
			var id := z.get_instance_id()
			if not _timers.has(id):
				z.take_damage(dmg)
				_timers[id] = HIT_COOLDOWN
				_spawn_hit_fx(z.global_position)

	queue_redraw()


func _draw() -> void:
	# 모션 잔상(휩쓰는 공격 영역) — 확장 시 더 크게 보이도록 리치 반경을 옅게 깐다.
	draw_circle(Vector2.ZERO, HIT_RADIUS, Color(0.70, 0.88, 1.0, 0.08))

	# 십자형 이중 칼날(자전으로 회전하는 표창/검 느낌). 금속 본체 + 능선 하이라이트.
	var tip := Vector2(BLADE_LEN, 0.0)
	var s1 := Vector2(BLADE_LEN * 0.28, -BLADE_W)
	var back := Vector2(-BLADE_LEN * 0.42, 0.0)
	var s2 := Vector2(BLADE_LEN * 0.28, BLADE_W)
	var steel := Color(0.85, 0.92, 1.0, 0.96)
	var steel_dim := Color(0.62, 0.74, 0.92, 0.92)
	var edge := Color(1.0, 1.0, 1.0, 0.95)

	# 가로 칼날
	draw_colored_polygon(PackedVector2Array([tip, s1, back, s2]), steel)
	draw_line(back, tip, edge, 1.6, true)
	draw_colored_polygon(PackedVector2Array([-tip, -s1, -back, -s2]), steel_dim)
	draw_line(-back, -tip, edge, 1.4, true)
	# 세로 칼날(직교) — 회전 시 십자 칼날처럼 보이게
	var tipv := Vector2(0.0, BLADE_LEN)
	var v1 := Vector2(BLADE_W, BLADE_LEN * 0.28)
	var backv := Vector2(0.0, -BLADE_LEN * 0.42)
	var v2 := Vector2(-BLADE_W, BLADE_LEN * 0.28)
	draw_colored_polygon(PackedVector2Array([tipv, v1, backv, v2]), steel_dim)
	draw_colored_polygon(PackedVector2Array([-tipv, -v1, -backv, -v2]), steel_dim)

	# 중심 허브
	draw_circle(Vector2.ZERO, 4.5, Color(0.95, 0.97, 1.0, 1.0))
	draw_circle(Vector2.ZERO, 2.0, Color(0.45, 0.6, 0.85, 1.0))


func _spawn_hit_fx(world_pos: Vector2) -> void:
	_FXBurst.spawn(get_tree().current_scene, world_pos, Color(0.75, 0.9, 1.0), 20.0, 0.20)
