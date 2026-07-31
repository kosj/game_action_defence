extends Node2D
## 터렛(설치물): 바닥에 설치되어 수명 동안 사거리 내 최근접 적을 자동 사격한다. 수명이 다하면 자기 해제.
## 월드(current_scene)에 스폰. 총알은 기존 Bullet 풀을 재사용한다.

const BULLET := preload("res://scenes/Bullet.tscn")
const _FXBurst := preload("res://scripts/FXBurst.gd")
const FIRE_INTERVAL := 0.5   # 터렛 자체 발사 간격

var damage: int = 2
var bullet_speed: float = 700.0
var range: float = 300.0
var color: Color = Color(0.7, 0.8, 1.0)
var _life: float = 6.0
var _t: float = 0.0
var _aim: Vector2 = Vector2.RIGHT


func setup(pos: Vector2, dmg: int, bspeed: float, rng: float, life: float, tint: Color) -> void:
	global_position = pos
	damage = dmg
	bullet_speed = bspeed
	range = rng
	_life = life
	color = tint


func _ready() -> void:
	z_index = -1   # 지면 설치물 — 유닛 아래


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	_t += delta
	if _t >= FIRE_INTERVAL:
		_t = 0.0
		_fire()
	queue_redraw()


func _fire() -> void:
	var target := _nearest_zombie()
	if target == null:
		return
	_aim = (target.global_position - global_position).normalized()
	var b := Pool.acquire(BULLET, get_tree().current_scene)
	b.global_position = global_position
	b.direction = _aim
	b.rotation = _aim.angle() + PI / 2
	b.speed = bullet_speed
	b.damage = damage
	b.is_crit = false
	b.scale = Vector2.ONE * 0.9
	b.trail_color = color
	b.pierce = 0
	b.knockback = 0.0
	b.splash_radius = 0.0
	b.queue_redraw()
	SoundManager.play("shoot", 0.08, 1.15)


func _nearest_zombie() -> Node2D:
	var nearest: Node2D = null
	var min_d := range * range
	for z in Events.live_zombies():
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		var d := global_position.distance_squared_to(z.global_position)
		if d < min_d:
			min_d = d
			nearest = z
	return nearest


func _draw() -> void:
	var fade := clampf(_life / 0.8, 0.0, 1.0)
	# 받침대 + 회전 포탑(조준 방향)
	draw_circle(Vector2.ZERO, 11.0, Color(0.18, 0.20, 0.24, 0.95 * fade))
	draw_circle(Vector2.ZERO, 7.0, Color(0.30, 0.34, 0.40, fade))
	var barrel := _aim * 16.0
	draw_line(Vector2.ZERO, barrel, Color(color.r, color.g, color.b, 0.95 * fade), 4.0, true)
	draw_circle(barrel, 3.0, Color(1.0, 1.0, 1.0, 0.9 * fade))
