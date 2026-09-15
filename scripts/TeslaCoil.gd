extends Node2D
## 연구소 기믹: 폭주 테슬라 코일. 예고 후 주변에 방전해 범위 내 좀비·플레이어에게 피해. 주기 반복.
## 코일 본체·충전 아크·위험 구역·방전 섬광을 단계별로 보여 주어 기능을 바로 읽을 수 있게 한다.

const _FXBurst := preload("res://scripts/FXBurst.gd")

const TELEGRAPH := 0.8
const ACTIVE := 0.3
const COOLDOWN := 1.0
const ARC_R := 96.0
const ZOMBIE_DMG := 14
const PLAYER_DMG := 1
const LIFE := 12.0

var _player: Node2D = null
var _age: float = 0.0
var _life: float = LIFE
var _phase_t: float = 0.0
var _fired: bool = false
var _arcs: Array = []   # 방전 순간의 대상 상대좌표(그릴 끝점)


func _ready() -> void:
	z_index = 1   # 코일·아크가 유닛 위로
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	_age += delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	_phase_t += delta
	var ph := fmod(_phase_t, TELEGRAPH + ACTIVE + COOLDOWN)
	if ph < TELEGRAPH:
		_fired = false
	elif ph < TELEGRAPH + ACTIVE and not _fired:
		_fired = true
		_discharge()
	queue_redraw()


func _discharge() -> void:
	_arcs.clear()
	var r_sq := ARC_R * ARC_R
	for z in Events.live_zombies():
		if is_instance_valid(z) and z.is_in_group("zombies") \
				and global_position.distance_squared_to(z.global_position) < r_sq:
			z.take_damage(ZOMBIE_DMG)
			_arcs.append(z.global_position - global_position)
	if is_instance_valid(_player) and _player.global_position.distance_squared_to(global_position) < r_sq \
			and _player.has_method("take_hit"):
		_player.take_hit(PLAYER_DMG)
		_arcs.append(_player.global_position - global_position)
	_FXBurst.spawn(get_tree().current_scene, global_position, Color(0.6, 0.8, 1.0), ARC_R * 0.5, 0.25)
	Events.shake(4.0)
	SoundManager.play("tesla_arc", 0.06, 0.85)   # 고정 설치 코일 — 무기보다 낮고 묵직하게


