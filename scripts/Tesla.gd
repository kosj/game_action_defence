extends WeaponModule
## 테슬라 코일(연쇄 번개): 주기적으로 최근접 적을 때리고, 근처 적들로 번개가 연쇄된다.
## _data: fire_interval=방전 주기, area_radius=첫 표적 사거리, proj_damage/dmg_per_level=타격당 피해.
## 연쇄 수는 레벨로 늘어난다.

const _FXMaterial := preload("res://scripts/FXMaterial.gd")
const CHAIN_RANGE := 170.0   # 다음 연쇄 대상까지 허용 거리
const ARC_FADE := 0.22       # 아크 잔상 지속 — 번개가 "번쩍하고 남는" 여운
const JAG_STEP := 26.0       # 지그재그 분할 간격(px) — 짧을수록 세밀한 번개
const FLICKER := 0.035       # 이 간격마다 지그재그를 다시 뽑아 파직거리는 플리커를 만든다

var _t: float = 0.0
var _arc_t: float = 0.0
var _segs: Array = []        # Array[[Vector2, Vector2]] — 연쇄 구간(월드 좌표, 직선 기준점)
var _bolts: Array = []       # Array[PackedVector2Array] — 구간별 지그재그 폴리라인(월드 좌표)
var _branches: Array = []    # Array[PackedVector2Array] — 곁가지(월드 좌표)
var _flick_t: float = 0.0


func _chain_count(lvl: int) -> int:
	return 2 + int(lvl / 2)


func _ready() -> void:
	# 가산 블렌드 — 번개 겹칠수록 빛나는 이미시브 발광(FXLightning 과 동일 규약).
	material = _FXMaterial.additive()   # 공유 인스턴스 — 개별 생성 시 드로우 배치가 쪼개진다


func _physics_process(delta: float) -> void:
	if _data == null:
		return
	_t += delta
	if _t >= _data.fire_interval:
		_t = 0.0
		_zap()
	if _arc_t > 0.0:
		_arc_t -= delta
		_flick_t -= delta
		if _flick_t <= 0.0:
			_flick_t = FLICKER
			_rebuild_bolts()   # 잔상 동안 지그재그를 계속 다시 뽑아 파직거리게
		if _arc_t <= 0.0:
			_segs.clear()
			_bolts.clear()
			_branches.clear()
		queue_redraw()


func _zap() -> void:
	var lvl := _level()
	var first := _nearest_zombie(_data.area_radius * Events.area_mult())
	if first == null:
		return
	var dmg: int = _data.proj_damage + _data.dmg_per_level * (lvl - 1)
	var chain := _chain_count(lvl)
	var hit: Dictionary = {}
	var prev: Vector2 = _muzzle()   # 첫 아크는 캐릭터 몸통이 아니라 그림 속 총구에서 뻗는다
	var cur: Node2D = first
	_segs.clear()
	for _i in range(chain):
		if cur == null:
			break
		hit[cur.get_instance_id()] = true
		cur.take_damage(dmg)
		var cp: Vector2 = cur.global_position
		_segs.append([prev, cp])
		_FXBurst.spawn(get_tree().current_scene, cp, _data.color, 26.0, 0.20)
		prev = cp
		cur = _next_chain(cp, hit)
	_arc_t = ARC_FADE
	_flick_t = 0.0   # 다음 물리 틱에 즉시 지그재그 생성
	_rebuild_bolts()
	SoundManager.play("tesla_arc", 0.1, 1.15)   # 연쇄 번개 — 코일보다 가볍고 빠르게
	queue_redraw()


## 연쇄 구간마다 지그재그 폴리라인과 곁가지를 새로 뽑는다 — 호출할 때마다 모양이 달라져
## 잔상 동안 번개가 살아있는 것처럼 파직거린다.
func _rebuild_bolts() -> void:
	_bolts.clear()
	_branches.clear()
	for seg in _segs:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var seg_len := a.distance_to(b)
		var n := maxi(2, int(seg_len / JAG_STEP))
		var dir := (b - a) / float(n)
		var perp := dir.orthogonal().normalized()
		var pts := PackedVector2Array()
		pts.append(a)
		for i in range(1, n):
			# 끝점(발사원·타격점)은 고정하고 중간일수록 크게 흔든다 — 번개 특유의 열상 형태.
			var mid_w := sin(PI * float(i) / float(n))
			pts.append(a + dir * float(i) + perp * randf_range(-1.0, 1.0) * seg_len * 0.10 * (0.35 + mid_w))
		pts.append(b)
		_bolts.append(pts)
		# 곁가지 — 중간 지점에서 짧게 갈라져 나가는 잔가지 1~2개.
		for _k in range(1 + randi() % 2):
			if pts.size() < 3:
				break
			var bi := 1 + randi() % (pts.size() - 2)
			var origin := pts[bi]
			var bdir := (dir.normalized().rotated(randf_range(-1.2, 1.2)))
			var blen := seg_len * randf_range(0.15, 0.30)
			_branches.append(PackedVector2Array([origin, origin + bdir * blen * 0.6,
				origin + bdir * blen + perp * randf_range(-8.0, 8.0)]))


## 마지막 타격 지점 근처의, 아직 안 맞은 최근접 좀비.
func _next_chain(from: Vector2, hit: Dictionary) -> Node2D:
	var nearest: Node2D = null
	var chain_r := CHAIN_RANGE * Events.area_mult()
	var min_d := chain_r * chain_r
	for z in Events.live_zombies():
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		if hit.has(z.get_instance_id()):
			continue
		var d := from.distance_squared_to(z.global_position)
		if d < min_d:
			min_d = d
			nearest = z
	return nearest


## 볼류메트릭 번개: 굵고 옅은 외곽 광륜 → 중간 → 흰 코어의 다층 폴리라인(가산 블렌드로 발광).
## 타격점에는 대기 글로우 + 코어 섬광을 겹친다.
func _draw() -> void:
	if _arc_t <= 0.0 or _bolts.is_empty():
		return
	var a := clampf(_arc_t / ARC_FADE, 0.0, 1.0)
	var gp := global_position
	for pts in _bolts:
		var local := PackedVector2Array()
		for p in pts:
			local.append(p - gp)
		draw_polyline(local, Color(0.25, 0.45, 1.0, a * 0.16), 16.0, true)   # 깊은 파랑 외곽 광륜
		draw_polyline(local, Color(0.45, 0.75, 1.0, a * 0.30), 8.5, true)
		draw_polyline(local, Color(0.75, 0.92, 1.0, a * 0.65), 4.0, true)
		draw_polyline(local, Color(1.0, 1.0, 1.0, a), 1.8, true)             # 흰 코어
	for pts in _branches:
		var local2 := PackedVector2Array()
		for p in pts:
			local2.append(p - gp)
		draw_polyline(local2, Color(0.45, 0.75, 1.0, a * 0.25), 5.0, true)
		draw_polyline(local2, Color(0.95, 0.98, 1.0, a * 0.8), 1.5, true)
	# 타격점 발광 — 연쇄가 꽂힌 곳마다 전기 스파크 코어.
	for seg in _segs:
		var p1: Vector2 = seg[1] - gp
		draw_circle(p1, 13.0, Color(0.35, 0.6, 1.0, a * 0.22))
		draw_circle(p1, 6.5, Color(0.7, 0.9, 1.0, a * 0.55))
		draw_circle(p1, 2.8, Color(1.0, 1.0, 1.0, a))
