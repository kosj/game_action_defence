class_name FireworksFX
extends RefCounted
## 축하 폭죽 헬퍼 — 일시정지 중에도 동작하는 UI 레이어(PROCESS_MODE_ALWAYS)에 원샷 파티클
## 폭죽을 시차를 두고 터뜨린다. 파티클은 finished 시그널로 스스로 정리되어 조기 닫힘에도 안전.

## 폭죽 1발 — 방사 폭발 + 중력 낙하 + 알파 페이드.
static func burst(parent: Node, pos: Vector2, color: Color, size_mul: float = 1.0) -> void:
	if not is_instance_valid(parent):
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = int(24 * size_mul)
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2(0, 260)
	p.initial_velocity_min = 150.0 * size_mul
	p.initial_velocity_max = 340.0 * size_mul
	p.damping_min = 40.0
	p.damping_max = 110.0
	p.scale_amount_min = 1.4
	p.scale_amount_max = 3.2 * size_mul
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	p.emitting = true
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	SoundManager.play_ui("gold", 0.08, 1.3 + randf() * 0.3)


## 영역 안 무작위 위치에 count 발을 시차 발사(첫 발은 즉시에 가깝게).
static func celebrate(parent: Node, region: Rect2, cols: Array, count: int) -> void:
	if not is_instance_valid(parent) or cols.is_empty():
		return
	var tw := parent.create_tween()
	for i in count:
		tw.tween_interval(0.03 if i == 0 else randf_range(0.09, 0.20))
		tw.tween_callback(_pop_random.bind(parent, region, cols))


static func _pop_random(parent: Node, region: Rect2, cols: Array) -> void:
	if not is_instance_valid(parent):
		return
	var pos := Vector2(randf_range(region.position.x, region.end.x), randf_range(region.position.y, region.end.y))
	burst(parent, pos, cols[randi() % cols.size()])
