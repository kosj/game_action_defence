extends WeaponModule
## 캐릭터 궁극기(모듈 "ultimate"): 긴 재사용 대기 후 자동 발동 — area_duration 초 동안
## 화면 전체(플레이어 주변 SCREEN_R)의 모든 적에게 틱 피해를 퍼붓는다.
## _data: fire_interval=재사용 대기(초), area_duration=지속(초),
## proj_damage/dmg_per_level=틱 피해(레벨업 카드로 강화), color=연출색(캐릭터 테마).

const _FXMaterial := preload("res://scripts/FXMaterial.gd")
const TICK := 0.30           # 피해 틱 간격
const SCREEN_R := 720.0      # 화면 커버 반경(포트레이트 720x1280 반대각 ≈ 734)
const FX_PER_TICK := 6       # 틱마다 무작위 피격 지점에 터뜨릴 버스트 수(과부하 방지 상한)
const QUAKE_GROW := 0.55     # 균열이 끝까지 뻗는 데 걸리는 시간(초)
const QUAKE_TREMOR := 9.0    # 균열 끝단이 옆으로 흔들리는 폭(px)
const QUAKE_TREMOR_HZ := 14.0  # 흔들림 속도(rad/s) — 낮으면 출렁, 높으면 지직

var _cd: float = 0.0
var _active: float = 0.0
var _tick_t: float = 0.0
var _pulse: float = 0.0
var _cracks: Array = []   # quake 전용 — 발동 시 뽑는 방사형 균열 폴리라인들(로컬 좌표)


## 결정적 의사난수(0..1) — 프레임마다 흔들리지 않는 연출 배치용.
func _h(n: int) -> float:
	return absf(fmod(sin(float(n) * 127.1 + 311.7) * 43758.5453, 1.0))


