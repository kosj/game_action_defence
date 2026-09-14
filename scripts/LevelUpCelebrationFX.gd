class_name LevelUpCelebrationFX
extends Control
## 레벨업 패널 뒤에서 화면 전체를 채우는 저채도 축하 연출.
## 폭죽은 별도 파티클 레이어가 담당하고, 이 노드는 방사광·링·별빛으로 화면 중심을 묶는다.

var _energy := 0.0:
	set(value):
		_energy = value
		queue_redraw()
var _phase := 0.0
var _accent := Color(0.52, 0.82, 1.0)
var _pulse: Tween = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	hide()


func play(evolved: bool = false) -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_accent = Color(1.0, 0.76, 0.24) if evolved else Color(0.48, 0.86, 1.0)
	_phase = 0.0
	_energy = 0.0
	show()
	set_process(true)
	_pulse = create_tween()
	_pulse.tween_property(self, "_energy", 1.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pulse.tween_property(self, "_energy", 0.42, 0.85).set_trans(Tween.TRANS_SINE)


func confirm() -> void:
	if not visible:
		return
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_pulse = create_tween()
	_pulse.tween_property(self, "_energy", 1.0, 0.10).set_trans(Tween.TRANS_QUAD)
	_pulse.tween_property(self, "_energy", 0.32, 0.30).set_trans(Tween.TRANS_SINE)


func clear() -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_pulse = null
	_energy = 0.0
	set_process(false)
	hide()


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * 0.34, TAU)
	queue_redraw()


func _draw() -> void:
	if _energy <= 0.001 or size.x <= 0.0 or size.y <= 0.0:
		return
	var center := size * 0.5
	var outer := size.length() * 0.58
	var inner := minf(size.x, size.y) * 0.16
	# 얇은 방사광이 패널 뒤에서 화면 끝까지 이어져 축하 장면의 중심을 만든다.
	for i in 16:
		var a0 := _phase + TAU * float(i) / 16.0
		var a1 := a0 + 0.055
		var col := _accent
		col.a = (0.035 if i % 2 == 0 else 0.018) * _energy
		draw_colored_polygon(PackedVector2Array([
			center + Vector2.from_angle(a0) * inner,
			center + Vector2.from_angle(a0) * outer,
			center + Vector2.from_angle(a1) * outer,
			center + Vector2.from_angle(a1) * inner]), col)
	for radius in [inner * 1.05, inner * 1.42, inner * 1.86]:
		var ring := _accent
		ring.a = 0.16 * _energy
		draw_arc(center, radius + sin(_phase * 3.0 + radius) * 4.0, 0.0, TAU, 96, ring, 2.0, true)
	# 고정된 분포를 회전시켜 매 프레임 난수를 쓰지 않고도 별빛이 화면 전체에서 흐르게 한다.
	for i in 28:
		var fx := fmod(float(i * 97 + 31), 101.0) / 101.0
		var fy := fmod(float(i * 53 + 17), 103.0) / 103.0
		var p := Vector2(fx * size.x, fy * size.y)
		var twinkle := 0.45 + 0.55 * sin(_phase * 5.0 + float(i) * 1.7)
		var s := (2.0 + float(i % 3)) * _energy
		var star := _accent.lightened(0.45)
		star.a = maxf(0.08, twinkle * 0.65) * _energy
		draw_line(p - Vector2(s, 0), p + Vector2(s, 0), star, 1.5, true)
		draw_line(p - Vector2(0, s), p + Vector2(0, s), star, 1.5, true)
