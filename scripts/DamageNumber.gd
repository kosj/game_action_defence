extends Node2D
## 떠오르는 데미지 숫자(타격 피드백). 명중 위치에서 살짝 튀어올라 사라진다.
## FXBurst 와 동일한 정적 풀로 재사용해 할당 비용을 없앤다.
##
## 노이즈·부하 제어: 대량 난전(좀비 100+·연사)에서 매 히트 숫자를 다 띄우면 화면 도배 +
## 웹 프레임 드랍이 난다. 일반 숫자는 "프레임당 스폰 상한"으로 표본만 보여주고(피해는 정상),
## 큰 한 방(보스/크리티컬)은 별도의(더 낮은) 상한으로 우선 표시한다.
##
## 숫자는 **폰트가 아니라 게임플레이 아틀라스에 구운 비트맵 자릿수**로 그린다.
## `draw_string` 은 폰트 글리프 아틀라스를 쓰는데 그건 게임플레이 시트와 별개 텍스처라
## 숫자 하나가 뜰 때마다 배치가 끊긴다 — 실측으로 이 노드 하나가 드로우 콜 49개였다.
## 자릿수를 아틀라스 쿼드로 그리면 좀비·이펙트와 같은 배치에 묶여 사실상 0이 된다.
## 자릿수 텍스처는 `tools/gen_damage_digits.gd` 가 굽는다(검은 아웃라인 + 흰 글리프 한 장 —
## 색을 틴트로 곱하면 아웃라인은 검정 그대로, 글리프만 색이 된다).
##
## 프레임당 상한만으로는 부족하다 — 수명 LIFE 동안 누적되므로 MAX_PER_FRAME × LIFE × fps
## 만큼 동시에 살아있을 수 있다. 배치가 묶인 지금도 화면 도배(가독성)와 오버드로가 남으므로
## FXBurst 처럼 동시 활성 상한을 유지한다.

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


## 현재 동시 활성 수 / 상한 — 성능 디버그 오버레이(PerfOverlay)가 읽는다.
static func debug_active() -> int:
	return _active_count

static func debug_cap() -> int:
	return MAX_ACTIVE

const MAX_ACTIVE := 36           # 동시 활성 상한 — 텍스트 드로우 총량을 이 수로 묶는다
const MAX_PER_FRAME := 8         # 일반 숫자 프레임당 상한(초과분은 생략 — 피해엔 영향 없음)
const MAX_BYPASS_PER_FRAME := 2  # 우선 표시(보스 등)도 프레임당 상한을 둔다 — 보스는 초당 수십 회 피격된다
const LIFE := 0.6
const BASE_FONT_SIZE := 24       # 일반 숫자 기준 크기(팝 애니메이션은 이 값에 배율)
const BIG_FONT_SIZE := 34        # 크리티컬/보스 강조 크기

## 비트맵 자릿수 — tools/gen_damage_digits.gd 가 굽고 아래 세 상수를 출력한다.
## 값을 손으로 고치지 말고 생성기를 다시 돌려 출력된 것을 그대로 옮긴다.
## 좌표계는 BASE_FONT_SIZE(24) 표시 기준이며, 원본 draw_string 과 같이 y=0 이 베이스라인이다.
const GLYPH_ADVANCE := 13.0000                    # 자릿수 하나의 전진폭
const GLYPH_OFFSET := Vector2(-1.3333, -19.6667)  # 펜 위치 -> 쿼드 좌상단
const GLYPH_SIZE := Vector2(15.6667, 21.6667)     # 쿼드 크기
const _DIGIT_TEX := [
	preload("res://assets/atlas/dmg_0.tres"), preload("res://assets/atlas/dmg_1.tres"),
	preload("res://assets/atlas/dmg_2.tres"), preload("res://assets/atlas/dmg_3.tres"),
	preload("res://assets/atlas/dmg_4.tres"), preload("res://assets/atlas/dmg_5.tres"),
	preload("res://assets/atlas/dmg_6.tres"), preload("res://assets/atlas/dmg_7.tres"),
	preload("res://assets/atlas/dmg_8.tres"), preload("res://assets/atlas/dmg_9.tres"),
]

