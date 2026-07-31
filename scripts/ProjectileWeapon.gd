extends Node2D
## 데이터 구동 발사체 무기 모듈(뱀서식 인벤토리 무기). Player 의 자식으로 붙어,
## 자신의 WeaponData(GameData) 파라미터로 가장 가까운 적을 자동 조준해 독립 타이머로 발사한다.
## 여러 종(산탄총/기관총/석궁 등)이 같은 코드를 파라미터만 바꿔 공유한다(동작 모듈 패턴).

const BULLET := preload("res://scenes/Bullet.tscn")
const _FXBurst := preload("res://scripts/FXBurst.gd")

const RANGE := 430.0            # 이 반경 안의 적만 조준
const _MULTI_SPREAD := 0.20     # 무기 자체 분산이 0인데 다중탄일 때 보기 좋게 퍼뜨리는 최소 분산

var weapon_id: String = ""
var _data: WeaponData = null
var _accum: float = 0.0
var _facing: float = 1.0        # 조준 대상이 없을 때 사용할 마지막 좌/우 방향


## Player 가 생성 직후 호출 — 어떤 무기인지 지정하고 데이터를 물어온다.
func setup(id: String) -> void:
	weapon_id = id
	_data = GameData.weapon_def(id)


func _level() -> int:
	var m: int = _data.max_level if _data != null else 8
	return clampi(int(Events.weapons.get(weapon_id, 0)), 1, m)


func _physics_process(delta: float) -> void:
	if _data == null:
		return
	var lvl := _level()
	_accum += delta
	if _accum < _interval(lvl):
		return
	_accum = 0.0
	_fire(lvl)


## 레벨/헤이스트(발사속도 패시브) 반영 발사 간격 — 하한은 기본 간격의 절반.
func _interval(lvl: int) -> float:
	var iv: float = _data.fire_interval * pow(0.94, float(lvl - 1)) * pow(0.85, float(Events.upgrade_atk_speed))
	return maxf(_data.fire_interval * 0.5, iv)


func _fire(lvl: int) -> void:
	var target := _nearest_zombie()
	var base_dir: Vector2
	if target != null:
		base_dir = (target.global_position - global_position).normalized()
		if absf(base_dir.x) > 0.05:
			_facing = signf(base_dir.x)
	else:
		base_dir = Vector2(_facing, 0.0)   # 사거리 내 적 없음 — 바라보던 방향 유지

	var pellets: int = _data.pellets + int((lvl - 1) / 4)     # 레벨업 시 완만히 탄 수 증가
	var pierce_total: int = _data.pierce + int((lvl - 1) / 5)
	var spread: float = _data.spread
	if pellets > 1 and spread <= 0.0:
		spread = _MULTI_SPREAD
	var dmg: int = _data.proj_damage + _data.dmg_per_level * (lvl - 1)

	for i in range(pellets):
		var angle_off := 0.0
		if pellets > 1 and i > 0:
			var pair := (i + 1) / 2
			var side := 1.0 if (i % 2 == 1) else -1.0
			var steps: int = pellets / 2
			angle_off = side * spread * float(pair) / float(maxi(steps, 1))
		var dir := base_dir.rotated(angle_off)
		var b := Pool.acquire(BULLET, get_tree().current_scene)
		b.global_position = global_position
		b.direction = dir
		b.rotation = dir.angle() + PI / 2
		b.speed = _data.proj_speed
		# 크리티컬 패시브(crit) — 탄마다 개별 판정, 데미지 2배.
		var crit_chance := Events.crit_chance()
		var is_crit := crit_chance > 0.0 and randf() < crit_chance
		b.damage = (dmg * 2) if is_crit else dmg
		b.is_crit = is_crit
		b.scale = Vector2.ONE * _data.proj_scale
		b.trail_color = _data.color
		b.pierce = pierce_total
		b.knockback = _data.knockback
		b.splash_radius = 0.0
		b.queue_redraw()

	SoundManager.play("shoot", 0.1, 1.0)
	_FXBurst.spawn(get_tree().current_scene, global_position, _data.color, 12.0, 0.08)


## 사거리 내 최근접 좀비 — Player 와 동일하게 프레임 공유 스냅샷 + distance_squared 사용.
func _nearest_zombie() -> Node2D:
	var nearest: Node2D = null
	var min_d := RANGE * RANGE
	for z in Events.live_zombies():
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		var d := global_position.distance_squared_to(z.global_position)
		if d < min_d:
			min_d = d
			nearest = z
	return nearest
