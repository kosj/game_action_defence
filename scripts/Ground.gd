extends Node2D
## 바닥 타일 — 게임 시작 시 4종 테마 중 하나가 랜덤 선택됨.
## Camera2D 가 플레이어를 따라오므로 뷰포트 범위만 그려 WebGL 성능 유지.

const TILE := 80
## 바닥 타일을 어둡게 깔아 그 위 이펙트가 잘 보이게 하는 곱연산 색(밝은 아트일수록 중요).
const TILE_DARKEN := Color(0.55, 0.55, 0.60)

## 테마별 전용 바닥 타일 텍스처(있으면 체커+절차 장식 대신 타일링). 없는 테마(desert 등)는 폴백.
## 타일은 assets/sprites 가 아니라 assets/tiles 에 둔다 — sprites/ 는 통째로 아틀라스 대상이자
## 익스포트 제외 대상인데, 타일은 texture_repeat 로 화면을 채워야 해서 아틀라스에 못 넣는다.
const _TILE_TEX := {
	"grass":  preload("res://assets/tiles/tile_grass.png"),
	"stone":  preload("res://assets/tiles/tile_stone.png"),
	"frozen": preload("res://assets/tiles/tile_frozen.png"),
}

## name: 로직 분기용 식별자
## bg:   화면 바깥 빈 공간 채우는 ColorRect 색상
## tile_a/b: 체커보드 두 가지 타일 색
## mark: 타일 위 세부 장식(풀·돌·눈송이 등) 색
const THEMES: Array = [
	{
		"name": "grass",
		"bg":     Color(0.10, 0.16, 0.08),
		"tile_a": Color(0.13, 0.20, 0.10),
		"tile_b": Color(0.16, 0.24, 0.13),
		"mark":   Color(0.22, 0.31, 0.16),
	},
	{
		"name": "desert",
		"bg":     Color(0.18, 0.14, 0.08),
		"tile_a": Color(0.38, 0.30, 0.16),
		"tile_b": Color(0.43, 0.34, 0.19),
		"mark":   Color(0.27, 0.21, 0.10),
	},
	{
		"name": "stone",
		"bg":     Color(0.09, 0.09, 0.11),
		"tile_a": Color(0.18, 0.18, 0.22),
		"tile_b": Color(0.23, 0.23, 0.28),
		"mark":   Color(0.30, 0.30, 0.36),
	},
	{
		"name": "frozen",
		"bg":     Color(0.07, 0.09, 0.17),
		"tile_a": Color(0.11, 0.15, 0.26),
		"tile_b": Color(0.14, 0.19, 0.33),
		"mark":   Color(0.22, 0.32, 0.58),
	},
]

var _player: Node2D = null
var _last_pos := Vector2(INF, INF)
var _theme: Dictionary = {}

## ── 반복감 완화(타일 단조로움 해소) ────────────────────────────────────
## 타일 1장을 그대로 반복하면 같은 무늬가 격자로 읽힌다. 새 아트 없이 두 겹을 얹어 깬다:
##  (1) 큰 스케일 얼룩(노이즈) — 타일 주기(256)와 어긋나는 큰 주기로 명암을 흩어 반복 인지를 무너뜨린다.
##  (2) 패치 데칼 — 월드 해시로 흩뿌린 작은 얼룩/자국(테마별 색). 위치가 고정돼 이동해도 흔들리지 않는다.
const OVERLAY_CELL := 880.0        # 얼룩 오버레이 한 장이 덮는 월드 크기(타일 256 과 서로소에 가깝게)
const OVERLAY_ALPHA := 0.14        # 얼룩 세기(과하면 바닥이 뿌옇게 떠 보인다)
const DECAL_CELL := 150.0          # 데칼 배치 격자
const DECAL_DENSITY := 42          # 셀당 데칼 확률(%)

var _noise_tex: NoiseTexture2D = null


func _ready() -> void:
	# 타일을 한 칸씩 스트레치해 직접 그리므로(draw_texture_rect, tile=false) 반복 샘플링은 필요 없다(CLAMP).
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_player = get_tree().get_first_node_in_group("player")
	_theme = _resolve_theme()
	_build_overlay_noise()
	# Background ColorRect 색을 테마에 맞게 교체
	var bg := get_parent().get_node_or_null("Background")
	if bg:
		bg.color = _theme["bg"]


