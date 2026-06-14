extends CharacterBody2D
## 좀비: 플레이어를 향해 단순 방향벡터 이동. 사망 시 그 자리에 골드 드랍.
## (A* 패스파인딩 없이 방향벡터만 사용 → 수십 마리도 가볍게 처리)

@export var speed: float = 65.0
@export var max_health: int = 3

const GOLD := preload("res://scenes/Gold.tscn")

var health: int
var player: Node2D = null


func _ready() -> void:
	add_to_group("zombies")
	health = max_health
	player = get_tree().get_first_node_in_group("player")


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()  # 좀비끼리는 충돌(레이어2/마스크2)로 자연스럽게 분산


func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		_die()


func _die() -> void:
	var g := GOLD.instantiate()
	g.global_position = global_position
	get_tree().current_scene.add_child(g)
	queue_free()
