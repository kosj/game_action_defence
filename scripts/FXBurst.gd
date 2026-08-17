extends Node2D
## 폭발/플래시 FX. 대량 동시 사망·발사 시 new()/queue_free() 가 프레임당 수십 번 일어나면
## 노드 할당/해제 스파이크로 끊김이 생긴다. 정적 풀(free-list)로 인스턴스를 재사용해
## 할당 비용을 0 으로 만든다 — 호출부는 _FXBurst.spawn(...) 만 쓰면 된다.

static var _pool: Array = []

# 동시표시 상한(Phase 7 성능 방어): 대량 난전에서 폭발 FX 가 프레임당 수백 개 생기면 그리기·노드
# 비용이 폭증한다. 동시 활성 수(_active_count)와 프레임당 신규 수(_spawned_this_frame)를 상한 처리해
# 초과분은 조용히 생략한다(피해·게임플레이엔 영향 없음, 시각 노이즈만 줄임).
const MAX_ACTIVE := 48
const MAX_PER_FRAME := 20
static var _active_count: int = 0
static var _frame: int = -1
static var _spawned_this_frame: int = 0

## 씬 전환 시 정적 풀 초기화 — 이전 씬과 함께 해제된 노드를 재사용해 "freed instance" 에러가 나거나,
## 활성 카운터가 리셋되지 않아 이펙트가 영구히 막히는 것을 방지한다(Main._clean_slate 가 호출).
static func reset_pool() -> void:
	_pool.clear()
	_active_count = 0
	_frame = -1
	_spawned_this_frame = 0


## 현재 동시 활성 수 / 상한 — 성능 디버그 오버레이(PerfOverlay)가 읽는다.
static func debug_active() -> int:
	return _active_count

static func debug_cap() -> int:
	return MAX_ACTIVE


var color: Color = Color(1.0, 0.7, 0.2)
var max_radius: float = 32.0
var duration: float = 0.35
var start_delay: float = 0.0   # >0 이면 그 시간만큼 기다렸다 터진다(시간차 다중 파동용)
var _time: float = 0.0
var _active: bool = false


## 풀에서 FX 하나를 꺼내(없으면 생성) parent 에 붙이고 즉시 재생. 끝나면 자동으로 풀에 반납.
static func spawn(parent: Node, pos: Vector2, p_color: Color, p_max_radius: float, p_duration: float, p_delay: float = 0.0) -> void:
	# 동시표시/프레임당 상한 — 초과분은 생략(프레임 방어).
	var f := Engine.get_physics_frames()
	if f != _frame:
		_frame = f
		_spawned_this_frame = 0
	if _active_count >= MAX_ACTIVE or _spawned_this_frame >= MAX_PER_FRAME:
		return
	_spawned_this_frame += 1
	_active_count += 1
	var fx = _pool.pop_back() if _pool.size() > 0 else (load("res://scripts/FXBurst.gd") as GDScript).new()
	fx.color = p_color
	fx.max_radius = p_max_radius
	fx.duration = p_duration
	fx.start_delay = p_delay
	fx._time = 0.0
	fx._active = true
	fx.visible = true
	# 이펙트는 Y 정렬이 필요 없다 — 전용 레이어(Events.fx_layer)에 붙여 유닛 스트림에서 빼면
	# 유닛 스프라이트 사이에 다른 텍스처/절차 드로우가 끼지 않아 배칭이 유지된다.
	# 레이어를 못 얻는 상황(씬 밖 호출)에서는 넘겨받은 parent 로 폴백한다.
	var host: Node = Events.fx_layer()
	if host == null:
		host = parent
	if fx.get_parent() != host:
		if fx.get_parent() != null:
			fx.get_parent().remove_child(fx)
		host.add_child(fx)
	fx.global_position = pos
	fx.queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	if start_delay > 0.0:
		start_delay -= delta
		return
	_time += delta
	if _time >= duration:
		_recycle()
		return
	queue_redraw()


## 트리에서 떼어내 풀에 보관(재사용 대기) — queue_free 를 대체해 재할당 비용을 없앤다.
func _recycle() -> void:
	_active = false
	visible = false
	_active_count = maxi(0, _active_count - 1)
	if get_parent() != null:
		get_parent().remove_child(self)
	_pool.append(self)


## 씬 전환 시 보관 중인 FX 오르팬 노드를 정리(메모리·오르팬 경고 방지).
static func clear_pool() -> void:
	for fx in _pool:
		if is_instance_valid(fx):
			fx.queue_free()
	_pool.clear()
	_active_count = 0


func _draw() -> void:
	if not _active or start_delay > 0.0:
		return
	var t := _time / duration
	# expanding outer ring
	draw_circle(Vector2.ZERO, max_radius * t, Color(color.r, color.g, color.b, (1.0 - t) * 0.55))
	# bright inner flash (only early)
	if t < 0.45:
		var ft := t / 0.45
		draw_circle(Vector2.ZERO, max_radius * 0.38 * (1.0 - ft), Color(1.0, 1.0, 0.8, (1.0 - ft) * 0.85))