## 선택 테마(ThemeManager/데이터) → 그리기용 dict. 데이터가 없으면 기존 랜덤 테마로 폴백.
func _resolve_theme() -> Dictionary:
	var td: ThemeData = ThemeManager.selected()
	if td != null:
		return {"name": td.detail_style, "bg": td.bg, "tile_a": td.tile_a, "tile_b": td.tile_b, "mark": td.mark}
	return THEMES[randi() % THEMES.size()]


## 재드로우 격자. _draw() 의 모든 좌표는 global_position 을 빼서 월드에 고정되므로, 노드가
## 플레이어를 픽셀 단위로 따라다닐 필요가 없다 — 격자에 스냅해도 화면에 보이는 그림은 동일하다.
const SNAP := 128.0
## 데칼용 텍스처 — 흰색 + 알파 모양만 담고 색은 그리는 쪽에서 틴트로 넣는다.
## 그래야 테마의 mark 색이 데이터 구동으로 유지된다(색을 텍스처에 구우면 themes.tres 를
## 고쳐도 데칼이 안 따라온다). 세로 획은 회전을 피하려고 미리 돌려 둔 별도 텍스처를 쓴다.
const _DECAL_BLOB := preload("res://assets/atlas/decal_blob.tres")
const _DECAL_STREAK := preload("res://assets/atlas/decal_streak.tres")
const _DECAL_STREAK_V := preload("res://assets/atlas/decal_streak_v.tres")


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	var p := _player.global_position
	# 예전에는 임계값이 distance_squared > 0.5(≈0.7px)라 이동 중 사실상 매 프레임 _draw() 가 돌았다.
	# _draw() 는 화면 전체의 타일·얼룩·데칼을 매번 재발행하므로(드로우 커맨드 수백 개) 좀비 수와
	# 무관하게 항상 부과되는 고정 비용이었다. 스냅 칸이 바뀔 때만 다시 그린다(재드로우 ~1/25).
	var snapped := Vector2(floor(p.x / SNAP) * SNAP, floor(p.y / SNAP) * SNAP)
	if snapped == _last_pos:
		return
	_last_pos = snapped
	global_position = snapped
	queue_redraw()


