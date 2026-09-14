extends WeaponModule
## 캐릭터 궁극기(모듈 "ultimate"): 긴 재사용 대기 후 자동 발동 — area_duration 초 동안
## 화면 전체(플레이어 주변 _effect_radius)의 모든 적에게 틱 피해를 퍼붓는다.
## _data: fire_interval=재사용 대기(초), area_duration=지속(초),
## proj_damage/dmg_per_level=틱 피해(레벨업 카드로 강화), color=연출색(캐릭터 테마).

const _FXMaterial := preload("res://scripts/FXMaterial.gd")
const TICK := 0.30           # 피해 틱 간격
const FX_PER_TICK := 6       # 틱마다 무작위 피격 지점에 터뜨릴 버스트 수(과부하 방지 상한)
const QUAKE_GROW := 0.55     # 균열이 끝까지 뻗는 데 걸리는 시간(초)
const QUAKE_TREMOR := 9.0    # 균열 끝단이 옆으로 흔들리는 폭(px)
const QUAKE_TREMOR_HZ := 14.0  # 흔들림 속도(rad/s) — 낮으면 출렁, 높으면 지직
const FIELD_COVERAGE := 0.96  # 화면 가장자리까지 쓰되 착탄 중심이 잘리지 않을 최소 여백
const ARROW_MIN := 42
const ARROW_MAX := 72
const ARROW_DENSITY_CELL := 200.0

var _cd: float = 0.0
var _active: float = 0.0
var _tick_t: float = 0.0
var _pulse: float = 0.0
var _cracks: Array = []   # quake 전용 — 발동 시 뽑는 방사형 균열 폴리라인들(로컬 좌표)
## 피해와 연출이 함께 쓰는 현재 화면의 월드 반경/절반 크기. 고정 해상도를 가정하지 않는다.
var _effect_radius: float = 720.0
var _field_half_extents: Vector2 = Vector2(640.0, 360.0)


## 결정적 의사난수(0..1) — 프레임마다 흔들리지 않는 연출 배치용.
func _h(n: int) -> float:
	return absf(fmod(sin(float(n) * 127.1 + 311.7) * 43758.5453, 1.0))


func _ready() -> void:
	z_index = 3
	material = _FXMaterial.additive()   # 공유 인스턴스 — 개별 생성 시 드로우 배치가 쪼개진다   # 발동 중 화면을 물들이는 발광 오버레이
	_sync_field_geometry()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


## 현재 보이는 화면을 월드 단위로 환산한다. 피해 원과 세 궁극기 연출이 이 값 하나를 공유하므로
## 해상도·화면 회전·카메라 줌이 달라도 중앙의 작은 고정 영역에만 연출이 몰리지 않는다.
func _sync_field_geometry() -> void:
	var field_size := get_viewport().get_visible_rect().size
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.zoom.x > 0.0 and cam.zoom.y > 0.0:
		field_size = Vector2(field_size.x / cam.zoom.x, field_size.y / cam.zoom.y)
	_field_half_extents = field_size * 0.5
	_effect_radius = maxf(field_size.length() * 0.5, 1.0)


func _on_viewport_size_changed() -> void:
	_sync_field_geometry()
	if _active > 0.0 and weapon_id == "ult_quake":
		_build_quake_cracks()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _data == null:
		return
	if _cd <= 0.0 and _active <= 0.0:
		_cd = _data.fire_interval * 0.4   # 첫 발동은 절반 이하 대기로 빨리 맛보게
	if _active > 0.0:
		_active -= delta
		_pulse += delta
		_tick_t -= delta
		if _tick_t <= 0.0:
			_tick_t = TICK
			_damage_tick()
		queue_redraw()
		if _active <= 0.0:
			queue_redraw()   # 마지막 프레임 — 오버레이 제거
		return
	_cd -= delta
	if _cd <= 0.0:
		_cd = _data.fire_interval
		_activate()


