extends CharacterBody2D
## 플레이어: 가상 조이스틱으로 이동 + 가장 가까운 좀비에게 자동 발사

@export var move_speed: float = 220.0
@export var attack_range: float = 360.0     # 이 범위 안의 적만 조준
@export var attack_cooldown: float = 0.35   # 발사 간격(초)
@export var max_health: int = 5
@export var contact_damage: int = 1
@export var contact_cooldown: float = 0.8   # 좀비 접촉 피해 간격(= 피격 후 무적 시간)
@export var contact_radius: float = 26.0    # 실제 접촉으로 인정할 중심간 거리(스프라이트가 겹쳤을 때만 피해)

const BULLET := preload("res://scenes/Bullet.tscn")
const _OrbClass := preload("res://scripts/Orb.gd")
const _LightningClass := preload("res://scripts/Lightning.gd")
const _GarlicClass := preload("res://scripts/GarlicAura.gd")
const _HolyClass := preload("res://scripts/HolyWater.gd")
# 데이터 구동 무기 모듈: WeaponData.module 문자열 → 모듈 스크립트. 새 모듈 무기는
# 여기에 한 줄 + 카탈로그(.tres) 항목만 추가하면 Player 가 자동으로 생성/유지한다.
const _MODULE_CLASSES := {
	"projectile": preload("res://scripts/ProjectileWeapon.gd"),
	"flamethrower": preload("res://scripts/Flamethrower.gd"),
	"molotov": preload("res://scripts/Molotov.gd"),
	"mine": preload("res://scripts/MineLayer.gd"),
	"melee_arc": preload("res://scripts/MeleeArc.gd"),
	"chainsaw": preload("res://scripts/Chainsaw.gd"),
	"turret": preload("res://scripts/Turret.gd"),
	"drone": preload("res://scripts/Drone.gd"),
	"tesla": preload("res://scripts/Tesla.gd"),
}
const _FXBurst  := preload("res://scripts/FXBurst.gd")
const _SpriteFX := preload("res://scripts/SpriteFX.gd")
const _FX_MUZZLE := preload("res://assets/sprites/fx/fx_muzzle.png")
const _WeaponDB := preload("res://scripts/WeaponDB.gd")
const BASE_BULLET_SPEED := 700.0

@onready var body: Node2D = $Body
@onready var muzzle: Marker2D = $Body/Muzzle
@onready var shadow: Sprite2D = $Shadow
@onready var hurtbox: Area2D = $Hurtbox
@onready var camera: Camera2D = $Camera2D

# 화면 흔들림(타격감): Events.screen_shake_requested 로 세기를 누적하고 매 프레임 감쇠하며
# 카메라에 랜덤 오프셋을 준다. 멀미 방지를 위해 상한을 두고, 큰 이벤트에서만 흔든다.
const SHAKE_MAX := 13.0
const SHAKE_DECAY := 34.0
var _shake: float = 0.0
var _base_zoom: Vector2 = Vector2.ONE   # 카메라 기본 줌(줌 펀치 복귀 기준)
var _zoom_tween: Tween = null

var joystick: Node = null
var health: int
var _attack_accum: float = 0.0
var _hurt_timer: float = 0.0
var _dead: bool = false
var _regen_accum: float = 0.0   # 체력 재생(regen) 업그레이드 누적 타이머

# 캐릭터 조건부 트레잇(Phase 4-B) — 선택 캐릭터의 trait_key 로 동적 효과.
var _trait_key: String = ""
var _still_time: float = 0.0    # 정지 지속 시간(사냥꾼 치명타 램프)
var _kill_heal_accum: int = 0   # 처치 누적(베테랑 전투 회복)

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
var _garlic: Node2D = null
var _holy: Node2D = null
var _weapon_modules: Dictionary = {}   # weapon_id -> 모듈 노드(데이터 구동 무기: 발사체/화염/장판/지뢰)
var current_weapon: Dictionary = _WeaponDB.default_weapon()

