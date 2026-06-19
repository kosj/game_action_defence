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
var _score_value: int = 0
var _contact_damage: int = 1


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


## 스포너가 풀에서 꺼낸 직후 호출해 종류별 스탯·스프라이트를 주입한다.
func setup(type_data: Dictionary) -> void:
	speed = type_data["speed"]
	max_health = type_data["max_health"]
	health = max_health
	_type_color = type_data["modulate"]   # 사망 폭발 FX·피격 잔광 색
	_score_value = type_data.get("score", 0)
	_contact_damage = type_data.get("contact", 1)
	if type_data.has("texture"):
		body.texture = type_data["texture"]   # 종류별 캐릭터 스프라이트
	body.modulate = Color.WHITE              # 스프라이트 본연의 색을 그대로 노출
	body.scale = Vector2.ONE * float(type_data.get("scale", 1.0))


## 종류별 접촉 피해(차저/저거넛 등 강화 좀비는 더 큰 피해). Player 가 호출.
func get_contact_damage() -> int:
	return _contact_damage


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
	body.modulate = Color(1.0, 0.45, 0.45)   # 피격 순간 붉게 번쩍
	var tw := create_tween()
	tw.tween_property(body, "modulate", Color.WHITE, 0.12)
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
