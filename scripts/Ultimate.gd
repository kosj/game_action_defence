extends WeaponModule
## 캐릭터 궁극기(모듈 "ultimate"): 긴 재사용 대기 후 자동 발동 — area_duration 초 동안
## 화면 전체(플레이어 주변 SCREEN_R)의 모든 적에게 틱 피해를 퍼붓는다.
## _data: fire_interval=재사용 대기(초), area_duration=지속(초),
## proj_damage/dmg_per_level=틱 피해(레벨업 카드로 강화), color=연출색(캐릭터 테마).

const TICK := 0.30           # 피해 틱 간격
const SCREEN_R := 720.0      # 화면 커버 반경(포트레이트 720x1280 반대각 ≈ 734)
const FX_PER_TICK := 6       # 틱마다 무작위 피격 지점에 터뜨릴 버스트 수(과부하 방지 상한)

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
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD   # 발동 중 화면을 물들이는 발광 오버레이
	material = mat


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
			SoundManager.play("laser", 0.08, 1.35)
			SoundManager.play("boom", 0.06, 1.1)
		_:
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
	for pts in _cracks:
		draw_polyline(pts, Color(0.12, 0.05, 0.03, 0.85 * fade), 7.0, true)
		draw_polyline(pts, Color(c.r, c.g * 0.7, c.b * 0.4, 0.8 * fade), 3.0, true)
		draw_polyline(pts, Color(1.0, 0.85, 0.4, 0.5 * fade * (0.6 + 0.4 * sin(_pulse * 11.0))), 1.4, true)
	# 연쇄 충격 링 3겹 — 시차를 두고 화면 밖으로 퍼진다.
	for k in 3:
		var ring_r := fmod(_pulse * 760.0 + float(k) * SCREEN_R / 3.0, SCREEN_R)
		draw_arc(Vector2.ZERO, maxf(ring_r, 8.0), 0.0, TAU, 40, Color(c.r, c.g, c.b, 0.30 * fade * (1.0 - ring_r / SCREEN_R)), 6.0, true)


func _draw_arrowstorm(c: Color, fade: float) -> void:
	# 화살 비 — 화면 전역에 대각으로 쏟아지는 스트릭. 개체별 위상/열이 결정적 난수로 고정된다.
	var drop := Vector2(-0.35, 1.0).normalized()   # 낙하 방향(살짝 왼쪽으로 기울어진 비)
	for i in 30:
		var x := (_h(i) - 0.5) * 2.0 * SCREEN_R
		var speed := 1500.0 + _h(i * 7) * 700.0
		var span := SCREEN_R * 2.2
		var t := fmod(_pulse * speed + _h(i * 13) * span, span)
		var head := Vector2(x, -SCREEN_R) + drop * t
		var tail := head - drop * (90.0 + _h(i * 3) * 60.0)
		draw_line(tail, head, Color(c.r, c.g, c.b, 0.35 * fade), 3.5, true)
		draw_line(head - drop * 26.0, head, Color(1.0, 1.0, 1.0, 0.8 * fade), 2.0, true)
		draw_circle(head, 3.2, Color(1.0, 1.0, 1.0, 0.9 * fade))   # 빛나는 촉


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
