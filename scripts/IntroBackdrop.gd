extends Control
## 인트로 "The Last Beacon" 분위기 배경 — 코드로 그린 일러스트.
##
## 톤은 타이틀 아트(assets/ui/bg_title.png)를 그대로 이어받는다: 크림슨 노을이 지평선에서
## 타오르고, 그 앞을 폐허 도시 실루엣 3겹이 가리며, 잔불(ember)이 천천히 떠오른다.
## 그 위에 홀로 구조 신호를 보내는 송신탑(맥동 비컨)이 서 있다 — 인트로 서사의 주인공.
##
## 셀셰이딩 톤에 맞춰 하늘은 부드러운 그라데이션 대신 납작한 색 띠(band)로 쌓고,
## 건물은 지붕 형태(계단/안테나/물탱크)를 섞어 실루엣이 밋밋해지지 않게 한다.
##
## assets/ui/bg_intro.png 일러스트가 있으면 그것을 배경으로 쓰고 잔불만 위에 얹는다
## (그 경우 송신탑은 일러스트에 포함된 것으로 본다 — INTRO_ART_PROMPT.md 참고).

const BG_PATH := "res://assets/ui/bg_intro.png"

# 타이틀 아트에서 뽑은 팔레트(위→아래).
const SKY_TOP   := Color(0.06, 0.03, 0.06)
const SKY_MID   := Color(0.19, 0.07, 0.11)
const SKY_LOW   := Color(0.36, 0.08, 0.13)
const GLOW      := Color(0.96, 0.20, 0.23)   # 지평선 크림슨 발광
const CITY_FAR  := Color(0.22, 0.09, 0.14)
const CITY_MID  := Color(0.11, 0.05, 0.09)
const CITY_NEAR := Color(0.035, 0.025, 0.045)
const GROUND    := Color(0.02, 0.015, 0.03)
const WINDOW    := Color(1.0, 0.72, 0.34)
const EMBER     := Color(1.0, 0.55, 0.20)
const BEACON_COL := Color(1.0, 0.36, 0.26)   # 구조 신호(붉은) 비컨 색

const SKY_BANDS := 40     # 하늘 색 띠 수 — 너무 적으면 줄무늬 아티팩트로 보인다
const EMBER_N := 26
const HORIZON := 0.86     # 지평선 높이 비율(아래 여백은 시작 버튼 자리)

var _t: float = 0.0
var _stars: Array = []    # [Vector2(0..1 비율), 크기, 위상]
var _embers: Array = []   # [x(0..1), y0(0..1), 속도, 크기, 위상]
var _blds: Array = []     # 사전 계산한 건물 [Rect2, 색, 지붕타입, 창문 Rect2 배열]
var _built_for := Vector2.ZERO   # _blds 를 만들 때의 화면 크기(리사이즈 시 재생성)
var _art: Texture2D = null


func _ready() -> void:
	if ResourceLoader.exists(BG_PATH):
		var t = load(BG_PATH)
		if t is Texture2D:
			_art = t
	_seed_stars()
	_seed_embers()
	set_process(true)


func _seed_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 73101
	_stars.clear()
	for i in 48:
		# 별은 위쪽(노을에 씻기지 않는 영역)에만.
		_stars.append([Vector2(rng.randf(), rng.randf() * 0.42), rng.randf_range(0.7, 1.7), rng.randf() * TAU])


func _seed_embers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20477
	_embers.clear()
	for i in EMBER_N:
		_embers.append([rng.randf(), rng.randf(), rng.randf_range(0.012, 0.045),
			rng.randf_range(1.2, 2.8), rng.randf() * TAU])


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	if s.x <= 1.0 or s.y <= 1.0:
		return
	if _art:
		_draw_art(s)      # 일러스트가 있으면 그것으로 대체(송신탑 포함으로 간주)
		_draw_embers(s)
		return
	_draw_sky(s)
	_draw_stars(s)
	_draw_glow(s)
	_ensure_buildings(s)
	_draw_buildings(s)
	_draw_beacon(s)
	_draw_embers(s)


## 일러스트를 화면에 꽉 차게(cover) 그린다 — 비율 유지, 넘치는 쪽은 잘라낸다.
func _draw_art(s: Vector2) -> void:
	var ts := Vector2(_art.get_size())
	if ts.x <= 0.0 or ts.y <= 0.0:
		return
	var k := maxf(s.x / ts.x, s.y / ts.y)
	var dst := ts * k
	draw_texture_rect(_art, Rect2((s - dst) * 0.5, dst), false)


## 하늘 — 위(암적)에서 지평선(진홍)으로 가는 납작한 색 띠. 셀셰이딩 톤 유지.
func _draw_sky(s: Vector2) -> void:
	var hz := s.y * HORIZON
	for i in SKY_BANDS:
		var f := float(i) / float(SKY_BANDS - 1)
		var col := SKY_TOP.lerp(SKY_MID, minf(f * 1.6, 1.0)) if f < 0.62 else SKY_MID.lerp(SKY_LOW, (f - 0.62) / 0.38)
		var y0 := hz * (float(i) / float(SKY_BANDS))
		var y1 := hz * (float(i + 1) / float(SKY_BANDS)) + 1.0
		draw_rect(Rect2(0.0, y0, s.x, y1 - y0), col)


