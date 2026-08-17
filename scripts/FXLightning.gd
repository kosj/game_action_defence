extends Node2D
## 번개 타격 이펙트: 위에서 내려오는 굵은 지그재그 번개 + 꺽임 강조 + 분기 + 충돌 지점 플래시.

const _FXMaterial := preload("res://scripts/FXMaterial.gd")
var duration: float = 0.28
var _time: float = 0.0
var _bolt: PackedVector2Array = []
var _branches: Array = []   # Array[PackedVector2Array]
var _joints: PackedVector2Array = []   # interior bend points, drawn brighter

const _DROP_HEIGHT := 900.0
const _SEGMENTS := 7
const _JITTER := 38.0


## 동시 표시 상한. 인스턴스 하나가 _draw 당 draw 커맨드 30개 이상을 내는데, 다중 낙뢰
## (upgrade_lightning_count)는 한 프레임에 가닥 수만큼 전부 생성되므로 상한이 필요하다.
const MAX_ACTIVE := 6
static var _active_count: int = 0

## 씬 전환 시 카운터 초기화 — 인스턴스가 씬과 함께 해제되면 감소 처리를 못 지나가므로,
## 리셋하지 않으면 상한에 걸린 채 번개가 영구히 안 보이게 된다(Main._clean_slate 가 호출).
static func reset_pool() -> void:
	_active_count = 0


## 현재 동시 활성 수 / 상한 — 성능 디버그 오버레이(PerfOverlay)가 읽는다.
static func debug_active() -> int:
	return _active_count

static func debug_cap() -> int:
	return MAX_ACTIVE


## 상한을 지키며 생성. 초과분은 조용히 생략한다(피해는 Lightning 이 이미 적용했으므로 무관).
static func spawn(parent: Node, pos: Vector2) -> void:
	if _active_count >= MAX_ACTIVE:
		return
	_active_count += 1
	var fx: Node2D = (load("res://scripts/FXLightning.gd") as GDScript).new()
	parent.add_child(fx)
	fx.global_position = pos


func _ready() -> void:
	# 가산 혼합(ADD) — 겹치는 획이 서로 더해져 진짜 발광(이미시브)처럼 보인다.
	material = _FXMaterial.additive()   # 다른 가산 이펙트와 인스턴스를 공유해야 배치가 합쳐진다
	_bolt = _make_jagged(Vector2(0.0, -_DROP_HEIGHT), Vector2.ZERO, _SEGMENTS, _JITTER)
	_joints = _bolt.slice(1, _bolt.size() - 1)
	_branches = _make_branches()


## 시작점→끝점을 따라 중간 지점들을 무작위로 옆으로 꺾어 지그재그를 만든다.
func _make_jagged(from: Vector2, to: Vector2, segments: int, jitter: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments + 1):
		var t := float(i) / segments
		var p := from.lerp(to, t)
		if i != 0 and i != segments:
			p.x += randf_range(-jitter, jitter)
		pts.append(p)
	return pts


## 본선 중간의 꺽이는 지점 한두 곳에서 옆으로 갈라지는 짧은 가지를 생성.
func _make_branches() -> Array:
	var branches := []
	var branch_count := randi_range(1, 2)
	for i in branch_count:
		var idx := randi_range(1, _bolt.size() - 2)
		var origin: Vector2 = _bolt[idx]
		var side := -1.0 if randf() < 0.5 else 1.0
		var end := origin + Vector2(side * randf_range(60.0, 110.0), randf_range(70.0, 130.0))
		branches.append(_make_jagged(origin, end, 3, 16.0))
	return branches


func _process(delta: float) -> void:
	_time += delta
	if _time >= duration:
		_active_count = maxi(0, _active_count - 1)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _time / duration
	var a := 1.0 - t

	# 본선: 아주 넓은 대기 글로우 → 외곽 → 중간 → 두꺼운 백색 코어. 가산 혼합이라 겹칠수록
	# 밝게 타올라 부피감 있는 발광 기둥으로 보인다.
	draw_polyline(_bolt, Color(0.20, 0.45, 1.0, a * 0.16), 34.0, true)
	draw_polyline(_bolt, Color(0.40, 0.70, 1.0, a * 0.30), 19.0, true)
	draw_polyline(_bolt, Color(0.65, 0.88, 1.0, a * 0.65), 10.0, true)
	draw_polyline(_bolt, Color(1.0, 1.0, 1.0, a), 5.0, true)

	# 꺽이는 지점 — 발광 마디(코어 + 글로우 2겹)로 굴절을 강조
	for joint in _joints:
		draw_circle(joint, 7.0, Color(1.0, 1.0, 1.0, a * 0.9))
		draw_circle(joint, 13.0, Color(0.6, 0.88, 1.0, a * 0.40))
		draw_circle(joint, 20.0, Color(0.35, 0.6, 1.0, a * 0.18))

	# 분기 가지: 본선보다 얇게(글로우 포함)
	for branch in _branches:
		draw_polyline(branch, Color(0.35, 0.6, 1.0, a * 0.25), 12.0, true)
		draw_polyline(branch, Color(0.6, 0.88, 1.0, a * 0.5), 6.5, true)
		draw_polyline(branch, Color(1.0, 1.0, 1.0, a * 0.85), 3.0, true)

	# 착탄 지점 — 넓은 대기광 + 코어 글로우 + 바깥으로 퍼지는 충격 링
	draw_circle(Vector2.ZERO, 84.0 * (1.0 - t * 0.35), Color(0.35, 0.6, 1.0, a * 0.14))
	draw_circle(Vector2.ZERO, 40.0 * (1.0 - t * 0.5), Color(0.6, 0.88, 1.0, a * 0.40))
	draw_arc(Vector2.ZERO, 18.0 + 74.0 * t, 0.0, TAU, 30, Color(0.75, 0.92, 1.0, (1.0 - t) * 0.5), 4.0, true)
	if t < 0.4:
		var ft := t / 0.4
		draw_circle(Vector2.ZERO, 20.0 * (1.0 - ft), Color(1.0, 1.0, 1.0, (1.0 - ft)))
