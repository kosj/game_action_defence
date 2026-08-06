extends Area2D
## 경험치 젬(좀비 드랍): 플레이어가 자석 범위 안에 들어오면 빨려 들어가며, 가까워질수록 가속.
## 수집 시 경험치를 준다(골드는 필드의 보물상자에서만). 거리 계산만 사용(충돌 콜백 없음).

@export var magnet_radius: float = 130.0
@export var collect_radius: float = 22.0
@export var move_speed: float = 420.0
@export var value: int = 1

const COLLECT_SCALE := Vector2(0.4, 0.4)   # tscn 에서 설정한 기본 크기
const COLLECT_POP := 0.08                  # 수집 시 톡 커지는 연출 시간(초)

# 흡인(빨려들기) 물리 — 거리로 속도를 즉석 계산하지 않고 "속도를 누적(가속)"해서
# 시간이 갈수록 점점 빨라지며 확 빨려드는 느낌을 만든다(중력 우물).
const PULL_ACCEL := 2400.0    # 기본 흡인 가속(px/s^2) — 가까울수록 더 강해진다
const PULL_MAX := 1600.0      # 최대 흡인 속도(px/s)
const PULL_SWIRL := 0.30      # 초반 접선(소용돌이) 성분 비율 — 가까울수록 사라진다
const PULL_STEER := 0.14      # 속도 방향을 플레이어 쪽으로 재정렬하는 정도(플레이어 이동 추적)

## 필드에 동시에 존재할 수 있는 젬 상한. 처치 속도가 수집 속도를 앞지르면 젬이 무한히 쌓여
## (각자 매 프레임 자석 판정) 프레임이 급락한다. 초과 시 가장 오래된 젬을 즉시 흡수(경험치는
## 그대로 지급)해 개수를 묶는다 — 사실상 자동 자석 청소.
static var _live: Array = []
const LIVE_CAP := 140


## 판 전환 시 정적 추적 목록 초기화 — 씬 해제로 무효화된 참조가 판 간 쌓이지 않도록 Main 이 호출.
static func reset_live() -> void:
	_live.clear()

@onready var body: Sprite2D = $Body

var player: Node2D = null
var _alive: bool = false
var _launching: bool = false   # 분출 연출 중에는 자석 흡수를 멈춘다(보스 동전 폭발 등)
var _collecting: bool = false  # 수집 팝 연출 중 — Tween 대신 타이머로 처리(대량 수집 시 Tween 폭증 방지)
var _collect_t: float = 0.0
var _pull_vel: Vector2 = Vector2.ZERO   # 누적 흡인 속도(가속되며 커진다)
var _captured: bool = false             # 자석에 걸려 빨려드는 중


func _ready() -> void:
	monitoring = false
	monitorable = false


func on_spawn() -> void:
	_alive = true
	_launching = false
	_collecting = false
	_captured = false
	_pull_vel = Vector2.ZERO
	value = 1                     # 풀 재사용 대비 기본값 리셋(등급 젬은 set_value 로 덮어씀)
	body.scale = COLLECT_SCALE   # 수집 애니메이션 후 리셋
	body.modulate = Color(1, 1, 1)   # 경험치 젬 — 파란 다이아(원색). 등급은 set_value 로 틴트.
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if not _live.has(self):
		_live.append(self)
	_enforce_cap()


## 젬 개수 상한 유지 — 오래된 것부터 즉시 흡수해 필드를 정리한다.
func _enforce_cap() -> void:
	if _live.size() <= LIVE_CAP:
		return
	# 먼저 죽은/무효 참조를 걷어낸다(게임 재시작·수집으로 남은 것) — 그것만으로 상한 이하가 될 수 있다.
	_live = _live.filter(func(g): return is_instance_valid(g) and g._alive)
	while _live.size() > LIVE_CAP:
		var g: Object = _live[0]
		if g == self:   # 자기 자신은 유지(방금 스폰) — 다른 게 없으면 중단
			break
		_live.remove_at(0)
		g._force_absorb()


## 상한 초과로 강제 흡수 — 경험치는 지급하되 연출·사운드 없이 즉시 반납(대량 정리 시 부하·소음 방지).
func _force_absorb() -> void:
	if not _alive:
		return
	_alive = false
	Events.add_xp(value)
	Pool.release(self)


## 젬 등급 지정(강한 적일수록 큰 값). 값이 클수록 골드·경험치가 많고 색으로 구분된다.
func set_value(v: int) -> void:
	value = maxi(1, v)
	if value >= 4:
		body.modulate = Color(1.5, 1.35, 0.85)  # 황금빛 프리미엄 — 대형 경험치 젬
	elif value >= 2:
		body.modulate = Color(1.2, 1.25, 1.4)   # 밝은 청백 — 중형 젬
	else:
		body.modulate = Color(1, 1, 1)          # 파란 다이아 원색 — 기본 젬


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
	_live.erase(self)


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
	# 자석 버프 중이거나 자석 범위 안에 들어오면 "포획" — 이후로는 속도를 누적하며 빨려든다.
	# 자석 범위 업그레이드(pickup_range): 레벨당 +30%.
	var mag_r := magnet_radius * (1.0 + 0.30 * Events.upgrade_pickup_range)
	if Events.gold_magnet_active or dist_sq <= mag_r * mag_r:
		_captured = true
	if _captured:
		var dist := sqrt(dist_sq)
		var dir := (player.global_position - global_position) / dist   # 정규화(이미 dist 계산됨)
		var t := clampf(1.0 - dist / mag_r, 0.0, 1.0)   # 멀리 0 → 가까이 1
		if Events.gold_magnet_active:
			t = maxf(t, 0.5)
		# 가속: 가까울수록 더 세게 당긴다. 속도가 프레임마다 "쌓여" 점점 빨라진다.
		var accel := PULL_ACCEL * (0.45 + 1.4 * t)
		_pull_vel += dir * accel * delta
		# 접선 소용돌이(멀리서 휘어 들어옴, 가까울수록 사라짐)
		_pull_vel += dir.orthogonal() * accel * PULL_SWIRL * (1.0 - t) * delta
		# 플레이어가 움직여도 빨려들도록 속도 방향을 조금씩 플레이어 쪽으로 재정렬
		_pull_vel = _pull_vel.lerp(dir * _pull_vel.length(), PULL_STEER)
		if _pull_vel.length() > PULL_MAX:
			_pull_vel = _pull_vel.normalized() * PULL_MAX
		global_position += _pull_vel * delta
		# 빨려들수록(가까울수록) 작아져 중심으로 사라지는 느낌
		body.scale = COLLECT_SCALE * clampf(dist / 90.0, 0.4, 1.0)
	else:
		_pull_vel = Vector2.ZERO
		body.scale = COLLECT_SCALE   # 자석 범위 밖에서는 정지·원래 크기


func _collect() -> void:
	_alive = false
	Events.add_xp(value)   # 좀비 드랍은 경험치 젬 — 수집이 곧 인게임 성장(레벨업). 골드는 보물상자에서.
	SoundManager.play("gold", 0.05)
	# 잠깐 커졌다가 풀로 반납(스파클 효과) — _physics_process 에서 타이머로 진행
	_collecting = true
	_collect_t = COLLECT_POP
