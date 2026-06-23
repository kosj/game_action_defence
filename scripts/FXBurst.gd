extends Node2D
## 폭발/플래시 FX. 대량 동시 사망·발사 시 new()/queue_free() 가 프레임당 수십 번 일어나면
## 노드 할당/해제 스파이크로 끊김이 생긴다. 정적 풀(free-list)로 인스턴스를 재사용해
## 할당 비용을 0 으로 만든다 — 호출부는 _FXBurst.spawn(...) 만 쓰면 된다.

static var _pool: Array = []

var color: Color = Color(1.0, 0.7, 0.2)
var max_radius: float = 32.0
var duration: float = 0.35
var start_delay: float = 0.0   # >0 이면 그 시간만큼 기다렸다 터진다(시간차 다중 파동용)
var _time: float = 0.0
var _active: bool = false


## 풀에서 FX 하나를 꺼내(없으면 생성) parent 에 붙이고 즉시 재생. 끝나면 자동으로 풀에 반납.
static func spawn(parent: Node, pos: Vector2, p_color: Color, p_max_radius: float, p_duration: float, p_delay: float = 0.0) -> void:
	var fx = _pool.pop_back() if _pool.size() > 0 else (load("res://scripts/FXBurst.gd") as GDScript).new()
	fx.color = p_color
	fx.max_radius = p_max_radius
	fx.duration = p_duration
	fx.start_delay = p_delay
	fx._time = 0.0
	fx._active = true
	fx.visible = true
	if fx.get_parent() != parent:
		if fx.get_parent() != null:
			fx.get_parent().remove_child(fx)
		parent.add_child(fx)
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
	if get_parent() != null:
		get_parent().remove_child(self)
	_pool.append(self)


## 씬 전환 시 보관 중인 FX 오르팬 노드를 정리(메모리·오르팬 경고 방지).
static func clear_pool() -> void:
	for fx in _pool:
		if is_instance_valid(fx):
			fx.queue_free()
	_pool.clear()


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