func _draw() -> void:
	if _theme.is_empty():
		return
	# 화면에 실제로 보이는 "월드" 크기 = 뷰포트 픽셀 / 카메라 줌(stretch=expand·줌 대응).
	var vp := get_viewport().get_visible_rect().size
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.zoom.x > 0.0 and cam.zoom.y > 0.0:
		vp = Vector2(vp.x / cam.zoom.x, vp.y / cam.zoom.y)
	# 노드가 SNAP 격자에 스냅돼 있어 플레이어가 최대 SNAP 만큼 어긋난 위치에 있을 수 있다 —
	# 그만큼 그리는 범위를 넓혀야 화면 가장자리에 빈 칸이 생기지 않는다.
	var half_w := vp.x * 0.5 + SNAP
	var half_h := vp.y * 0.5 + SNAP
	var wx     := global_position.x
	var wy     := global_position.y

	var tx0 := int(floor((wx - half_w) / TILE)) - 1
	var ty0 := int(floor((wy - half_h) / TILE)) - 1
	var tx1 := int(ceil((wx + half_w) / TILE)) + 1
	var ty1 := int(ceil((wy + half_h) / TILE)) + 1

	var tile_a: Color  = _theme["tile_a"]
	var tile_b: Color  = _theme["tile_b"]
	var mark: Color    = _theme["mark"]
	var theme_name: String = _theme["name"]

	# 전용 타일 텍스처가 있으면 타일 단위로 그린다. 타일은 심리스(가장자리 힐 처리)라 "모든 타일을
	# 같은 방향으로" 이어 붙이면 흙길이 경계를 넘어 자연스럽게 연결된다. (예전의 좌우/상하 플립은
	# 대칭이 아닌 이 유기적 타일에서 뒤집힌 엣지가 이웃과 나비 대칭으로 어긋나 오히려 격자를 만들었다 —
	# 그래서 플립을 제거.) modulate 로 바닥을 어둡게 깔아 그 위 이펙트가 잘 보이게 한다.
	if _TILE_TEX.has(theme_name):
		var tex: Texture2D = _TILE_TEX[theme_name]
		var ts := tex.get_size()
		var ttx0 := int(floor((wx - half_w) / ts.x)) - 1
		var ttx1 := int(ceil((wx + half_w) / ts.x)) + 1
		var tty0 := int(floor((wy - half_h) / ts.y)) - 1
		var tty1 := int(ceil((wy + half_h) / ts.y)) + 1
		for ttx in range(ttx0, ttx1):
			for tty in range(tty0, tty1):
				var lx := float(ttx) * ts.x - wx
				var ly := float(tty) * ts.y - wy
				# 0.5px 겹침으로 서브픽셀 헤어라인 방지(플립이 없어 엣지 감김 걱정 없음).
				draw_texture_rect(tex, Rect2(lx - 0.5, ly - 0.5, ts.x + 1.0, ts.y + 1.0), false, TILE_DARKEN)
		# 반복감 완화 2겹: 큰 얼룩 → 작은 데칼 순으로 덮는다.
		_draw_overlay(wx, wy, half_w, half_h)
		# 얼룩·자국은 CHEATS > DECALS 로 끌 수 있다(5-M Phase 0) — 바닥 데칼이 프레임에서
		# 차지하는 몫을 실기기에서 그 자리에서 A/B 하기 위한 것이다.
		if Cheats.decals:
			_draw_decals(wx, wy, half_w, half_h, theme_name, mark)
		return

	# 타일 텍스처가 없는 detail_style 용 폴백(절차적 체커보드). 지금 세 테마는 전부
	# grass/stone/frozen 이라 위에서 return 으로 빠지므로 여기는 돌지 않는다 — 도달하는
	# 유일한 경로는 ThemeManager.selected() 가 null 이고 THEMES 추첨이 "desert" 를 뽑는
	# 경우다. 핫패스가 아니므로 프리미티브를 그대로 둔다.
	for tx in range(tx0, tx1):
		for ty in range(ty0, ty1):
			var lx := float(tx * TILE) - wx
			var ly := float(ty * TILE) - wy
			var col := tile_a if (tx + ty) & 1 == 0 else tile_b
			# batching-exempt: 위 주석 참고 — 실제 테마 3종은 여기 오지 않는다
			draw_rect(Rect2(lx, ly, float(TILE), float(TILE)), col)
			_draw_detail(theme_name, lx, ly, tx, ty, mark)


## 큰 스케일 얼룩용 심리스 노이즈를 런타임 생성(외부 아트 불필요). 생성은 스레드에서 끝나므로
## 완료 시 다시 그린다.
func _build_overlay_noise() -> void:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.006
	n.fractal_octaves = 3
	var t := NoiseTexture2D.new()
	t.noise = n
	t.width = 256
	t.height = 256
	t.seamless = true          # 이어 붙여도 경계가 보이지 않게
	t.generate_mipmaps = false
	t.changed.connect(queue_redraw)
	Cheats.changed.connect(queue_redraw)   # DECALS 토글이 즉시 화면에 반영되도록
	_noise_tex = t


## (1) 큰 스케일 얼룩 — 타일보다 훨씬 큰 주기로 명암을 흩어, 같은 타일이 반복돼도 눈에 덜 띄게 한다.
func _draw_overlay(wx: float, wy: float, half_w: float, half_h: float) -> void:
	if _noise_tex == null:
		return
	var c := OVERLAY_CELL
	var x0 := int(floor((wx - half_w) / c)) - 1
	var x1 := int(ceil((wx + half_w) / c)) + 1
	var y0 := int(floor((wy - half_h) / c)) - 1
	var y1 := int(ceil((wy + half_h) / c)) + 1
	var col := Color(1.0, 1.0, 1.0, OVERLAY_ALPHA)
	for ox in range(x0, x1):
		for oy in range(y0, y1):
			var px := float(ox) * c - wx
			var py := float(oy) * c - wy
			draw_texture_rect(_noise_tex, Rect2(px, py, c, c), false, col)


