extends CharacterBody2D
## 플레이어: 가상 조이스틱으로 이동 + 가장 가까운 좀비에게 자동 발사

@export var move_speed: float = 220.0
@export var attack_range: float = 360.0     # 이 범위 안의 적만 조준
@export var attack_cooldown: float = 0.35   # 발사 간격(초)
@export var max_health: int = 5
@export var contact_damage: int = 1
@export var contact_cooldown: float = 1.5   # 좀비 접촉 피해 간격
@export var contact_radius: float = 26.0    # 실제 접촉으로 인정할 중심간 거리(스프라이트가 겹쳤을 때만 피해)

const BULLET := preload("res://scenes/Bullet.tscn")
const _OrbClass := preload("res://scripts/Orb.gd")
const _LightningClass := preload("res://scripts/Lightning.gd")
const _FXBurst  := preload("res://scripts/FXBurst.gd")
const _WeaponDB := preload("res://scripts/WeaponDB.gd")
const BASE_BULLET_SPEED := 700.0

@onready var body: Node2D = $Body
@onready var muzzle: Marker2D = $Body/Muzzle
@onready var hurtbox: Area2D = $Hurtbox

var joystick: Node = null
var health: int
var _attack_accum: float = 0.0
var _hurt_timer: float = 0.0
var _dead: bool = false

# 최근접 적 캐시: _get_nearest_zombie() 는 좀비 그룹 전체를 순회하므로(O(n)) 매 프레임
# 돌리면 대량 좀비 환경에서 비싸다. 짧은 주기로만 갱신하고 그 사이에는 캐시를 재사용한다.
var _target: Node2D = null
var _target_accum: float = 999.0
const TARGET_RESCAN := 0.1

# 주기적 자동저장: 웨이브 클리어/상점 체크포인트 사이에 종료해도 점수·골드·진행이
# 유실되지 않도록 일정 간격으로 현재 상태를 저장한다(_notification 으로 백그라운드/종료 시에도).
var _autosave_accum: float = 0.0
const AUTOSAVE_INTERVAL := 4.0
var _base_move_speed: float
var _base_attack_cooldown: float
var _base_max_health: int
var _orbs: Array = []
var _lightning: Node2D = null
var current_weapon: Dictionary = _WeaponDB.default_weapon()

# 임시 무기 사용 시간 / 골드 자석 버프 타이머 (초 단위 변화 시에만 HUD 로 신호)
var _weapon_time_left: float = 0.0
var _weapon_duration: float = 0.0
var _weapon_last_sec: int = -1
var _magnet_time_left: float = 0.0
var _magnet_last_sec: int = -1


func _ready() -> void:
	add_to_group("player")
	_base_move_speed = move_speed
	_base_attack_cooldown = attack_cooldown
	_base_max_health = max_health
	_recompute_combat_stats()
	health = max_health
	_hurt_timer = 5.0   # 시작 시 5초 무적 (프리워밍·첫 좀비 도착 전 보호)
	Events.update_player_health(health, max_health)
	Events.shop_closed.connect(apply_upgrades)
	Events.shop_closed.connect(_autosave)
	Events.wave_complete.connect(func(_wave: int): _autosave())
	if SaveManager.pending_continue:
		_load_saved_state()


func _physics_process(delta: float) -> void:
	_hurt_timer -= delta
	if _dead:
		return
	_tick_buffs(delta)
	# 무적 중 깜빡임 — 플레이어가 언제까지 안전한지 시각적으로 표시
	if _hurt_timer > 0.0:
		body.modulate.a = 1.0 if fmod(_hurt_timer, 0.4) > 0.2 else 0.35
	else:
		body.modulate.a = 1.0
	_check_contact_damage()
	_handle_move()
	# 최근접 적은 짧은 주기로만 재탐색하고(대상 소멸 시 즉시 재탐색) 그 외엔 캐시 재사용.
	# 죽은 좀비는 풀로 반납돼도 is_instance_valid 는 참이므로(트리에서 분리될 뿐) "zombies"
	# 그룹 소속까지 확인한다 — 좀비는 사망 즉시 그룹에서 빠진다.
	_target_accum += delta
	if _target_accum >= TARGET_RESCAN or not _is_live_target(_target):
		_target_accum = 0.0
		_target = _get_nearest_zombie()
	var target := _target
	_handle_attack(delta, target)
	_update_facing(target)

	# 주기적 자동저장(체크포인트 사이 진행 보존). 사망 시엔 위에서 이미 return.
	_autosave_accum += delta
	if _autosave_accum >= AUTOSAVE_INTERVAL:
		_autosave_accum = 0.0
		_autosave()


func _check_contact_damage() -> void:
	if _hurt_timer > 0.0:
		return
	var contact_r_sq := contact_radius * contact_radius
	for body_node in hurtbox.get_overlapping_bodies():
		if body_node.is_in_group("zombies"):
			# Area2D 광역 검출은 가장자리 접촉(중심거리 ~32px)도 잡으므로,
			# 실제로 스프라이트가 겹친 경우(중심거리 ≤ contact_radius)에만 피해를 준다.
			if global_position.distance_squared_to(body_node.global_position) > contact_r_sq:
				continue
			var dmg := contact_damage
			if body_node.has_method("get_contact_damage"):
				dmg = body_node.get_contact_damage()   # 보스 등 강화 적은 더 큰 접촉 피해
			_take_damage(dmg)
			break