func _activate() -> void:
	_sync_field_geometry()
	_active = _data.area_duration
	_tick_t = 0.0
	_pulse = 0.0
	Events.shake(9.0)
	# 첫 파동부터 실제 피해 반경까지 퍼져야 '화면 전체 공격'으로 읽힌다.
	_FXBurst.spawn(get_tree().current_scene, global_position, _data.color, _effect_radius, 0.62)
	match weapon_id:
		"ult_quake":
			if SoundManager.has_stream("ult_quake"):
				SoundManager.play("ult_quake", 0.04, 1.0)
			else:
				SoundManager.play("boom", 0.08, 0.55)   # 낮게 우르릉
			_build_quake_cracks()
		"ult_arrowstorm":
			if SoundManager.has_stream("ult_arrow"):
				SoundManager.play("ult_arrow", 0.04, 1.0)
			else:
				SoundManager.play("laser", 0.08, 1.35)
				SoundManager.play("boom", 0.06, 1.1)
		_:
			if SoundManager.has_stream("ult_orbital"):
				SoundManager.play("ult_orbital", 0.04, 1.0)
			else:
				SoundManager.play("laser", 0.08, 0.8)
				SoundManager.play("boom", 0.08, 0.9)


func _damage_tick() -> void:
	var lvl := _level()
	var dmg: int = _data.proj_damage + _data.dmg_per_level * (lvl - 1) + int(Events.upgrade_bullet_damage / 2)
	var r_sq := _effect_radius * _effect_radius
	var hit_pos: Array = []
	for z in Events.live_zombies():
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		if global_position.distance_squared_to(z.global_position) > r_sq:
			continue
		z.take_damage(dmg)
		if hit_pos.size() < FX_PER_TICK and randf() < 0.25:
			hit_pos.append(z.global_position)
	var scn := get_tree().current_scene
	for p in hit_pos:
		_FXBurst.spawn(scn, p, _data.color, 30.0, 0.22)
	if weapon_id == "ult_quake":
		Events.shake(3.5)   # 지진 — 지속되는 진동


## 발동 중 오버레이 — 궁극기마다 고유 연출(가산 블렌드로 화면을 화려하게 물들인다).
##   ult_quake: 방사형 균열 + 연쇄 충격 링(대지가 갈라지는 지진)
##   ult_arrowstorm: 화면을 가로지르는 화살 비(대각 스트릭 + 빛나는 촉)
##   ult_orbital: 하늘에서 꽂히는 수직 광선 폭격(조준 링 + 착탄 글로우)
## ⚠️ 프리미티브 대신 **QuadDraw(텍스처 쿼드)** 로 그린다 — 캔버스 배처는 한 아이템
## 안에서도 프리미티브 종류가 다르면 배치를 끊는다(ASSET_PIPELINE.md 1절).
## 화살비는 화살마다 선 5~6개를 발행하므로 화면 면적에 따라 42~72개로 제한한다.
func _draw() -> void:
	if _active <= 0.0 or _data == null:
		return
	var fade := clampf(_active / maxf(_data.area_duration, 0.01), 0.0, 1.0)
	var c: Color = _data.color
	# 공통 — 실제 피해 반경 전체를 물들이고, 반복 파동이 중심에서 화면 끝까지 이동한다.
	var field_fade := minf(fade * 2.0, 1.0)
	QuadDraw.disc(self, Vector2.ZERO, _effect_radius,
		Color(c.r, c.g, c.b, (0.075 + 0.035 * sin(_pulse * 9.0)) * field_fade))
	for i in 3:
		var phase := fmod(_pulse * 0.46 + float(i) / 3.0, 1.0)
		var wave_r := lerpf(24.0, _effect_radius, phase)
		QuadDraw.ring(self, Vector2.ZERO, wave_r,
			Color(c.r, c.g, c.b, (1.0 - phase) * 0.18 * field_fade), 8.0, 48)
	match weapon_id:
		"ult_quake":
			_draw_quake(c, fade)
		"ult_arrowstorm":
			_draw_arrowstorm(c, fade)
		_:
			_draw_orbital(c, fade)


