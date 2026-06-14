extends Control
## 모바일 가상 조이스틱 (다이내믹 방식)
## - 화면(또는 좌측 영역)을 터치하면 그 지점에 베이스가 생기고, 드래그로 방향 입력.
## - get_value() 가 -1..1 범위의 Vector2 를 돌려줌 (길이 0~1).
## - _input() 으로 InputEventScreenTouch/Drag 를 직접 처리하므로 화면 크기/스케일에 강함.
## - emulate_touch_from_mouse=true 덕분에 데스크톱 마우스로도 테스트된다.

@export var base_radius: float = 110.0      # 베이스(바깥 원) 반지름
@export var knob_radius: float = 48.0       # 노브(손가락) 반지름
@export var dead_zone: float = 0.12         # 이 미만의 입력은 0 처리
@export var activation_ratio: float = 1.0   # 1.0=화면 전체, 0.5=좌측 절반에서만 활성화

const _BASE_TEX := preload("res://assets/ui/ui_joystick_base.png")
const _KNOB_TEX := preload("res://assets/ui/ui_joystick_knob.png")

var _value: Vector2 = Vector2.ZERO
var _active: bool = false
var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO     # 베이스 중심(화면 좌표)
var _knob_pos: Vector2 = Vector2.ZERO   # 노브 위치(화면 좌표)


func _ready() -> void:
	add_to_group("joystick")
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # gui 이벤트를 막지 않음


func get_value() -> Vector2:
	return _value


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			# 아직 활성화되지 않았고, 활성화 영역 안에서 눌렀다면 시작
			var max_x := get_viewport_rect().size.x * activation_ratio
			if not _active and event.position.x <= max_x:
				_active = true
				_touch_index = event.index
				_origin = event.position
				_knob_pos = event.position
				_value = Vector2.ZERO
				queue_redraw()
		elif event.index == _touch_index:
			_reset()

	elif event is InputEventScreenDrag and _active and event.index == _touch_index:
		var offset := event.position - _origin
		# 베이스 반지름으로 클램프 → 정규화
		if offset.length() > base_radius:
			offset = offset.normalized() * base_radius
		_knob_pos = _origin + offset
		var v := offset / base_radius          # 길이 0~1
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
