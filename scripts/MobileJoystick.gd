extends Control
## 모바일 가상 조이스틱 (다이내믹 방식)
## - 화면(또는 좌측 영역)을 터치/클릭하면 그 지점에 베이스가 생기고, 드래그로 방향 입력.
## - get_value() 가 -1..1 범위의 Vector2 를 돌려줌 (길이 0~1).
## - 터치(InputEventScreenTouch) + 마우스(InputEventMouseButton) 모두 지원.
##   WebGL에서 emulate_touch_from_mouse 가 작동하지 않는 경우 마우스 경로로 폴백.

@export var base_radius: float = 110.0
@export var knob_radius: float = 48.0
@export var dead_zone: float = 0.12
@export var activation_ratio: float = 1.0

const _BASE_TEX := preload("res://assets/ui/ui_joystick_base.png")
const _KNOB_TEX := preload("res://assets/ui/ui_joystick_knob.png")
const _MOUSE_INDEX := -999   # 마우스 입력 구분용 센티널

var _value: Vector2 = Vector2.ZERO
var _active: bool = false
var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("joystick")
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func get_value() -> Vector2:
	return _value


func _input(event: InputEvent) -> void:
	# ── 터치 시작/종료 ────────────────────────────────────────────
	if event is InputEventScreenTouch:
		if event.pressed:
			_try_activate(event.position, event.index)
		elif event.index == _touch_index:
			_reset()

	# ── 마우스 버튼 (WebGL 데스크톱 폴백) ──────────────────────────
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_activate(event.position, _MOUSE_INDEX)
		elif _touch_index == _MOUSE_INDEX:
			_reset()

	# ── 터치 드래그 ───────────────────────────────────────────────
	elif event is InputEventScreenDrag and _active and event.index == _touch_index:
		_move_knob(event.position)

	# ── 마우스 이동 ───────────────────────────────────────────────
	elif event is InputEventMouseMotion and _active and _touch_index == _MOUSE_INDEX:
		_move_knob(event.position)


func _try_activate(pos: Vector2, index: int) -> void:
	if _active:
		return
	var max_x := get_viewport_rect().size.x * activation_ratio
	if pos.x <= max_x:
		_active = true
		_touch_index = index
		_origin = pos
		_knob_pos = pos
		_value = Vector2.ZERO
		queue_redraw()


func _move_knob(pos: Vector2) -> void:
	var offset := pos - _origin
	if offset.length() > base_radius:
		offset = offset.normalized() * base_radius
	_knob_pos = _origin + offset
	var v := offset / base_radius
	if v.length() < dead_zone:
		v = Vector2.ZERO
	_value = v
	queue_redraw()


func _reset() -> void:
	_active = false
	_touch_index = -1
	_value = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var base_sz := Vector2(base_radius * 2, base_radius * 2)
	var knob_sz := Vector2(knob_radius * 2, knob_radius * 2)
	draw_texture_rect(_BASE_TEX, Rect2(_origin - base_sz * 0.5, base_sz), false)
	draw_texture_rect(_KNOB_TEX, Rect2(_knob_pos - knob_sz * 0.5, knob_sz), false)