## (2) 패치 데칼 — 월드 셀 해시로 흩뿌린 작은 얼룩/자국. 테마 색을 옅게 써서 바닥에 녹아들게 한다.
##
## ⚠️ **모든 데칼은 텍스처 쿼드로 그린다** — draw_circle / draw_line 을 쓰지 않는다.
## Godot 캔버스 배처는 한 아이템 안에서도 **프리미티브 종류가 다르면 배치를 끊는다.**
## 색은 정점 데이터라 명령마다 달라도 묶이지만(그래서 mark 색을 그대로 쓴다), 원·선은
## 쿼드와 섞이지 않는다. 예전에는 draw_circle 42 + draw_line 45 를 발행해 Ground 격리
## 드로우 콜이 93이었다 — 같은 그림을 쿼드로만 바꾸니 43 이 됐다(ASSET_PIPELINE.md 1절).
func _draw_decals(wx: float, wy: float, half_w: float, half_h: float, theme_name: String, mark: Color) -> void:
	var c := DECAL_CELL
	var x0 := int(floor((wx - half_w) / c)) - 1
	var x1 := int(ceil((wx + half_w) / c)) + 1
	var y0 := int(floor((wy - half_h) / c)) - 1
	var y1 := int(ceil((wy + half_h) / c)) + 1
	var ci := int(c)
	for dx in range(x0, x1):
		for dy in range(y0, y1):
			var h := ((dx * 73856093) ^ (dy * 19349663)) & 0x7fffffff
			if h % 100 >= DECAL_DENSITY:
				continue
			var p := Vector2(float(dx) * c + float((h / 7) % ci) - wx,
					float(dy) * c + float((h / 13) % ci) - wy)
			var r := 12.0 + float((h / 31) % 26)          # 12~37px
			var kind := (h / 101) % 3
			match theme_name:
				"grass":
					if kind == 0:      # 마른 흙 얼룩
						_blob(p, r, Color(0.30, 0.24, 0.13, 0.16))
					elif kind == 1:    # 짙은 풀 무리
						_blob(p, r * 0.8, Color(mark.r, mark.g, mark.b, 0.18))
					else:              # 잔풀 몇 포기
						for i in 3:
							var o := Vector2(float((h / (7 + i)) % 18) - 9.0, float((h / (11 + i)) % 14) - 7.0)
							_streak(p + o + Vector2(0, 4), p + o - Vector2(0, 5),
								Color(mark.r, mark.g, mark.b, 0.5), 1.6)
				"stone":
					if kind == 0:      # 기름/물 얼룩
						_blob(p, r, Color(0.05, 0.05, 0.07, 0.22))
					elif kind == 1:    # 흩어진 자갈
						for i in 4:
							var o2 := Vector2(float((h / (5 + i)) % 30) - 15.0, float((h / (9 + i)) % 24) - 12.0)
							_blob(p + o2, 2.0 + float(i % 2), Color(mark.r, mark.g, mark.b, 0.40))
					else:              # 갈라진 금
						_streak(p + Vector2(-r * 0.7, -r * 0.3), p + Vector2(0, r * 0.15),
							Color(0.06, 0.06, 0.08, 0.35), 1.8)
						_streak(p + Vector2(0, r * 0.15), p + Vector2(r * 0.65, r * 0.45),
							Color(0.06, 0.06, 0.08, 0.35), 1.8)
				"frozen":
					if kind == 0:      # 성에 낀 자리
						_blob(p, r, Color(0.75, 0.90, 1.0, 0.10))
					elif kind == 1:    # 얼음 균열
						for i in 3:
							var a := TAU * float(i) / 3.0 + float(h % 7)
							_streak(p, p + Vector2.from_angle(a) * r * 0.9,
								Color(0.80, 0.93, 1.0, 0.22), 1.5)
					else:              # 눈 무더기
						_blob(p, r * 0.7, Color(0.90, 0.95, 1.0, 0.13))
				_:
					_blob(p, r, Color(mark.r, mark.g, mark.b, 0.13))


## 원형 얼룩 한 장. draw_circle 대체 — 같은 아틀라스의 쿼드라 다른 데칼과 배칭된다.
func _blob(p: Vector2, r: float, col: Color) -> void:
	draw_texture_rect(_DECAL_BLOB, Rect2(p.x - r, p.y - r, r * 2.0, r * 2.0), false, col)


