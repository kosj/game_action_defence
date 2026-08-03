extends Node2D
## 지뢰: 바닥에 설치되어 짧게 무장 후, 좀비가 트리거 반경에 들어오거나 수명이 다하면 폭발한다.
## 폭발은 반경 내 좀비에게 광역 피해 + 넉백. 월드(current_scene)에 스폰되며 폭발 후 자기 해제.

const _FXBurst := preload("res://scripts/FXBurst.gd")
const _SpriteFX := preload("res://scripts/SpriteFX.gd")
const _FX_EXPLOSION := preload("res://assets/sprites/fx/fx_explosion.png")
const _FX_SMOKE := preload("res://assets/sprites/fx/fx_smoke.png")

const ARM_TIME := 0.4       # 설치 직후 무장 지연(즉폭 방지)
const TRIGGER_R := 34.0     # 이 반경에 좀비가 들어오면 기폭

var explode_r: float = 72.0
var damage: int = 4
var knockback: float = 210.0
var color: Color = Color(1.0, 0.45, 0.15)
var _life: float = 9.0
var _armed: float = 0.0
var _pulse: float = 0.0
var _done: bool = false
var _spr: Sprite2D


func _ready() -> void:
	# 전용 스프라이트(지뢰). 무장 경고등 깜빡임은 _draw 의 붉은 링으로 별도 표시.
	_spr = Sprite2D.new()
	_spr.texture = preload("res://assets/sprites/field_mine.png")
	_spr.scale = Vector2(0.26, 0.26)
	add_child(_spr)


func setup(pos: Vector2, r: float, dmg: int, kb: float, life: float, tint: Color) -> void:
	global_position = pos
	explode_r = r
	damage = dmg
	knockback = kb
	_life = life
	color = tint


func _physics_process(delta: float) -> void:
	if _done:
		return
	_pulse += delta
	_armed += delta
	_life -= delta
	if _life <= 0.0:
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
	var r_sq := explode_r * explode_r
	for z in Events.live_zombies():
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		if global_position.distance_squared_to(z.global_position) < r_sq:
			z.take_damage(damage)
			if z.has_method("apply_knockback"):
				var dir: Vector2 = (z.global_position - global_position).normalized()
				z.apply_knockback(dir, knockback)
	# 폭발 텍스처(반경에 맞춤) + 피어오르는 연기 + 확산 잔광.
	var scn := get_tree().current_scene
	_SpriteFX.spawn(scn, global_position, _FX_EXPLOSION, explode_r * 2.0, 0.34, color.lightened(0.25))
	_SpriteFX.spawn(scn, global_position + Vector2(0.0, -explode_r * 0.25), _FX_SMOKE, \
		explode_r * 1.4, 0.6, Color(0.5, 0.5, 0.5, 1.0), 0.0, 0.6)
	_FXBurst.spawn(scn, global_position, color, explode_r * 0.7, 0.35)
	Events.shake(5.0)
	SoundManager.play("boom", 0.1, 0.9)
	queue_free()


func _draw() -> void:
	# 스프라이트가 본체를 그리므로, 무장 후 "기폭 임박" 경고 링만 붉게 깜빡인다.
	if _armed < ARM_TIME:
		return
	var blink := 0.5 + 0.5 * sin(_pulse * 9.0)
	draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 22, Color(0.95, 0.15, 0.1, 0.3 + 0.45 * blink), 2.0, true)
