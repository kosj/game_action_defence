extends Node2D
## 바닥 타일 — 게임 시작 시 4종 테마 중 하나가 랜덤 선택됨.
## Camera2D 가 플레이어를 따라오므로 뷰포트 범위만 그려 WebGL 성능 유지.

const TILE := 80
## 바닥 타일을 어둡게 깔아 그 위 이펙트가 잘 보이게 하는 곱연산 색(밝은 아트일수록 중요).
const TILE_DARKEN := Color(0.55, 0.55, 0.60)

## 테마별 전용 바닥 타일 텍스처(있으면 체커+절차 장식 대신 타일링). 없는 테마(desert 등)는 폴백.
const _TILE_TEX := {
	"grass":  preload("res://assets/sprites/tiles/tile_grass.png"),
	"stone":  preload("res://assets/sprites/tiles/tile_stone.png"),
	"frozen": preload("res://assets/sprites/tiles/tile_frozen.png"),
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


func _ready() -> void:
	# 타일을 한 칸씩 스트레치해 직접 그리므로(draw_texture_rect, tile=false) 반복 샘플링은 필요 없다(CLAMP).
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_player = get_tree().get_first_node_in_group("player")
	_theme = _resolve_theme()
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


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	var p := _player.global_position
	if p.distance_squared_to(_last_pos) > 0.5:
		global_position = p
		_last_pos = p
		queue_redraw()


func _draw() -> void:
	if _theme.is_empty():
		return
	# 화면에 실제로 보이는 "월드" 크기 = 뷰포트 픽셀 / 카메라 줌(stretch=expand·줌 대응).
	var vp := get_viewport().get_visible_rect().size
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.zoom.x > 0.0 and cam.zoom.y > 0.0:
		vp = Vector2(vp.x / cam.zoom.x, vp.y / cam.zoom.y)
	var half_w := vp.x * 0.5
	var half_h := vp.y * 0.5
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
		return

	for tx in range(tx0, tx1):
		for ty in range(ty0, ty1):
			var lx := float(tx * TILE) - wx
			var ly := float(ty * TILE) - wy
			var col := tile_a if (tx + ty) & 1 == 0 else tile_b
			draw_rect(Rect2(lx, ly, float(TILE), float(TILE)), col)
			_draw_detail(theme_name, lx, ly, tx, ty, mark)


## 테마별 타일 장식. 월드 타일 좌표(tx, ty)를 해시로 사용해 이동해도 패턴이 유지됨.
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
