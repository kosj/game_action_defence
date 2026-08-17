extends Node2D
## 날씨 연출 — 일정 주기(슬롯)마다 선택 테마의 날씨를 하나 뽑아 페이드 인/아웃 한다.
##
## **연출 전용이다.** 이동속도·명중률·피해량 등 어떤 전투 수치도 건드리지 않는다.
##
## 스케줄은 결정론적이다: Events.env_seed(런마다 발급·세이브됨) + 슬롯 인덱스로만 결정되는
## 순수 함수라, 이어하기가 같은 날씨 타임라인을 그대로 복원하고 헤드리스 검증이 가능하다.
##
## 예산: 날씨 이미터 1개(하드 캡) + 비 전용 착지 파문 이미터 1개. 파문은 비가 아닐 때 emitting=false
## 라 비용이 0 이고, 동시에 도는 이미터는 어떤 경우에도 2개를 넘지 않는다.
## 노드가 플레이어를 따라다니며 local_coords=false 로 입자를 월드에 남긴다 — 이동해도 화면이
## 계속 채워지고, 특히 파문이 바닥에 못 박혀 카메라를 따라 끌려다니지 않는다.

const SLOT := 75.0        # 날씨 슬롯 길이(초) — 이 경계에서만 날씨가 바뀐다
const FADE := 5.0         # 슬롯 경계 페이드 인/아웃(갑자기 비가 켜지지 않게)
const CLEAR_WEIGHT := 34  # '맑음' 가중치(%). 나머지 66% 를 테마 날씨가 균등 분배한다
const HAZE_MARGIN := 240.0   # 안개/섬광 판이 화면 밖까지 덮는 여유(카메라 흔들림 대비)

## 번개(비 전용) — 간헐적 섬광 + 천둥.
const BOLT_MIN := 7.0
const BOLT_MAX := 16.0
const BOLT_FLASH := 0.5   # 섬광 알파 피크
const BOLT_DECAY := 3.0   # 초당 감쇠

## 날씨 정의.
##   tint     = 시간 틴트에 곱할 색(어둡게/따뜻하게)
##   haze     = 화면 전체를 덮는 옅은 판의 알파 — 시야가 뿌예지는 날씨(안개·모래바람·눈)에만
##   haze_col = 그 판의 색조. 모래바람은 따뜻한 황토빛이라야 '먼지'로 읽힌다
const _DEF: Dictionary = {
	"rain": {"tint": Color(0.80, 0.84, 0.92), "haze": 0.00, "haze_col": Color(1.00, 1.00, 1.00), "bolt": true},
	"snow": {"tint": Color(0.92, 0.95, 1.00), "haze": 0.06, "haze_col": Color(1.00, 1.00, 1.00), "bolt": false},
	"fog":  {"tint": Color(0.90, 0.91, 0.94), "haze": 0.14, "haze_col": Color(1.00, 1.00, 1.00), "bolt": false},
	"dust": {"tint": Color(1.00, 0.88, 0.70), "haze": 0.12, "haze_col": Color(1.00, 0.80, 0.52), "bolt": false},
}

var _keys: PackedStringArray = PackedStringArray()   # 이 테마에서 나올 수 있는 날씨
var _player: Node2D = null
var _day: Node = null            # DayNightCycle — 합성 틴트를 여기에 넘긴다
var _emitter: CPUParticles2D = null
## 빗방울 착지 파문 — 비일 때만 켜지는 보조 이미터(지면 레벨). 다른 날씨에서는 항상 꺼져 있다.
var _splash: CPUParticles2D = null
var _streak_tex: Texture2D = null
var _soft_tex: Texture2D = null
var _ring_tex: Texture2D = null

var _slot: int = -1
var _key: String = ""
## 확정된 날씨 시퀀스 캐시(슬롯 0부터). 시드 **또는 테마 날씨 목록**이 바뀌면 버린다 —
## 시퀀스는 둘 다에 의존하므로 시드만 보고 재사용하면 다른 테마의 날씨가 새어 나온다.
var _seq: Array = []
var _seq_sig: String = ""
var _haze_base: float = 0.0
var _haze_col: Color = Color.WHITE
var _flash: float = 0.0
var _bolt_cd: float = 0.0
var _haze_vp := Vector2.ZERO


