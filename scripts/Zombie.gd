extends CharacterBody2D
## 좀비: 플레이어를 향해 단순 방향벡터 이동. 사망 시 골드 드랍 후 풀로 반납.

@export var speed: float = 65.0
@export var max_health: int = 3

const GOLD := preload("res://scenes/Gold.tscn")

var health: int
var player: Node2D = null
var _alive: bool = false


func _ready() -> void:
	add_to_group("zombies")


func on_spawn() -> void:
	add_to_group("zombies")   # 재사용 시 멱등 재등록(안전)
	health = max_health
	velocity = Vector2.ZERO
	_alive = true
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")


func _physics_process(_delta: float) -> void:
	if not _alive:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()   # 좀비끼리 충돌(레이어2/마스크2)로 자연스럽게 분산


func take_damage(amount: int) -> void:
	if not _alive:
		return
	health -= amount
	if health <= 0:
		_die()


func _die() -> void:
	_alive = false
	remove_from_group("zombies")   # 즉시 타깃/카운트에서 제외
	var g := Pool.acquire(GOLD, get_tree().current_scene)
	g.global_position = global_position
	Pool.release(self)
