extends CharacterBody2D
## 플레이어: 가상 조이스틱으로 이동 + 가장 가까운 좀비에게 자동 발사

@export var move_speed: float = 220.0
@export var attack_range: float = 360.0     # 이 범위 안의 적만 조준
@export var attack_cooldown: float = 0.35   # 발사 간격(초)
@export var max_health: int = 5
@export var contact_damage: int = 1
@export var contact_cooldown: float = 1.5   # 좀비 접촉 피해 간격

const BULLET := preload("res://scenes/Bullet.tscn")
const _OrbClass := preload("res://scripts/Orb.gd")
const _LightningClass := preload("res://scripts/Lightning.gd")
const _FXBurst  := preload("res://scripts/FXBurst.gd")
const _WeaponDB := preload("res://scripts/WeaponDB.gd")
const BASE_BULLET_SPEED := 700.0

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
var _orbs: Array = []
var _lightning: Node2D = null
var current_weapon: Dictionary = _WeaponDB.default_weapon()


func _ready() -> void:
	add_to_group("player")
	_base_move_speed = move_speed
	_base_attack_cooldown = attack_cooldown
	_base_max_health = max_health
	_recompute_combat_stats()
	health = max_health
	_hurt_timer = 5.0   # 시작 시 5초 무적 (프리워밍·첫 좀비 도착 전 보호)
	Events.update_player_health(health, max_health)
	Events.shop_closed.connect(apply_upgrades)
	Events.shop_closed.connect(_autosave)
	Events.wave_complete.connect(func(_wave: int): _autosave())
	if SaveManager.pending_continue:
		_load_saved_state()


func _physics_process(delta: float) -> void:
	_hurt_timer -= delta
	if _dead:
		return
	# 무적 중 깜빡임 — 플레이어가 언제까지 안전한지 시각적으로 표시
	if _hurt_timer > 0.0:
		body.modulate.a = 1.0 if fmod(_hurt_timer, 0.4) > 0.2 else 0.35
	else:
		body.modulate.a = 1.0
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
	var base_dir := (target.global_position - global_position).normalized()
	var count: int = current_weapon["pellet_count"] + Events.upgrade_multi_bullet
	var spread: float = current_weapon["spread"]
	if count > 1 and spread <= 0.0:
		spread = 0.22   # 무기 자체엔 탄퍼짐이 없어도 다중발사 강화 시 보기 좋게 퍼지도록
	for i in range(count):
		var angle_off := 0.0
		if count > 1:
			angle_off = lerp(-spread, spread, float(i) / (count - 1))
		var dir := base_dir.rotated(angle_off)
		var b := Pool.acquire(BULLET, get_tree().current_scene)
		b.global_position = muzzle.global_position
		b.direction = dir
		b.rotation = dir.angle() + PI / 2
		b.speed = BASE_BULLET_SPEED * current_weapon["bullet_speed_mult"]
		b.damage = current_weapon["damage"] + Events.upgrade_bullet_damage
		b.scale = Vector2.ONE * current_weapon["bullet_scale"]
		b.trail_color = current_weapon["color"]
		b.splash_radius = current_weapon["splash_radius"]
	# muzzle flash — 무기 등급이 높을수록 더 크고 화려하게
	var fx := _FXBurst.new()
	fx.color = current_weapon["color"]
	fx.max_radius = 14.0 * (1.0 + (current_weapon["tier_mult"] - 1.0) * 0.35)
	fx.duration = 0.1
	get_tree().current_scene.add_child(fx)
	fx.global_position = muzzle.global_position


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
	_recompute_combat_stats()
	var new_max := _base_max_health + Events.upgrade_max_health
	if new_max > max_health:
		health += new_max - max_health   # 늘어난 만큼 즉시 회복
		max_health = new_max
		Events.update_player_health(health, max_health)
	_update_orbs()
	_update_lightning()


func _update_orbs() -> void:
	var desired := Events.upgrade_orbs
	while _orbs.size() > desired:
		var orb = _orbs.pop_back()
		if is_instance_valid(orb):
			orb.queue_free()
	while _orbs.size() < desired:
		var orb := _OrbClass.new()
		add_child(orb)
		_orbs.append(orb)
	for i in _orbs.size():
		if is_instance_valid(_orbs[i]):
			_orbs[i].init_angle(TAU * i / max(_orbs.size(), 1))


func _update_lightning() -> void:
	var owned := Events.upgrade_lightning > 0
	if owned and _lightning == null:
		_lightning = _LightningClass.new()
		add_child(_lightning)
	elif not owned and _lightning != null:
		_lightning.queue_free()
		_lightning = null


## 상점의 회복 아이템 구매 시 호출.
func heal_full() -> void:
	health = max_health
	Events.update_player_health(health, max_health)


func _recompute_combat_stats() -> void:
	attack_cooldown = _base_attack_cooldown * pow(0.85, Events.upgrade_atk_speed) * current_weapon["cooldown_mult"]


## 맵의 무기 픽업 획득 시 호출 — 즉시 교체 장착.
func equip_weapon(weapon_stats: Dictionary) -> void:
	current_weapon = weapon_stats
	_recompute_combat_stats()
	Events.weapon_equipped.emit(weapon_stats)
	_autosave()


## 메인 메뉴의 "이어하기"로 진입했을 때, 저장된 체력/무기 상태를 적용.
func _load_saved_state() -> void:
	apply_upgrades()
	health = clampi(SaveManager.pending_player_health, 1, max_health)
	Events.update_player_health(health, max_health)
	equip_weapon(_WeaponDB.build_from_ids(SaveManager.pending_weapon_id, SaveManager.pending_weapon_tier_id))
	SaveManager.pending_continue = false


func _autosave() -> void:
	SaveManager.save_game(self)
