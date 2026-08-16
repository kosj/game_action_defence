extends Node2D
## 데이터 구동 발사체 무기 모듈(뱀서식 인벤토리 무기). Player 의 자식으로 붙어,
## 자신의 WeaponData(GameData) 파라미터로 독립 타이머로 발사한다.
## 여러 종(산탄총/기관총/석궁 등)이 같은 코드를 파라미터만 바꿔 공유한다(동작 모듈 패턴).
##
## 캐릭터가 손에 들고 쏘는 무기이므로 **그림 속 총구에서 바라보는 쪽으로** 나간다.
## 예전에는 최근접 적을 360° 자동 조준했는데, 캐릭터 그림은 좌우 플립뿐이라 등 뒤나
## 위아래로 총알이 나가 어색했다. 360° 조준이 필요한 무기는 소환물 계열(드론/터렛)이 맡는다.

const BULLET := preload("res://scenes/Bullet.tscn")
const _FXBurst := preload("res://scripts/FXBurst.gd")

const _MULTI_SPREAD := 0.20     # 무기 자체 분산이 0인데 다중탄일 때 보기 좋게 퍼뜨리는 최소 분산

var weapon_id: String = ""
var _data: WeaponData = null
var _accum: float = 0.0
var _player: Node2D = null


func _ready() -> void:
	_player = get_parent() as Node2D


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
	var base_dir := Vector2(_facing(), 0.0)   # 캐릭터가 바라보는 좌/우로만 발사
	var origin := _origin()

	var pellets: int = _data.pellets + int((lvl - 1) / 4)     # 레벨업 시 완만히 탄 수 증가
	var pierce_total: int = _data.pierce + int((lvl - 1) / 5)
	var spread: float = _data.spread
	if pellets > 1 and spread <= 0.0:
		spread = _MULTI_SPREAD
	# 총기 계열은 '화약'(패시브)·'위력'(메타) 데미지 강화 혜택을 받는다(정합성).
	var dmg: int = _data.proj_damage + _data.dmg_per_level * (lvl - 1) + Events.upgrade_bullet_damage

	for i in range(pellets):
		var angle_off := 0.0
		if pellets > 1 and i > 0:
			var pair := (i + 1) / 2
			var side := 1.0 if (i % 2 == 1) else -1.0
			var steps: int = pellets / 2
			angle_off = side * spread * float(pair) / float(maxi(steps, 1))
		var dir := base_dir.rotated(angle_off)
		var b := Pool.acquire(BULLET, get_tree().current_scene)
		b.global_position = origin
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
		# 모양은 캐릭터를 따르고(헌터=볼트, 엔지니어=못), 무기가 고유 모양을 가진 경우에만
		# 그쪽이 이긴다(톱날). 색은 무기 색이므로 무기 구분은 그대로 남는다.
		b.style = _data.proj_style if _data.proj_style != "" else _style()
		b.spin = _data.proj_spin
		b.homing = _data.proj_homing
		b.homing_arc = _data.proj_homing_arc
		b.pierce = pierce_total
		b.knockback = _data.knockback
		b.splash_radius = 0.0
		b.queue_redraw()

	SoundManager.play("shoot", 0.1, 1.0)
	_FXBurst.spawn(get_tree().current_scene, origin, _data.color, 12.0, 0.08)


## 캐릭터가 바라보는 좌/우. Player 가 없으면(테스트 등) 오른쪽으로 둔다.
func _facing() -> float:
	if _player != null and _player.has_method("aim_facing"):
		return _player.aim_facing()
	return 1.0


## 쏘는 캐릭터의 기본 탄 모양(예광탄/볼트/못).
func _style() -> String:
	if _player != null and _player.has_method("projectile_style"):
		return _player.projectile_style()
	return "bullet"


## 그림 속 총구 위치 — 캐릭터마다 무기를 뻗은 지점이 달라 Player 가 알려준다.
func _origin() -> Vector2:
	if _player != null and _player.has_method("muzzle_position"):
		return _player.muzzle_position()
	return global_position
