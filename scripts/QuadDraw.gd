class_name QuadDraw
extends RefCounted
## 캔버스 프리미티브를 텍스처 쿼드로 그리는 공용 헬퍼.
##
## 왜 필요한가
##   Godot 캔버스 배처는 한 CanvasItem 안에서도 **프리미티브 종류가 다르면 배치를 끊는다.**
##   색은 정점 데이터라 명령마다 달라도 묶이므로, 색을 텍스처에 구울 필요는 없다 —
##   모양만 텍스처로 옮기고 색은 틴트로 넘기면 된다(ASSET_PIPELINE.md 1절).
##
##   여기 있는 함수들은 전부 **게임플레이 아틀라스의 같은 시트**를 쓰므로 서로,
##   그리고 좀비·탄·바닥 쿼드와도 한 배치로 묶인다.
##
## 쓰는 법 — CanvasItem 을 첫 인자로 넘긴다(static 함수는 draw_* 를 직접 못 부른다).
##   QuadDraw.disc(self, Vector2.ZERO, 12.0, Color.RED)
##   QuadDraw.segment(self, a, b, col, 3.0)
##   QuadDraw.polyline(self, pts, col, 4.0)

## 단단한 원판(가장자리 2px 감쇠) — draw_circle 대체.
const BLOB := preload("res://assets/atlas/decal_blob.tres")
## 가로로 누운 획 — 선분 대체.
const STREAK := preload("res://assets/atlas/decal_streak.tres")
## 중심에서 퍼지는 쐐기 — 부채꼴/god-ray 대체.
const WEDGE := preload("res://assets/atlas/fx_wedge.tres")


static func disc(ci: CanvasItem, pos: Vector2, r: float, col: Color) -> void:
	if r <= 0.0:
		return
	ci.draw_texture_rect(BLOB, Rect2(pos.x - r, pos.y - r, r * 2.0, r * 2.0), false, col)


## 선분 하나. 축에 정렬된 것은 변환 없이 그린다 — draw_set_transform 은 명령이 하나 더 붙는다.
static func segment(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d := b - a
	var len := d.length()
	if len <= 0.001 or w <= 0.0:
		return
	ci.draw_set_transform(a, d.angle(), Vector2.ONE)
	ci.draw_texture_rect(STREAK, Rect2(0.0, -w * 0.5, len, w), false, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 꺾은선. 폭이 넓으면 꺾임점에 원판을 얹어 이음매가 벌어지는 것을 막는다
## (draw_polyline 은 조인트를 스스로 채우지만 쿼드는 그러지 못한다).
static func polyline(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float) -> void:
	if pts.size() < 2:
		return
	for i in pts.size() - 1:
		segment(ci, pts[i], pts[i + 1], col, w)
	if w > 3.0:
		for i in range(1, pts.size() - 1):
			disc(ci, pts[i], w * 0.5, col)


## 중심에서 뻗는 쐐기. ang=방향(rad), half=반각(rad), r=길이.
static func wedge(ci: CanvasItem, center: Vector2, ang: float, half: float,
		r: float, col: Color) -> void:
	if r <= 0.0 or half <= 0.0:
		return
	var w := 2.0 * r * sin(half)
	ci.draw_set_transform(center, ang, Vector2.ONE)
	ci.draw_texture_rect(WEDGE, Rect2(0.0, -w * 0.5, r, w), false, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 원형 테두리. 두께를 반지름과 무관하게 유지해야 하므로 세그먼트 쿼드로 그린다
## (링 텍스처를 늘리면 두께까지 같이 늘어난다). 전부 같은 시트라 한 배치로 묶인다.
static func ring(ci: CanvasItem, center: Vector2, r: float, col: Color, w: float,
		segs: int = 32, from_a: float = 0.0, to_a: float = TAU) -> void:
	if r <= 0.0 or segs < 2:
		return
	var span := to_a - from_a
	var step := span / float(segs)
	var prev := center + Vector2.from_angle(from_a) * r
	for i in range(1, segs + 1):
		var cur := center + Vector2.from_angle(from_a + step * float(i)) * r
		segment(ci, prev, cur, col, w)
		prev = cur
