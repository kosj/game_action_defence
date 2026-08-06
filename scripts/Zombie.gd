extends Node2D
## 좀비: 플레이어를 향해 단순 방향벡터 이동. 사망 시 골드 드랍 후 풀로 반납.
## 물리 바디가 아니다 — move_and_slide 를 쓰지 않고 위치를 직접 적분하며, 총알 명중·플레이어
## 접촉 판정도 모두 공유 공간 해시(Events.zombies_near) 거리 계산으로 처리한다. 좀비 1만 마리에서
## 물리 서버에 바디 1만 개를 등록하는 비용이 그대로 사라진다.
## 일부 종류는 고유 행동 패턴을 가진다(weaver: 지그재그 / spitter: 원거리 / bomber: 자폭).

@export var speed: float = 65.0
@export var max_health: int = 3

const GOLD := preload("res://scenes/Gold.tscn")
const ENEMY_BULLET := preload("res://scenes/EnemyBullet.tscn")
const _FXBurst := preload("res://scripts/FXBurst.gd")
## 이 거리(제곱)보다 멀면 화면 밖으로 보고 연출을 생략한다(뷰포트 720x1280 반대각 ≈ 734).
const _ANIM_CULL_SQ := 950.0 * 950.0
const _DamageNumber := preload("res://scripts/DamageNumber.gd")

# 행동 패턴 파라미터
const WEAVE_FREQ := 6.5          # weaver 좌우 흔들림 주파수
const WEAVE_AMP_RATIO := 0.8     # weaver 측면 속도 = speed * 이 비율
const SPIT_RANGE := 360.0        # spitter 발사 사거리
const SPIT_COOLDOWN := 1.6       # spitter 발사 간격(초)
const SPIT_KEEP_DIST := 240.0    # spitter 가 유지하려는 거리
const SPIT_PROJ_SPEED := 250.0
const BOMB_TRIGGER := 74.0       # bomber 점화 시작 거리
const BOMB_FUSE := 0.55          # bomber 점화~폭발 시간(도망 기회)
const BOMB_RADIUS := 92.0        # bomber 폭발 피해 반경

@onready var body: Node2D = $Body
@onready var shadow: Node2D = $Shadow

const _SHADOW_BASE := 0.32   # 크기 1.0 좀비 기준 그림자 스케일(Zombie.tscn 과 일치)
const _HIT_FLASH := 0.12     # 피격 잔광 지속(초)
const _HIT_COLOR := Color(1.0, 0.45, 0.45)

# 걷기 애니메이션(스프라이트 시트 없이 절차적) — 이동 거리에 비례해 위상이 진행하므로
# 멈추면 자동으로 멈춘다. 좌우로 뒤뚱(tilt) + 발 딛는 스쿼시(squash) 로 살아있는 움직임을 준다.
const _WALK_FREQ := 0.085    # 이동 픽셀당 걸음 위상 증가(라디안)
const _WALK_SQUASH := 0.085  # 발 딛을 때 눌리는 정도
const _WALK_BOB := 2.8       # 발 딛을 때 살짝 뜨는 수직 바운스(px)
const _WALK_SWAY := 0.05     # 좌우로 뒤뚱거리는 회전(라디안, ≈3°)

var health: int
var player: Node2D = null
var _alive: bool = false
var _type_color: Color = Color.WHITE
var _score_value: int = 0
var _contact_damage: int = 1
var _behavior: String = "chase"
var _wt: float = 0.0             # weaver 위상 누적
var _fire_timer: float = 0.0     # spitter 발사 쿨다운
var _fuse_active: bool = false   # bomber 점화 여부
var _fuse_timer: float = 0.0
var _flash: float = 0.0      # 피격 잔광 잔여 시간 — 매 프레임 Tween 생성 대신 직접 감쇠
var _walk_phase: float = 0.0     # 걷기 애니메이션 위상(이동 거리로 진행)
var _body_base_scale: float = 1.0   # 종류별 기본 스프라이트 스케일(스쿼시는 이 값을 기준으로)
var _facing: float = 1.0            # 사이드뷰 좌우 방향: 1=오른쪽, -1=왼쪽(회전 대신 수평 플립)

