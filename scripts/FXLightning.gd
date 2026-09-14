extends Node2D
## 번개 타격 이펙트: 위에서 내려오는 굵은 지그재그 번개 + 꺽임 강조 + 분기 + 충돌 지점 플래시.

const _FXMaterial := preload("res://scripts/FXMaterial.gd")
var duration: float = 0.34
var _time: float = 0.0
var _bolt: PackedVector2Array = []
var _echo_bolt: PackedVector2Array = []
var _branches: Array = []   # Array[PackedVector2Array]
var _ground_forks: Array = []
var _sparks: Array = []
var _joints: PackedVector2Array = []   # interior bend points, drawn brighter

const _DROP_HEIGHT := 900.0
const _SEGMENTS := 9
const _JITTER := 48.0


## 동시 표시 상한. 인스턴스 하나가 짧은 시간 동안 많은 발광 레이어를 그리므로, 다중 낙뢰
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
	_echo_bolt = _make_jagged(Vector2(-18.0,-_DROP_HEIGHT),Vector2(5.0,0.0),_SEGMENTS,60.0)
	_joints = _bolt.slice(1, _bolt.size() - 1)
	_branches = _make_branches()
	_ground_forks = _make_ground_forks()
	for i in 14:
		_sparks.append({
			"dir": Vector2.from_angle(randf_range(-PI*0.94,-PI*0.06)),
			"dist": randf_range(45.0,125.0),
			"size": randf_range(1.5,4.0),
		})


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


## 본선 중간에서 여러 갈래로 갈라져 단일 선이 아니라 전기 방전 덩어리로 읽히게 한다.
func _make_branches() -> Array:
	var branches := []
	var branch_count := randi_range(3, 5)
	for i in branch_count:
		var idx := randi_range(1, _bolt.size() - 2)
		var origin: Vector2 = _bolt[idx]
		var side := -1.0 if randf() < 0.5 else 1.0
		var end := origin + Vector2(side*randf_range(70.0,150.0),randf_range(45.0,125.0))
		branches.append(_make_jagged(origin,end,randi_range(3,4),22.0))
	return branches


func _make_ground_forks() -> Array:
	var forks := []
	for i in 6:
		var angle := TAU*float(i)/6.0+randf_range(-0.28,0.28)
		var end := Vector2.from_angle(angle)*randf_range(60.0,125.0)
		# 지면 방전은 세로 폭을 눌러 바닥을 타고 퍼지는 모양으로 만든다.
		end.y *= 0.34
		forks.append(_make_jagged(Vector2.ZERO,end,3,10.0))
	return forks


func _process(delta: float) -> void:
	_time += delta
	if _time >= duration:
		_active_count = maxi(0, _active_count - 1)
		queue_free()
		return
	queue_redraw()


## ⚠️ 프리미티브 대신 **QuadDraw(텍스처 쿼드)** 로 그린다 — 캔버스 배처는 한 아이템
## 안에서도 프리미티브 종류가 다르면 배치를 끊는다(ASSET_PIPELINE.md 1절).
func _draw_tapered_bolt(points: PackedVector2Array, alpha: float, size_mul: float = 1.0) -> void:
	for i in points.size()-1:
		var depth := float(i+1)/float(points.size()-1)
		# 하늘 쪽은 가늘고 착탄점으로 갈수록 굵어진다. 구간별 맥동으로 케이블 같은 균일함을 없앤다.
		var irregular := 0.82+0.22*absf(sin(float(i)*2.17+_time*38.0))
		var width := lerpf(15.0,31.0,depth)*irregular*size_mul
		QuadDraw.segment(self,points[i],points[i+1],Color(0.16,0.38,1.0,alpha*0.15),width*1.9)
		QuadDraw.segment(self,points[i],points[i+1],Color(0.38,0.70,1.0,alpha*0.34),width)
		QuadDraw.segment(self,points[i],points[i+1],Color(0.72,0.92,1.0,alpha*0.72),width*0.45)
		QuadDraw.segment(self,points[i],points[i+1],Color(1.0,1.0,1.0,alpha),maxf(1.8,width*0.16))


func _draw() -> void:
	var t := _time / duration
	var a := pow(1.0-t,1.25)
	var flicker := 0.72+0.28*absf(sin(_time*64.0))
	a *= flicker

	# 번개 주변 공기까지 밝히는 넓은 광량 기둥. 선 바깥에 면적이 생겨 낙뢰의 부피가 느껴진다.
	QuadDraw.wedge(self,Vector2.ZERO,-PI*0.5,0.18,560.0,Color(0.22,0.48,1.0,a*0.055))
	QuadDraw.wedge(self,Vector2.ZERO,-PI*0.5,0.08,720.0,Color(0.55,0.82,1.0,a*0.045))
	# 약한 보조 방전 뒤에 굵기가 계속 변하는 본 방전을 겹친다.
	_draw_tapered_bolt(_echo_bolt,a*0.30,0.72)
	_draw_tapered_bolt(_bolt,a,1.0)

	# 꺽이는 지점 — 발광 마디(코어 + 글로우 2겹)로 굴절을 강조
	for joint in _joints:
		QuadDraw.disc(self, joint, 7.0, Color(1.0, 1.0, 1.0, a * 0.9))
		QuadDraw.disc(self, joint, 13.0, Color(0.6, 0.88, 1.0, a * 0.40))
		QuadDraw.disc(self, joint, 20.0, Color(0.35, 0.6, 1.0, a * 0.18))

	# 분기 가지: 본선보다 얇게(글로우 포함)
	for branch in _branches:
		QuadDraw.polyline(self,branch,Color(0.28,0.58,1.0,a*0.24),13.0)
		QuadDraw.polyline(self,branch,Color(0.72,0.92,1.0,a*0.68),4.0)
		QuadDraw.polyline(self,branch,Color(1.0,1.0,1.0,a*0.92),1.4)

	# 착탄점에서 지면을 타고 퍼지는 짧은 방전과 위로 튀는 전기 불꽃.
	for fork in _ground_forks:
		QuadDraw.polyline(self,fork,Color(0.25,0.55,1.0,a*0.32),10.0)
		QuadDraw.polyline(self,fork,Color(0.9,0.98,1.0,a*0.86),2.0)
	for spark in _sparks:
		var travel: Vector2 = spark["dir"]*float(spark["dist"])*(0.18+t)
		travel.y += 95.0*t*t
		QuadDraw.disc(self,travel,float(spark["size"])*(1.0-t),Color(0.78,0.94,1.0,a*0.9))

	# 착탄 지점 — 납작한 지면광과 여러 속도의 충격파로 폭발 면적을 만든다.
	QuadDraw.disc(self,Vector2.ZERO,98.0*(1.0-t*0.28),Color(0.22,0.52,1.0,a*0.15))
	QuadDraw.disc(self,Vector2.ZERO,48.0*(1.0-t*0.46),Color(0.65,0.90,1.0,a*0.44))
	QuadDraw.ring(self,Vector2.ZERO,16.0+96.0*t,Color(0.72,0.92,1.0,(1.0-t)*0.58),5.0,34)
	QuadDraw.ring(self,Vector2.ZERO,10.0+145.0*t,Color(0.32,0.68,1.0,(1.0-t)*0.24),2.5,40)
	if t < 0.4:
		var ft := t / 0.4
		QuadDraw.disc(self, Vector2.ZERO, 20.0 * (1.0 - ft), Color(1.0, 1.0, 1.0, (1.0 - ft)))
