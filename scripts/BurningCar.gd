extends Node2D
## 도심 기믹: 불타는 폐차. 좀비 근접·수명 종료 시 대폭발(가스통의 도심판, 더 큰 반경).
## 유인해 터뜨리면 강력한 처치 도구지만 플레이어도 폭심 근처면 피해(양날).

const _FXBurst := preload("res://scripts/FXBurst.gd")
const _SpriteFX := preload("res://scripts/SpriteFX.gd")
const _FX_EXPLOSION := preload("res://assets/atlas/fx_explosion.tres")
const _FX_SMOKE := preload("res://assets/atlas/fx_smoke.tres")

const TRIGGER_R := 52.0
const EXPLODE_R := 150.0
const DAMAGE := 34
const PLAYER_R := 78.0
const PLAYER_DMG := 1
const KNOCKBACK := 360.0
const ARM_TIME := 0.7
const LIFE := 20.0

var _player: Node2D = null
var _spr: Sprite2D
var _armed: float = 0.0
var _t: float = 0.0
var _pulse: float = 0.0
var _done: bool = false


func _ready() -> void:
	z_index = -1
	_player = get_tree().get_first_node_in_group("player")
	_spr = Sprite2D.new()
	_spr.texture = preload("res://assets/sprites/props/prop_wreck_car.png")
	_spr.scale = Vector2(0.34, 0.34)
	_spr.modulate = Color(0.7, 0.62, 0.6)
	add_child(_spr)


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
	var scn := get_tree().current_scene
	_SpriteFX.spawn(scn, global_position, _FX_EXPLOSION, EXPLODE_R * 2.0, 0.14, Color(1.0, 0.98, 0.9))
	_SpriteFX.spawn(scn, global_position, _FX_EXPLOSION, EXPLODE_R * 1.7, 0.4, Color(1.0, 0.6, 0.2))
	_SpriteFX.spawn(scn, global_position + Vector2(0.0, -EXPLODE_R * 0.2), _FX_SMOKE, EXPLODE_R * 1.6, 0.6, \
		Color(0.4, 0.4, 0.42, 1.0), 0.0, 0.5)
	_FXBurst.spawn(scn, global_position, Color(1.0, 0.55, 0.15), EXPLODE_R * 0.7, 0.35)
	Events.shake(9.0)
	SoundManager.play("boom", 0.05, 0.8)
	queue_free()


func _draw() -> void:
	var blink := 0.5 + 0.5 * sin(_pulse * 6.0)
	if _armed >= ARM_TIME:   # 무장 후 깜빡이는 경고 링
		draw_arc(Vector2.ZERO, TRIGGER_R * 0.8, 0.0, TAU, 24, Color(1.0, 0.4, 0.1, 0.25 + 0.4 * blink), 2.0, true)
	for i in 3:   # 차 위 불꽃 일렁임
		var fxp := -8.0 + 8.0 * float(i)
		var fyp := -14.0 - 6.0 * absf(sin(_pulse * 5.0 + float(i)))
		draw_circle(Vector2(fxp, fyp), 3.5 + blink * 1.5, Color(1.0, 0.5 + 0.3 * blink, 0.1, 0.7))