# 넉백(피격 반응): 총알 직격 시 잠깐 뒤로 밀린다 — "총알이 박히는" 타격감.
# 빠르게 감쇠해 순 이동은 미미(밸런스 영향 최소). 누적 상한으로 폭주 방지.
const KNOCKBACK_DECAY := 1400.0   # 감쇠 가속(px/s^2) — 클수록 금방 멈춘다
const KNOCKBACK_MAX := 170.0      # 넉백 속도 상한(px/s)
var _knockback: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("zombies")


func on_spawn() -> void:
	add_to_group("zombies")   # 재사용 시 멱등 재등록(안전)
	health = max_health
	_flash = 0.0
	_knockback = Vector2.ZERO
	_alive = true
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")


func on_despawn() -> void:
	_alive = false
	_flash = 0.0
	remove_from_group("zombies")
	body.modulate = Color.WHITE
	body.scale = Vector2.ONE
	body.rotation = 0.0
	body.position = Vector2.ZERO
	shadow.scale = Vector2.ONE * _SHADOW_BASE


## 스포너가 풀에서 꺼낸 직후 호출해 종류별 스탯·스프라이트·행동을 주입한다.
func setup(type_data: Dictionary) -> void:
	speed = type_data["speed"]
	max_health = type_data["max_health"]
	health = max_health
	_type_color = type_data["modulate"]   # 사망 폭발 FX·투사체·피격 잔광 색
	_score_value = type_data.get("score", 0)
	_contact_damage = type_data.get("contact", 1)
	_behavior = type_data.get("behavior", "chase")
	_wt = 0.0
	_fire_timer = SPIT_COOLDOWN * 0.5   # 등장 직후 즉시 난사하지 않도록 약간의 지연
	_fuse_active = false
	_fuse_timer = 0.0
	if type_data.has("texture"):
		body.texture = type_data["texture"]   # 종류별 캐릭터 스프라이트
	body.modulate = Color.WHITE              # 스프라이트 본연의 색을 그대로 노출
	var s := float(type_data.get("scale", 1.0))
	_body_base_scale = s
	_walk_phase = randf() * TAU              # 개체마다 위상을 달리해 군집이 똑같이 움직이지 않게
	_facing = 1.0
	body.rotation = 0.0
	body.position = Vector2.ZERO
	body.scale = Vector2.ONE * s
	_fit_shadow()   # 스프라이트 크기·발 위치에 맞춰 바닥 그림자 배치


## 종류별 접촉 피해(차저/저거넛 등 강화 적은 더 큰 피해). Player 가 호출.
func get_contact_damage() -> int:
	return _contact_damage


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	# 화면 밖 좀비는 보이지 않으므로 연출(잔광·걷기 애니메이션)을 건너뛴다 — 이동/추적은 그대로라
	# 게임플레이는 동일하고, 대량 좀비에서 스프라이트 갱신 비용만 사라진다.
	var vis := global_position.distance_squared_to(player.global_position) <= _ANIM_CULL_SQ
	# 피격 잔광: Tween 대신 잔여 시간을 직접 감쇠(대량 동시 피격 시 Tween 폭증 방지)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		if vis:
			body.modulate = Color.WHITE.lerp(_HIT_COLOR, _flash / _HIT_FLASH)
	var prev_pos := global_position
	match _behavior:
		"weaver":  _behave_weaver(delta)
		"spitter": _behave_spitter(delta)
		"bomber":  _behave_bomber(delta)
		_:         _behave_chase(delta)
	# 이번 프레임 이동량으로 걷기 애니메이션을 진행(behave 가 _face() 로 좌우 방향을 갱신하므로,
	# 여기서는 그 방향(_facing)에 발딛기 스쿼시를 더한다).
	if vis:
		_animate_walk(global_position.distance_to(prev_pos))
	# 넉백은 걷기 애니메이션에 반영하지 않고 순수 위치 이동으로만 적용(빠르게 감쇠).
	if _knockback != Vector2.ZERO:
		global_position += _knockback * delta
		_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)


