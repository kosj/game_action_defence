extends CharacterBody2D
## 좀비: 플레이어를 향해 단순 방향벡터 이동. 사망 시 골드 드랍 후 풀로 반납.

@export var speed: float = 65.0
@export var max_health: int = 3

const GOLD := preload("res://scenes/Gold.tscn")
const _FXBurst := preload("res://scripts/FXBurst.gd")

@onready var body: Node2D = $Body
@onready var shadow: Node2D = $Shadow

const _SHADOW_BASE := 0.32   # 크기 1.0 좀비 기준 그림자 스케일(Zombie.tscn 과 일치)
const _HIT_FLASH := 0.12     # 피격 잔광 지속(초)
const _HIT_COLOR := Color(1.0, 0.45, 0.45)

var health: int
var player: Node2D = null
var _alive: bool = false
var _type_color: Color = Color.WHITE
var _score_value: int = 0
var _contact_damage: int = 1
var _flash: float = 0.0      # 피격 잔광 잔여 시간 — 매 프레임 Tween 생성 대신 직접 감쇠


func _ready() -> void:
	add_to_group("zombies")


func on_spawn() -> void:
	add_to_group("zombies")   # 재사용 시 멱등 재등록(안전)
	health = max_health
	velocity = Vector2.ZERO
	_flash = 0.0
	_alive = true
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")


func on_despawn() -> void:
	_alive = false
	velocity = Vector2.ZERO
	_flash = 0.0
	remove_from_group("zombies")
	body.modulate = Color.WHITE
	body.scale = Vector2.ONE
	shadow.scale = Vector2.ONE * _SHADOW_BASE


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
	var s := float(type_data.get("scale", 1.0))
	body.scale = Vector2.ONE * s
	shadow.scale = Vector2.ONE * (_SHADOW_BASE * s)   # 큰 좀비일수록 그림자도 크게


## 종류별 접촉 피해(차저/저거넛 등 강화 좀비는 더 큰 피해). Player 가 호출.
func get_contact_damage() -> int:
	return _contact_damage


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	# 피격 잔광: Tween 대신 잔여 시간을 직접 감쇠(대량 동시 피격 시 Tween 폭증 방지)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		body.modulate = Color.WHITE.lerp(_HIT_COLOR, _flash / _HIT_FLASH)
	var dir := (player.global_position - global_position).normalized()
	body.rotation = dir.angle()
	# 직선 적분 이동: 좀비끼리 상호 충돌을 해소하는 move_and_slide() 는 개체 수의 제곱에
	# 비례해 비싸져 수천~만 마리 환경에서 프레임을 깎는다. 위치를 직접 갱신해 좀비당 비용을
	# O(1) 로 낮춘다(스프라이트끼리 겹칠 수 있으나 대규모 횡스크롤 디펜스에선 일반적).
	# 충돌 도형(레이어2)은 그대로 남아 총알 명중·플레이어 접촉 판정에 계속 쓰인다.
	global_position += dir * speed * delta


func take_damage(amount: int) -> void:
	if not _alive:
		return
	health -= amount
	SoundManager.play("zombie_hit")
	body.modulate = _HIT_COLOR   # 피격 순간 붉게 번쩍 — 이후 _physics_process 에서 흰색으로 감쇠
	_flash = _HIT_FLASH
	if health <= 0:
		_die()


func _die() -> void:
	_alive = false
	SoundManager.play("zombie_die")
	remove_from_group("zombies")
	Events.zombie_killed.emit()
	Events.add_score(_score_value)
	_FXBurst.spawn(get_tree().current_scene, global_position, _type_color, 38.0, 0.38)
	var g := Pool.acquire(GOLD, get_tree().current_scene)
	g.global_position = global_position
	Pool.release(self)
