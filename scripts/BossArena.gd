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
## 이 게임의 규칙에도 어긋난다. 대신 아트로 "닿으면 아프다"를 말한다 — 노랑·검정 경고 줄무늬
## 레일 사이로 흐르는 고압 전류 밴드 + 감전 경고판을 단 파일런, 그리고 닿는 순간의 스파크.
## 노랑/검정 경고 줄무늬는 이 게임의 다른 위협 표식(주황·빨강·초록)과 겹치지 않아,
## 공격 텔레그래프와 헷갈리지 않으면서도 "위험"으로 즉시 읽힌다(기존 prop_barrier 와 같은 언어).

const _FXBurst := preload("res://scripts/FXBurst.gd")
## 경계 아트는 파일런(감전 경고 기둥) 한 장뿐이고, 기둥 사이는 코드로 그린 전기선으로 잇는다.
## 띠 텍스처를 호를 따라 반복해 두르는 방식을 먼저 썼는데, 같은 그림이 이어 붙는 이음매가 드러나
## 전기 울타리가 아니라 굵은 밧줄처럼 보였다. 선으로 잇는 쪽이 이음매가 없고, 지직거리는 애니메이션도
## 공짜로 얻는다(FXLightning 과 같은 "넓은 글로우 → 얇은 흰 코어" 겹치기).
const _PYLON := preload("res://assets/sprites/arena_pylon.png")

const OPEN_TIME := 0.5       # 전개 연출: 넓은 원에서 제 크기로 조여든다
const OPEN_SCALE := 1.4      # 전개 시작 반경 배수
const CLOSE_TIME := 0.45     # 보스 처치 후 해제 연출
const NEAR_BAND := 90.0      # 경계에서 이 거리 안이면 "붙었다"로 보고 더 밝게 그린다
const PYLON_GAP := 165.0     # 기둥 간격 = 전기선 한 칸의 길이
## 전선은 2단이다 — 한 줄만 걸면 울타리가 아니라 빨랫줄로 보인다. 위쪽이 기둥 단자에 걸리는 본선.
const WIRE_Y := -60.0        # 본선 높이(기둥 위 방전 단자). 기둥 밑동은 경계선 위에 선다
const WIRE_Y2 := -32.0       # 아래 보조선
const WIRE_KINKS := 6        # 한 칸에 들어가는 꺾임 수
const WIRE_JITTER := 4.0     # 꺾임 폭. 크게 잡으면 팽팽한 전선이 아니라 번개 리본이 된다
const FLICKER_HZ := 12.0     # 지직거림 갱신 빈도(매 프레임 흔들면 노이즈로 보인다)
## 경고 노랑 — 스파크·전개 연출 등 코드로 그리는 부분을 파일런의 경고 줄무늬 색에 맞춘다.
const COLOR := Color(1.0, 0.72, 0.15)
const ZAP_INTERVAL := 0.22   # 경계에 닿아 있는 동안 스파크가 튀는 간격

var radius: float = 620.0

var _t: float = 0.0          # 전개 경과
var _closing: bool = false
var _close_t: float = 0.0
var _pulse: float = 0.0
var _near: float = 0.0       # 플레이어가 경계에 붙은 정도(0~1)
var _zap_cd: float = 0.0     # 접촉 스파크 쿨다운


## 지정 위치를 중심으로 구역을 전개한다. 보스 처치(Events.boss_died) 시 스스로 사라진다.
static func spawn(parent: Node, center: Vector2, p_radius: float) -> Node2D:
	var a = (load("res://scripts/BossArena.gd") as GDScript).new()
	a.radius = p_radius
	parent.add_child(a)
	a.global_position = center
	return a


func _ready() -> void:
	add_to_group("boss_arena")   # 자동플레이 조종 AI 가 경계를 피하려고 찾는다
	# 지면 위·유닛 아래(GroundHazard 와 같은 층). Main 씬의 층은 배경 -3 · 바닥 -2 · 프롭 -1 이라
	# 이 값이 -3 이하로 내려가면 배경 ColorRect 에 통째로 덮여 화면에서 사라진다(실제로 그랬다).
	z_index = -1
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
		var hit := global_position + to_p / d * r
		player.global_position = hit
		_zap(hit)


## 경계에 밀린 순간의 감전 연출 — 피해는 없지만 "닿으면 아프다"를 몸으로 알린다.
## 벽을 따라 계속 문지르면 매 프레임 터지므로 간격을 둔다(FX 상한·소리 폭주 방지).
func _zap(at: Vector2) -> void:
	if _zap_cd > 0.0:
		return
	_zap_cd = ZAP_INTERVAL
	_FXBurst.spawn(get_tree().current_scene, at, Color(1.0, 0.95, 0.6), 46.0, 0.22)
	SoundManager.play("tesla_arc", 0.15, 1.25)
	Events.shake(2.0)