# 이동 걷기 애니메이션(절차적, 좀비와 동일 방식) — 이동 거리로 위상이 진행해 좌우 뒤뚱 + 발딛기
# 스쿼시를 준다. 멈추면 위상이 멈춰 자연스러운 정지 자세. facing 회전 위에 얹힌다.
const _WALK_FREQ := 0.085
const _WALK_TILT := 0.10     # 좌우 흔들림(라디안)
const _WALK_SQUASH := 0.08   # 발 딛을 때 눌림
var _walk_phase: float = 0.0
var _body_base_scale: Vector2 = Vector2.ONE
var _facing: float = 1.0   # 사이드뷰 좌우 방향: 1=오른쪽, -1=왼쪽(회전 대신 수평 플립)

# 임시 무기 사용 시간 / 골드 자석 버프 타이머 (초 단위 변화 시에만 HUD 로 신호)
var _weapon_time_left: float = 0.0
var _weapon_duration: float = 0.0
var _weapon_last_sec: int = -1
var _magnet_time_left: float = 0.0
var _magnet_last_sec: int = -1


func _ready() -> void:
	add_to_group("player")
	_apply_character_sprite()        # 선택 캐릭터 전용 스프라이트 적용(기본 스케일 캡처 전에)
	_body_base_scale = body.scale   # 걷기 스쿼시는 이 기본 스케일을 기준으로 오간다
	_fit_shadow()
	_base_move_speed = move_speed
	_base_attack_cooldown = attack_cooldown
	_base_max_health = max_health
	_recompute_combat_stats()
	health = max_health
	_hurt_timer = 5.0   # 시작 시 5초 무적 (프리워밍·첫 좀비 도착 전 보호)
	Events.update_player_health(health, max_health)
	Events.shop_closed.connect(apply_upgrades)
	Events.shop_closed.connect(_autosave)
	Events.screen_shake_requested.connect(_on_screen_shake)
	Events.wave_complete.connect(func(_wave: int): _autosave())
	var _char: CharacterData = CharacterManager.selected()
	_trait_key = _char.trait_key if _char != null else ""
	Events.zombie_killed.connect(_on_kill_for_trait)   # 베테랑 전투 회복
	_base_zoom = camera.zoom
	Events.boss_spawned.connect(func(_hp): _camera_zoom_punch(0.90, 0.55))   # 보스 등장 — 순간 줌아웃 리빌
	if SaveManager.pending_continue:
		_load_saved_state()


## 선택 캐릭터 전용 스프라이트를 Body 에 적용. 데이터가 없거나 경로가 비면 씬 기본 player.png 유지.
## sprite_scale(>0)로 스프라이트별 크기 편차를 정규화한다. _body_base_scale 캡처 전에 호출한다.
func _apply_character_sprite() -> void:
	var c: CharacterData = CharacterManager.selected()
	if c == null or c.sprite_path == "":
		return
	if not ResourceLoader.exists(c.sprite_path):
		return
	var tex = load(c.sprite_path)
	if tex is Texture2D and body is Sprite2D:
		body.texture = tex
		if c.sprite_scale > 0.0:
			body.scale = Vector2(c.sprite_scale, c.sprite_scale)


