extends Node2D
## 바닥 타일 — 게임 시작 시 4종 테마 중 하나가 랜덤 선택됨.
## Camera2D 가 플레이어를 따라오므로 뷰포트 범위만 그려 WebGL 성능 유지.

const TILE := 80

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
	_player = get_tree().get_first_node_in_group("player")
	_theme = THEMES[randi() % THEMES.size()]
	# Background ColorRect 색을 테마에 맞게 교체
	var bg := get_parent().get_node_or_null("Background")
	if bg:
		bg.color = _theme["bg"]


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
	var vp     := get_viewport().get_visible_rect().size
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
