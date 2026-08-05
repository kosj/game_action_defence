extends Node2D
## 미장센 프롭 필드 — 선택 테마의 장식 프롭을 필드에 흩뿌린다.
## 월드좌표 해시로 배치해 플레이어가 움직여도 위치가 고정되고, Ground 처럼 보이는 범위만
## draw 로 그려 WebGL 성능을 지킨다. Phase A: 정적 배경 장식(충돌 없음, z_index=-1 로 유닛 뒤).
## prop_keys 가 비어 있는 테마(아트 미준비)는 아무것도 그리지 않는다.

const CELL := 260.0                       # 배치 격자(셀당 최대 1개)
const DENSITY := 30                       # 셀당 프롭 확률(해시 %100 < 이 값)
const TARGET := 104.0                     # 프롭 표시 최대 변(px) 기준
const DARKEN := Color(0.82, 0.82, 0.86)   # 바닥과 어우러지게 살짝 어둡게

const _PROP_TEX := {
	"wreck_car": preload("res://assets/sprites/props/prop_wreck_car.png"),
	"fence":     preload("res://assets/sprites/props/prop_fence.png"),
	"tank":      preload("res://assets/sprites/props/prop_tank.png"),
}

var _player: Node2D = null
var _last := Vector2(INF, INF)
var _keys: Array = []   # 이 테마에서 그릴 프롭 키(텍스처가 있는 것만)


func _ready() -> void:
	z_index = -1   # 바닥(-2) 위, 유닛(0) 아래
	_player = get_tree().get_first_node_in_group("player")
	var t: ThemeData = ThemeManager.selected()
	if t != null:
		for k in t.prop_keys:
			if _PROP_TEX.has(k):
				_keys.append(k)


func _process(_delta: float) -> void:
	if _keys.is_empty():
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	var p := _player.global_position
	if p.distance_squared_to(_last) > 16.0:
		_last = p
		queue_redraw()


## 정수 셀 좌표 → 안정적 해시(음수 없이).
func _hash(cx: int, cy: int) -> int:
	return ((cx * 73856093) ^ (cy * 19349663)) & 0x7fffffff


func _draw() -> void:
	if _keys.is_empty():
		return
	# 화면에 보이는 월드 크기 = 뷰포트 / 카메라 줌.
	var vp := get_viewport().get_visible_rect().size
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.zoom.x > 0.0 and cam.zoom.y > 0.0:
		vp = Vector2(vp.x / cam.zoom.x, vp.y / cam.zoom.y)
	var c := _last
	var margin := CELL   # 화면 경계에 걸친 프롭도 그려지도록 여유
	var x0 := int(floor((c.x - vp.x * 0.5 - margin) / CELL))
	var x1 := int(ceil((c.x + vp.x * 0.5 + margin) / CELL))
	var y0 := int(floor((c.y - vp.y * 0.5 - margin) / CELL))
	var y1 := int(ceil((c.y + vp.y * 0.5 + margin) / CELL))
	var cell_i := int(CELL)
	for cx in range(x0, x1):
		for cy in range(y0, y1):
			var h := _hash(cx, cy)
			if h % 100 >= DENSITY:
				continue
			var key: String = _keys[(h / 100) % _keys.size()]
			var tex: Texture2D = _PROP_TEX[key]
			var ts := tex.get_size()
			var sc: float = (TARGET / maxf(ts.x, ts.y)) * (0.8 + 0.5 * float((h / 7) % 100) / 100.0)
			var w := ts.x * sc
			var hgt := ts.y * sc
			# 셀 내 지터(월드 좌표 — 노드가 원점이라 로컬==월드)
			var px := float(cx) * CELL + float((h / 11) % cell_i)
			var py := float(cy) * CELL + float((h / 17) % cell_i)
			if ((h / 3) & 1) == 1:   # 좌우 반전으로 반복감 완화
				draw_set_transform(Vector2(px, py), 0.0, Vector2(-1.0, 1.0))
				draw_texture_rect(tex, Rect2(-w * 0.5, -hgt * 0.5, w, hgt), false, DARKEN)
			else:
				draw_texture_rect(tex, Rect2(px - w * 0.5, py - hgt * 0.5, w, hgt), false, DARKEN)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