func _process(delta: float) -> void:
	_pulse += delta
	_zap_cd = maxf(0.0, _zap_cd - delta)
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
	# 전류가 흐르는 느낌 — 맥동에 더해 플레이어가 붙을수록 밝아진다("여기가 벽이다").
	var hot := clampf(0.86 + 0.09 * sin(_pulse * 7.0) + 0.15 * _near, 0.0, 1.2)

	var pn: int = maxi(6, int(round(TAU * r / PYLON_GAP)))

	# ── 경계선(지면) — 기둥이 서 있는 실제 경계. 전기선은 기둥 높이에 걸리므로,
	# 발이 어디서 막히는지는 이 얇은 선이 알려준다.
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 72,
			Color(COLOR.r, COLOR.g, COLOR.b, (0.20 + 0.20 * _near) * fade), 2.0, true)

	# ── 전기선 — 기둥 단자를 잇는 한 줄 폐곡선. 통째로 한 번에 그려 이음매가 없다.
	# FXLightning 과 같은 겹치기: 넓고 흐린 글로우 → 중간 → 얇고 흰 코어. 글로우를 아끼면
	# 코어만 남아 흰 줄 하나로 보인다 — 방전으로 읽히는 건 바깥의 주황 번짐 쪽이다.
	var low := _wire_points(r, pn, WIRE_Y2, 53)
	draw_polyline(low, Color(1.0, 0.35, 0.03, 0.22 * hot * fade), 10.0, true)
	draw_polyline(low, Color(1.0, 0.88, 0.40, 0.70 * hot * fade), 1.6, true)

	var wire := _wire_points(r, pn, WIRE_Y, 0)
	draw_polyline(wire, Color(1.0, 0.30, 0.02, 0.30 * hot * fade), 17.0, true)
	draw_polyline(wire, Color(1.0, 0.55, 0.06, 0.55 * hot * fade), 9.0, true)
	draw_polyline(wire, Color(1.0, 0.85, 0.30, 0.85 * hot * fade), 4.0, true)
	draw_polyline(wire, Color(1.0, 1.0, 0.90, 1.0 * hot * fade), 1.6, true)
	# 방전 마디 — 몇 군데만 골라 밝게 튀긴다(전부 찍으면 점선처럼 보인다).
	var flick := int(_pulse * FLICKER_HZ)
	for i in range(wire.size()):
		if (i + flick) % 9 != 0:
			continue
		var p: Vector2 = wire[i]
		draw_circle(p, 5.0, Color(1.0, 0.7, 0.2, 0.32 * fade))
		draw_circle(p, 2.0, Color(1.0, 1.0, 0.92, 0.9 * fade))

	# ── 경고 파일런 — 밑동이 경계선 위에 놓이도록 세운다(다른 프롭과 같은 규약).
	var psz: Vector2 = _PYLON.get_size()
	for i in range(pn):
		var p := Vector2.from_angle(TAU * float(i) / float(pn)) * r
		draw_texture(_PYLON, p - Vector2(psz.x * 0.5, psz.y), Color(1, 1, 1, fade))


## 기둥 단자를 잇는 지직거리는 전기선. 기둥 위치는 고정점이고 그 사이만 흔들린다 —
## 선이 기둥에서 떨어져 보이면 "매달려 있다"는 인상이 깨진다.
func _wire_points(r: float, n: int, y: float, seed: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var step := TAU / float(n)
	var flick := int(_pulse * FLICKER_HZ)   # 이 값이 바뀔 때만 꺾임이 새로 잡힌다
	var lift := Vector2(0.0, y)
	for i in range(n):
		pts.append(Vector2.from_angle(step * float(i)) * r + lift)
		for k in range(1, WIRE_KINKS + 1):
			var f := float(k) / float(WIRE_KINKS + 1)
			var dir := Vector2.from_angle(step * (float(i) + f))
			pts.append(dir * (r + _jitter(i + seed, k, flick) * WIRE_JITTER)
					+ lift + Vector2(0.0, _jitter(i + seed, k + 91, flick) * WIRE_JITTER))
	pts.append(Vector2.from_angle(0.0) * r + lift)   # 시작 기둥으로 닫는다
	return pts


## 정수 삼중항 → -1~1. 프레임마다 randf() 를 쓰면 선 전체가 매 프레임 다시 뽑혀 노이즈가 되므로,
## flick 단계가 같은 동안에는 같은 모양이 유지되도록 해시로 만든다.
func _jitter(a: int, b: int, c: int) -> float:
	var h: int = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	return float(h & 0xFFFF) / 32767.5 - 1.0
