extends Node2D
## 도심 기믹: 파열된 증기관. 예고 후 스팀을 뿜어 범위 내 좀비·플레이어에게 피해 + 넉백. 주기 반복.
## 리듬을 읽고 피하는 지역 통제형 — 예고 링이 차오르면 분출 임박.

const _FXBurst := preload("res://scripts/FXBurst.gd")
const _SpriteFX := preload("res://scripts/SpriteFX.gd")
const _FX_SMOKE := preload("res://assets/sprites/fx/fx_smoke.png")

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


func _draw() -> void:
	var ph := fmod(_phase_t, TELEGRAPH + ACTIVE + COOLDOWN)
	# 지면 균열
	draw_line(Vector2(-14, 4), Vector2(6, -3), Color(0.1, 0.1, 0.12, 0.9), 3.0)
	draw_line(Vector2(6, -3), Vector2(16, 6), Color(0.1, 0.1, 0.12, 0.9), 3.0)
	if ph < TELEGRAPH:
		var p := ph / TELEGRAPH
		draw_arc(Vector2.ZERO, BURST_R, 0.0, TAU, 28, Color(0.8, 0.85, 0.95, 0.2 + 0.4 * p), 2.0, true)
	elif ph < TELEGRAPH + ACTIVE:
		draw_circle(Vector2.ZERO, BURST_R, Color(0.9, 0.93, 0.98, 0.22))