func _handle_move() -> void:
	# 조이스틱은 HUD 가 준비된 뒤에 그룹에 등록되므로 지연 조회
	if joystick == null:
		joystick = get_tree().get_first_node_in_group("joystick")

	var input := Vector2.ZERO
	if joystick:
		input = joystick.get_value()

	velocity = input * move_speed
	move_and_slide()


func _handle_attack(delta: float, target: Node2D) -> void:
	_attack_accum += delta
	if _attack_accum < attack_cooldown:
		return
	if target:
		_attack_accum = 0.0
		_shoot_at(target)


## 조준 대상이 있으면 그쪽을, 없으면 이동 방향을 바라본다(스프라이트만 회전).
func _update_facing(target: Node2D) -> void:
	if target:
		body.rotation = (target.global_position - global_position).angle()
	elif velocity.length() > 1.0:
		body.rotation = velocity.angle()


func _shoot_at(target: Node2D) -> void:
	SoundManager.play(current_weapon.get("sfx", "shoot"), 0.12, current_weapon.get("sfx_pitch", 1.0))
	var base_dir := (target.global_position - global_position).normalized()
	var count: int = current_weapon["pellet_count"] + Events.upgrade_multi_bullet
	var spread: float = current_weapon["spread"]
	if count > 1 and spread <= 0.0:
		spread = 0.22   # 무기 자체엔 탄퍼짐이 없어도 다중발사 강화 시 보기 좋게 퍼지도록
	for i in range(count):
		# 첫 발(i=0)은 항상 정조준 → 직격 보장. 짝수 발일 때 정중앙이 비어 단일 표적을
		# 빗나가던 문제를 막는다. 나머지 탄은 좌우로 번갈아 부채꼴 분산.
		var angle_off := 0.0
		if count > 1 and i > 0:
			var pair := (i + 1) / 2                # 1,1,2,2,3,3...
			var side := 1.0 if (i % 2 == 1) else -1.0
			var steps: int = count / 2
			angle_off = side * spread * float(pair) / float(maxi(steps, 1))
		var dir := base_dir.rotated(angle_off)
		var b := Pool.acquire(BULLET, get_tree().current_scene)
		b.global_position = muzzle.global_position
		b.direction = dir
		b.rotation = dir.angle() + PI / 2
		b.speed = BASE_BULLET_SPEED * current_weapon["bullet_speed_mult"]
		b.damage = current_weapon["damage"] + Events.upgrade_bullet_damage
		b.scale = Vector2.ONE * current_weapon["bullet_scale"]
		b.trail_color = current_weapon["color"]
		b.splash_radius = current_weapon["splash_radius"]
		b.queue_redraw()   # 트레일은 발사 시 1회만 그린다(Bullet 은 매 프레임 redraw 하지 않음)
	# muzzle flash — 무기 등급이 높을수록 더 크고 화려하게
	_FXBurst.spawn(get_tree().current_scene, muzzle.global_position, current_weapon["color"], \
		14.0 * (1.0 + (current_weapon["tier_mult"] - 1.0) * 0.35), 0.1)


## 캐시된 조준 대상이 아직 살아있는 좀비인지(풀 반납·사망 제외).
func _is_live_target(t: Node2D) -> bool:
	return is_instance_valid(t) and t.is_in_group("zombies")


## 최근접 적 탐색 — Events.live_zombies() 프레임 공유 스냅샷 사용. distance_squared 로 sqrt 제거.
func _get_nearest_zombie() -> Node2D:
	var nearest: Node2D = null
	var min_d := attack_range * attack_range
	for z in Events.live_zombies():
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		var d := global_position.distance_squared_to(z.global_position)
		if d < min_d:
			min_d = d
			nearest = z
	return nearest


## 적 투사체/폭발 등 비접촉 피해 진입점(스피터·자폭 좀비가 호출). 무적 시간 중이면 무시.
func take_hit(amount: int) -> void:
	if _dead or _hurt_timer > 0.0:
		return
	_take_damage(amount)


func _take_damage(amount: int) -> void:
	_hurt_timer = contact_cooldown
	SoundManager.play("player_hurt")
	health = max(0, health - amount)
	Events.update_player_health(health, max_health)
	if health <= 0:
		_die()


func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	Events.player_died.emit()


## 보상형 광고 시청 후 사망 직후 부활 — 체력을 가득 채우고 잠시 무적을 부여한다.
## (게임 트리는 사망 시 멈추지 않으므로 그대로 이어서 진행된다.)
func revive() -> void:
	if not _dead:
		return
	_dead = false
	health = max_health
	_hurt_timer = 3.0   # 부활 직후 무적 — 둘러싼 좀비에게 즉사하지 않도록
	_attack_accum = 0.0
	_autosave_accum = 0.0
	Events.update_player_health(health, max_health)
	Events.player_revived.emit()