## 절차적 걷기: 이동 거리에 비례해 위상을 진행시켜, 좌우로 뒤뚱거리고(tilt) 발을 딛을 때마다
## 살짝 눌리는(squash) 움직임을 준다. 멈추면(이동량 0) 위상이 멈춰 자연스럽게 정지 포즈가 된다.
## 사이드뷰 걷기: 회전 대신 좌우 플립(_facing) + 발딛기 스쿼시 + 수직 바운스 + 좌우 뒤뚱.
## 이동량(moved) 기반으로 위상이 진행하므로 멈추면 자동으로 기본 자세로 복귀한다.
func _animate_walk(moved: float) -> void:
	var fx := _body_base_scale * _facing
	if moved <= 0.01:
		body.scale = Vector2(fx, _body_base_scale)
		body.position.y = move_toward(body.position.y, 0.0, 0.6)
		body.rotation = move_toward(body.rotation, 0.0, 0.02)
		return
	_walk_phase += moved * _WALK_FREQ
	var s := sin(_walk_phase)
	var squash := absf(s) * _WALK_SQUASH
	body.scale = Vector2(fx * (1.0 + squash * 0.4), _body_base_scale * (1.0 - squash))
	body.position.y = -absf(s) * _WALK_BOB   # 발 딛을 때 통통 튀는 느낌
	body.rotation = s * _WALK_SWAY            # 좌우로 뒤뚱거림


## 사이드뷰 좌우 방향 갱신 — 진행/추격 방향의 수평 성분으로만 판단(뱀서식 플립).
func _face(dir: Vector2) -> void:
	if absf(dir.x) > 0.02:
		_facing = -1.0 if dir.x < 0.0 else 1.0


## 그림자를 스프라이트 폭에 비례하는 납작한 타원으로, 캐릭터 발밑(스프라이트 하단)에 배치.
## shadow.png 는 128x72. 그림자는 Body 플립과 무관하게 루트 자식이라 항상 고정.
func _fit_shadow() -> void:
	if body.texture == null:
		return
	var tex: Vector2 = body.texture.get_size()
	# 그림자를 좀비 폭에 맞게 크게(1.28x) 잡아 발밑 존재감을 준다.
	var sx: float = (tex.x * _body_base_scale * 1.28) / 128.0
	shadow.scale = Vector2(sx, sx * 0.52)
	shadow.position = Vector2(0.0, tex.y * _body_base_scale * 0.46)


## 기본: 플레이어를 향해 직진 추격.
## 직선 적분 이동: 좀비끼리 상호 충돌을 해소하는 move_and_slide() 는 개체 수의 제곱에 비례해
## 비싸진다. 위치를 직접 갱신해 좀비당 비용을 O(1) 로 낮춘다(스프라이트끼리 겹칠 수 있으나
## 대규모 디펜스에선 일반적). 충돌 도형(레이어2)은 남아 총알 명중·플레이어 접촉 판정에 쓰인다.
## 좀비의 collision_mask 는 0 이다(Zombie.tscn) — move_and_slide 를 안 쓰므로 좀비끼리 충돌
## 감지가 불필요한데, mask 를 켜두면 물리 엔진이 매 프레임 좀비×좀비 충돌쌍을 O(n²) 로 계산해
## 낭비한다. mask=0 으로 그 비용을 제거한다(레이어2 는 남아 총알·플레이어 감지는 그대로).
func _behave_chase(delta: float) -> void:
	var dir := (player.global_position - global_position).normalized()
	_face(dir)
	global_position += dir * speed * delta


## 지그재그: 플레이어로 접근하되 진행 방향에 수직으로 흔들어 조준을 어렵게 한다.
func _behave_weaver(delta: float) -> void:
	_wt += delta
	var dir := (player.global_position - global_position).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var vel := dir * speed + perp * (sin(_wt * WEAVE_FREQ) * speed * WEAVE_AMP_RATIO)
	_face(dir)
	global_position += vel * delta


## 원거리: 선호 거리를 유지하며 주기적으로 투사체를 발사(카이팅).
func _behave_spitter(delta: float) -> void:
	var to_p := player.global_position - global_position
	var dist := to_p.length()
	var dir := to_p / maxf(dist, 0.001)
	var vel := Vector2.ZERO
	if dist < SPIT_KEEP_DIST - 30.0:
		vel = -dir * speed      # 너무 가까우면 물러난다
	elif dist > SPIT_KEEP_DIST + 30.0:
		vel = dir * speed       # 너무 멀면 접근
	_face(dir)
	global_position += vel * delta
	_fire_timer -= delta
	if dist <= SPIT_RANGE and _fire_timer <= 0.0:
		_fire_timer = SPIT_COOLDOWN
		_spit(dir)