func _ready() -> void:
	z_index = 54   # 유닛(0)·FX(1~3) 앞, DamageNumber(60) 뒤 — 대미지 숫자는 비를 뚫고 읽힌다
	var t: ThemeData = ThemeManager.selected()
	if t != null:
		for k in t.weather_keys:
			if _DEF.has(k):
				_keys.append(k)
	_player = get_tree().get_first_node_in_group("player")
	_day = get_tree().get_first_node_in_group("daynight")
	_streak_tex = _make_streak()
	_soft_tex = _make_soft()
	_ring_tex = _make_ring()
	_build_emitter()
	_build_splash()
	# 치트 토글은 일시정지 메뉴에서 눌린다 — 그때는 _process 가 멈춰 있어 신호로 즉시 반영해야
	# 패널을 닫기 전에 비/안개가 사라진 것을 볼 수 있다.
	Cheats.changed.connect(_on_cheats_changed)


func _on_cheats_changed() -> void:
	_process(0.0)


## ── 스케줄(순수 함수) ────────────────────────────────────────────────────

func slot_of(elapsed: float) -> int:
	return int(floor(maxf(0.0, elapsed) / SLOT))


## 슬롯 안에서의 세기 0~1 — 경계에서 정확히 0 이라 날씨 교체 순간의 팝이 보이지 않는다.
func strength_at(elapsed: float) -> float:
	var t := fposmod(maxf(0.0, elapsed), SLOT)
	if t < FADE:
		return t / FADE
	if t > SLOT - FADE:
		return (SLOT - t) / FADE
	return 1.0


## 슬롯 → 날씨 키("" = 맑음). Events.env_seed 와 슬롯 인덱스만으로 결정된다.
##
## 시퀀스를 0번 슬롯부터 순서대로 확정해 캐시한다. "이전 슬롯의 최종 결과"를 알아야 연속 반복을
## 제대로 막을 수 있기 때문이다(이전 슬롯의 기본 롤과 비교하면, 그 슬롯이 재롤된 경우 비교 대상이
## 틀려 반복이 새어 나간다). 30분 런의 슬롯 수는 24개라 처음부터 훑어도 비용이 없다.
func weather_for_slot(slot: int) -> String:
	if slot < 0 or _keys.is_empty():
		return ""
	var sig := "%d|%s" % [Events.env_seed, "/".join(_keys)]
	if _seq_sig != sig:
		_seq_sig = sig
		_seq.clear()
	while _seq.size() <= slot:
		var i := _seq.size()
		var pick := _roll(i)
		# 같은 날씨가 두 슬롯 연속 이어지지 않게 1회 재롤. 맑음은 예외로 둔다 — 연속으로 맑은 건
		# 자연스럽고, 재롤 결과에 맑음을 섞으면 전체 맑음 비율이 CLEAR_WEIGHT 에서 밀린다.
		if pick != "" and i > 0 and pick == String(_seq[i - 1]):
			pick = _reroll(i, String(_seq[i - 1]))
		_seq.append(pick)
	return String(_seq[slot])


