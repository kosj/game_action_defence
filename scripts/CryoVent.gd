extends Node2D
## 연구소 기믹: 냉각기 파열. 예고 후 냉기 파동을 뿜어 범위 내 플레이어를 얼려(이동속도 급감) + 소량 피해.
## 좀비도 피해. 주기 반복하는 슬로우 통제 존 — 활성 동안 안에 있으면 계속 느려진다.

const _FXBurst := preload("res://scripts/FXBurst.gd")

const TELEGRAPH := 0.9
const ACTIVE := 0.9
const COOLDOWN := 1.0
const FROST_R := 70.0
const SLOW := 0.45
const ZOMBIE_DMG := 6
const PLAYER_DMG := 1
const LIFE := 13.0

var _player: Node2D = null
var _age: float = 0.0
var _life: float = LIFE
var _phase_t: float = 0.0
var _fired: bool = false


func _ready() -> void:
	z_index = -1
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	_age += delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	_phase_t += delta
	var ph := fmod(_phase_t, TELEGRAPH + ACTIVE + COOLDOWN)
	if ph >= TELEGRAPH and ph < TELEGRAPH + ACTIVE:
		if not _fired:
			_fired = true
			_freeze_burst()
		if is_instance_valid(_player) and _player.has_method("slow_this_frame") \
				and _player.global_position.distance_squared_to(global_position) < FROST_R * FROST_R:
			_player.slow_this_frame(SLOW)
	elif ph < TELEGRAPH:
		_fired = false
	queue_redraw()


func _freeze_burst() -> void:
	var r_sq := FROST_R * FROST_R
	for z in Events.live_zombies():
		if is_instance_valid(z) and z.is_in_group("zombies") \
				and global_position.distance_squared_to(z.global_position) < r_sq:
			z.take_damage(ZOMBIE_DMG)
	if is_instance_valid(_player) and _player.global_position.distance_squared_to(global_position) < r_sq \
			and _player.has_method("take_hit"):
		_player.take_hit(PLAYER_DMG)
	_FXBurst.spawn(get_tree().current_scene, global_position, Color(0.6, 0.85, 1.0), FROST_R, 0.35)
	Events.shake(3.0)
	SoundManager.play("boom", 0.04, 1.5)


func _draw() -> void:
	var ph := fmod(_phase_t, TELEGRAPH + ACTIVE + COOLDOWN)
	# 파열된 냉각 장치 본체. 기존에는 범위 원과 6개 선만 떠 있어 정체를 알 수 없었다.
	# 금속 베이스와 청록 냉매 코어를 항상 남겨 "여기서 냉기가 분출된다"는 원인을 보여 준다.
	QuadDraw.disc(self, Vector2(0, 5), 20.0, Color(0.025, 0.055, 0.075, 0.62))
	QuadDraw.disc(self, Vector2.ZERO, 16.0, Color(0.16, 0.22, 0.27, 0.98))
	QuadDraw.ring(self, Vector2.ZERO, 16.0, Color(0.58, 0.72, 0.80, 0.95), 2.4, 24)
	for i in 4:
		var va := PI * 0.25 + TAU * float(i) / 4.0
		QuadDraw.segment(self, Vector2.from_angle(va) * 9.0,
			Vector2.from_angle(va) * 14.0, Color(0.45, 0.58, 0.65, 0.95), 3.5)
	var core_pulse := 0.75 + 0.25 * sin(_age * 9.0)
	QuadDraw.disc(self, Vector2.ZERO, 8.0 + core_pulse * 2.0,
		Color(0.18, 0.68, 0.88, 0.26 + 0.18 * core_pulse))
	QuadDraw.disc(self, Vector2.ZERO, 5.5, Color(0.65, 0.94, 1.0, 0.95))
	if ph < TELEGRAPH:
		var p := ph / TELEGRAPH
		# 분출 전: 위험 반경이 차오르고 세 구간의 회전 호가 수축해 임박함을 알린다.
		QuadDraw.disc(self, Vector2.ZERO, FROST_R * p,
			Color(0.38, 0.76, 1.0, 0.035 + 0.07 * p))
		QuadDraw.ring(self, Vector2.ZERO, FROST_R,
			Color(0.6, 0.85, 1.0, 0.30 + 0.45 * p), 2.5, 32)
		var sweep := _age * 2.8
		for i in 3:
			var a := sweep + TAU * float(i) / 3.0
			QuadDraw.ring(self, Vector2.ZERO, FROST_R * (1.12 - 0.12 * p),
				Color(0.78, 0.96, 1.0, 0.40 + 0.40 * p), 3.5, 10, a, a + 0.55)
	elif ph < TELEGRAPH + ACTIVE:
		var fade := 1.0 - (ph - TELEGRAPH) / ACTIVE
		QuadDraw.disc(self, Vector2.ZERO, FROST_R,
			Color(0.56, 0.86, 1.0, (0.18 + 0.10 * core_pulse) * fade))
		QuadDraw.ring(self, Vector2.ZERO, FROST_R,
			Color(0.82, 0.97, 1.0, 0.75 * fade), 3.2, 36)
		# 단순 별표 대신 가지가 달린 눈 결정을 그려 효과가 즉시 "결빙"으로 읽히게 한다.
		for i in 6:
			var a := TAU * float(i) / 6.0
			var dir := Vector2.from_angle(a)
			var tip := dir * FROST_R * (0.72 + 0.18 * fade)
			QuadDraw.segment(self, dir * 17.0, tip,
				Color(0.86, 0.98, 1.0, 0.74 * fade), 2.6)
			var joint := dir * FROST_R * 0.56
			var side_a := Vector2.from_angle(a + 0.62)
			var side_b := Vector2.from_angle(a - 0.62)
			QuadDraw.segment(self, joint, joint - side_a * 13.0,
				Color(0.78, 0.94, 1.0, 0.64 * fade), 2.0)
			QuadDraw.segment(self, joint, joint - side_b * 13.0,
				Color(0.78, 0.94, 1.0, 0.64 * fade), 2.0)
		# 얼음 파편이 바깥으로 밀려나며 분출 방향과 세기를 보강한다.
		for i in 8:
			var ia := TAU * float(i) / 8.0 + _age * 0.18
			var ip := Vector2.from_angle(ia) * FROST_R * (0.55 + 0.32 * fade)
			QuadDraw.disc(self, ip, 2.0 + 2.0 * fade,
				Color(0.82, 0.97, 1.0, 0.76 * fade))
	else:
		# 재충전 중에도 코어에서 새는 냉매 안개를 남겨 살아 있는 장치임을 보여 준다.
		for i in 3:
			var fi := float(i)
			var mist_t := fmod(_age * 0.75 + fi * 0.33, 1.0)
			QuadDraw.disc(self,
				Vector2(sin(_age * 2.2 + fi * 2.4) * 9.0, -11.0 - mist_t * 24.0),
				4.0 + mist_t * 3.0, Color(0.65, 0.90, 1.0, 0.26 * (1.0 - mist_t)))