## 카메라 줌 펀치 — target 배율로 순간 전환 후 기본 줌으로 부드럽게 복귀(등장 연출용).
func _camera_zoom_punch(target_factor: float, dur: float) -> void:
	if not is_instance_valid(camera):
		return
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	camera.zoom = _base_zoom * target_factor
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(camera, "zoom", _base_zoom, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 카메라 흔들림은 렌더 프레임(_process)에서 감쇠·적용해 부드럽게 보이게 한다.
func _process(delta: float) -> void:
	if _shake > 0.05:
		_shake = maxf(0.0, _shake - SHAKE_DECAY * delta)
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO


func _on_screen_shake(amount: float) -> void:
	_shake = minf(SHAKE_MAX, _shake + amount)


func _physics_process(delta: float) -> void:
	_hurt_timer -= delta
	if _dead:
		return
	_tick_buffs(delta)
	_tick_regen(delta)
	# 무적 중 깜빡임 — 플레이어가 언제까지 안전한지 시각적으로 표시
	if _hurt_timer > 0.0:
		body.modulate.a = 1.0 if fmod(_hurt_timer, 0.4) > 0.2 else 0.35
	else:
		body.modulate.a = 1.0
	_check_contact_damage()
	_handle_move()
	_update_trait_mods(delta)   # 캐릭터 조건부 트레잇(velocity 확정 후)
	# 최근접 적은 짧은 주기로만 재탐색하고(대상 소멸 시 즉시 재탐색) 그 외엔 캐시 재사용.
	# 죽은 좀비는 풀로 반납돼도 is_instance_valid 는 참이므로(트리에서 분리될 뿐) "zombies"
	# 그룹 소속까지 확인한다 — 좀비는 사망 즉시 그룹에서 빠진다.
	_update_facing()                 # 이동(좌우)으로 조준 방향 결정
	_handle_attack(delta)            # 바라보는 방향으로 자동 발사
	_animate_walk(velocity.length() * delta)   # 이동량 기반 걷기 연출(스프라이트만)

	# 주기적 자동저장(체크포인트 사이 진행 보존). 사망 시엔 위에서 이미 return.
	_autosave_accum += delta
	if _autosave_accum >= AUTOSAVE_INTERVAL:
		_autosave_accum = 0.0
		_autosave()


## 캐릭터 조건부 트레잇 — 매 프레임 Events 의 동적 배수를 갱신한다.
##   베테랑: 저체력일수록 나가는 피해↑ / 사냥꾼: 정지할수록 치명타↑ / 엔지니어: 정적 효과(트레잇 배수 없음).
func _update_trait_mods(delta: float) -> void:
	match _trait_key:
		"veteran":
			var ratio := float(health) / float(maxi(max_health, 1))
			# 체력 절반 이하부터 상승, 빈사에서 +60% 피해.
			Events.trait_damage_mult = 1.0 + 0.6 * clampf((0.5 - ratio) / 0.5, 0.0, 1.0)
			Events.trait_crit_bonus = 0.0
		"hunter":
			if velocity.length() < 8.0:
				_still_time = minf(_still_time + delta, 1.2)
			else:
				_still_time = 0.0
			# 1.2초 정지 시 최대 +30% 치명타 확률.
			Events.trait_crit_bonus = 0.30 * (_still_time / 1.2)
			Events.trait_damage_mult = 1.0
		_:
			Events.trait_damage_mult = 1.0
			Events.trait_crit_bonus = 0.0


## 베테랑 전투 회복 — 근접 지향 캐릭터의 지속력. 일정 처치마다 1 회복(체력 미만일 때).
func _on_kill_for_trait() -> void:
	if _trait_key != "veteran" or _dead or health >= max_health:
		return
	_kill_heal_accum += 1
	if _kill_heal_accum >= 8:
		_kill_heal_accum = 0
		health = mini(max_health, health + 1)
		Events.update_player_health(health, max_health)


## 체력 재생(regen) 업그레이드 — 레벨이 높을수록 빠르게 1씩 회복(최대 체력까지).
func _tick_regen(delta: float) -> void:
	if Events.upgrade_regen <= 0 or health >= max_health:
		return
	_regen_accum += delta
	var interval := 8.0 / float(Events.upgrade_regen)   # Lv1=8초/회복, Lv5=1.6초/회복
	if _regen_accum >= interval:
		_regen_accum = 0.0
		health = mini(max_health, health + 1)
		Events.update_player_health(health, max_health)


func _check_contact_damage() -> void:
	if _hurt_timer > 0.0:
		return
	var contact_r_sq := contact_radius * contact_radius
	# Area2D 물리 질의(get_overlapping_bodies) 대신 공유 공간 해시에서 주변 좀비만 본다 —
	# 좀비가 수천이어도 비용이 주변 몇 마리로 고정된다.
	for body_node in Events.zombies_near(global_position):
		if is_instance_valid(body_node) and body_node.is_in_group("zombies"):
			# 스프라이트가 실제로 겹친 경우(중심거리 ≤ contact_radius)에만 피해를 준다.
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

	velocity = input * move_speed * _ext_slow
	move_and_slide()
	_ext_slow = 1.0   # 다음 프레임 리셋 — 느림 존(진창/냉기)이 매 프레임 다시 설정한다.


## 필드 느림 존(진창·냉기 분출 등)이 매 프레임 호출 — 이 프레임의 이동속도 배수를 낮춘다(가장 강한 값 적용).
var _ext_slow: float = 1.0
func slow_this_frame(mult: float) -> void:
	_ext_slow = minf(_ext_slow, clampf(mult, 0.15, 1.0))


func _handle_attack(delta: float) -> void:
	_attack_accum += delta
	if _attack_accum < attack_cooldown:
		return
	_attack_accum = 0.0
	_shoot_dir(Vector2(_facing, 0.0))   # 바라보는 좌/우 방향으로 직선 발사


## 사이드뷰: 이동(좌우)으로 조준한다 — 수평 이동 방향으로 캐릭터를 뒤집고 그 방향으로 발사한다.
## 위/아래로만 움직이면(velocity.x≈0) 방향은 마지막 좌/우 값을 유지한다.
func _update_facing() -> void:
	if absf(velocity.x) > 5.0:
		_facing = -1.0 if velocity.x < 0.0 else 1.0


## 그림자를 스프라이트 폭에 맞춘 납작한 타원으로 발밑에 배치(shadow.png 128x72).
func _fit_shadow() -> void:
	if body.texture == null:
		return
	var tex: Vector2 = body.texture.get_size()
	# 그림자를 캐릭터 폭에 맞게 크게(1.28x) + 약간 더 도톰한 타원으로 — 발밑 존재감을 준다.
	var sx: float = (tex.x * _body_base_scale.x * 1.28) / 128.0
	shadow.scale = Vector2(sx, sx * 0.52)
	shadow.position = Vector2(0.0, tex.y * _body_base_scale.y * 0.46)


## 절차적 걷기 — 발딛기 스쿼시 + 수직 바운스 + 좌우 뒤뚱. 좌우 방향은 _facing 으로 플립.
func _animate_walk(moved: float) -> void:
	var fx := _body_base_scale.x * _facing
	if moved <= 0.01:
		_walk_phase = 0.0
		body.scale = Vector2(fx, _body_base_scale.y)
		body.position.y = move_toward(body.position.y, 0.0, 0.6)
		body.rotation = move_toward(body.rotation, 0.0, 0.02)
		return
	_walk_phase += moved * _WALK_FREQ
	var s := sin(_walk_phase)
	var squash := absf(s) * _WALK_SQUASH
	body.scale = Vector2(fx * (1.0 + squash * 0.4), _body_base_scale.y * (1.0 - squash))
	body.position.y = -absf(s) * 2.4   # 수직 바운스(플레이어는 다소 절제)
	body.rotation = s * 0.04           # 좌우 뒤뚱(작게)


## 주어진 방향(base_dir, 정규화됨)으로 발사 — 다중발사는 그 방향 기준 부채꼴로 분산.
func _shoot_dir(base_dir: Vector2) -> void:
	SoundManager.play(current_weapon.get("sfx", "shoot"), 0.12, current_weapon.get("sfx_pitch", 1.0))
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
		# 크리티컬(crit) 업그레이드: 레벨당 +8% 확률(상한 60%)로 데미지 2배. 탄마다 개별 판정.
		var base_dmg: int = current_weapon["damage"] + Events.upgrade_bullet_damage
		var crit_chance := Events.crit_chance()
		var is_crit_hit := crit_chance > 0.0 and randf() < crit_chance
		b.damage = (base_dmg * 2) if is_crit_hit else base_dmg
		b.is_crit = is_crit_hit
		b.scale = Vector2.ONE * current_weapon["bullet_scale"]
		b.trail_color = current_weapon["color"]
		b.splash_radius = current_weapon["splash_radius"]
		b.queue_redraw()   # 트레일은 발사 시 1회만 그린다(Bullet 은 매 프레임 redraw 하지 않음)
	# muzzle flash — 조준 방향으로 향한 텍스처 플래시(무기 등급이 높을수록 더 크게).
	var mcol: Color = current_weapon["color"]
	var flash_col := Color(minf(mcol.r * 1.4 + 0.25, 1.0), minf(mcol.g * 1.4 + 0.25, 1.0), \
		minf(mcol.b * 1.4 + 0.25, 1.0), 1.0)
	var flash_px: float = 30.0 * (1.0 + (current_weapon["tier_mult"] - 1.0) * 0.35)
	_SpriteFX.spawn(get_tree().current_scene, muzzle.global_position, _FX_MUZZLE, \
		flash_px, 0.11, flash_col, base_dir.angle())


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
	Events.shake(7.0)   # 피격 타격감 — 화면을 확 흔든다
	health = max(0, health - amount)
	Events.update_player_health(health, max_health)
	if health <= 0:
		if Events.revives_left > 0:   # 메타 무료 부활 — 광고 없이 즉시 재기(iframe 부여)
			Events.revives_left -= 1
			_free_revive()
		else:
			_die()


## 메타 'revive' 무료 부활 — 사망 대신 체력 회복 + 짧은 무적 + 화면 연출.
func _free_revive() -> void:
	health = max_health
	_hurt_timer = 3.0
	_attack_accum = 0.0
	Events.update_player_health(health, max_health)
	Events.shake(9.0)
	SoundManager.play("gold", 0.0, 0.7)


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
	_update_singleton_weapon("garlic")
	_update_singleton_weapon("holy")
	_update_weapon_modules()


## 단일 인스턴스 무기(마늘·성수 등) 보유 여부에 맞춰 노드를 생성/해제.
func _update_singleton_weapon(id: String) -> void:
	var owned: bool = (Events.upgrade_garlic > 0) if id == "garlic" else (Events.upgrade_holy > 0)
	var node: Node2D = _garlic if id == "garlic" else _holy
	if owned and node == null:
		node = (_GarlicClass.new() if id == "garlic" else _HolyClass.new())
		add_child(node)
	elif not owned and node != null:
		node.queue_free()
		node = null
	if id == "garlic":
		_garlic = node
	else:
		_holy = node


## 데이터 구동 무기 모듈(module!="") — 보유한 것만 모듈 노드로 생성/유지.
## 카탈로그(GameData)를 순회하므로 새 무기를 데이터+모듈맵에 추가하면 여기 코드 수정 없이 동작한다.
func _update_weapon_modules() -> void:
	for wd in GameData.weapon_defs:
		if wd == null or wd.module == "":
			continue
		var owned: bool = int(Events.weapons.get(wd.id, 0)) > 0
		var node: Node2D = _weapon_modules.get(wd.id)
		if owned and node == null:
			var cls = _MODULE_CLASSES.get(wd.module)
			if cls == null:
				continue   # 알 수 없는 모듈 타입 — 조용히 건너뜀(데이터가 앞서갈 때 안전)
			node = cls.new()
			add_child(node)
			node.setup(wd.id)
			_weapon_modules[wd.id] = node
		elif not owned and node != null:
			node.queue_free()
			_weapon_modules.erase(wd.id)


func _update_orbs() -> void:
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