func _roll(slot: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = Events.env_seed ^ (slot * 0x9E3779B1)
	var r := rng.randi_range(0, 99)
	if r < CLEAR_WEIGHT:
		return ""
	return _keys[((r - CLEAR_WEIGHT) * _keys.size()) / (100 - CLEAR_WEIGHT)]


## 직전 날씨를 뺀 나머지 중에서 다시 뽑는다 — 맑음을 섞지 않으므로 맑음 비율이 그대로 보존된다.
## 테마 날씨가 1종뿐이면 피할 곳이 없어 맑음으로 넘긴다(현재 모든 테마는 2종 이상).
func _reroll(slot: int, prev: String) -> String:
	var alts: PackedStringArray = PackedStringArray()
	for k in _keys:
		if k != prev:
			alts.append(k)
	if alts.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = Events.env_seed ^ (slot * 0x9E3779B1) ^ 0x85EBCA6B
	return alts[rng.randi_range(0, alts.size() - 1)]


## ── 구동 ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(_player):
		global_position = _player.global_position
	if not is_instance_valid(_day):
		_day = get_tree().get_first_node_in_group("daynight")
	var elapsed: float = Events.elapsed_time
	var s := slot_of(elapsed)
	if s != _slot:
		_slot = s
		_switch(weather_for_slot(s))
	# 치트(CHEATS > WEATHER)로 날씨를 끄면 세기를 0 으로 눌러 입자·안개 판·틴트·번개가 한꺼번에
	# 사라진다(=상시 맑음). 슬롯 스케줄과 _key 는 그대로 굴러가므로 결정론·이어하기가 유지되고,
	# 다시 켜면 그 시점에 원래 와야 할 날씨가 이어진다.
	var strength := strength_at(elapsed) if (_key != "" and Cheats.weather) else 0.0
	if _emitter != null:
		_emitter.emitting = _key != "" and strength > 0.01
		_emitter.modulate.a = strength
	if _splash != null:
		_splash.emitting = _key == "rain" and strength > 0.01
		_splash.modulate.a = strength
	_tick_bolt(delta, strength)
	if _day != null and _day.has_method("set_weather_tint"):
		_day.call("set_weather_tint", Color.WHITE.lerp(_tint_of(_key), strength))
	# 번개 섬광은 날씨 색조와 무관하게 흰빛이어야 하므로, 섬광 세기만큼 흰색으로 당긴다.
	var hc := _haze_col.lerp(Color.WHITE, clampf(_flash / BOLT_FLASH, 0.0, 1.0)) if _flash > 0.0 else _haze_col
	self_modulate = Color(hc.r, hc.g, hc.b, clampf(_haze_base * strength + _flash, 0.0, 1.0))
	_sync_haze_size()


func _tint_of(key: String) -> Color:
	return _DEF[key]["tint"] if _DEF.has(key) else Color.WHITE


## 비가 충분히 세게 올 때만 간헐적으로 번개가 친다.
func _tick_bolt(delta: float, strength: float) -> void:
	if _flash > 0.0:
		# 세기가 0 이면(맑음·슬롯 경계·날씨 치트 OFF) 잔광을 즉시 지운다 — 치트로 끈 순간
		# 화면에 섬광 잔상이 남아 있으면 "꺼졌다"로 읽히지 않는다.
		_flash = 0.0 if strength <= 0.0 else maxf(0.0, _flash - delta * BOLT_DECAY)
	if not bool(_DEF.get(_key, {}).get("bolt", false)) or strength < 0.6:
		return
	_bolt_cd -= delta
	if _bolt_cd <= 0.0:
		_bolt_cd = randf_range(BOLT_MIN, BOLT_MAX)
		_flash = BOLT_FLASH
		SoundManager.play("lightning", 0.15, 0.75)


func _switch(key: String) -> void:
	if key == _key:
		return
	_key = key
	_haze_base = float(_DEF.get(key, {}).get("haze", 0.0))
	_haze_col = _DEF.get(key, {}).get("haze_col", Color.WHITE)
	_bolt_cd = randf_range(BOLT_MIN * 0.4, BOLT_MAX * 0.6)
	if _emitter != null:
		_configure(key)
	# 날씨를 꺼 둔 동안에는 화면에 아무것도 안 바뀌므로 전환 배너도 띄우지 않는다.
	if Cheats.weather:
		Events.weather_changed.emit(key)


## ── 파티클 ───────────────────────────────────────────────────────────────

func _build_emitter() -> void:
	var p := CPUParticles2D.new()
	p.z_index = 1               # 부모(54) 기준 상대 → 실효 55. 안개 판(54)보다 앞
	p.local_coords = false      # 방출된 입자는 월드에 남는다(이동해도 끌려다니지 않음)
	p.emitting = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	add_child(p)
	_emitter = p
	_configure("")


## 빗방울이 지면에 닿아 잔잔히 퍼지는 파문. 별도 이미터인 이유:
##  - 빗줄기와 수명·크기 곡선·그리는 깊이가 전혀 다르다(파문은 지면, 빗줄기는 유닛 앞).
##  - `local_coords=false` 로 월드에 못 박혀야 파문이 바닥에 고정돼 보인다. 카메라가 따라와도
##    파문이 끌려다니면 즉시 가짜로 읽힌다.
## 비가 아닐 때는 emitting=false 라 비용이 0 이다.
func _build_splash() -> void:
	var p := CPUParticles2D.new()
	# 지면 레벨(-1)에 고정 — 부모(54) 상대 계산을 피하려고 절대 z 로 둔다. 유닛(0) 아래라
	# 파문이 플레이어·좀비 발밑에 깔린다.
	p.z_as_relative = false
	p.z_index = -1
	p.local_coords = false
	p.emitting = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.texture = _ring_tex
	p.amount = 24
	p.lifetime = 0.7
	p.preprocess = 0.7
	p.explosiveness = 0.0
	p.direction = Vector2(0, -1)
	p.spread = 0.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 0.0     # 파문은 퍼질 뿐 흐르지 않는다
	p.initial_velocity_max = 0.0
	p.scale_amount_min = 0.55
	p.scale_amount_max = 1.05
	p.color = Color(0.80, 0.90, 1.00, 1.0)
	# 작게 시작해 퍼지고, 뜨자마자 옅어진다 — "잔잔하게".
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.18))
	sc.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = sc
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.22, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
	p.color_ramp = ramp
	var vp := get_viewport().get_visible_rect().size
	p.emission_rect_extents = Vector2(vp.x * 0.62, vp.y * 0.62)
	add_child(p)
	_splash = p