func _spit(dir: Vector2) -> void:
	var p := Pool.acquire(ENEMY_BULLET, get_tree().current_scene)
	p.global_position = global_position
	p.direction = dir
	p.speed = SPIT_PROJ_SPEED
	p.damage = 1
	p.color = _type_color
	p.queue_redraw()   # 색 주입 후 1회 그리기(EnemyBullet 은 매 프레임 redraw 하지 않음)


## 자폭: 플레이어에게 돌진 → 근접 시 점화(점멸) → 폭발로 광역 피해 후 사망.
## 점화 중 처치하면 폭발 없이 무력화된다(보고 쏠 기회).
func _behave_bomber(delta: float) -> void:
	if _fuse_active:
		_fuse_timer -= delta
		body.modulate = Color(1, 1, 1) if fmod(_fuse_timer, 0.16) > 0.08 else Color(1.0, 0.4, 0.2)
		if _fuse_timer <= 0.0:
			_explode()
		return
	var to_p := player.global_position - global_position
	var dir := to_p.normalized()
	_face(dir)
	global_position += dir * speed * delta
	if to_p.length() <= BOMB_TRIGGER:
		_fuse_active = true
		_fuse_timer = BOMB_FUSE


func _explode() -> void:
	if not _alive:
		return
	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= BOMB_RADIUS:
		if player.has_method("take_hit"):
			player.take_hit(_contact_damage)
	_FXBurst.spawn(get_tree().current_scene, global_position, Color(1.0, 0.45, 0.15), BOMB_RADIUS, 0.4)
	Events.shake(5.0)   # 자폭 폭발 타격감
	_die()   # 처치로 집계 — 웨이브 진행/골드 드랍 처리


## 총알 직격 방향으로 잠깐 밀어낸다(Bullet 이 호출). 보스는 이 메서드가 없어 자연히 면역.
func apply_knockback(dir: Vector2, force: float) -> void:
	if not _alive:
		return
	_knockback = (_knockback + dir * force).limit_length(KNOCKBACK_MAX)


const _CRIT_COLOR := Color(1.0, 0.55, 0.1)

func take_damage(amount: int, is_crit: bool = false) -> void:
	if not _alive:
		return
	if Events.trait_damage_mult != 1.0:   # 캐릭터 트레잇: 나가는 피해 배수(수신측에서 일괄 적용)
		amount = maxi(1, int(round(amount * Events.trait_damage_mult)))
	health -= amount
	if is_crit:
		# 크리티컬 피드백: 큰 주황 데미지 숫자 + 더 오래/강하게 번쩍 + 짧은 스파크.
		_DamageNumber.spawn(get_tree().current_scene, global_position, amount, true, _CRIT_COLOR)
		_FXBurst.spawn(get_tree().current_scene, global_position, _CRIT_COLOR, 26.0, 0.22)
		SoundManager.play("zombie_hit", 0.1, 1.5)   # 살짝 높은 음으로 타격감 강조
		_flash = _HIT_FLASH * 2.2
	else:
		_DamageNumber.spawn(get_tree().current_scene, global_position, amount)
		SoundManager.play("zombie_hit")
		_flash = _HIT_FLASH
	body.modulate = _HIT_COLOR   # 피격 순간 붉게 번쩍 — 이후 _physics_process 에서 흰색으로 감쇠
	if health <= 0:
		_die()


func _die() -> void:
	_alive = false
	SoundManager.play("zombie_die")
	remove_from_group("zombies")
	Events.zombie_killed.emit()
	Events.add_score(_score_value)
	var scene := get_tree().current_scene
	# 흰 팝 섬광(즉각적 처치 타격감) + 피 스플랫(어두운 적색) + 종류색 파편. FX 는 풀링돼 부하 최소.
	_FXBurst.spawn(scene, global_position, Color(1.0, 1.0, 0.95), 26.0, 0.16)
	_FXBurst.spawn(scene, global_position, Color(0.58, 0.05, 0.06), 44.0, 0.32)
	_FXBurst.spawn(scene, global_position, _type_color, 34.0, 0.30)
	var g := Pool.acquire(GOLD, get_tree().current_scene)
	g.global_position = global_position
	g.set_value(maxi(1, 1 + int(max_health / 6)))   # 튼튼한 좀비일수록 큰 젬(골드·경험치↑)
	Pool.release(self)
