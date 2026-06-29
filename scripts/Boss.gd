extends CharacterBody2D
## 보스: 웨이브 종료 시 등장하는 강력한 단일 적.
## 일반 좀비와 같은 "zombies" 그룹에 속해 총알/접촉 데미지 시스템을 그대로 재사용하되,
## 별도의 체력바·강화된 외형·다량의 보상을 가진다. 풀링하지 않고 등장 시마다 인스턴스화.

const GOLD := preload("res://scenes/Gold.tscn")
const _FXBurst := preload("res://scripts/FXBurst.gd")

@onready var body: Node2D = $Body

var speed: float = 55.0
var max_health: int = 80
var health: int = 80
var contact_damage: int = 2
var score_value: int = 200
var gold_drop: int = 12

var _alive: bool = false
var _base_color: Color = Color(0.55, 0.12, 0.14)
var _pulse: float = 0.0


func _ready() -> void:
	add_to_group("zombies")
	add_to_group("boss")


## 스포너가 인스턴스 직후 호출 — 등장 회차에 따른 스탯 주입 후 등장 연출.
func setup(stats: Dictionary) -> void:
	max_health = stats.get("max_health", 80)
	health = max_health
	speed = stats.get("speed", 55.0)
	contact_damage = stats.get("contact_damage", 2)
	score_value = stats.get("score", 200)
	gold_drop = stats.get("gold", 12)
	_alive = true
	body.modulate = _base_color
	Events.boss_spawned.emit(max_health)
	Events.boss_health_changed.emit(health, max_health)
	_spawn_intro()


func get_contact_damage() -> int:
	return contact_damage


func _spawn_intro() -> void:
	# 주의: 루트(CharacterBody2D)의 scale 을 애니메이션하면 move_and_slide 의 이동/충돌이
	# 깨져 보스가 그 자리에 얼어붙는다. 그래서 루트는 건드리지 않고 Body 스프라이트만 확대한다.
	var target_scale := body.scale   # 씬에 지정된 크기(2.7)
	body.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(body, "scale", target_scale, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_FXBurst.spawn(get_tree().current_scene, global_position, Color(0.9, 0.2, 0.2), 90.0, 0.5)


func _physics_process(_delta: float) -> void:
	if not _alive:
		return
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * speed
	body.rotation = dir.angle()
	move_and_slide()


func _process(delta: float) -> void:
	if not _alive:
		return
	_pulse += delta
	queue_redraw()


## 머리 위 체력바 + 위협적인 오라 링.
func _draw() -> void:
	if not _alive:
		return
	# 맥동하는 오라 링
	var r := 46.0 + sin(_pulse * 4.0) * 4.0
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.95, 0.25, 0.2, 0.5), 3.0, true)

	# 체력바 (스프라이트 위쪽)
	var bar_w := 84.0
	var bar_h := 9.0
	var bar_y := -64.0
	var ratio := clampf(float(health) / float(max_health), 0.0, 1.0)
	# 테두리/배경
	draw_rect(Rect2(-bar_w * 0.5 - 2.0, bar_y - 2.0, bar_w + 4.0, bar_h + 4.0), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, bar_h), Color(0.2, 0.05, 0.06, 0.9))
	# 채움 (체력 비율에 따라 색 변화: 녹색→노랑→빨강)
	var fill := Color(0.9, 0.2, 0.2).lerp(Color(1.0, 0.85, 0.2), ratio)
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * ratio, bar_h), fill)


func take_damage(amount: int) -> void:
	if not _alive:
		return
	health = max(0, health - amount)
	Events.boss_health_changed.emit(health, max_health)
	SoundManager.play("zombie_hit")
	body.modulate = Color(1, 1, 1)
	var tw := create_tween()
	tw.tween_property(body, "modulate", _base_color, 0.12)
	if health <= 0:
		_die()


func _die() -> void:
	_alive = false
	remove_from_group("zombies")
	remove_from_group("boss")
	SoundManager.play("zombie_die")
	Events.add_score(score_value)
	Events.boss_died.emit()

	# 다중 충격파 — 흰 섬광 → 황금 링 → 주황 링이 시간차로 번지며 터진다.
	_burst(Color(1.0, 1.0, 0.85), 70.0,  0.28, 0.0)    # 중심 흰 섬광
	_burst(Color(1.0, 0.82, 0.25), 150.0, 0.6,  0.0)    # 큰 황금 링
	_burst(Color(1.0, 0.45, 0.15), 120.0, 0.5,  0.12)   # 주황 2차 파동
	_burst(Color(1.0, 0.88, 0.35), 190.0, 0.7,  0.24)   # 넓게 퍼지는 마지막 황금 링

	# 황금 동전 분수 — 보스 중심에서 사방으로 튀어 흩어졌다가 착지(시간차 분출).
	for i in range(gold_drop):
		var g := Pool.acquire(GOLD, get_tree().current_scene)
		g.global_position = global_position
		var landing := global_position + Vector2.from_angle(randf() * TAU) * randf_range(45.0, 135.0)
		g.launch(landing, randf() * 0.18)

	queue_free()


## 지정한 지연 후 한 번 터지는 확산 파동(FXBurst). 보스 처치 연출용 헬퍼.
## FXBurst 가 start_delay 로 스스로 시간차 재생하므로(타이머·콜백 불필요) 보스가 곧바로
## 해제돼도 안전하다 — 파동 노드는 현재 씬에 독립적으로 붙는다.
func _burst(c: Color, radius: float, dur: float, delay: float) -> void:
	_FXBurst.spawn(get_tree().current_scene, global_position, c, radius, dur, delay)