## 상점에서 업그레이드 구매 후 또는 웨이브 시작 시 호출.
func apply_upgrades() -> void:
	move_speed = _base_move_speed + 30.0 * Events.upgrade_speed
	_recompute_combat_stats()
	var new_max := _base_max_health + Events.upgrade_max_health
	if new_max > max_health:
		health += new_max - max_health   # 늘어난 만큼 즉시 회복
		max_health = new_max
		Events.update_player_health(health, max_health)
	_update_orbs()
	_update_lightning()


func _update_orbs() -> void:
	# 어떤 경로로든 해제된 오브 참조가 남아 있으면 개수 계산이 틀어져
	# "샀는데 오브가 안 생기는" 문제가 되므로 먼저 정리한다(방어적).
	_orbs = _orbs.filter(func(o) -> bool: return is_instance_valid(o))
	var desired := Events.upgrade_orbs
	while _orbs.size() > desired:
		var orb = _orbs.pop_back()
		if is_instance_valid(orb):
			orb.queue_free()
	while _orbs.size() < desired:
		var orb := _OrbClass.new()
		add_child(orb)
		_orbs.append(orb)
	for i in _orbs.size():
		if is_instance_valid(_orbs[i]):
			_orbs[i].init_angle(TAU * i / max(_orbs.size(), 1))


func _update_lightning() -> void:
	var owned := Events.upgrade_lightning_count > 0
	if owned and _lightning == null:
		_lightning = _LightningClass.new()
		add_child(_lightning)
	elif not owned and _lightning != null:
		_lightning.queue_free()
		_lightning = null


## 상점의 회복 아이템 구매 시 호출.
func heal_full() -> void:
	health = max_health
	Events.update_player_health(health, max_health)


func _recompute_combat_stats() -> void:
	attack_cooldown = _base_attack_cooldown * pow(0.85, Events.upgrade_atk_speed) * current_weapon["cooldown_mult"]


## 맵의 무기 픽업 획득 시 호출 — 즉시 교체 장착. duration>0 이면 사용 시간이 지나면 만료된다.
func equip_weapon(weapon_stats: Dictionary) -> void:
	current_weapon = weapon_stats
	_recompute_combat_stats()
	_weapon_duration = float(weapon_stats.get("duration", 0.0))
	_weapon_time_left = _weapon_duration
	_weapon_last_sec = int(ceil(_weapon_time_left))
	Events.weapon_equipped.emit(weapon_stats)
	Events.weapon_timer_changed.emit(_weapon_time_left, _weapon_duration)
	_autosave()


## 골드 자석 아이템 획득 시 호출 — 일정 시간 동안 필드 골드를 거리와 무관하게 자동 흡수.
func activate_gold_magnet(duration: float) -> void:
	_magnet_time_left = duration
	_magnet_last_sec = int(ceil(duration))
	Events.gold_magnet_active = true
	Events.gold_magnet_changed.emit(true, duration)


## 임시 무기·골드 자석 버프 잔여 시간 갱신. 만료 시 각각 기본 무기 복귀 / 자석 해제.
func _tick_buffs(delta: float) -> void:
	if _weapon_time_left > 0.0:
		_weapon_time_left -= delta
		if _weapon_time_left <= 0.0:
			equip_weapon(_WeaponDB.default_weapon())   # 사용 시간 만료 → 기본 무기로 복귀
		else:
			var sec := int(ceil(_weapon_time_left))
			if sec != _weapon_last_sec:
				_weapon_last_sec = sec
				Events.weapon_timer_changed.emit(_weapon_time_left, _weapon_duration)
	if _magnet_time_left > 0.0:
		_magnet_time_left -= delta
		if _magnet_time_left <= 0.0:
			_magnet_time_left = 0.0
			Events.gold_magnet_active = false
			Events.gold_magnet_changed.emit(false, 0.0)
		else:
			var msec := int(ceil(_magnet_time_left))
			if msec != _magnet_last_sec:
				_magnet_last_sec = msec
				Events.gold_magnet_changed.emit(true, _magnet_time_left)


## 메인 메뉴의 "이어하기"로 진입했을 때, 저장된 체력/무기 상태를 적용.
func _load_saved_state() -> void:
	apply_upgrades()
	health = clampi(SaveManager.pending_player_health, 1, max_health)
	Events.update_player_health(health, max_health)
	equip_weapon(_WeaponDB.build_from_ids(SaveManager.pending_weapon_id, SaveManager.pending_weapon_tier_id))
	SaveManager.pending_continue = false


func _autosave() -> void:
	SaveManager.save_game(self)


## 창 닫기·앱 백그라운드 전환(모바일/웹) 직전에 마지막 상태를 저장 — 종료 시점 점수가
## 유실되지 않도록 한다. 사망 후엔 체크포인트가 무효이므로 저장하지 않는다.
func _notification(what: int) -> void:
	if _dead:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_autosave()
