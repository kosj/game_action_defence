extends Node2D
## 번개 타격 이펙트: 위에서 내려오는 지그재그 번개 + 충돌 지점 플래시.

var duration: float = 0.22
var _time: float = 0.0
var _bolt: PackedVector2Array = []

const _DROP_HEIGHT := 900.0
const _SEGMENTS := 9
const _JITTER := 22.0


func _ready() -> void:
	_bolt = _make_bolt()


func _make_bolt() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var start := Vector2(0.0, -_DROP_HEIGHT)
	for i in range(_SEGMENTS + 1):
		var t := float(i) / _SEGMENTS
		var p := start.lerp(Vector2.ZERO, t)
		if i != 0 and i != _SEGMENTS:
			p.x += randf_range(-_JITTER, _JITTER)
		pts.append(p)
	return pts


func _process(delta: float) -> void:
	_time += delta
	if _time >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _time / duration
	var a := 1.0 - t
	draw_polyline(_bolt, Color(1.0, 1.0, 1.0, a), 2.0)
	draw_polyline(_bolt, Color(0.55, 0.85, 1.0, a * 0.9), 6.0)
	draw_circle(Vector2.ZERO, 30.0 * (1.0 - t * 0.5), Color(0.6, 0.88, 1.0, a * 0.35))
	if t < 0.4:
		var ft := t / 0.4
		draw_circle(Vector2.ZERO, 12.0 * (1.0 - ft), Color(1.0, 1.0, 1.0, (1.0 - ft) * 0.9))