func _ready() -> void:
	z_index = 3
	material = _FXMaterial.additive()   # 공유 인스턴스 — 개별 생성 시 드로우 배치가 쪼개진다   # 발동 중 화면을 물들이는 발광 오버레이


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
	_active = _data.area_duration
	_tick_t = 0.0
	_pulse = 0.0
	Events.shake(9.0)
	_FXBurst.spawn(get_tree().current_scene, global_position, _data.color, 150.0, 0.5)
	match weapon_id:
		"ult_quake":
			if SoundManager.has_stream("ult_quake"):
				SoundManager.play("ult_quake", 0.04, 1.0)
			else:
				SoundManager.play("boom", 0.08, 0.55)   # 낮게 우르릉
			_cracks.clear()
			for i in 8:   # 플레이어에서 화면 밖으로 뻗는 방사형 균열
				var ang := TAU * (float(i) + _h(i) * 0.6) / 8.0
				var pts := PackedVector2Array([Vector2.ZERO])
				var pos := Vector2.ZERO
				var seg_len := 70.0
				for k in 9:
					ang += (_h(i * 17 + k) - 0.5) * 0.7
					pos += Vector2.from_angle(ang) * seg_len * (0.8 + _h(i * 31 + k) * 0.5)
					pts.append(pos)
				_cracks.append(pts)
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
	var r_sq := SCREEN_R * SCREEN_R
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
func _draw() -> void:
	if _active <= 0.0 or _data == null:
		return
	var fade := clampf(_active / maxf(_data.area_duration, 0.01), 0.0, 1.0)
	var c: Color = _data.color
	# 공통 — 캐릭터색 스크린워시.
	draw_circle(Vector2.ZERO, SCREEN_R, Color(c.r, c.g, c.b, 0.05 + 0.03 * sin(_pulse * 9.0)))
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
		draw_polyline(pts, Color(0.12, 0.05, 0.03, 0.85 * fade), 7.0, true)
		draw_polyline(pts, Color(c.r, c.g * 0.7, c.b * 0.4, 0.8 * fade), 3.0, true)
		draw_polyline(pts, Color(1.0, 0.85, 0.4, 0.5 * fade * (0.6 + 0.4 * sin(_pulse * 11.0))), 1.4, true)
		# 갈라지는 끝단의 파편 불티 — 균열이 지금도 뻗어나가는 중임을 보여준다.
		var tip: Vector2 = pts[pts.size() - 1]
		var spark := 0.35 + 0.65 * absf(sin(_pulse * 17.0 + float(ci)))
		draw_circle(tip, 3.4 * spark, Color(1.0, 0.8, 0.35, 0.75 * fade * spark))
	# 연쇄 충격 링 3겹 — 시차를 두고 화면 밖으로 퍼진다.
	for k in 3:
		var ring_r := fmod(_pulse * 760.0 + float(k) * SCREEN_R / 3.0, SCREEN_R)
		draw_arc(Vector2.ZERO, maxf(ring_r, 8.0), 0.0, TAU, 40, Color(c.r, c.g, c.b, 0.30 * fade * (1.0 - ring_r / SCREEN_R)), 6.0, true)


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
	for i in 42:
		var cycle := 0.42 + _h(i * 11) * 0.25           # 화살별 낙하+꽂힘 주기(초)
		var raw := _pulse / cycle + _h(i * 13)
		var t := fmod(raw, 1.0)                          # 0..0.62 낙하, 0.62..1 꽂힘
		var bucket := int(raw)                           # 사이클마다 착지 지점이 바뀐다
		var target := Vector2((_h(i * 29 + bucket) - 0.5) * 1.8 * 640.0,
			(_h(i * 47 + bucket * 3) - 0.5) * 1.8 * 520.0)
		if t < 0.62:
			# 낙하: 위에서 목표 지점으로 빠르게 떨어지는 화살 + 꼬리 스트릭.
			var p := t / 0.62
			var head := target + drop * (-(1.0 - p) * 560.0)
			var tail := head - drop * 46.0
			draw_line(head - drop * 130.0, head, Color(c.r, c.g, c.b, 0.28 * fade), 3.0, true)   # 꼬리 잔상
			draw_line(tail, head, Color(0.92, 0.96, 1.0, 0.9 * fade), 2.2, true)                 # 화살대
			var perp := drop.orthogonal()
			draw_line(head, head - drop * 9.0 + perp * 4.0, Color(1.0, 1.0, 1.0, 0.9 * fade), 2.0, true)   # 촉
			draw_line(head, head - drop * 9.0 - perp * 4.0, Color(1.0, 1.0, 1.0, 0.9 * fade), 2.0, true)
			draw_line(tail, tail - drop * 7.0 + perp * 5.0, Color(c.r, c.g, c.b, 0.75 * fade), 1.6, true)  # 깃
			draw_line(tail, tail - drop * 7.0 - perp * 5.0, Color(c.r, c.g, c.b, 0.75 * fade), 1.6, true)
		else:
			# 꽂힘: 착지 먼지 링이 퍼지고, 비스듬히 꽂힌 화살이 잠시 남는다.
			var s := (t - 0.62) / 0.38
			var a := (1.0 - s) * fade
			draw_arc(target, 6.0 + 22.0 * s, 0.0, TAU, 16, Color(0.85, 0.9, 1.0, 0.5 * a), 2.0, true)
			draw_circle(target, 4.0, Color(1.0, 1.0, 1.0, 0.8 * a))
			var shaft := target - drop * 26.0
			draw_line(shaft, target, Color(0.92, 0.96, 1.0, 0.85 * a), 2.2, true)
			var perp2 := drop.orthogonal()
			draw_line(shaft, shaft - drop * 6.0 + perp2 * 4.5, Color(c.r, c.g, c.b, 0.7 * a), 1.5, true)
			draw_line(shaft, shaft - drop * 6.0 - perp2 * 4.5, Color(c.r, c.g, c.b, 0.7 * a), 1.5, true)


func _draw_orbital(c: Color, fade: float) -> void:
	# 궤도 폭격 — 0.35초마다 자리를 옮기며 꽂히는 수직 광선 5기 + 조준 링 + 착탄 글로우.
	var bucket := int(_pulse / 0.35)
	var bt := fmod(_pulse, 0.35) / 0.35   # 이 광선 세트의 수명(0..1)
	for i in 5:
		var seed := bucket * 5 + i
		var impact := Vector2((_h(seed) - 0.5) * 1.7 * 640.0, (_h(seed * 3 + 1) - 0.5) * 1.7 * 520.0)
		var beam_a := (1.0 - bt) * fade
		draw_line(impact + Vector2(0, -SCREEN_R * 1.2), impact, Color(c.r, c.g, c.b, 0.30 * beam_a), 24.0, true)
		draw_line(impact + Vector2(0, -SCREEN_R * 1.2), impact, Color(1.0, 1.0, 1.0, 0.65 * beam_a), 7.0, true)
		draw_circle(impact, 34.0 * (0.5 + bt * 0.8), Color(c.r, c.g, c.b, 0.35 * beam_a))
		draw_circle(impact, 12.0, Color(1.0, 1.0, 1.0, 0.8 * beam_a))
		draw_arc(impact, 46.0 + bt * 30.0, 0.0, TAU, 24, Color(c.r, c.g, c.b, 0.45 * beam_a), 2.5, true)
