extends Node2D
## 떠오르는 데미지 숫자(타격 피드백). 명중 위치에서 살짝 튀어올라 사라진다.
## FXBurst 와 동일한 정적 풀로 재사용해 할당 비용을 없앤다.
##
## 노이즈·부하 제어: 대량 난전(좀비 100+·연사)에서 매 히트 숫자를 다 띄우면 화면 도배 +
## 웹 프레임 드랍이 난다. 일반 숫자는 "프레임당 스폰 상한"으로 표본만 보여주고(피해는 정상),
## 큰 한 방(보스/크리티컬)은 별도의(더 낮은) 상한으로 우선 표시한다.
##
## 문자열 드로우는 GL Compatibility 렌더러에서 가장 비싼 2D 연산이다(글리프 셰이핑 + 외곽선은
## 글리프를 여러 방향으로 재렌더). 프레임당 상한만으로는 부족하다 — 수명 LIFE 동안 누적되므로
## MAX_PER_FRAME × LIFE × fps 만큼 동시에 살아있을 수 있다. FXBurst 처럼 동시 활성 상한을 둔다.

static var _pool: Array = []
static var _frame: int = -1
static var _spawned_this_frame: int = 0
static var _bypass_this_frame: int = 0
static var _active_count: int = 0

## 씬 전환 시 정적 풀 초기화 — 이전 씬과 함께 해제된 노드를 재사용해 "freed instance" 에러가 나거나,
## 활성 카운터가 리셋되지 않아 이펙트가 영구히 막히는 것을 방지한다(Main._clean_slate 가 호출).
static func reset_pool() -> void:
	_pool.clear()
	_frame = -1
	_spawned_this_frame = 0
	_bypass_this_frame = 0
	_active_count = 0

const MAX_ACTIVE := 36           # 동시 활성 상한 — 텍스트 드로우 총량을 이 수로 묶는다
const MAX_PER_FRAME := 8         # 일반 숫자 프레임당 상한(초과분은 생략 — 피해엔 영향 없음)
const MAX_BYPASS_PER_FRAME := 2  # 우선 표시(보스 등)도 프레임당 상한을 둔다 — 보스는 초당 수십 회 피격된다
const LIFE := 0.6
const BASE_FONT_SIZE := 24       # 일반 숫자 기준 크기(팝 애니메이션은 이 값에 배율)
const BIG_FONT_SIZE := 34        # 크리티컬/보스 강조 크기

var _amount: int = 0
var _t: float = 0.0
var _active: bool = false
var _big: bool = false
var _color: Color = Color.WHITE
var _vel: Vector2 = Vector2(0, -50)
var _half_w: float = 0.0   # 기본 폰트 크기에서의 문자열 반폭 — spawn 시 1회만 측정해 캐시


## big=true 는 큰 글씨(강조). bypass_cap=true 는 일반 숫자 상한과 별도의 우선 슬롯을 쓴다
## (보스 피격처럼 놓치면 안 되는 표시). 동시 활성 상한(MAX_ACTIVE)은 양쪽 모두 지킨다.
## 크리티컬은 big=true·주황색으로 크게 보이되, 대량 발생 가능하므로 일반 상한을 따른다(bypass_cap=false).
static func spawn(parent: Node, pos: Vector2, amount: int, big: bool = false, color: Color = Color(1, 1, 1), bypass_cap: bool = false) -> void:
	var f := Engine.get_physics_frames()
	if f != _frame:
		_frame = f
		_spawned_this_frame = 0
		_bypass_this_frame = 0
	# 동시 활성 상한은 우선 표시 여부와 무관하게 지킨다 — 이게 텍스트 드로우 총량의 실질 방어선이다.
	if _active_count >= MAX_ACTIVE:
		return
	if bypass_cap:
		if _bypass_this_frame >= MAX_BYPASS_PER_FRAME:
			return
		_bypass_this_frame += 1
	else:
		if _spawned_this_frame >= MAX_PER_FRAME:
			return
		_spawned_this_frame += 1
	_active_count += 1
	var d = _pool.pop_back() if _pool.size() > 0 else (load("res://scripts/DamageNumber.gd") as GDScript).new()
	d._amount = amount
	d._big = big
	d._color = color
	d._t = 0.0
	d._active = true
	d.visible = true
	# 문자열 폭은 수명 내내 바뀌지 않는다(팝은 배율로 근사) — 여기서 1회만 측정한다.
	var base_size := BIG_FONT_SIZE if big else BASE_FONT_SIZE
	d._half_w = ThemeDB.fallback_font.get_string_size(str(amount), HORIZONTAL_ALIGNMENT_LEFT, -1, base_size).x * 0.5
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
	_active_count = maxi(0, _active_count - 1)   # reset_pool 이 0 으로 되돌린 뒤 잔존 노드가 반납돼도 음수가 되지 않게
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
	# 등장 팝 — 초반 0.12초 동안 크게 튀었다 정상 크기로. 크리티컬(_big)은 더 큰 팝 + 미세 흔들림.
	# 크기는 2px 단위로 양자화한다: 팝 중 매 프레임 다른 크기를 쓰면 크기별 글리프 아틀라스가
	# 프레임마다 새로 생겨 캐시가 무의미해진다(팝은 0.12초뿐이지만 동시 수십 개가 함께 튄다).
	var base := BIG_FONT_SIZE if _big else BASE_FONT_SIZE
	var pop := 1.0 + (0.7 if _big else 0.45) * (1.0 - clampf(_t / 0.12, 0.0, 1.0))
	var fsize := int(round(base * pop / 2.0)) * 2
	var txt := str(_amount)
	# 폭은 spawn 시 측정한 기본 크기 기준값에 팝 배율을 곱해 근사(매 프레임 셰이핑 측정 제거).
	var half_w := _half_w * (float(fsize) / float(base))
	var shake := (sin(_t * 55.0) * 2.2 * (1.0 - t)) if _big else 0.0
	var pos := Vector2(-half_w + shake, 0.0)
	draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 5, Color(0, 0, 0, a * 0.9))
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(_color.r, _color.g, _color.b, a))
