extends CharacterBody2D
## 플레이어: 가상 조이스틱으로 이동 + 가장 가까운 좀비에게 자동 발사

@export var move_speed: float = 220.0
@export var attack_range: float = 360.0     # 이 범위 안의 적만 조준
@export var attack_cooldown: float = 0.35   # 발사 간격(초)
@export var max_health: int = 5
@export var contact_damage: int = 1
@export var contact_cooldown: float = 1.0   # 좀비 접촉 피해 간격

const BULLET := preload("res://scenes/Bullet.tscn")

@onready var muzzle: Marker2D = $Muzzle
@onready var hurtbox: Area2D = $Hurtbox

var joystick: Node = null
var health: int
var _attack_accum: float = 0.0
var _hurt_timer: float = 0.0
var _dead: bool = false


func _ready() -> void:
	add_to_group("player")
	health = max_health
	Events.update_player_health(health, max_health)


func _physics_process(delta: float) -> void:
	_hurt_timer -= delta
	if not _dead:
		_check_contact_damage()
		_handle_move()
		_handle_attack(delta)


func _check_contact_damage() -> void:
	if _hurt_timer > 0.0:
		return
	for body in hurtbox.get_overlapping_bodies():
		if body.is_in_group("zombies"):
			_take_damage(contact_damage)
			break


func _handle_move() -> void:
	# 조이스틱은 HUD 가 준비된 뒤에 그룹에 등록되므로 지연 조회
	if joystick == null:
		joystick = get_tree().get_first_node_in_group("joystick")

	var input := Vector2.ZERO
	if joystick:
		input = joystick.get_value()

	velocity = input * move_speed
	move_and_slide()


func _handle_attack(delta: float) -> void:
	_attack_accum += delta
	if _attack_accum < attack_cooldown:
		return
	var target := _get_nearest_zombie()
	if target:
		_attack_accum = 0.0
		_shoot_at(target)


func _shoot_at(target: Node2D) -> void:
	var b := Pool.acquire(BULLET, get_tree().current_scene)
	b.global_position = muzzle.global_position
	b.direction = (target.global_position - global_position).normalized()


## 그룹 순회로 최근접 적 탐색. distance_squared 로 sqrt 비용 제거.
func _get_nearest_zombie() -> Node2D:
	var nearest: Node2D = null
	var min_d := attack_range * attack_range
	for z in get_tree().get_nodes_in_group("zombies"):
		var d := global_position.distance_squared_to(z.global_position)
		if d < min_d:
			min_d = d
			nearest = z
	return nearest


func _take_damage(amount: int) -> void:
	_hurt_timer = contact_cooldown
	health = max(0, health - amount)
	Events.update_player_health(health, max_health)
	if health <= 0:
		_die()


func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	Events.player_died.emit()