func _draw_stars(s: Vector2) -> void:
	for st: Array in _stars:
		var p := Vector2(st[0].x * s.x, st[0].y * s.y)
		var tw: float = 0.55 + 0.45 * sin(_t * 1.6 + st[2])
		# 아래(노을 쪽)로 갈수록 별이 묻힌다.
		var fade := clampf(1.0 - st[0].y / 0.42, 0.15, 1.0)
		draw_circle(p, st[1], Color(1.0, 0.92, 0.88, (0.12 + 0.35 * tw) * fade))


## 지평선 발광 — 도시 뒤에서 타오르는 빛. 납작한 타원을 겹쳐 은은하게.
func _draw_glow(s: Vector2) -> void:
	var c := Vector2(s.x * 0.5, s.y * HORIZON)
	for i in 10:
		var f := float(i) / 10.0
		var rw := s.x * (0.92 - 0.78 * f)
		var rh := s.y * (0.22 - 0.18 * f)
		draw_set_transform(c, 0.0, Vector2(1.0, rh / maxf(rw, 1.0)))
		draw_circle(Vector2.ZERO, rw, Color(GLOW.r, GLOW.g, GLOW.b, 0.028 + 0.105 * f))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 건물 실루엣을 화면 크기당 1회만 생성(매 프레임 RNG 재계산 방지).
func _ensure_buildings(s: Vector2) -> void:
	if _built_for.is_equal_approx(s) and not _blds.is_empty():
		return
	_built_for = s
	_blds.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 41011
	var hz := s.y * HORIZON
	# 송신탑(꼭대기 y≈0.34)이 스카이라인 위로 확실히 솟도록 건물 높이를 제한한다.
	_gen_layer(s, rng, hz + s.y * 0.012, 0.045, 0.13, CITY_FAR, false)    # 먼 능선
	_gen_layer(s, rng, hz + s.y * 0.004, 0.060, 0.19, CITY_MID, false)    # 중간
	_gen_layer(s, rng, hz, 0.070, 0.24, CITY_NEAR, true)                  # 앞줄(창문 있음)


func _gen_layer(s: Vector2, rng: RandomNumberGenerator, base_y: float,
		min_frac: float, max_frac: float, col: Color, windows: bool) -> void:
	var x := -s.x * 0.04
	while x < s.x + s.x * 0.04:
		var w := rng.randf_range(s.x * 0.05, s.x * 0.13)
		var h := rng.randf_range(s.y * min_frac, s.y * max_frac)
		var top := base_y - h
		var roof := rng.randi_range(0, 3)
		var wins: Array = []
		if windows:
			var cols := int(w / (s.x * 0.026))
			var rows := int(h / (s.y * 0.028))
			for cx in cols:
				for cy in rows:
					if rng.randf() < 0.07:
						wins.append(Rect2(
							x + s.x * 0.011 + cx * s.x * 0.026,
							top + s.y * 0.012 + cy * s.y * 0.028,
							s.x * 0.008, s.y * 0.007))
		_blds.append([Rect2(x, top, w + 1.0, base_y - top), col, roof, wins, rng.randf()])
		x += w + rng.randf_range(s.x * 0.004, s.x * 0.016)


func _draw_buildings(s: Vector2) -> void:
	for b: Array in _blds:
		var r: Rect2 = b[0]
		var col: Color = b[1]
		draw_rect(r, col)
		_draw_roof(s, r, col, int(b[2]), float(b[4]))
		for w: Rect2 in b[3]:
			draw_rect(w, Color(WINDOW.r, WINDOW.g, WINDOW.b, 0.55))
	# 지면
	draw_rect(Rect2(0.0, s.y * HORIZON, s.x, s.y * (1.0 - HORIZON) + 2.0), GROUND)


## 지붕 장식 — 계단/안테나/물탱크를 섞어 실루엣이 반복적으로 보이지 않게 한다.
func _draw_roof(s: Vector2, r: Rect2, col: Color, kind: int, seed_f: float) -> void:
	match kind:
		1:   # 한 단 올린 옥탑
			var w := r.size.x * 0.45
			draw_rect(Rect2(r.position.x + (r.size.x - w) * seed_f, r.position.y - s.y * 0.018, w, s.y * 0.018), col)
		2:   # 안테나
			var ax := r.position.x + r.size.x * (0.25 + 0.5 * seed_f)
			draw_line(Vector2(ax, r.position.y), Vector2(ax, r.position.y - s.y * 0.045), col, maxf(s.x * 0.003, 1.5))
		3:   # 물탱크(다리 + 통)
			var cx := r.position.x + r.size.x * (0.3 + 0.4 * seed_f)
			var tw := r.size.x * 0.3
			draw_rect(Rect2(cx - tw * 0.5, r.position.y - s.y * 0.026, tw, s.y * 0.016), col)
			draw_rect(Rect2(cx - tw * 0.5, r.position.y - s.y * 0.010, tw, s.y * 0.010), col)
		_:
			pass