## ⚠️ 프리미티브 대신 **QuadDraw(텍스처 쿼드)** 로 그린다 — 캔버스 배처는 한 아이템
## 안에서도 프리미티브 종류가 다르면 배치를 끊는다(ASSET_PIPELINE.md 1절).
func _draw() -> void:
	var ph := fmod(_phase_t, TELEGRAPH + ACTIVE + COOLDOWN)
	var head := Vector2(0.0, -31.0)
	var charge := 0.5 + 0.5 * sin(_age * 12.0)

	# 넓은 받침과 적층 코일을 항상 그려 단순한 표식이 아니라 전기 설비로 보이게 한다.
	QuadDraw.disc(self, Vector2(0.0, 8.0), 18.0, Color(0.02, 0.04, 0.07, 0.55))
	QuadDraw.rect(self, Rect2(-15.0, 1.0, 30.0, 8.0), Color(0.12, 0.16, 0.21, 1.0))
	QuadDraw.rect(self, Rect2(-11.0, -23.0, 22.0, 27.0), Color(0.20, 0.24, 0.31, 1.0))
	QuadDraw.rect(self, Rect2(-4.0, -28.0, 8.0, 31.0), Color(0.48, 0.55, 0.68, 1.0))
	for y in [-20.0, -13.0, -6.0]:
		QuadDraw.rect(self, Rect2(-14.0, y - 2.0, 28.0, 4.0), Color(0.34, 0.55, 0.78, 1.0))
		QuadDraw.rect(self, Rect2(-11.0, y - 0.7, 22.0, 1.4), Color(0.72, 0.88, 1.0, 0.85))
	# 상단 구형 전극과 양옆 방전봉.
	QuadDraw.segment(self, Vector2(-8.0, -25.0), Vector2(-17.0, -34.0), Color(0.45, 0.53, 0.65), 3.5)
	QuadDraw.segment(self, Vector2(8.0, -25.0), Vector2(17.0, -34.0), Color(0.45, 0.53, 0.65), 3.5)
	QuadDraw.disc(self, Vector2(-18.0, -35.0), 3.2, Color(0.74, 0.88, 1.0, 0.95))
	QuadDraw.disc(self, Vector2(18.0, -35.0), 3.2, Color(0.74, 0.88, 1.0, 0.95))
	QuadDraw.disc(self, head, 11.0 + 2.0 * charge, Color(0.30, 0.65, 1.0, 0.12 + 0.16 * charge))
	QuadDraw.disc(self, head, 7.0, Color(0.64, 0.82, 1.0, 1.0))
	QuadDraw.disc(self, head + Vector2(-2.0, -2.0), 2.4, Color(0.96, 1.0, 1.0, 0.95))
	# 받침의 번개 문양은 이 장치가 전기 위험물임을 정지 화면에서도 알려 준다.
	var bolt_col := Color(0.95, 0.82, 0.22, 0.95)
	QuadDraw.segment(self, Vector2(-2.0, -1.0), Vector2(3.0, 3.0), bolt_col, 2.2)
	QuadDraw.segment(self, Vector2(3.0, 3.0), Vector2(-1.0, 3.0), bolt_col, 2.2)
	QuadDraw.segment(self, Vector2(-1.0, 3.0), Vector2(3.0, 7.0), bolt_col, 2.2)
	if ph < TELEGRAPH:
		var p := ph / TELEGRAPH
		var blink := 0.55 + 0.45 * sin(_age * 20.0)
		# 충전: 범위가 밝아지고 바깥의 분절 아크가 회전하며 방전 시점을 예고한다.
		QuadDraw.disc(self, Vector2.ZERO, ARC_R, Color(0.16, 0.48, 0.92, 0.035 + 0.075 * p))
		QuadDraw.ring(self, Vector2.ZERO, ARC_R, Color(0.45, 0.72, 1.0, 0.30 + 0.45 * p), 2.6, 36)
		var sweep := -_age * 3.2
		for i in 4:
			var a := sweep + TAU * float(i) / 4.0
			QuadDraw.ring(self, Vector2.ZERO, ARC_R * (1.04 - 0.04 * p),
				Color(0.75, 0.92, 1.0, 0.42 + 0.45 * blink * p), 4.0, 8, a, a + 0.52)
		# 짧은 전기 스파크가 전극 사이를 튀며 "충전 중"임을 명시한다.
		_draw_bolt(Vector2(-18.0, -35.0), head, 0.35 + 0.55 * p, 1.5)
		_draw_bolt(head, Vector2(18.0, -35.0), 0.35 + 0.55 * p, 1.5)
		QuadDraw.disc(self, head, 9.0 + 7.0 * p, Color(0.72, 0.90, 1.0, (0.18 + 0.30 * blink) * p))
	elif ph < TELEGRAPH + ACTIVE:
		var fade := 1.0 - (ph - TELEGRAPH) / ACTIVE
		# 방전: 대상 유무와 관계없이 위험 구역 전체로 전기가 퍼져 나간다.
		QuadDraw.disc(self, Vector2.ZERO, ARC_R, Color(0.35, 0.68, 1.0, 0.16 * fade))
		QuadDraw.ring(self, Vector2.ZERO, ARC_R, Color(0.82, 0.95, 1.0, 0.88 * fade), 4.2, 36)
		QuadDraw.ring(self, Vector2.ZERO, ARC_R * (0.70 + 0.30 * fade), Color(0.50, 0.82, 1.0, 0.42 * fade), 2.5, 32)
		for i in 6:
			var a := TAU * float(i) / 6.0 + _age * 0.35
			_draw_bolt(head, Vector2.from_angle(a) * ARC_R * 0.9, 0.48 * fade, 2.3)
		for e in _arcs:
			_draw_bolt(head, e, fade, 3.2)
	else:
		# 재충전 중에도 작은 누설 스파크를 남겨 살아 있는 위험물임을 알린다.
		var leak_side := -1.0 if int(_age * 5.0) % 2 == 0 else 1.0
		var leak_end := head + Vector2(13.0 * leak_side, -7.0 - 4.0 * charge)
		_draw_bolt(head, leak_end, 0.24 + 0.20 * charge, 1.3)


## 지그재그 번개 선. 바깥 청색 광채와 흰 심선을 겹쳐 실제 방전처럼 보이게 한다.
func _draw_bolt(a: Vector2, b: Vector2, alpha: float = 1.0, width: float = 2.0) -> void:
	var segs := 6
	var pts := PackedVector2Array([a])
	var perp := (b - a).orthogonal().normalized()
	for i in range(1, segs + 1):
		var t := float(i) / float(segs)
		var mid := a.lerp(b, t)
		if i < segs:
			mid += perp * (sin(t * 15.0 + _age * 34.0) * minf(8.0, a.distance_to(b) * 0.08))
		pts.append(mid)
	QuadDraw.polyline(self, pts, Color(0.20, 0.58, 1.0, 0.34 * alpha), width * 2.8)
	QuadDraw.polyline(self, pts, Color(0.88, 0.97, 1.0, 0.95 * alpha), width)