func _draw_quake(c: Color, fade: float) -> void:
	# 방사형 균열 — 안쪽은 벌겋게 달아오른 코어, 바깥은 어두운 틈.
	# 발동 직후 바깥으로 **갈라져 나가고**, 그동안 계속 잘게 떤다. 예전에는 완성된 균열이
	# 그 자리에 박힌 채 밝기만 깜빡여서 지진이라기보다 무늬처럼 보였다.
	for ci in _cracks.size():
		var pts := _quake_crack(ci)
		if pts.size() < 2:
			continue
		QuadDraw.polyline(self, pts, Color(0.12, 0.05, 0.03, 0.85 * fade), 7.0)
		QuadDraw.polyline(self, pts, Color(c.r, c.g * 0.7, c.b * 0.4, 0.8 * fade), 3.0)
		QuadDraw.polyline(self, pts, Color(1.0, 0.85, 0.4, 0.5 * fade * (0.6 + 0.4 * sin(_pulse * 11.0))), 1.4)
		# 갈라지는 끝단의 파편 불티 — 균열이 지금도 뻗어나가는 중임을 보여준다.
		var tip: Vector2 = pts[pts.size() - 1]
		var spark := 0.35 + 0.65 * absf(sin(_pulse * 17.0 + float(ci)))
		QuadDraw.disc(self, tip, 3.4 * spark, Color(1.0, 0.8, 0.35, 0.75 * fade * spark))
	# 연쇄 충격 링 3겹 — 시차를 두고 화면 밖으로 퍼진다.
	for k in 3:
		var ring_r := fmod(_pulse * 760.0 + float(k) * _effect_radius / 3.0, _effect_radius)
		QuadDraw.ring(self, Vector2.ZERO, maxf(ring_r, 8.0), Color(c.r, c.g, c.b, 0.30 * fade * (1.0 - ring_r / _effect_radius)), 6.0, 40)


## 현재 피해 반경을 기준으로 균열을 다시 만든다. 이전 고정 9×70px 길이는 넓은 웹 화면에서
## 피해 반경의 절반에도 못 미쳤다. 경로가 꺾여도 끝이 화면 가장자리에 닿도록 여유를 둔다.
func _build_quake_cracks() -> void:
	const SPOKES := 10
	const SEGMENTS := 11
	_cracks.clear()
	var seg_len := _effect_radius * 1.28 / float(SEGMENTS)
	for i in SPOKES:
		var ang := TAU * (float(i) + _h(i) * 0.6) / float(SPOKES)
		var pts := PackedVector2Array([Vector2.ZERO])
		var pos := Vector2.ZERO
		for k in SEGMENTS:
			ang += (_h(i * 17 + k) - 0.5) * 0.58
			pos += Vector2.from_angle(ang) * seg_len * (0.86 + _h(i * 31 + k) * 0.30)
			pts.append(pos)
		_cracks.append(pts)


## 균열 ci 의 이번 프레임 모양 — 자라난 길이까지만, 각 마디를 옆으로 떨어서 돌려준다.
## 떨림은 결정적 sin 파라 프레임마다 튀지 않고 '진동'으로 읽힌다(randf 를 쓰면 지직거린다).
func _quake_crack(ci: int) -> PackedVector2Array:
	var src: PackedVector2Array = _cracks[ci]
	var last := src.size() - 1
	if last < 1:
		return PackedVector2Array()
	var grow := clampf(_pulse / QUAKE_GROW, 0.0, 1.0)
	var shown := maxi(1, int(round(float(last) * grow)))   # 마지막 '인덱스'(개수 아님)
	var out := PackedVector2Array()
	for k in range(shown + 1):
		var p: Vector2 = src[k]
		if k == 0:
			out.append(p)
			continue
		# 바깥 마디일수록 크게 흔들린다(중심은 플레이어 발밑이라 고정).
		var amp := QUAKE_TREMOR * float(k) / float(last)
		var ph := _pulse * QUAKE_TREMOR_HZ + _h(ci * 7 + k) * TAU
		out.append(p + p.normalized().orthogonal() * sin(ph) * amp)
	return out


