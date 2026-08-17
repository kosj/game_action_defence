extends Node2D
## 시간 경과 연출 — 경과 시간으로 아레나 전체를 물들이는 낮/밤 순환.
##
## 구동원은 Events.elapsed_time 하나뿐이다(자체 타이머를 두지 않는다). 그 값이 이미 세이브에
## 들어 있어 이어하기가 저절로 맞고, Cheats.time_skip 도 따라오며, 히트스톱(Engine.time_scale)이나
## 일시정지와 어긋날 여지가 없다.
##
## 순환 주기 = DifficultyData.boss_seconds(하드코딩 금지 규칙). 가장 어두운 지점 u=0(≡1)이
## 정확히 보스 등장 시각(600/1200/1800초)에 떨어지고 그 직후 동이 튼다 — 밤이 깊을수록 보스가
## 오고, 보스를 잡는 동안 해가 뜬다. 주기가 보스 주기와 같으므로 t=0 도 같은 위상이다:
## 게임은 한밤에 시작해 40초 안에 일출로 밝아진다(초반 5초는 스폰 유예라 가독성 부담이 없다).
##
## 색은 CanvasModulate 로 곱한다. HUD/LevelUpPanel/ShopPanel/SceneFade 는 전부 CanvasLayer 라
## 이 곱연산이 닿지 않는다 — 월드만 물들고 UI 는 원색을 유지한다.

## 순환 키프레임 [u, 곱연산 색]. u=0.00 과 u=1.00 이 같은 색이어야 순환 이음매가 튀지 않는다.
const KEYS: Array = [
	[0.00, Color(0.62, 0.66, 0.92)],   # 한밤 — 가장 어두움(= 보스 등장 시각)
	[0.07, Color(0.86, 0.72, 0.78)],   # 여명
	[0.14, Color(1.00, 0.90, 0.82)],   # 일출(따뜻한 저각도 빛)
	[0.26, Color(1.00, 0.99, 0.96)],   # 아침
	[0.45, Color(1.00, 1.00, 1.00)],   # 한낮 — 무보정 기준값
	[0.60, Color(1.00, 0.97, 0.90)],   # 오후
	[0.72, Color(1.00, 0.80, 0.60)],   # 해질녘
	[0.86, Color(0.80, 0.74, 0.92)],   # 땅거미
	[1.00, Color(0.62, 0.66, 0.92)],   # 한밤(= 0.00)
]

## 가독성 하한. 바닥은 이미 Ground.TILE_DARKEN(0.55)으로 깔려 있어, 여기서 이 밑으로 더 내리면
## 좀비 실루엣과 탄이 죽는다. 날씨 틴트까지 곱한 "최종" 색에 적용한다.
const LUMA_FLOOR := 0.62

## 달빛 헤일로 — 밤에 플레이어 주변만 들어올려 전투 반경 가독성을 지킨다.
## PointLight2D 를 쓰지 않는 이유: 2D 라이트는 조명 대상 CanvasItem 을 라이트마다 다시 그린다.
## 좀비 상한이 320마리인 이 게임에서는 드로우콜이 배로 뛴다 — 가산 쿼드 1장이면 비용은 1.
const HALO_RADIUS := 460.0
const HALO_ALPHA := 0.18
## 달빛 색 — 순백으로 더하면 잔디 위에서 초록만 증폭돼 스포트라이트처럼 뜬다. 푸른 기를 넣어
## 달빛으로 읽히게 하고, 넓고 옅게 깔아 경계가 드러나지 않게 한다.
const MOON := Color(0.72, 0.82, 1.00)

## 밤 강도 판정 구간(기준 틴트의 휘도 → 0=낮, 1=한밤).
const NIGHT_FROM := 0.95
const NIGHT_TO := 0.68

## 앰비언트 입자(Main.gd 가 만든 티끌)를 밤에 따뜻한 반딧불 톤으로 옮긴다.
const FIREFLY := Color(1.0, 0.85, 0.45)

## 치트(CHEATS > DAY/NIGHT)로 시간 처리를 껐을 때 쓰는 고정 시간 틴트 — 한낮(무보정).
## 날씨 틴트는 계속 곱한다. 치트가 끄는 것은 "시간"뿐이라 비/안개는 그대로 보여야 한다.
const CHEAT_OFF_TINT := Color.WHITE

var _mod: CanvasModulate = null
var _halo: Sprite2D = null
var _player: Node2D = null
var _ambient: CPUParticles2D = null
var _ambient_day: Color = Color.WHITE

## 순환 주기(초). _ready 에서 난이도 데이터의 보스 주기로 채운다.
var _cycle: float = 600.0

## 날씨 시스템이 써 넣는 곱연산 틴트(맑음이면 흰색). 시간 틴트와 곱해 한 번에 반영한다.
var _weather_tint: Color = Color.WHITE

## 마지막으로 CanvasModulate 에 기록한 색 — 변화가 미미하면 쓰기를 건너뛴다.
var _applied := Color(-1.0, -1.0, -1.0)


