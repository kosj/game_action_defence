extends Area2D
## 골드: 플레이어가 자석 범위 안에 들어오면 빨려 들어가며, 가까워질수록 가속.
## 거리 계산만 사용(충돌 콜백 없음). 수집 시 스파클 연출 후 풀로 반납(재사용).

@export var magnet_radius: float = 130.0
@export var collect_radius: float = 22.0
@export var move_speed: float = 420.0
@export var value: int = 1

const COLLECT_SCALE := Vector2(0.4, 0.4)   # tscn 에서 설정한 기본 크기
const COLLECT_POP := 0.08                  # 수집 시 톡 커지는 연출 시간(초)

@onready var body: Sprite2D = $Body

var player: Node2D = null
var _alive: bool = false
var _launching: bool = false   # 분출 연출 중에는 자석 흡수를 멈춘다(보스 동전 폭발 등)
var _collecting: bool = false  # 수집 팝 연출 중 — Tween 대신 타이머로 처리(대량 수집 시 Tween 폭증 방지)
var _collect_t: float = 0.0


func _ready() -> void:
	monitoring = false
	monitorable = false


func on_spawn() -> void:
	_alive = true
	_launching = false
	_collecting = false
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
	# 수집 팝 연출: 잠깐 커졌다가 풀로 반납(Tween 없이 타이머로)
	if _collecting:
		_collect_t -= delta
		var k := clampf(1.0 - _collect_t / COLLECT_POP, 0.0, 1.0)
		body.scale = COLLECT_SCALE.lerp(COLLECT_SCALE * 1.8, k)
		if _collect_t <= 0.0:
			_collecting = false
			Pool.release(self)
		return
	if not _alive or _launching:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	# sqrt 비용 제거: 자석/수집 판정을 거리제곱으로. 실제 거리는 흡수 가속 계산에만 사용.
	var dist_sq := global_position.distance_squared_to(player.global_position)
	if dist_sq <= collect_radius * collect_radius:
		_collect()
		return
	# 자석 버프 중에는 거리와 무관하게 끌려온다(자동 줍기).
	if Events.gold_magnet_active or dist_sq <= magnet_radius * magnet_radius:
		var dist := sqrt(dist_sq)
		var dir := (player.global_position - global_position) / dist   # 정규화(이미 dist 계산됨)
		var t := clampf(1.0 - dist / magnet_radius, 0.0, 1.0)   # 가까울수록 가속
		var spd := move_speed * (0.3 + t)
		if Events.gold_magnet_active:
			spd = maxf(spd, move_speed)   # 멀리 있어도 빠르게 흡수
		global_position += dir * spd * delta


func _collect() -> void:
	_alive = false
	Events.add_gold(value)
	SoundManager.play("gold", 0.05)
	# 잠깐 커졌다가 풀로 반납(스파클 효과) — _physics_process 에서 타이머로 진행
	_collecting = true
	_collect_t = COLLECT_POP
