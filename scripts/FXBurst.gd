extends Node2D

var color: Color = Color(1.0, 0.7, 0.2)
var max_radius: float = 32.0
var duration: float = 0.35
var start_delay: float = 0.0   # >0 이면 그 시간만큼 기다렸다 터진다(시간차 다중 파동용)
var _time: float = 0.0

func _process(delta: float) -> void:
	if start_delay > 0.0:
		start_delay -= delta
		return
	_time += delta
	if _time >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if start_delay > 0.0:
		return
	var t := _time / duration
	# expanding outer ring
	draw_circle(Vector2.ZERO, max_radius * t, Color(color.r, color.g, color.b, (1.0 - t) * 0.55))
	# bright inner flash (only early)
	if t < 0.45:
		var ft := t / 0.45
		draw_circle(Vector2.ZERO, max_radius * 0.38 * (1.0 - ft), Color(1.0, 1.0, 0.8, (1.0 - ft) * 0.85))