var _t: float = 0.0
var _active: bool = false
var _big: bool = false
var _color: Color = Color.WHITE
var _vel: Vector2 = Vector2(0, -50)
var _digits: PackedByteArray = PackedByteArray()   # 자릿수(상위→하위) — spawn 시 1회 분해


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
	d._big = big
	d._color = color
	d._t = 0.0
	d._active = true
	d.visible = true
	# 자릿수 분해도 수명 내내 바뀌지 않는다 — 여기서 1회만 한다(_draw 에서 str() 할당 제거).
	# ⚠️ 지역 변수에 만들어 **통째로 대입**한다. PackedByteArray 는 값 타입이라
	# `d._digits.append(...)` 처럼 동적 프로퍼티 접근 뒤에 메서드를 부르면 사본이 바뀌고
	# 원본에는 아무 일도 안 일어난다(조용히 빈 배열이 되어 숫자가 안 보인다).
	var digs := PackedByteArray()
	var v := absi(amount)
	if v == 0:
		digs.append(0)
	else:
		while v > 0:
			digs.append(v % 10)
			v /= 10
		digs.reverse()
	d._digits = digs
	d.z_index = 60   # 유닛·이펙트 위에 표시
	d._vel = Vector2(randf_range(-18.0, 18.0), randf_range(-62.0, -42.0))
	# 이펙트는 Y 정렬이 필요 없다 — 전용 레이어(Events.fx_layer)에 붙여 유닛 스트림에서 빼면
	# 유닛 스프라이트 사이에 다른 텍스처/절차 드로우가 끼지 않아 배칭이 유지된다.
	# 레이어를 못 얻는 상황(씬 밖 호출)에서는 넘겨받은 parent 로 폴백한다.
	var host: Node = Events.fx_layer()
	if host == null:
		host = parent
	if d.get_parent() != host:
		if d.get_parent() != null:
			d.get_parent().remove_child(d)
		host.add_child(d)
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
	# 등장 팝 — 초반 0.12초 동안 크게 튀었다 정상 크기로. 크리티컬(_big)은 더 큰 팝 + 미세 흔들림.
	# 예전에는 크기를 2px 단위로 양자화했다(크기마다 글리프 아틀라스가 새로 생겨서). 비트맵
	# 자릿수는 텍스처 한 장을 배율만 바꿔 그리므로 그 비용이 없다 — 연속 배율로 부드럽게 튄다.
	var base := BIG_FONT_SIZE if _big else BASE_FONT_SIZE
	var pop := 1.0 + (0.7 if _big else 0.45) * (1.0 - clampf(_t / 0.12, 0.0, 1.0))
	var sc := float(base) * pop / float(BASE_FONT_SIZE)
	var shake := (sin(_t * 55.0) * 2.2 * (1.0 - t)) if _big else 0.0
	var adv := GLYPH_ADVANCE * sc
	var n := _digits.size()
	var x := -adv * float(n) * 0.5 + shake   # 원본의 -half_w 와 같은 중앙 정렬
	var qsz := GLYPH_SIZE * sc
	var qoff := GLYPH_OFFSET * sc
	# 아웃라인은 텍스처에 이미 구워져 있다(검정). 틴트를 곱해도 0 × c = 0 이라 검정 그대로고
	# 글리프(흰색)만 색이 된다 — 원본의 draw_string_outline + draw_string 두 번이 한 번이 된다.
	var col := Color(_color.r, _color.g, _color.b, a)
	for i in n:
		draw_texture_rect(_DIGIT_TEX[_digits[i]], Rect2(Vector2(x, 0.0) + qoff, qsz), false, col)
		x += adv