## 획 하나. draw_line 대체. 세로/가로로 누운 것은 회전 없이 그린다 —
## draw_set_transform 은 명령이 하나 더 붙으므로 필요할 때만 쓴다.
func _streak(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d := b - a
	if absf(d.x) < 0.01:                                   # 수직
		var top := minf(a.y, b.y)
		draw_texture_rect(_DECAL_STREAK_V,
			Rect2(a.x - w * 0.5, top, w, absf(d.y)), false, col)
		return
	if absf(d.y) < 0.01:                                   # 수평
		var left := minf(a.x, b.x)
		draw_texture_rect(_DECAL_STREAK,
			Rect2(left, a.y - w * 0.5, absf(d.x), w), false, col)
		return
	draw_set_transform(a, d.angle(), Vector2.ONE)
	draw_texture_rect(_DECAL_STREAK, Rect2(0.0, -w * 0.5, d.length(), w), false, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 테마별 타일 장식. 월드 타일 좌표(tx, ty)를 해시로 사용해 이동해도 패턴이 유지됨.
## batching-exempt: 위 폴백 경로에서만 불린다(타일 텍스처가 없는 detail_style).
## 지금 세 테마는 전부 grass/stone/frozen 이라 여기 도달하지 않으므로 핫패스가 아니다.
func _draw_detail(theme: String, lx: float, ly: float, tx: int, ty: int, mark: Color) -> void:
	var cx := lx + TILE * 0.5
	var cy := ly + TILE * 0.5
	match theme:

		"grass":
			if (tx * 3 + ty * 7) % 7 == 0:
				draw_circle(Vector2(cx, cy), 4.0, mark)
			elif (tx * 5 + ty * 3) % 11 == 0:
				draw_line(Vector2(cx - 5, cy - 2), Vector2(cx + 5, cy - 2), mark, 1.5)
				draw_line(Vector2(cx, cy - 6), Vector2(cx, cy + 2), mark, 1.5)

		"desert":
			if (tx * 3 + ty * 5) % 9 == 0:
				# 작은 돌멩이 2개
				draw_circle(Vector2(cx - 5, cy + 5), 3.5, mark)
				draw_circle(Vector2(cx + 5, cy + 3), 2.5, mark)
			elif (tx * 7 + ty * 2) % 11 == 0:
				# 지면 균열
				draw_line(Vector2(cx - 9, cy - 3), Vector2(cx, cy + 2), mark, 1.2)
				draw_line(Vector2(cx, cy + 2), Vector2(cx + 7, cy + 6), mark, 1.2)
			elif (tx * 2 + ty * 9) % 17 == 0:
				# 작은 자갈 하나
				draw_circle(Vector2(cx + 3, cy - 4), 2.0, mark)

		"stone":
			if (tx * 4 + ty * 6) % 11 == 0:
				# 긴 대각 균열
				draw_line(Vector2(cx - 10, cy - 8), Vector2(cx + 2, cy + 5), mark, 1.5)
			elif (tx * 6 + ty * 3) % 13 == 0:
				# 꺾인 타일 금
				draw_line(Vector2(lx + 4,          ly + TILE * 0.38), Vector2(lx + TILE * 0.55, ly + TILE * 0.42), mark, 1.5)
				draw_line(Vector2(lx + TILE * 0.55, ly + TILE * 0.42), Vector2(lx + TILE - 4,    ly + TILE * 0.58), mark, 1.5)
			elif (tx * 5 + ty * 7) % 19 == 0:
				# 짧은 수직 균열
				draw_line(Vector2(cx + 4, cy - 5), Vector2(cx + 6, cy + 5), mark, 1.2)

		"frozen":
			if (tx * 3 + ty * 4) % 7 == 0:
				# 눈송이: 3축 교차선 (6방향)
				var r := 7.0
				for i in 3:
					var a := float(i) * PI / 3.0
					var d := Vector2.from_angle(a) * r
					draw_line(Vector2(cx, cy) - d, Vector2(cx, cy) + d, mark, 1.5)
			elif (tx * 5 + ty * 2) % 13 == 0:
				# 작은 얼음 파편
				var pts := PackedVector2Array([
					Vector2(cx,       cy - 5),
					Vector2(cx + 4,   cy    ),
					Vector2(cx + 1,   cy + 4),
					Vector2(cx - 3,   cy + 2),
					Vector2(cx - 2,   cy - 3),
				])
				draw_colored_polygon(pts, Color(mark.r, mark.g, mark.b, 0.55))
