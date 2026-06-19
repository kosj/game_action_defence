extends CharacterBody2D
## 좀비: 플레이어를 향해 단순 방향벡터 이동. 사망 시 골드 드랍 후 풀로 반납.

@export var speed: float = 65.0
@export var max_health: int = 3

const GOLD := preload("res://scenes/Gold.tscn")
const ENEMY_BULLET := preload("res://scenes/EnemyBullet.tscn")
const _FXBurst := preload("res://scripts/FXBurst.gd")

# 행동 패턴 파라미터
const WEAVE_FREQ := 6.5          # weaver 좌우 흔들림 주파수
const WEAVE_AMP_RATIO := 0.8     # weaver 측면 속도 = speed * 이 비율
const SPIT_RANGE := 360.0        # spitter 발사 사거리
const SPIT_COOLDOWN := 1.6       # spitter 발사 간격(초)
const SPIT_KEEP_DIST := 240.0    # spitter 가 유지하려는 거리
const SPIT_PROJ_SPEED := 250.0
const BOMB_TRIGGER := 74.0       # bomber 점화 시작 거리
const BOMB_FUSE := 0.55          # bomber 점화~폭발 시간(도망 기회)
const BOMB_RADIUS := 92.0        # bomber 폭발 피해 반경

@onready var body: Node2D = $Body

var health: int
var player: Node2D = null
var _alive: bool = false
var _type_color: Color = Color.WHITE
var _score_value: int = 0
var _contact_damage: int = 1
var _behavior: String = "chase"
var _wt: float = 0.0             # weaver 위상 누적
var _fire_timer: float = 0.0     # spitter 발사 쿨다운
var _fuse_active: bool = false   # bomber 점화 여부
var _fuse_timer: float = 0.0


func _ready() -> void:
	add_to_group("zombies")


func on_spawn() -> void:
	add_to_group("zombies")   # 재사용 시 멱등 재등록(안전)
	health = max_health
	velocity = Vector2.ZERO
	_alive = true
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")


func on_despawn() -> void:
	_alive = false
	velocity = Vector2.ZERO
	remove_from_group("zombies")
	body.modulate = Color.WHITE
	body.scale = Vector2.ONE


## 스포너가 풀에서 꺼낸 직후 호출해 종류별 스탯·색상을 주입한다.
func setup(type_data: Dictionary) -> void:
	speed = type_data["speed"]
	max_health = type_data["max_health"]
	health = max_health
	_type_color = type_data["modulate"]
	_score_value = type_data.get("score", 0)
	_contact_damage = type_data.get("contact", 1)
	_behavior = type_data.get("behavior", "chase")
	_wt = 0.0
	_fire_timer = SPIT_COOLDOWN * 0.5   # 등장 직후 즉시 난사하지 않도록 약간의 지연
	_fuse_active = false
	_fuse_timer = 0.0
	body.modulate = _type_color
	body.scale = Vector2.ONE * float(type_data.get("scale", 1.0))


## 종류별 접촉 피해(차저/저거넛 등 강화 좀비는 더 큰 피해). Player 가 호출.
func get_contact_damage() -> int:
	return _contact_damage


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	match _behavior:
		"weaver":  _behave_weaver(delta)
		"spitter": _behave_spitter(delta)
		"bomber":  _behave_bomber(delta)
		_:         _behave_chase()


## 기본: 플레이어를 향해 직진 추격. move_and_slide 로 좀비끼리 자연 분산.
func _behave_chase() -> void:
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * speed
	body.rotation = dir.angle()
	move_and_slide()


## 지그재그: 플레이어로 접근하되 진행 방향에 수직으로 흔들어 조준을 어렵게 한다.
func _behave_weaver(delta: float) -> void:
	_wt += delta
	var dir := (player.global_position - global_position).normalized()
	var perp := Vector2(-dir.y, dir.x)
	velocity = dir * speed + perp * (sin(_wt * WEAVE_FREQ) * speed * WEAVE_AMP_RATIO)
	body.rotation = dir.angle()
	move_and_slide()


## 원거리: 선호 거리를 유지하며 주기적으로 투사체를 발사(카이팅).
func _behave_spitter(delta: float) -> void:
	var to_p := player.global_position - global_position
	var dist := to_p.length()
	var dir := to_p / maxf(dist, 0.001)
	if dist < SPIT_KEEP_DIST - 30.0:
		velocity = -dir * speed      # 너무 가까우면 물러난다
	elif dist > SPIT_KEEP_DIST + 30.0:
		velocity = dir * speed       # 너무 멀면 접근
	else:
		velocity = Vector2.ZERO
	body.rotation = dir.angle()
	move_and_slide()
	_fire_timer -= delta
	if dist <= SPIT_RANGE and _fire_timer <= 0.0:
		_fire_timer = SPIT_COOLDOWN
		_spit(dir)


func _spit(dir: Vector2) -> void:
	var p := Pool.acquire(ENEMY_BULLET, get_tree().current_scene)
	p.global_position = global_position
	p.direction = dir
	p.speed = SPIT_PROJ_SPEED
	p.damage = 1
	p.color = _type_color


## 자폭: 플레이어에게 돌진 → 근접 시 점화(점멸) → 폭발로 광역 피해 후 사망.
## 점화 중 처치하면 폭발 없이 무력화된다(보고 쏠 기회).
func _behave_bomber(delta: float) -> void:
	if _fuse_active:
		_fuse_timer -= delta
		body.modulate = Color(1, 1, 1) if fmod(_fuse_timer, 0.16) > 0.08 else Color(1.0, 0.4, 0.2)
		if _fuse_timer <= 0.0:
			_explode()
		return
	var to_p := player.global_position - global_position
	var dir := to_p.normalized()
	velocity = dir * speed
	body.rotation = dir.angle()
	move_and_slide()
	if to_p.length() <= BOMB_TRIGGER:
		_fuse_active = true
		_fuse_timer = BOMB_FUSE
		velocity = Vector2.ZERO


func _explode() -> void:
	if not _alive:
		return
	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= BOMB_RADIUS:
		if player.has_method("take_hit"):
			player.take_hit(_contact_damage)
	var fx := _FXBurst.new()
	fx.color = Color(1.0, 0.45, 0.15)
	fx.max_radius = BOMB_RADIUS
	fx.duration = 0.4
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position
	_die()   # 처치로 집계 — 웨이브 진행/골드 드랍 처리


func take_damage(amount: int) -> void:
	if not _alive:
		return
	health -= amount
	SoundManager.play("zombie_hit")
	body.modulate = Color.WHITE
	var tw := create_tween()
	tw.tween_property(body, "modulate", _type_color, 0.12)
	if health <= 0:
		_die()


func _die() -> void:
	_alive = false
	SoundManager.play("zombie_die")
	remove_from_group("zombies")
	Events.zombie_killed.emit()
	Events.add_score(_score_value)
	var fx := _FXBurst.new()
	fx.color = _type_color
	fx.max_radius = 38.0
	fx.duration = 0.38
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position
	var g := Pool.acquire(GOLD, get_tree().current_scene)
	g.global_position = global_position
	Pool.release(self)
