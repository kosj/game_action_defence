extends CharacterBody2D
## 좀비: 플레이어를 향해 단순 방향벡터 이동. 사망 시 골드 드랍 후 풀로 반납.

@export var speed: float = 65.0
@export var max_health: int = 3

const GOLD := preload("res://scenes/Gold.tscn")
const _FXBurst := preload("res://scripts/FXBurst.gd")

@onready var body: Node2D = $Body

var health: int
var player: Node2D = null
var _alive: bool = false
var _type_color: Color = Color.WHITE


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


## 스포너가 풀에서 꺼낸 직후 호출해 종류별 스탯·색상을 주입한다.
func setup(type_data: Dictionary) -> void:
	speed = type_data["speed"]
	max_health = type_data["max_health"]
	health = max_health
	_type_color = type_data["modulate"]
	body.modulate = _type_color


func _physics_process(_delta: float) -> void:
	if not _alive:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * speed
	body.rotation = dir.angle()
	move_and_slide()   # 좀비끼리 충돌(레이어2/마스크2)로 자연스럽게 분산


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
	var fx := _FXBurst.new()
	fx.color = _type_color
	fx.max_radius = 38.0
	fx.duration = 0.38
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position
	var g := Pool.acquire(GOLD, get_tree().current_scene)
	g.global_position = global_position
	Pool.release(self)