func _configure(key: String) -> void:
	var vp := get_viewport().get_visible_rect().size
	# 방출 사각형이 화면보다 지나치게 크면 입자 대부분이 화면 밖에 있어, 같은 개수를 쓰고도
	# 눈에 보이는 밀도가 절반 이하로 떨어진다. 화면의 1.24배까지만 잡아(가장자리 12% 여유)
	# 예산은 그대로 두고 체감 밀도를 올린다. 안개만 예외 — 덩어리가 256~512px 라 여유가 더 필요.
	var ext := 0.85 if key == "fog" else 0.62
	_emitter.emission_rect_extents = Vector2(vp.x * ext, vp.y * ext)
	_emitter.gravity = Vector2.ZERO
	_emitter.angular_velocity_min = 0.0
	_emitter.angular_velocity_max = 0.0
	_emitter.angle_min = 0.0
	_emitter.angle_max = 0.0
	match key:
		"rain":
			# 거의 수직으로 떨어뜨린다(화살비). 예전 0.30 기울기는 16.7°나 돼서, 플레이어가
			# 가로로 달릴 때 화면상 비가 옆으로 흐르는 것처럼 읽혔다. 살짝만 눕혀 기계적으로
			# 보이지 않을 정도(4.6°)만 남기고, 대신 줄을 길고 빠르게 해 낙하감을 준다.
			var dir := Vector2(0.08, 1.0).normalized()
			_emitter.texture = _streak_tex
			_emitter.amount = 90
			_emitter.lifetime = 1.1
			_emitter.preprocess = 1.0
			_emitter.direction = dir
			_emitter.spread = 2.0
			_emitter.initial_velocity_min = 1150.0
			_emitter.initial_velocity_max = 1500.0
			_emitter.scale_amount_min = 1.4
			_emitter.scale_amount_max = 2.4
			_emitter.color = Color(0.72, 0.82, 1.00, 0.72)
			# 세로 스트릭 텍스처를 낙하 방향에 맞춰 눕힌다.
			var ang := -rad_to_deg(atan2(dir.x, dir.y))
			_emitter.angle_min = ang
			_emitter.angle_max = ang
		"snow":
			_emitter.texture = _soft_tex
			_emitter.amount = 90
			_emitter.lifetime = 6.0
			_emitter.preprocess = 3.0
			_emitter.direction = Vector2(0.25, 1.0).normalized()
			_emitter.spread = 25.0
			_emitter.gravity = Vector2(6.0, 12.0)
			_emitter.initial_velocity_min = 40.0
			_emitter.initial_velocity_max = 90.0
			# 소프트 점 텍스처가 32px 이라 배율이 곧 눈송이 지름(px)의 1/32 이다 — 7~18px.
			_emitter.scale_amount_min = 0.22
			_emitter.scale_amount_max = 0.55
			_emitter.color = Color(0.95, 0.98, 1.00, 0.85)
			_emitter.angular_velocity_min = -25.0
			_emitter.angular_velocity_max = 25.0
		"fog":
			# 큰 반투명 덩어리는 오버드로가 비싸다 — 개수를 크게 줄이고 알파를 낮춰
			# 화면 대비 오버드로를 2배 안쪽으로 묶는다(모바일 WebGL 필레이트 예산).
			_emitter.texture = _soft_tex
			_emitter.amount = 12
			_emitter.lifetime = 14.0
			_emitter.preprocess = 8.0
			_emitter.direction = Vector2(1.0, 0.0)
			_emitter.spread = 20.0
			_emitter.initial_velocity_min = 12.0
			_emitter.initial_velocity_max = 30.0
			_emitter.scale_amount_min = 8.0
			_emitter.scale_amount_max = 16.0
			_emitter.color = Color(0.80, 0.84, 0.90, 0.10)
		"dust":
			_emitter.texture = _soft_tex
			_emitter.amount = 90
			_emitter.lifetime = 2.2
			_emitter.preprocess = 1.5
			_emitter.direction = Vector2(1.0, 0.12).normalized()
			_emitter.spread = 8.0
			_emitter.initial_velocity_min = 320.0
			_emitter.initial_velocity_max = 560.0
			_emitter.scale_amount_min = 0.25
			_emitter.scale_amount_max = 0.70
			_emitter.color = Color(0.85, 0.70, 0.45, 0.58)
		_:
			_emitter.amount = 1
			_emitter.emitting = false
			return
	_emitter.restart()