## 화살비 — 화살 하나하나가 하늘에서 쏟아져 땅에 콱콱 꽂히는 사이클을 반복한다.
##   각 화살: 낙하(스트릭 + 화살 실루엣) → 착지(먼지 링 + 꽂힌 화살이 잠시 남음).
##   목표 지점·주기는 결정적 난수로 고정되어 프레임 간 흔들리지 않는다.
func _draw_arrowstorm(c: Color, fade: float) -> void:
	var drop := Vector2(-0.22, 1.0).normalized()   # 낙하 방향(살짝 기울어진 폭우)
	var field_area := _field_half_extents.x * 2.0 * _field_half_extents.y * 2.0
	var arrow_count := clampi(int(round(field_area / (ARROW_DENSITY_CELL * ARROW_DENSITY_CELL))),
		ARROW_MIN, ARROW_MAX)
	for i in arrow_count:
		var cycle := 0.42 + _h(i * 11) * 0.25           # 화살별 낙하+꽂힘 주기(초)
		var raw := _pulse / cycle + _h(i * 13)
		var t := fmod(raw, 1.0)                          # 0..0.62 낙하, 0.62..1 꽂힘
		var bucket := int(raw)                           # 사이클마다 착지 지점이 바뀐다
		var target := _field_point(i * 29 + bucket, i * 47 + bucket * 3)
		if t < 0.62:
			# 낙하: 위에서 목표 지점으로 빠르게 떨어지는 화살 + 꼬리 스트릭.
			var p := t / 0.62
			var head := target + drop * (-(1.0 - p) * 560.0)
			var tail := head - drop * 46.0
			QuadDraw.segment(self, head - drop * 130.0, head, Color(c.r, c.g, c.b, 0.28 * fade), 3.0)   # 꼬리 잔상
			QuadDraw.segment(self, tail, head, Color(0.92, 0.96, 1.0, 0.9 * fade), 2.2)                 # 화살대
			var perp := drop.orthogonal()
			QuadDraw.segment(self, head, head - drop * 9.0 + perp * 4.0, Color(1.0, 1.0, 1.0, 0.9 * fade), 2.0)   # 촉
			QuadDraw.segment(self, head, head - drop * 9.0 - perp * 4.0, Color(1.0, 1.0, 1.0, 0.9 * fade), 2.0)
			QuadDraw.segment(self, tail, tail - drop * 7.0 + perp * 5.0, Color(c.r, c.g, c.b, 0.75 * fade), 1.6)  # 깃
			QuadDraw.segment(self, tail, tail - drop * 7.0 - perp * 5.0, Color(c.r, c.g, c.b, 0.75 * fade), 1.6)
		else:
			# 꽂힘: 착지 먼지 링이 퍼지고, 비스듬히 꽂힌 화살이 잠시 남는다.
			var s := (t - 0.62) / 0.38
			var a := (1.0 - s) * fade
			QuadDraw.ring(self, target, 6.0 + 22.0 * s, Color(0.85, 0.9, 1.0, 0.5 * a), 2.0, 16)
			QuadDraw.disc(self, target, 4.0, Color(1.0, 1.0, 1.0, 0.8 * a))
			var shaft := target - drop * 26.0
			QuadDraw.segment(self, shaft, target, Color(0.92, 0.96, 1.0, 0.85 * a), 2.2)
			var perp2 := drop.orthogonal()
			QuadDraw.segment(self, shaft, shaft - drop * 6.0 + perp2 * 4.5, Color(c.r, c.g, c.b, 0.7 * a), 1.5)
			QuadDraw.segment(self, shaft, shaft - drop * 6.0 - perp2 * 4.5, Color(c.r, c.g, c.b, 0.7 * a), 1.5)


func _draw_orbital(c: Color, fade: float) -> void:
	# 궤도 폭격 — 0.35초마다 자리를 옮기며 꽂히는 수직 광선 5~8기 + 조준 링 + 착탄 글로우.
	var bucket := int(_pulse / 0.35)
	var bt := fmod(_pulse, 0.35) / 0.35   # 이 광선 세트의 수명(0..1)
	var beam_count := clampi(int(ceil(_effect_radius / 220.0)), 5, 8)
	for i in beam_count:
		var seed := bucket * 5 + i
		var impact := _field_point(seed, seed * 3 + 1)
		var beam_a := (1.0 - bt) * fade
		QuadDraw.segment(self, impact + Vector2(0, -_effect_radius * 1.2), impact, Color(c.r, c.g, c.b, 0.30 * beam_a), 24.0)
		QuadDraw.segment(self, impact + Vector2(0, -_effect_radius * 1.2), impact, Color(1.0, 1.0, 1.0, 0.65 * beam_a), 7.0)
		QuadDraw.disc(self, impact, 34.0 * (0.5 + bt * 0.8), Color(c.r, c.g, c.b, 0.35 * beam_a))
		QuadDraw.disc(self, impact, 12.0, Color(1.0, 1.0, 1.0, 0.8 * beam_a))
		QuadDraw.ring(self, impact, 46.0 + bt * 30.0, Color(c.r, c.g, c.b, 0.45 * beam_a), 2.5, 24)


## 화면 안 무작위 지점. 실제 보이는 월드 사각형을 기준으로 세 궁극기의 착탄 분포를 맞춘다.
func _field_point(seed_x: int, seed_y: int) -> Vector2:
	return Vector2(
		(_h(seed_x) - 0.5) * 2.0 * _field_half_extents.x * FIELD_COVERAGE,
		(_h(seed_y) - 0.5) * 2.0 * _field_half_extents.y * FIELD_COVERAGE)
