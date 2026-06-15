extends CharacterBody2D
## 플레이어: 가상 조이스틱으로 이동 + 가장 가까운 좀비에게 자동 발사

@export var move_speed: float = 220.0
@export var attack_range: float = 360.0     # 이 범위 안의 적만 조준
@export var attack_cooldown: float = 0.35   # 발사 간격(초)
@export var max_health: int = 5
@export var contact_damage: int = 1
@export var contact_cooldown: float = 1.5   # 좀비 접촉 피해 간격

const BULLET := preload("res://scenes/Bullet.tscn")

@onready var body: Node2D = $Body
@onready var muzzle: Marker2D = $Body/Muzzle
@onready var hurtbox: Area2D = $Hurtbox

var joystick: Node = null
var health: int
var _attack_accum: float = 0.0
var _hurt_timer: float = 0.0
var _dead: bool = false
var _base_move_speed: float
var _base_attack_cooldown: float
var _base_max_health: int


func _ready() -> void:
	add_to_group("player")
	_base_move_speed = move_speed
	_base_attack_cooldown = attack_cooldown
	_base_max_health = max_health
	health = max_health
	_hurt_timer = 3.0   # 시작 시 3초 무적 (프리워밍·첫 좀비 도착 전 보호)
	Events.update_player_health(health, max_health)
	Events.shop_closed.connect(apply_upgrades)


func _physics_process(delta: float) -> void:
	_hurt_timer -= delta
	if _dead:
		return
	_check_contact_damage()
	_handle_move()
	var target := _get_nearest_zombie()
	_handle_attack(delta, target)
	_update_facing(target)


func _check_contact_damage() -> void:
	if _hurt_timer > 0.0:
		return
	for body_node in hurtbox.get_overlapping_bodies():
		if body_node.is_in_group("zombies"):
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


func _handle_attack(delta: float, target: Node2D) -> void:
	_attack_accum += delta
	if _attack_accum < attack_cooldown:
		return
	if target:
		_attack_accum = 0.0
		_shoot_at(target)


## 조준 대상이 있으면 그쪽을, 없으면 이동 방향을 바라본다(스프라이트만 회전).
func _update_facing(target: Node2D) -> void:
	if target:
		body.rotation = (target.global_position - global_position).angle()
	elif velocity.length() > 1.0:
		body.rotation = velocity.angle()


func _shoot_at(target: Node2D) -> void:
	SoundManager.play("shoot")
	var b := Pool.acquire(BULLET, get_tree().current_scene)
	b.global_position = muzzle.global_position
	b.direction = (target.global_position - global_position).normalized()
	b.rotation = b.direction.angle() + PI / 2   # 총알 스프라이트는 위(-Y)를 향함


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
	SoundManager.play("player_hurt")
	health = max(0, health - amount)
	Events.update_player_health(health, max_health)
	if health <= 0:
		_die()


func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	Events.player_died.emit()


## 상점에서 업그레이드 구매 후 또는 웨이브 시작 시 호출.
func apply_upgrades() -> void:
	move_speed = _base_move_speed + 30.0 * Events.upgrade_speed
	attack_cooldown = _base_attack_cooldown * pow(0.85, Events.upgrade_atk_speed)
	var new_max := _base_max_health + Events.upgrade_max_health
	if new_max > max_health:
		health += new_max - max_health   # 늘어난 만큼 즉시 회복
		max_health = new_max
		Events.update_player_health(health, max_health)


## 상점의 회복 아이템 구매 시 호출.
func heal_full() -> void:
	health = max_health
	Events.update_player_health(health, max_health)