## 빗줄기용 세로 스트릭(2×26) — 런타임 생성이라 신규 아트가 필요 없다.
func _make_streak() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 2
	t.height = 26
	t.fill_from = Vector2(0.0, 0.0)
	t.fill_to = Vector2(0.0, 1.0)
	return t


## 착지 파문용 링(32×32 radial) — 가운데를 비우고 바깥 테두리만 남겨 물결로 읽히게 한다.
func _make_ring() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 0.80, 1.0])
	g.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.06), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t


## 눈·안개·먼지용 소프트 라운드 점(32×32 radial).
func _make_soft() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t


## ── 안개 판 / 번개 섬광 ──────────────────────────────────────────────────
## 판 자체는 고정 색으로 한 번만 그리고, 세기는 self_modulate.a 로 조절한다 —
## 매 프레임 재발행(queue_redraw)하지 않기 위해서다. self_modulate 는 자식(파티클)에 번지지 않는다.

func _sync_haze_size() -> void:
	var vp := get_viewport().get_visible_rect().size
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.zoom.x > 0.0 and cam.zoom.y > 0.0:
		vp = Vector2(vp.x / cam.zoom.x, vp.y / cam.zoom.y)
	if not vp.is_equal_approx(_haze_vp):
		_haze_vp = vp
		queue_redraw()


func _draw() -> void:
	if _haze_vp == Vector2.ZERO:
		return
	var m := HAZE_MARGIN
	draw_rect(Rect2(-_haze_vp.x * 0.5 - m, -_haze_vp.y * 0.5 - m,
			_haze_vp.x + m * 2.0, _haze_vp.y + m * 2.0), Color(0.92, 0.94, 1.0, 1.0))
