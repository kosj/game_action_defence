extends Node2D
## 번개 타격 이펙트: 위에서 내려오는 굵은 지그재그 번개 + 꺽임 강조 + 분기 + 충돌 지점 플래시.

var duration: float = 0.22
var _time: float = 0.0
var _bolt: PackedVector2Array = []
var _branches: Array = []   # Array[PackedVector2Array]
var _joints: PackedVector2Array = []   # interior bend points, drawn brighter

const _DROP_HEIGHT := 900.0
const _SEGMENTS := 7
const _JITTER := 38.0


func _ready() -> void:
	_bolt = _make_jagged(Vector2(0.0, -_DROP_HEIGHT), Vector2.ZERO, _SEGMENTS, _JITTER)
	_joints = _bolt.slice(1, _bolt.size() - 1)
	_branches = _make_branches()


## 시작점→끝점을 따라 중간 지점들을 무작위로 옆으로 꺾어 지그재그를 만든다.
func _make_jagged(from: Vector2, to: Vector2, segments: int, jitter: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments + 1):
		var t := float(i) / segments
		var p := from.lerp(to, t)
		if i != 0 and i != segments:
			p.x += randf_range(-jitter, jitter)
		pts.append(p)
	return pts


## 본선 중간의 꺽이는 지점 한두 곳에서 옆으로 갈라지는 짧은 가지를 생성.
func _make_branches() -> Array:
	var branches := []
	var branch_count := randi_range(1, 2)
	for i in branch_count:
		var idx := randi_range(1, _bolt.size() - 2)
		var origin: Vector2 = _bolt[idx]
		var side := -1.0 if randf() < 0.5 else 1.0
		var end := origin + Vector2(side * randf_range(60.0, 110.0), randf_range(70.0, 130.0))
		branches.append(_make_jagged(origin, end, 3, 16.0))
	return branches


func _process(delta: float) -> void:
	_time += delta
	if _time >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _time / duration
	var a := 1.0 - t

	# 본선: 굵은 외곽 글로우 -> 중간 톤 -> 가는 백색 코어 순으로 겹쳐 두께감 강조
	draw_polyline(_bolt, Color(0.55, 0.85, 1.0, a * 0.35), 16.0, true)
	draw_polyline(_bolt, Color(0.65, 0.88, 1.0, a * 0.7), 8.0, true)
	draw_polyline(_bolt, Color(1.0, 1.0, 1.0, a), 3.5, true)

	# 꺽이는 지점마다 밝은 점을 찍어 굴절을 시각적으로 강조
	for joint in _joints:
		draw_circle(joint, 6.0, Color(1.0, 1.0, 1.0, a * 0.9))
		draw_circle(joint, 10.0, Color(0.6, 0.88, 1.0, a * 0.4))

	# 분기 가지: 본선보다 얇게
	for branch in _branches:
		draw_polyline(branch, Color(0.6, 0.88, 1.0, a * 0.5), 6.0, true)
		draw_polyline(branch, Color(1.0, 1.0, 1.0, a * 0.85), 2.5, true)

	draw_circle(Vector2.ZERO, 34.0 * (1.0 - t * 0.5), Color(0.6, 0.88, 1.0, a * 0.35))
	if t < 0.4:
		var ft := t / 0.4
		draw_circle(Vector2.ZERO, 14.0 * (1.0 - ft), Color(1.0, 1.0, 1.0, (1.0 - ft) * 0.9))
