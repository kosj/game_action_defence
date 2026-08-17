extends Node2D
## 보스 격리 구역 — 보스가 등장하면 플레이어 주위에 원형 경계가 전개되고, 보스를 잡을 때까지
## 플레이어는 그 안을 벗어나지 못한다.
##
## 왜 필요한가: 이 월드에는 벽이 없고(카메라만 따라다닌다), 보스 이속은 회차가 올라도 121~174 로
## 플레이어(기본 220, 이속 업그레이드당 +30)를 절대 따라잡지 못한다. 그래서 보스전이 "한 방향으로
## 걸으며 원거리 딜"로 끝났고, 체력만 올려도(1차 902 → 6차 128,002) 그 구조는 그대로인 채 전투
## 시간만 늘어났다. 도망칠 공간을 없애 "좁은 곳에서 패턴을 피하며 싸우는" 보스전으로 바꾼다.
##
## 공정성: 경계 밖으로는 **밀어내기만** 한다 — 피해를 주지 않는다. 플레이어 최대 체력이
## 5(+업그레이드)라 경계 피해는 사실상 즉사이고, "모든 위협은 보고 피할 수 있어야 한다"는
## 이 게임의 규칙에도 어긋난다. 경계선은 항상 그려지고 가까이 갈수록 밝아진다.

const _FXBurst := preload("res://scripts/FXBurst.gd")

const OPEN_TIME := 0.5       # 전개 연출: 넓은 원에서 제 크기로 조여든다
const OPEN_SCALE := 1.4      # 전개 시작 반경 배수
const CLOSE_TIME := 0.45     # 보스 처치 후 해제 연출
const SEGMENTS := 96         # 경계 원 분할 수(반경이 커서 성기면 각져 보인다)
const NEAR_BAND := 90.0      # 경계에서 이 거리 안이면 "붙었다"로 보고 더 밝게 그린다
## 차가운 청록 — 보스 공격 표식(주황·빨강·초록)과 절대 헷갈리지 않을 색.
const COLOR := Color(0.45, 0.85, 1.0)

var radius: float = 620.0

var _t: float = 0.0          # 전개 경과
var _closing: bool = false
var _close_t: float = 0.0
var _pulse: float = 0.0
var _near: float = 0.0       # 플레이어가 경계에 붙은 정도(0~1)


## 지정 위치를 중심으로 구역을 전개한다. 보스 처치(Events.boss_died) 시 스스로 사라진다.
static func spawn(parent: Node, center: Vector2, p_radius: float) -> Node2D:
	var a = (load("res://scripts/BossArena.gd") as GDScript).new()
	a.radius = p_radius
	parent.add_child(a)
	a.global_position = center
	return a


func _ready() -> void:
	add_to_group("boss_arena")   # 자동플레이 조종 AI 가 경계를 피하려고 찾는다
	z_index = -5                 # 유닛·탄착 표식 아래, 바닥 위
	Events.boss_died.connect(_on_boss_died)
	SoundManager.play("tesla_arc", 0.0, 0.55)   # 역장 전개 저음
	_FXBurst.spawn(get_tree().current_scene, global_position, COLOR, 130.0, 0.5)


## 지금 실제로 막고 있는 반경. 전개 중에는 바깥에서 조여 들어오므로 **보이는 선이 곧 벽**이다.
func current_radius() -> float:
	if _closing:
		return radius * (1.0 + 0.35 * clampf(_close_t / CLOSE_TIME, 0.0, 1.0))
	var t := clampf(_t / OPEN_TIME, 0.0, 1.0)
	return radius * lerpf(OPEN_SCALE, 1.0, 1.0 - pow(1.0 - t, 3.0))


func _physics_process(_delta: float) -> void:
	if _closing:
		return
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return
	var to_p: Vector2 = player.global_position - global_position
	var d := to_p.length()
	var r := current_radius()
	_near = clampf((d - (r - NEAR_BAND)) / NEAR_BAND, 0.0, 1.0)
	if d > r and d > 0.001:
		# 경계 위로 되돌린다. 속도를 건드리지 않는 이유: 플레이어는 매 프레임 입력으로 velocity 를
		# 새로 쓰기 때문에(Player._handle_move) 여기서 손대도 다음 프레임에 덮어써진다.
		player.global_position = global_position + to_p / d * r


func _process(delta: float) -> void:
	_pulse += delta
	if _closing:
		_close_t += delta
		if _close_t >= CLOSE_TIME:
			queue_free()
			return
	elif _t < OPEN_TIME:
		_t += delta
	queue_redraw()


## 보스 처치 → 해제. 이 순간 보너스 레벨업 카드가 뜨면서 트리가 멈추므로(Events.bonus_level),
## 해제 연출은 카드를 고른 뒤에야 이어진다 — 전장 전체가 함께 멈추는 것이라 의도된 동작이다.
func _on_boss_died() -> void:
	if _closing:
		return   # 같은 판에서 두 번 불릴 일은 없지만, 해제 연출이 되감기지 않게 막는다
	_closing = true
	_close_t = 0.0


func _draw() -> void:
	var r := current_radius()
	var fade := (1.0 - clampf(_close_t / CLOSE_TIME, 0.0, 1.0)) if _closing else 1.0
	# 경계선 — 맥동 + 플레이어가 붙을수록 밝아진다("여기가 벽이다").
	var a := clampf(0.5 + 0.2 * sin(_pulse * 3.0) + 0.3 * _near, 0.0, 1.0) * fade
	draw_arc(Vector2.ZERO, r, 0.0, TAU, SEGMENTS, Color(COLOR.r, COLOR.g, COLOR.b, a), 5.0, true)
	# 안쪽 띠 — 벽이 두께로 읽히게.
	draw_arc(Vector2.ZERO, r - 9.0, 0.0, TAU, SEGMENTS,
			Color(COLOR.r, COLOR.g, COLOR.b, (0.10 + 0.26 * _near) * fade), 16.0, true)
	# 구역 눈금 — 세로 화면에선 원의 좌우가 화면 밖이라, 천천히 도는 눈금으로 "갇혔다"를 알린다.
	for i in range(12):
		var dir := Vector2.from_angle(TAU * float(i) / 12.0 + _pulse * 0.15)
		draw_line(dir * (r - 26.0), dir * r, Color(COLOR.r, COLOR.g, COLOR.b, 0.5 * fade), 3.0, true)
