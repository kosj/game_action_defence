extends Node2D
## 교외 기믹: 주유소 가스통. 좀비가 근접하거나 수명이 다하면 폭발해 넓은 범위 좀비에게 큰 피해 + 넉백.
## 플레이어도 폭심 근처면 약간 피해(양날). 필드 위험물이라 유인해 터뜨리면 강력한 처치 도구가 된다.

const _FXBurst := preload("res://scripts/FXBurst.gd")

const TRIGGER_R := 42.0
const EXPLODE_R := 130.0
const DAMAGE := 30           # 좀비 광역 피해(대폭발)
const PLAYER_R := 70.0       # 이 반경 안이면 플레이어도 피격
const PLAYER_DMG := 1
const KNOCKBACK := 320.0
const ARM_TIME := 0.6
const LIFE := 22.0

var _player: Node2D = null
var _t: float = 0.0
var _armed: float = 0.0
var _pulse: float = 0.0
var _done: bool = false


func _ready() -> void:
	z_index = -1
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if _done:
		return
	_pulse += delta
	_armed += delta
	_t += delta
	if _t >= LIFE:
		_explode()
		return
	if _armed >= ARM_TIME:
		var tr_sq := TRIGGER_R * TRIGGER_R
		for z in Events.live_zombies():
			if is_instance_valid(z) and z.is_in_group("zombies") \
					and global_position.distance_squared_to(z.global_position) < tr_sq:
				_explode()
				return
	queue_redraw()


func _explode() -> void:
	_done = true
	var r_sq := EXPLODE_R * EXPLODE_R
	for z in Events.live_zombies():
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		if global_position.distance_squared_to(z.global_position) < r_sq:
			z.take_damage(DAMAGE)
			if z.has_method("apply_knockback"):
				z.apply_knockback((z.global_position - global_position).normalized(), KNOCKBACK)
	if is_instance_valid(_player) and _player.global_position.distance_to(global_position) < PLAYER_R \
			and _player.has_method("take_hit"):
		_player.take_hit(PLAYER_DMG)
	_FXBurst.spawn(get_tree().current_scene, global_position, Color(1.0, 0.55, 0.15), EXPLODE_R, 0.4)
	Events.shake(8.0)
	SoundManager.play("boom", 0.05, 0.85)
	queue_free()


func _draw() -> void:
	# 빨간 가스통 + 무장 후 깜빡이는 경고. 위험물처럼 보이게.
	var blink := 0.5 + 0.5 * sin(_pulse * 6.0)
	draw_rect(Rect2(-8.0, -12.0, 16.0, 22.0), Color(0.75, 0.16, 0.10, 0.95))       # 통 몸통
	draw_rect(Rect2(-8.0, -12.0, 16.0, 5.0), Color(0.9, 0.25, 0.12, 0.95))          # 상단 캡
	draw_rect(Rect2(-3.0, -16.0, 6.0, 4.0), Color(0.3, 0.3, 0.32, 1.0))             # 노즐
	draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 20, Color(1.0, 0.5, 0.15, 0.3 + 0.4 * blink), 2.0, true)
	# 위험 표식
	draw_string(ThemeDB.fallback_font, Vector2(-4.0, 2.0), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(1, 1, 0.6, 0.9))