## 잔불 — 화면 아래에서 위로 천천히 떠오르며 좌우로 흔들린다(타이틀 아트의 불티와 동일 모티프).
func _draw_embers(s: Vector2) -> void:
	for e: Array in _embers:
		var y := fposmod(float(e[1]) - _t * float(e[2]), 1.0)
		var px := (float(e[0]) + 0.02 * sin(_t * 0.8 + float(e[4]))) * s.x
		var py := (0.20 + y * 0.82) * s.y
		var a: float = 0.35 + 0.35 * sin(_t * 2.2 + float(e[4]))
		# 위로 갈수록 사그라든다.
		a *= clampf(y * 1.6, 0.0, 1.0)
		draw_circle(Vector2(px, py), float(e[3]), Color(EMBER.r, EMBER.g, EMBER.b, a))


func _draw_beacon(s: Vector2) -> void:
	var bx := s.x * 0.70             # 중앙 텍스트와 겹치지 않게 약간 우측
	var base_y := s.y * 0.90         # 지평선 아래까지 내려 땅에 뿌리내리게
	var top_y := s.y * 0.34
	var hb := s.x * 0.045            # 아랫변 반폭 — 격자 철탑답게 넉넉히
	var ht := s.x * 0.012            # 윗변 반폭

	# 격자 철탑 — 속을 채우지 않고 다리·가로보·X 트러스만 그린다. 사이로 노을이 비쳐
	# "덩어리 실루엣"이 아니라 구조물로 읽힌다(채운 폴리곤은 트러스가 묻혀 보이지 않는다).
	const SEGS := 7
	var lw := maxf(s.x * 0.0045, 1.6)
	var ys: Array = []
	var hws: Array = []
	for i in SEGS + 1:
		var f := float(i) / float(SEGS)
		ys.append(lerpf(top_y, base_y, f))
		hws.append(lerpf(ht, hb, f))
	# 다리 2개
	draw_line(Vector2(bx - ht, top_y), Vector2(bx - hb, base_y), CITY_NEAR, lw)
	draw_line(Vector2(bx + ht, top_y), Vector2(bx + hb, base_y), CITY_NEAR, lw)
	for i in SEGS + 1:
		var y: float = ys[i]
		var hw: float = hws[i]
		draw_line(Vector2(bx - hw, y), Vector2(bx + hw, y), CITY_NEAR, lw * 0.8)   # 가로보
		if i < SEGS:   # X 트러스
			var y2: float = ys[i + 1]
			var hw2: float = hws[i + 1]
			draw_line(Vector2(bx - hw, y), Vector2(bx + hw2, y2), CITY_NEAR, lw * 0.6)
			draw_line(Vector2(bx + hw, y), Vector2(bx - hw2, y2), CITY_NEAR, lw * 0.6)
	# 꼭대기 장비 캐빈
	draw_rect(Rect2(bx - ht * 1.9, top_y + s.y * 0.006, ht * 3.8, s.y * 0.016), CITY_NEAR)

	# 맥동하는 비컨 불빛
	var pulse: float = 0.5 + 0.5 * sin(_t * 2.3)
	var light := Vector2(bx, top_y - s.y * 0.006)

	# 위로 뻗는 가느다란 빛기둥 — 여러 겹으로 나눠 위로 갈수록 옅어지게(딱딱한 삼각형 방지).
	var beam_h := s.y * 0.22
	for i in 4:
		var bf := float(i + 1) / 4.0
		var bw := s.x * 0.030 * bf * (0.7 + 0.3 * pulse)
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx, light.y),
			Vector2(bx - bw, light.y - beam_h * bf),
			Vector2(bx + bw, light.y - beam_h * bf),
		]), Color(BEACON_COL.r, BEACON_COL.g, BEACON_COL.b, (0.030 + 0.030 * pulse) * (1.0 - bf * 0.7)))

	# 광원 글로우 — 큰 원일수록 옅게(가장자리 하드 엣지 방지)
	for i in 7:
		var gf := float(i) / 7.0
		draw_circle(light, (s.y * 0.085) * (1.0 - gf) * (0.65 + 0.35 * pulse),
			Color(BEACON_COL.r, BEACON_COL.g, BEACON_COL.b, 0.012 + 0.055 * gf))

	# 코어
	draw_circle(light, s.y * 0.0032 + s.y * 0.0016 * pulse, Color(1.0, 0.7, 0.5, 0.92))
	draw_circle(light, s.y * 0.0016, Color(1.0, 0.96, 0.88, 1.0))
