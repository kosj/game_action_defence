extends Node2D
## 떠오르는 데미지 숫자(타격 피드백). 명중 위치에서 살짝 튀어올라 사라진다.
## FXBurst 와 동일한 정적 풀로 재사용해 할당 비용을 없앤다.
##
## 노이즈·부하 제어: 대량 난전(좀비 100+·연사)에서 매 히트 숫자를 다 띄우면 화면 도배 +
## 웹 프레임 드랍이 난다. 일반 숫자는 "프레임당 스폰 상한"으로 표본만 보여주고(피해는 정상),
## 큰 한 방(보스/크리티컬)은 상한과 무관하게 항상 크게 표시한다.

static var _pool: Array = []
static var _frame: int = -1
static var _spawned_this_frame: int = 0
const MAX_PER_FRAME := 10        # 일반 숫자 프레임당 상한(초과분은 생략 — 피해엔 영향 없음)
const LIFE := 0.55

var _amount: int = 0
var _t: float = 0.0
var _active: bool = false
var _big: bool = false
var _color: Color = Color.WHITE
var _vel: Vector2 = Vector2(0, -50)


## big=true 는 큰 글씨(강조). bypass_cap=true 는 프레임 상한을 무시하고 항상 표시(보스처럼 드문 한 방).
## 크리티컬은 big=true·주황색으로 크게 보이되, 대량 발생 가능하므로 상한은 지킨다(bypass_cap=false).
static func spawn(parent: Node, pos: Vector2, amount: int, big: bool = false, color: Color = Color(1, 1, 1), bypass_cap: bool = false) -> void:
	var f := Engine.get_physics_frames()
	if f != _frame:
		_frame = f
		_spawned_this_frame = 0
	if not bypass_cap:
		if _spawned_this_frame >= MAX_PER_FRAME:
			return
		_spawned_this_frame += 1
	var d = _pool.pop_back() if _pool.size() > 0 else (load("res://scripts/DamageNumber.gd") as GDScript).new()
	d._amount = amount
	d._big = big
	d._color = color
	d._t = 0.0
	d._active = true
	d.visible = true
	d.z_index = 60   # 유닛·이펙트 위에 표시
	d._vel = Vector2(randf_range(-18.0, 18.0), randf_range(-62.0, -42.0))
	if d.get_parent() != parent:
		if d.get_parent() != null:
			d.get_parent().remove_child(d)
		parent.add_child(d)
	d.global_position = pos + Vector2(randf_range(-6.0, 6.0), -12.0)
	d.queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	global_position += _vel * delta
	_vel.y += 70.0 * delta   # 살짝 감속(위로 튀었다 잦아듦)
	if _t >= LIFE:
		_recycle()
		return
	queue_redraw()


func _recycle() -> void:
	_active = false
	visible = false
	if get_parent() != null:
		get_parent().remove_child(self)
	_pool.append(self)


static func clear_pool() -> void:
	for d in _pool:
		if is_instance_valid(d):
			d.queue_free()
	_pool.clear()


func _draw() -> void:
	if not _active:
		return
	var t := clampf(_t / LIFE, 0.0, 1.0)
	var a := 1.0 - t * t   # 끝으로 갈수록 빠르게 투명
	var font := ThemeDB.fallback_font
	var fsize := 34 if _big else 19
	var txt := str(_amount)
	var half_w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x * 0.5
	var pos := Vector2(-half_w, 0.0)
	draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 5, Color(0, 0, 0, a * 0.9))
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(_color.r, _color.g, _color.b, a))
