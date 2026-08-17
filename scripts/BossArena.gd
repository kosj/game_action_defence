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
## 경계 아트. field = 경고 레일 사이를 흐르는 전류 밴드(호를 따라 반복), pylon = 감전 경고
## 파일런(일정 간격으로 세운다). 둘 다 마젠타 키잉 파이프라인으로 만든 것(BOSS_PLAN 11장).
const _FIELD := preload("res://assets/sprites/arena_field.png")
const _PYLON := preload("res://assets/sprites/arena_pylon.png")

const OPEN_TIME := 0.5       # 전개 연출: 넓은 원에서 제 크기로 조여든다
const OPEN_SCALE := 1.4      # 전개 시작 반경 배수
const CLOSE_TIME := 0.45     # 보스 처치 후 해제 연출
const NEAR_BAND := 90.0      # 경계에서 이 거리 안이면 "붙었다"로 보고 더 밝게 그린다
const TILE_ARC := 180.0      # 전류 밴드 한 장이 덮는 호 길이. 좁히면 번개가 뭉개져 통짜 띠로 보인다
const TILE_FACETS := 3       # 한 장을 이 수만큼 쪼개 곡률을 낸다(각지지 않게)
const PYLON_GAP := 260.0     # 파일런 간격
## 경고 노랑 — 스파크·전개 연출 등 코드로 그리는 부분을 아트의 레일 색에 맞춘다.
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
	var tint := Color(hot, hot, hot, fade)

	# ── 전류 밴드 — 아트 한 장을 호를 따라 반복해 두른다 ──────────────────
	# 한 장을 TILE_FACETS 개의 사각 조각으로 쪼개 곡률을 낸다. 조각 하나가 통짜면 반경이 커서
	# 원이 각져 보이고, 반대로 잘게 쪼개면 draw_polygon 호출 수만 늘어난다.
	var tiles: int = maxi(8, int(round(TAU * r / TILE_ARC)))
	var facets: int = tiles * TILE_FACETS
	var half_h := float(_FIELD.get_height()) * 0.5
	var cols := PackedColorArray([tint, tint, tint, tint])
	var step := TAU / float(facets)
	for i in range(facets):
		var a0 := step * float(i)
		var a1 := a0 + step
		var d0 := Vector2.from_angle(a0)
		var d1 := Vector2.from_angle(a1)
		# 이 조각이 아트에서 차지하는 가로 구간(0~1). 조각이 타일 경계를 넘지 않도록
		# facets 를 tiles 의 배수로 잡았다 — 넘으면 UV 가 잘려 이음매가 생긴다.
		var u0 := float(i % TILE_FACETS) / float(TILE_FACETS)
		var u1 := u0 + 1.0 / float(TILE_FACETS)
		draw_polygon(
			PackedVector2Array([d0 * (r - half_h), d1 * (r - half_h),
					d1 * (r + half_h), d0 * (r + half_h)]),
			cols,
			PackedVector2Array([Vector2(u0, 0.0), Vector2(u1, 0.0),
					Vector2(u1, 1.0), Vector2(u0, 1.0)]),
			_FIELD)

	# ── 경고 파일런 — 밴드 위에 일정 간격으로 세운다(감전 경고판·빨간 경광등) ──
	# 스프라이트는 세워서 그린다: 밑동이 링 위에 놓이도록 위로 올려 배치(다른 프롭과 같은 규약).
	var pn: int = maxi(6, int(round(TAU * r / PYLON_GAP)))
	var psz: Vector2 = _PYLON.get_size()
	for i in range(pn):
		var p := Vector2.from_angle(TAU * float(i) / float(pn)) * r
		draw_texture(_PYLON, p - Vector2(psz.x * 0.5, psz.y), Color(1, 1, 1, fade))
