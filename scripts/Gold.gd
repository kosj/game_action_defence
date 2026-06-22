extends Area2D
## 골드: 플레이어가 자석 범위 안에 들어오면 빨려 들어가며, 가까워질수록 가속.
## 거리 계산만 사용(충돌 콜백 없음). 수집 시 스파클 연출 후 풀로 반납(재사용).

@export var magnet_radius: float = 130.0
@export var collect_radius: float = 22.0
@export var move_speed: float = 420.0
@export var value: int = 1

const COLLECT_SCALE := Vector2(0.4, 0.4)   # tscn 에서 설정한 기본 크기

@onready var body: Sprite2D = $Body

var player: Node2D = null
var _alive: bool = false
var _launching: bool = false   # 분출 연출 중에는 자석 흡수를 멈춘다(보스 동전 폭발 등)


func _ready() -> void:
	monitoring = false
	monitorable = false


func on_spawn() -> void:
	_alive = true
	_launching = false
	body.scale = COLLECT_SCALE   # 수집 애니메이션 후 리셋
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")


## 한 지점에서 바깥으로 톡 튀어 흩어지는 분출 연출(보스 처치 동전 분수). 연출 동안에는
## 자석에 끌리지 않다가, 착지 후 평소대로 수집 가능 상태로 돌아온다.
func launch(to: Vector2, delay: float = 0.0) -> void:
	_launching = true
	body.scale = COLLECT_SCALE * 0.3
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", to, 0.4).set_delay(delay) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(body, "scale", COLLECT_SCALE, 0.4).set_delay(delay) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 분출 애니메이션(지연+0.4s)이 모두 끝난 뒤 자석 흡수를 다시 허용.
	tw.chain().tween_callback(func(): _launching = false)


func on_despawn() -> void:
	_alive = false


func _physics_process(delta: float) -> void:
	if not _alive or _launching:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	var dist := global_position.distance_to(player.global_position)
	if dist <= collect_radius:
		_collect()
		return
	# 자석 버프 중에는 거리와 무관하게 끌려온다(자동 줍기).
	if Events.gold_magnet_active or dist <= magnet_radius:
		var dir := (player.global_position - global_position).normalized()
		var t := clampf(1.0 - dist / magnet_radius, 0.0, 1.0)   # 가까울수록 가속
		var spd := move_speed * (0.3 + t)
		if Events.gold_magnet_active:
			spd = maxf(spd, move_speed)   # 멀리 있어도 빠르게 흡수
		global_position += dir * spd * delta


func _collect() -> void:
	_alive = false
	Events.add_gold(value)
	SoundManager.play("gold", 0.05)
	# 잠깐 커졌다가 풀로 반납(스파클 효과)
	var tw := create_tween()
	tw.tween_property(body, "scale", COLLECT_SCALE * 1.8, 0.08)
	tw.tween_callback(func(): Pool.release(self))
