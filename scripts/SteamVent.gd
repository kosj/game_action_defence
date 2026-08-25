extends Node2D
## 도심 기믹: 파열된 증기관. 예고 후 스팀을 뿜어 범위 내 좀비·플레이어에게 피해 + 넉백. 주기 반복.
## 리듬을 읽고 피하는 지역 통제형 — 예고 링이 차오르면 분출 임박.

const _FXBurst := preload("res://scripts/FXBurst.gd")
const _SpriteFX := preload("res://scripts/SpriteFX.gd")
const _FX_SMOKE := preload("res://assets/atlas/fx_smoke.tres")

const TELEGRAPH := 1.0
const ACTIVE := 0.35
const COOLDOWN := 1.1
const BURST_R := 62.0
const ZOMBIE_DMG := 16
const PLAYER_DMG := 1
const KNOCKBACK := 260.0
const LIFE := 14.0

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
	if ph < TELEGRAPH:
		_fired = false
	elif ph < TELEGRAPH + ACTIVE and not _fired:
		_fired = true
		_burst()
	queue_redraw()


func _burst() -> void:
	var r_sq := BURST_R * BURST_R
	for z in Events.live_zombies():
		if is_instance_valid(z) and z.is_in_group("zombies") \
				and global_position.distance_squared_to(z.global_position) < r_sq:
			z.take_damage(ZOMBIE_DMG)
			if z.has_method("apply_knockback"):
				z.apply_knockback((z.global_position - global_position).normalized(), KNOCKBACK)
	if is_instance_valid(_player) and _player.global_position.distance_squared_to(global_position) < r_sq \
			and _player.has_method("take_hit"):
		_player.take_hit(PLAYER_DMG)
	var scn := get_tree().current_scene
	_SpriteFX.spawn(scn, global_position + Vector2(0.0, -BURST_R * 0.3), _FX_SMOKE, BURST_R * 1.8, 0.5, \
		Color(0.85, 0.88, 0.92, 1.0), 0.0, 0.4)
	_FXBurst.spawn(scn, global_position, Color(0.9, 0.95, 1.0), BURST_R, 0.3)
	Events.shake(4.0)
	SoundManager.play("boom", 0.05, 1.3)


## 정체가 읽히는 연출: 항상 보이는 금속 통풍구(맨홀) 베이스 + 대기 중 스멀거리는 증기,
## 분출 직전에는 위험 반경이 점점 차오르는 경고 링과 노란 점멸로 "곧 터진다"를 예고한다.
func _draw() -> void:
	var ph := fmod(_phase_t, TELEGRAPH + ACTIVE + COOLDOWN)
	# 금속 통풍구 베이스 — 어두운 원판 + 밝은 림 + 배기 슬릿 3줄(무엇인지 한눈에 보이게).
	QuadDraw.disc(self, Vector2.ZERO, 16.0, Color(0.16, 0.17, 0.20, 0.95))
	QuadDraw.ring(self, Vector2.ZERO, 16.0, Color(0.55, 0.58, 0.66, 0.9), 2.2, 20)
	for i in 3:
		var y := -6.0 + 6.0 * float(i)
		QuadDraw.segment(self, Vector2(-8, y), Vector2(8, y), Color(0.42, 0.45, 0.52, 0.9), 2.5)
	if ph < TELEGRAPH:
		# 경고: 위험 반경 링이 차오르고(호가 자라며 회전) 통풍구가 노랗게 점멸.
		var p := ph / TELEGRAPH
		var blink := 0.5 + 0.5 * sin(_age * 18.0)
		QuadDraw.ring(self, Vector2.ZERO, 16.0, Color(1.0, 0.85, 0.25, 0.4 + 0.5 * blink * p), 2.5, 20)
		QuadDraw.disc(self, Vector2.ZERO, BURST_R, Color(1.0, 0.9, 0.4, 0.05 + 0.09 * p))
		QuadDraw.ring(self, Vector2.ZERO, BURST_R, Color(0.85, 0.88, 0.95, 0.25 + 0.35 * p), 2.0, 32)
		var sweep := _age * 2.5
		QuadDraw.ring(self, Vector2.ZERO, BURST_R, Color(1.0, 0.85, 0.3, 0.55 + 0.3 * blink), 3.5, 32, sweep, sweep + TAU * p)
	elif ph < TELEGRAPH + ACTIVE:
		# 분출: 범위 전체가 증기로 번쩍 + 수직 증기 기둥.
		QuadDraw.disc(self, Vector2.ZERO, BURST_R, Color(0.9, 0.93, 0.98, 0.30))
		QuadDraw.ring(self, Vector2.ZERO, BURST_R, Color(1.0, 1.0, 1.0, 0.7), 3.0, 32)
		for i in 4:
			var fi := float(i)
			QuadDraw.disc(self, Vector2(sin(_age * 20.0 + fi * 2.1) * 7.0, -14.0 - fi * 16.0), 11.0 - fi * 1.8, Color(0.92, 0.95, 1.0, 0.5 - fi * 0.1))
	else:
		# 대기: 슬릿에서 스멀스멀 새어 나오는 작은 증기 — 살아있는 위험임을 계속 알린다.
		for i in 2:
			var fi := float(i)
			var t := fmod(_age * 0.9 + fi * 0.5, 1.0)
			QuadDraw.disc(self, Vector2(sin(_age * 3.0 + fi * 3.7) * 5.0, -10.0 - t * 22.0), 3.5 + t * 3.0, Color(0.85, 0.88, 0.94, 0.30 * (1.0 - t)))
