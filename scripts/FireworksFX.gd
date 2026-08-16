class_name FireworksFX
extends RefCounted
## 축하 폭죽 헬퍼 — 일시정지 중에도 동작하는 UI 레이어(PROCESS_MODE_ALWAYS)에 원샷 파티클
## 폭죽을 시차를 두고 터뜨린다.
##
## 정리는 시간 기반이어야 한다. CPUParticles2D 는 화면에서 숨겨지면(패널이 닫히면)
## 시뮬레이션 자체를 멈추고 finished 를 영영 emit 하지 않는다. finished 에만 의존하면
## 조기에 닫을 때마다 파티클이 그대로 남아 쌓이고, 다음에 패널이 열리는 순간 수천 개가
## 한꺼번에 되살아나 프레임이 무너진다. 그래서 수명 타이머로도 반드시 해제한다.

## 한 홀더에 동시에 살아있을 수 있는 폭죽 수 — 폭주 방지 상한.
const MAX_LIVE := 64

## 폭죽 1발 — 방사 폭발 + 중력 낙하 + 알파 페이드.
static func burst(parent: Node, pos: Vector2, color: Color, size_mul: float = 1.0) -> void:
	if not is_instance_valid(parent) or parent.get_child_count() >= MAX_LIVE:
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
	# 숨겨져 finished 가 오지 않는 경우까지 확실히 정리(정지·배속과 무관한 실시간 타이머).
	var t := p.get_tree().create_timer(p.lifetime + 0.5, true, false, true)
	t.timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())
	SoundManager.play_ui("gold", 0.08, 1.3 + randf() * 0.3)


## 영역 안 무작위 위치에 count 발을 시차 발사 — 틱마다 2발씩 짧은 간격으로 쏟아붓는다.
## 반환한 Tween 은 호출측이 패널을 닫을 때 kill() 해야 한다(숨은 홀더로 계속 쏘지 않도록).
static func celebrate(parent: Node, region: Rect2, cols: Array, count: int) -> Tween:
	if not is_instance_valid(parent) or cols.is_empty():
		return null
	var tw := parent.create_tween()
	for i in range(maxi(1, count / 2)):
		tw.tween_interval(0.03 if i == 0 else randf_range(0.05, 0.11))
		tw.tween_callback(_pop_random.bind(parent, region, cols))
		tw.tween_callback(_pop_random.bind(parent, region, cols))
	return tw


static func _pop_random(parent: Node, region: Rect2, cols: Array) -> void:
	if not is_instance_valid(parent):
		return
	var pos := Vector2(randf_range(region.position.x, region.end.x), randf_range(region.position.y, region.end.y))
	burst(parent, pos, cols[randi() % cols.size()])
