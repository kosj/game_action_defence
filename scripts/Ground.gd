extends Node2D
## 잔디 바닥 — Camera2D 가 플레이어를 따라오므로 타일이 자동 스크롤되어 이동감 제공.
## 뷰포트 범위만 그려 WebGL 성능 유지.

const TILE := 80
const GRASS_A  := Color(0.13, 0.20, 0.10)   # 어두운 초록
const GRASS_B  := Color(0.16, 0.24, 0.13)   # 밝은 초록 (체커보드)
const MARK_COL := Color(0.22, 0.31, 0.16)   # 잔디 점·크로스

var _player: Node2D = null


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	global_position = _player.global_position
	queue_redraw()


func _draw() -> void:
	var vp    := get_viewport().get_visible_rect().size
	var half_w := vp.x * 0.5
	var half_h := vp.y * 0.5
	var wx    := global_position.x
	var wy    := global_position.y

	# 화면에 보이는 타일 인덱스 범위
	var tx0 := int(floor((wx - half_w) / TILE)) - 1
	var ty0 := int(floor((wy - half_h) / TILE)) - 1
	var tx1 := int(ceil((wx + half_w) / TILE)) + 1
	var ty1 := int(ceil((wy + half_h) / TILE)) + 1

	for tx in range(tx0, tx1):
		for ty in range(ty0, ty1):
			# 로컬 좌표 (= 화면 좌표 offset)
			var lx := float(tx * TILE) - wx
			var ly := float(ty * TILE) - wy
			# 체커보드 (월드 타일 인덱스 기반이므로 스크롤해도 패턴 유지)
			var col := GRASS_A if (tx + ty) & 1 == 0 else GRASS_B
			draw_rect(Rect2(lx, ly, float(TILE), float(TILE)), col)
			# 잔디 점
			if (tx * 3 + ty * 7) % 7 == 0:
				draw_circle(Vector2(lx + TILE * 0.5, ly + TILE * 0.5), 4.0, MARK_COL)
			# 작은 잔디 크로스
			elif (tx * 5 + ty * 3) % 11 == 0:
				var cx := lx + TILE * 0.5
				var cy := ly + TILE * 0.5
				draw_line(Vector2(cx - 5, cy - 2), Vector2(cx + 5, cy - 2), MARK_COL, 1.5)
				draw_line(Vector2(cx, cy - 6), Vector2(cx, cy + 2), MARK_COL, 1.5)
