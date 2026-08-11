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
	SoundManager.play("boom", 0.08, 0.75)
	_FXBurst.spawn(get_tree().current_scene, global_position, _data.color, 150.0, 0.5)


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


## 발동 중 오버레이 — 화면을 은은히 물들이는 캐릭터색 파동(가산 블렌드) + 맥동 링.
func _draw() -> void:
	if _active <= 0.0 or _data == null:
		return
	var fade := clampf(_active / maxf(_data.area_duration, 0.01), 0.0, 1.0)
	var c: Color = _data.color
	draw_circle(Vector2.ZERO, SCREEN_R, Color(c.r, c.g, c.b, 0.05 + 0.03 * sin(_pulse * 9.0)))
	var ring_r := fmod(_pulse * 900.0, SCREEN_R)   # 중심에서 화면 밖으로 반복 확산하는 충격 링
	draw_arc(Vector2.ZERO, maxf(ring_r, 8.0), 0.0, TAU, 40, Color(c.r, c.g, c.b, 0.35 * fade), 5.0, true)
	draw_arc(Vector2.ZERO, maxf(ring_r * 0.55, 6.0), 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.16 * fade), 2.5, true)