func _ready() -> void:
	add_to_group("daynight")
	var d: DifficultyData = GameData.difficulty
	if d != null and d.boss_seconds > 1.0:
		_cycle = d.boss_seconds
	_mod = CanvasModulate.new()
	add_child(_mod)
	_build_halo()
	_player = get_tree().get_first_node_in_group("player")
	# 치트 토글은 일시정지 메뉴에서 눌린다 — 그때는 _process 가 멈춰 있어 신호로 즉시 반영해야
	# 패널을 닫기 전에 화면이 바뀐 것을 볼 수 있다.
	Cheats.changed.connect(_on_cheats_changed)
	_apply(Events.elapsed_time)


func _on_cheats_changed() -> void:
	_apply(Events.elapsed_time)


## 날씨 시스템 전용 진입점 — 곱연산 틴트를 넘기면 다음 프레임부터 시간 틴트와 합성된다.
func set_weather_tint(c: Color) -> void:
	_weather_tint = c


## Rec.709 상대 휘도.
static func luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## 경과 시간 → 시간대 틴트(날씨 미포함). 순수 함수 — 검증 스크립트가 직접 호출한다.
func tint_at(elapsed: float) -> Color:
	var u := fposmod(elapsed, _cycle) / _cycle
	for i in range(KEYS.size() - 1):
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		var u0: float = a[0]
		var u1: float = b[0]
		if u <= u1:
			var t := 0.0 if u1 <= u0 else (u - u0) / (u1 - u0)
			return (a[1] as Color).lerp(b[1] as Color, clampf(t, 0.0, 1.0))
	return KEYS[KEYS.size() - 1][1]


## 시간 틴트 × 날씨 틴트에 가독성 하한을 씌운 최종 색. 순수 함수(검증용).
func composed_at(elapsed: float, weather: Color) -> Color:
	return with_luma_floor(tint_at(elapsed) * weather)


## 가독성 하한 보정 — 휘도가 하한 밑이면 채널을 비례 확대한다.
static func with_luma_floor(c: Color) -> Color:
	var l := luma(c)
	if l >= LUMA_FLOOR or l <= 0.0001:
		return c
	var k := LUMA_FLOOR / l
	return Color(c.r * k, c.g * k, c.b * k)


## 밤 강도 0~1 — 헤일로/앰비언트 색 전환에 쓴다.
func night_amount(elapsed: float) -> float:
	return clampf(inverse_lerp(NIGHT_FROM, NIGHT_TO, luma(tint_at(elapsed))), 0.0, 1.0)


func _process(_delta: float) -> void:
	_apply(Events.elapsed_time)


func _apply(elapsed: float) -> void:
	# 치트로 시간 처리를 끄면 시간 틴트만 한낮으로 고정한다 — 날씨 틴트와 가독성 하한은 그대로.
	var on: bool = Cheats.daynight
	var c := composed_at(elapsed, _weather_tint) if on else with_luma_floor(CHEAT_OFF_TINT * _weather_tint)
	# 색이 사실상 그대로면 쓰기를 건너뛴다(한낮·한밤 구간에서는 몇 초씩 정체된다).
	if absf(c.r - _applied.r) + absf(c.g - _applied.g) + absf(c.b - _applied.b) > 0.002:
		_applied = c
		if _mod != null:
			_mod.color = c
	# 시간 처리를 끈 동안은 항상 낮 — 달빛 헤일로와 반딧불 앰비언트도 함께 꺼진다.
	var n := night_amount(elapsed) if on else 0.0
	if _halo != null:
		if not is_instance_valid(_player):
			_player = get_tree().get_first_node_in_group("player")
		if is_instance_valid(_player):
			_halo.visible = n > 0.01
			_halo.global_position = _player.global_position
			# CanvasModulate 는 헤일로에도 곱해진다 — 그만큼 되밀어 밤에도 세기가 유지되게 한다.
			var comp := 1.0 / maxf(0.4, luma(c))
			_halo.modulate = Color(MOON.r * comp, MOON.g * comp, MOON.b * comp, n * HALO_ALPHA)
		else:
			_halo.visible = false
	_tint_ambient(n)


## Main.gd 가 뿌린 앰비언트 티끌을 밤에는 반딧불 톤으로 옮긴다(노드 재사용, 신규 생성 없음).
func _tint_ambient(n: float) -> void:
	if not is_instance_valid(_ambient):
		_ambient = get_tree().get_first_node_in_group("ambient_fx") as CPUParticles2D
		if _ambient == null:
			return
		_ambient_day = _ambient.color
	var target := _ambient_day.lerp(Color(FIREFLY.r, FIREFLY.g, FIREFLY.b, minf(_ambient_day.a * 1.5, 1.0)), n)
	if not _ambient.color.is_equal_approx(target):
		_ambient.color = target


## 소프트 radial 그라디언트를 런타임 생성(신규 아트 없음) → 가산 블렌드 쿼드 1장.
func _build_halo() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	var s := Sprite2D.new()
	s.texture = t
	s.scale = Vector2.ONE * (HALO_RADIUS * 2.0 / 128.0)
	s.z_index = -1          # 바닥 위·유닛 아래 — 지면에 빛이 고인 것처럼 보이게
	s.modulate = Color(1, 1, 1, 0)
	s.visible = false
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	add_child(s)
	_halo = s
