extends Node2D
## 공전 칼날: 플레이어를 중심으로 돌면서, 궤도 반경이 주기적으로 넓게 확장됐다가 다시
## 돌아오기를 반복한다(넓은 영역을 휩쓰는 공격 연출). 외형은 빠르게 자전하는 이중 칼날.

const ORBIT_MIN := 70.0     # 수축 시 궤도 반경
const ORBIT_MAX := 300.0    # 확장 시 궤도 반경(이전의 약 2배 — 훨씬 멀리 휩쓸고 복귀)
const PULSE_PERIOD := 2.6   # 한 번 확장→복귀에 걸리는 시간(초, 더 먼 거리라 약간 여유롭게)
const ORBIT_SPEED := 2.6    # 플레이어 주위를 도는 각속도(rad/s)
const SPIN_SPEED := 15.0    # 칼날 자전 각속도(rad/s) — 공격적인 회전 느낌
const HIT_COOLDOWN := 0.6   # 같은 적 재타격 간격
const HIT_RADIUS := 28.0    # 피해 판정 반경(칼날 리치)

const BLADE_LEN := 24.0
const BLADE_W := 7.5

const _FXBurst := preload("res://scripts/FXBurst.gd")

var _orbit_angle: float = 0.0
var _spin: float = 0.0
var _pulse_t: float = 0.0
var _timers: Dictionary = {}
## 공전 중심(플레이어). 오브는 Player 의 자식이 아니라 "씬의 자식"으로 붙고 매 프레임 이 노드를
## 따라다닌다 — Player 자식으로 붙였을 때 오브가 즉시 해제되던 문제를 우회(총알·번개FX 와 동일 패턴).
var host: Node2D = null


func _ready() -> void:
	# 물리 처리·그리기를 명시적으로 보장(어떤 상태에서 생성돼도 즉시 공전·렌더되도록).
	set_physics_process(true)
	z_index = 5   # 지면/좀비 위로 확실히 보이게
	queue_redraw()


## 여러 칼날을 각도만 균등 분산하고 확장 위상은 동기화 — 모두 같은 박자로 캐릭터를 중심으로
## 일정하게 멀어졌다 돌아오게 한다(깔끔한 맥동 링).
func init_angle(a: float) -> void:
	_orbit_angle = a
	_pulse_t = 0.0
	# 생성 즉시 궤도 위(중심 기준)에 배치 — 상점 정지 중에도 바로 보이게.
	if is_instance_valid(host):
		global_position = host.global_position + Vector2.from_angle(a) * ORBIT_MIN
	rotation = a
	queue_redraw()


func _physics_process(delta: float) -> void:
	# 중심(플레이어)이 사라졌으면 스스로 정리.
	if not is_instance_valid(host):
		queue_free()
		return
	_orbit_angle += ORBIT_SPEED * delta
	_spin += SPIN_SPEED * delta
	_pulse_t += delta

	# 0→1→0 으로 부드럽게 오갔다 돌아오는 확장 계수
	var pulse := 0.5 - 0.5 * cos(_pulse_t * TAU / PULSE_PERIOD)
	var radius := ORBIT_MIN + (ORBIT_MAX - ORBIT_MIN) * pulse
	# 씬의 자식이므로 전역 좌표로 플레이어를 중심에 둔다.
	global_position = host.global_position + Vector2.from_angle(_orbit_angle) * radius
	rotation = _spin

	# 재타격 쿨다운 감쇠
	for id in _timers.keys():
		_timers[id] -= delta
		if _timers[id] <= 0.0:
			_timers.erase(id)

	# 칼날 리치 안의 좀비에게 피해(확장 시 더 넓은 영역을 휩쓴다).
	# 좀비 목록은 프레임 공유 스냅샷(Events.live_zombies) — 오브 수만큼 그룹 스캔을 반복하지 않는다.
	var dmg := 1 + Events.upgrade_orb_damage
	var r_sq := HIT_RADIUS * HIT_RADIUS
	for z in Events.live_zombies():
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		if global_position.distance_squared_to(z.global_position) < r_sq:
			var id := z.get_instance_id()
			if not _timers.has(id):
				z.take_damage(dmg)
				_timers[id] = HIT_COOLDOWN
				_spawn_hit_fx(z.global_position)

	queue_redraw()


func _draw() -> void:
	# [임시 디버그] 오브가 "렌더되는지"를 육안으로 확실히 확인하기 위한 큰 마젠타 링.
	# draw_arc 는 총알에서도 쓰는 검증된 프리미티브라, 오브가 생성·배치돼 있으면 반드시 보인다.
	# → 이 링이 캐릭터 주위를 도는 게 보이면 "렌더는 정상, 칼날 모양만 안 보였던 것".
	#   링도 안 보이면 오브가 아예 생성/배치 안 된 것(HUD 의 DBG 숫자로 교차 확인).
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 28, Color(1.0, 0.15, 1.0, 0.95), 5.0)
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
