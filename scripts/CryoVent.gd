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
	if ph < TELEGRAPH:
		var p := ph / TELEGRAPH
		draw_arc(Vector2.ZERO, FROST_R, 0.0, TAU, 28, Color(0.6, 0.85, 1.0, 0.2 + 0.4 * p), 2.0, true)
	elif ph < TELEGRAPH + ACTIVE:
		var fade := 1.0 - (ph - TELEGRAPH) / ACTIVE
		draw_circle(Vector2.ZERO, FROST_R, Color(0.7, 0.9, 1.0, 0.18 * fade))
		for i in 6:   # 서리 결정 방사
			var a := TAU * float(i) / 6.0
			var d := Vector2.from_angle(a) * FROST_R * (0.5 + 0.4 * fade)
			draw_line(Vector2.ZERO, d, Color(0.8, 0.95, 1.0, 0.5 * fade), 2.0)
