extends CharacterBody2D
## 보스: 웨이브 종료 시 등장하는 강력한 단일 적.
## 일반 좀비와 같은 "zombies" 그룹에 속해 총알/접촉 데미지 시스템을 그대로 재사용하되,
## 별도의 체력바·강화된 외형·다량의 보상을 가진다. 풀링하지 않고 등장 시마다 인스턴스화.
##
## 아키타입(archetype) 으로 고유 행동을 분기한다(Zombie.gd 의 behavior 분기와 동일한 방식):
##   melee    — 근접 돌격(브루트)
##   gunner   — 거리 유지하며 조준 사격(총 쏘는 보스) — 텔레그래프 후 스프레드/방사 발사
##   summoner — 유지 거리에서 호위 좀비 주기 소환(스포너가 처리)
##   bomber   — 원거리에서 지연 폭발 탄착 표식(BossShell) 포격
##   berserk  — 느린 추적 ↔ 텔레그래프 후 초고속 대시 순환
## 모든 특수 공격은 HP 50% 이하에서 격노(페이즈)로 격화된다.
## 아키타입과 무관하게 공유하는 스킬이 하나 있다 — 쿨타임 기반 자가 회복(_tick_heal).

const GOLD := preload("res://scenes/Gold.tscn")
const _FXBurst := preload("res://scripts/FXBurst.gd")
const _BossShell := preload("res://scripts/BossShell.gd")
const _DamageNumber := preload("res://scripts/DamageNumber.gd")
const ENEMY_BULLET := preload("res://scenes/EnemyBullet.tscn")

## 아키타입별 전용 보스 스프라이트(업로드된 실제 아트워크). bomber 는 gunner 아트를 재사용,
## 최종 보스 REAPER(berserk)는 berserk 아트를 사용한다.
const _BOSS_TEX := {
	"melee":    preload("res://assets/sprites/boss_brute.png"),
	"gunner":   preload("res://assets/sprites/boss_gunner.png"),
	"summoner": preload("res://assets/sprites/boss_summoner.png"),
	"bomber":   preload("res://assets/sprites/boss_gunner.png"),
	"berserk":  preload("res://assets/sprites/boss_berserk.png"),
}

@onready var body: Node2D = $Body
@onready var shadow: Sprite2D = $Shadow

var speed: float = 55.0
var max_health: int = 80
var health: int = 80
var contact_damage: int = 2
var score_value: int = 200
var gold_drop: int = 12

var _alive: bool = false
var _archetype: String = "melee"
var _base_color: Color = Color(0.55, 0.12, 0.14)
const _HIT_FLASH := 0.12     # 피격 잔광 지속 시간
var _flash: float = 0.0      # 피격 잔광 잔여 시간 — 피격마다 Tween 을 만들지 않기 위해 직접 감쇠
var _proj_color: Color = Color(0.55, 0.8, 1.0)
var _pulse: float = 0.0
var _enraged: bool = false      # 격노(페이즈≥1) 여부 — 기존 행동 분기 호환용
var _phase: int = 0             # 다단계: 0=평상 / 1=66% 이하 / 2=33% 이하(추가 격화)
var _bal: BalanceData = null    # 밸런스 테이블 캐시(피해량·격화 파라미터)
var _alive_time: float = 0.0    # 생존 경과 — 지구전(카이팅) 방지 격화에 사용

# ── 근접형(melee) 지면 강타 ──────────────────────────────────────────
# 근접 보스가 "걸어오기만 하는 샌드백"이 되지 않도록, 사거리 안에 들면 예비 동작 후
# 넓은 충격파를 내리찍는다. 표식(BossShell)이 곧 텔레그래프라 이동으로 회피 가능.
const SLAM_RANGE := 300.0          # 이 거리 안이면 강타 시도
const SLAM_COOLDOWN := 3.6         # 강타 간격(초)
const SLAM_WARN := 0.55            # 표식 → 폭발 지연
const SLAM_RADIUS := 175.0         # 충격파 반경
var _slam_cd: float = 0.0

# ── 거너(gunner) 전용 상태 ────────────────────────────────────────────
const GUNNER_RANGE := 520.0        # 발사 사거리
const GUNNER_KEEP_DIST := 300.0    # 유지하려는 거리(카이팅)
const GUNNER_COOLDOWN := 1.7       # 발사 간격(초)
const GUNNER_TELEGRAPH := 0.4      # 발사 예비 동작(총구 점멸) 시간 — 보고 피할 여지
const GUNNER_PROJ_SPEED := 370.0   # 투사체 속도(플레이어 이속 220 대비 — 직선 도주로는 못 뿌리침)
var _fire_cd: float = 0.0
var _telegraph_t: float = 0.0      # >0 이면 발사 예비 동작 중
var _volley_pending: int = 0       # 2단계 연사: 남은 추가 일제사격 수
var _volley_t: float = 0.0         # 추가 일제사격까지 남은 시간
var _aim_dir: Vector2 = Vector2.RIGHT
var _facing: float = 1.0            # 사이드뷰 좌우 방향(회전 대신 수평 플립)
var _intro_scale_lock: bool = true # 등장 확대 트윈 중에는 스케일 플립을 보류(트윈 충돌 방지)
var _walk_phase: float = 0.0        # 걷기 바운스 위상(이동 거리로 진행)

# ── 서머너(summoner) 전용 상태 ───────────────────────────────────────
const SUMMON_KEEP_DIST := 260.0    # 유지 거리(플레이어에게서 물러나며 소환)
const SUMMON_COOLDOWN := 4.0       # 소환 간격(초)
const SUMMON_TELEGRAPH := 0.6      # 소환 예비 동작(소환진 점멸) 시간
const SUMMON_COUNT := 4            # 1회 소환 수(격노 시 +2)
var _summon_cd: float = 0.0
var _summon_tel: float = 0.0       # >0 이면 소환 예비 동작 중

# ── 바머(bomber) 전용 상태 ───────────────────────────────────────────
const BOMB_KEEP_DIST := 340.0      # 유지 거리(멀리서 포격)
const BOMB_COOLDOWN := 2.8         # 포격 간격(초)
const BOMB_WARN := 0.85            # 탄착 경고→폭발 지연(초) — 보고 피할 여지
const BOMB_RADIUS := 96.0          # 폭발 반경
const BOMB_SHELLS := 3             # 1회 포격 탄 수(격노 시 +2)
const BOMB_RING_COUNT := 7         # 2단계 포위 포격: 플레이어를 둘러싸는 탄 수
const BOMB_RING_RADIUS := 190.0    # 포위 링 반경(빈틈으로 빠져나가야 한다)
var _bomb_cd: float = 0.0

# ── 버서커(berserk) 전용 상태 ────────────────────────────────────────
# 느린 추적(stalk) → 예비 동작(wind, 대시 방향 고정) → 초고속 대시(dash) → 경직(recover) 순환.
# 대시 중 접촉 피해는 기존 접촉 시스템(높은 contact)이 그대로 처리한다.
const BERSERK_STALK_TIME := 1.3
const BERSERK_WIND := 0.5          # 대시 예비 동작(텔레그래프) 시간
const BERSERK_DASH_SPEED := 700.0  # 대시 속도(플레이어 이속 220 대비 압도적 — 예측 회피 요구)
const BERSERK_DASH_TIME := 0.4
const BERSERK_RECOVER := 0.7
const BERSERK_QUAKE_R := 130.0     # 대시 종료 지점의 착지 충격파 반경
var _dash_chain: int = 0           # 남은 연속 대시 수(페이즈≥1에서 연속 돌진)
var _bstate: String = "stalk"
var _is_final: bool = false        # 최종 보스(REAPER)면 처치 시 보너스 레벨업 대신 승리 처리
var _bt: float = 0.0               # 현재 상태 경과 시간

# ── 공용 스킬: 자가 회복(재생) ────────────────────────────────────────
# 아키타입 5종이 모두 공유하는 유일한 스킬. 체력이 balance.boss_heal_trigger 아래로 떨어지면
# 쿨타임마다 그 자리에 멈춰 시전하고, HEAL_CHANNEL 을 버텨내면 최대 체력의 일정 비율을 회복한다.
#
# 공정성 설계(다른 특수 공격과 같은 규칙):
#   · 시전 = 긴 텔레그래프. 초록 링이 조여드는 동안 보스는 이동·공격을 전부 멈추므로
#     그 자체가 플레이어에게 열리는 무료 딜 타임이다.
#   · 저지 가능. 시전 중 최대 체력의 boss_heal_break_ratio 만큼 피해를 누적시키면 회복이 깨진다.
#     저지에 필요한 피해(7%)가 회복량(15%)보다 훨씬 적어, "맞불 딜"보다 "끊기"가 항상 이득이다.
# 안전 장치: 시전 횟수(balance.boss_heal_charges)가 정해져 있고 저지당해도 소모되므로,
# 회복 총량에 상한이 있다 — DPS 가 낮아도 보스가 무한히 버티는 교착이 생기지 않는다.
const HEAL_CHANNEL := 1.4          # 시전(텔레그래프) 시간 — 이만큼 버티면 회복 성립
const HEAL_FIRST_DELAY := 3.0      # 발동 체력에 도달한 뒤 첫 시전까지의 유예
const HEAL_COLOR := Color(0.35, 1.0, 0.55)
var _heal_cd: float = HEAL_FIRST_DELAY
var _heal_t: float = 0.0           # >0 이면 회복 시전 중
var _heal_left: int = 0            # 남은 시전 횟수
var _heal_taken: int = 0           # 이번 시전 중 누적된 피해(저지 판정용)


func _ready() -> void:
	add_to_group("zombies")
	add_to_group("boss")


## 스포너가 인스턴스 직후 호출 — 등장 회차/타입에 따른 스탯 주입 후 등장 연출.
func setup(stats: Dictionary) -> void:
	_bal = GameData.balance
	max_health = stats.get("max_health", 80)
	health = max_health
	speed = stats.get("speed", 55.0)
	# 접촉 피해에 테이블 보정을 더한다 — 몸을 비비는 플레이가 확실히 아프도록.
	contact_damage = stats.get("contact_damage", 2) + _bal.boss_contact_bonus
	score_value = stats.get("score", 200)
	gold_drop = stats.get("gold", 12)
	_archetype = stats.get("archetype", "melee")
	_is_final = stats.get("final", false)
	# 전용 아트워크 사용 — 타입별 틴트 대신 아키타입 스프라이트를 그대로 노출(피격 잔광은 흰색 복귀).
	# 테마 보스는 전용 스프라이트(stats.sprite)를 우선 사용하고, 없으면 아키타입 기본 텍스처로 폴백.
	_base_color = Color(1, 1, 1)
	if body:
		var sprite_path: String = stats.get("sprite", "")
		var tex: Texture2D = null
		if sprite_path != "" and ResourceLoader.exists(sprite_path):
			var loaded = load(sprite_path)
			if loaded is Texture2D:
				tex = loaded
		if tex == null:
			tex = _BOSS_TEX.get(_archetype, _BOSS_TEX["melee"])
		body.texture = tex
		_fit_shadow()   # 확대 트윈 전(스케일=씬 값)에 그림자를 발밑 크기로 배치
	_proj_color = stats.get("proj_color", Color(0.55, 0.8, 1.0))
	_alive = true
	_enraged = false
	_phase = 0
	_fire_cd = GUNNER_COOLDOWN * 0.6   # 등장 직후 즉시 난사 방지
	_telegraph_t = 0.0
	_summon_cd = SUMMON_COOLDOWN * 0.5
	_summon_tel = 0.0
	_bomb_cd = BOMB_COOLDOWN * 0.5
	_slam_cd = SLAM_COOLDOWN * 0.55
	_volley_pending = 0
	_volley_t = 0.0
	_dash_chain = 0
	_alive_time = 0.0
	_bstate = "stalk"
	_bt = 0.0
	_heal_cd = HEAL_FIRST_DELAY
	_heal_t = 0.0
	_heal_taken = 0
	_heal_left = maxi(0, _bal.boss_heal_charges) if _bal != null else 0
	_flash = 0.0
	body.modulate = _base_color
	# HUD 가 체력바 위에 표시할 보스 이름(타입). 시그널 시그니처 변경 없이 Events 에 실어 보낸다.
	Events.boss_display_name = stats.get("name", "BOSS")
	Events.boss_spawned.emit(max_health)
	Events.boss_health_changed.emit(health, max_health)
	_spawn_intro()


func get_contact_damage() -> int:
	return contact_damage


func _spawn_intro() -> void:
	# 주의: 루트(CharacterBody2D)의 scale 을 애니메이션하면 move_and_slide 의 이동/충돌이
	# 깨져 보스가 그 자리에 얼어붙는다. 그래서 루트는 건드리지 않고 Body 스프라이트만 확대한다.
	var target_scale := body.scale   # 씬에 지정된 크기(2.7)
	body.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(body, "scale", target_scale, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _intro_scale_lock = false)   # 확대 완료 후부터 좌우 플립 허용
	_FXBurst.spawn(get_tree().current_scene, global_position, Color(0.9, 0.2, 0.2), 90.0, 0.5)


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return
	_alive_time += delta
	# 2단계 연사 예약(거너): 첫 일제사격 뒤 짧은 간격으로 추가 탄막을 뿌린다.
	if _volley_pending > 0:
		_volley_t -= delta
		if _volley_t <= 0.0:
			_volley_pending -= 1
			_volley_t = 0.22
			_fire_volley(true)
	# 자가 회복 시전 중이면 이 프레임의 아키타입 행동(이동·공격)을 통째로 건너뛴다 — 무방비 상태.
	if _tick_heal(delta):
		return
	match _archetype:
		"gunner":   _behave_gunner(delta, player)
		"summoner": _behave_summoner(delta, player)
		"bomber":   _behave_bomber(delta, player)
		"berserk":  _behave_berserk(delta, player)
		_:          _behave_melee(delta, player)   # melee 및 아직 미구현 아키타입의 기본 동작
	# 걷기 바운스 — 이동 속도에 비례해 위상을 올려 발 딛는 느낌(스케일 플립·확대와 독립).
	if not _intro_scale_lock:
		_walk_phase += velocity.length() * delta * 0.06
		body.position.y = -absf(sin(_walk_phase)) * 3.5


## 그림자를 보스 스프라이트 폭에 맞춘 납작한 타원으로 발밑에 배치(shadow.png 128x72).
func _fit_shadow() -> void:
	if body == null or body.texture == null:
		return
	var tex: Vector2 = body.texture.get_size()
	var sx: float = (tex.x * body.scale.x * 1.28) / 128.0
	shadow.scale = Vector2(sx, sx * 0.52)
	shadow.position = Vector2(0.0, tex.y * body.scale.y * 0.46)


## 사이드뷰 좌우 방향 갱신 — 회전 대신 Body 스케일 x 부호로 플립. 등장 확대 중에는 보류.
func _face(dir: Vector2) -> void:
	if absf(dir.x) > 0.02:
		_facing = -1.0 if dir.x < 0.0 else 1.0
	if not _intro_scale_lock:
		body.scale.x = absf(body.scale.x) * _facing


## 근접 돌격(브루트) — 플레이어를 향해 직진. 기존 동작 그대로.
## 근접형(브루트) — 추적 + 사거리 안에서 지면 강타(광역 충격파).
## 그냥 걸어오기만 하던 샌드백에서, 붙으면 위험한 압박형으로 바꾼다.
func _behave_melee(delta: float, player: Node2D) -> void:
	var to_p := player.global_position - global_position
	var dir := to_p / maxf(to_p.length(), 0.001)
	velocity = dir * speed
	_face(dir)
	move_and_slide()
	_slam_cd -= delta
	if _slam_cd <= 0.0 and to_p.length() <= SLAM_RANGE:
		_slam_cd = SLAM_COOLDOWN * _cd_mult()
		_do_slam(player)


## 지면 강타 — 플레이어의 예상 위치에 충격파 표식을 찍는다(페이즈 2 는 좌우 여진 2발 추가).
func _do_slam(player: Node2D) -> void:
	if not _alive:
		return
	SoundManager.play("boom", 0.05, 0.85)
	Events.shake(5.0)
	var scene := get_tree().current_scene
	var dmg: int = _bal.boss_slam_damage
	var focus := _lead_point(player, 420.0)
	_BossShell.spawn(scene, focus, SLAM_WARN, SLAM_RADIUS, dmg, Color(1.0, 0.45, 0.2))
	if _phase >= 2:
		# 광란: 본 강타 직후 좌우로 갈라지는 여진 — 제자리 회피를 막는다.
		var quake_dirs: Array[float] = [-1.0, 1.0]
		for sgn in quake_dirs:
			var off: Vector2 = Vector2.from_angle(randf() * TAU) * SLAM_RADIUS * 1.15 * sgn
			_BossShell.spawn(scene, focus + off, SLAM_WARN + 0.35, SLAM_RADIUS * 0.8, dmg,
					Color(1.0, 0.35, 0.2))


## 사격형(거너) — 유지 거리를 두고 카이팅하며, 텔레그래프 후 조준 사격.
## HP 50% 이하 격노 시 발사 간격 단축 + 방사형 난사로 격화(페이즈).
func _behave_gunner(delta: float, player: Node2D) -> void:
	var to_p := player.global_position - global_position
	var dist := maxf(to_p.length(), 0.001)
	var dir := to_p / dist
	# 카이팅: 너무 가까우면 물러나고, 너무 멀면 접근, 적정 거리면 측면 스트레이프.
	if dist < GUNNER_KEEP_DIST - 50.0:
		velocity = -dir * speed
	elif dist > GUNNER_KEEP_DIST + 50.0:
		velocity = dir * speed
	else:
		velocity = dir.orthogonal() * speed * 0.6
	_face(dir)
	move_and_slide()

	if _telegraph_t > 0.0:
		# 예비 동작 중 — 착탄 시점을 예측해 조준을 계속 갱신하다 종료 시 발사.
		_aim_dir = (_lead_point(player, GUNNER_PROJ_SPEED) - global_position).normalized()
		_telegraph_t -= delta
		if _telegraph_t <= 0.0:
			_fire_volley()
	else:
		_fire_cd -= delta
		if _fire_cd <= 0.0 and dist <= GUNNER_RANGE:
			_aim_dir = dir
			_telegraph_t = GUNNER_TELEGRAPH
			_fire_cd = GUNNER_COOLDOWN * _cd_mult()


## 조준 방향 기준 스프레드 발사. 평상시 5발(±11°/±22°), 격노 시 방사형 9발(2단계 13발).
## 2단계에서는 첫 사격 뒤 추가 일제사격 2회를 예약해(각 0.22초 간격, 회전 오프셋) 탄막을 겹친다.
func _fire_volley(is_followup: bool = false) -> void:
	if not _alive:
		return
	SoundManager.play("zombie_hit")
	if _enraged:
		var n := 9 if _phase < 2 else 13   # 2단계 광란: 더 촘촘한 방사형 탄막
		var twist := 0.0 if not is_followup else TAU / float(n) * 0.5   # 후속탄은 반 칸 어긋나게
		for i in range(n):
			_fire_bullet(Vector2.from_angle(_aim_dir.angle() + twist + TAU * i / n))
	else:
		var spread := deg_to_rad(11.0)
		var offsets: Array[float] = [-spread * 2.0, -spread, 0.0, spread, spread * 2.0]
		for off in offsets:
			_fire_bullet(_aim_dir.rotated(off))
	if _phase >= 2 and not is_followup:
		_volley_pending = 2
		_volley_t = 0.22


func _fire_bullet(dir: Vector2) -> void:
	var p := Pool.acquire(ENEMY_BULLET, get_tree().current_scene)
	p.global_position = global_position + dir * 24.0
	p.direction = dir
	p.speed = GUNNER_PROJ_SPEED
	p.damage = _bal.boss_bullet_damage
	p.color = _proj_color
	p.queue_redraw()   # 색 주입 후 1회 그리기(EnemyBullet 은 매 프레임 redraw 하지 않음)


## 소환형(서머너) — 유지 거리를 두고 천천히 물러나며, 주기적으로 호위 좀비를 소환.
## HP 50% 이하 격노 시 소환 간격 단축 + 소환 수 증가(페이즈).
func _behave_summoner(delta: float, player: Node2D) -> void:
	var to_p := player.global_position - global_position
	var dist := maxf(to_p.length(), 0.001)
	var dir := to_p / dist
	if dist < SUMMON_KEEP_DIST - 40.0:
		velocity = -dir * speed          # 너무 가까우면 물러난다
	elif dist > SUMMON_KEEP_DIST + 60.0:
		velocity = dir * speed * 0.5     # 너무 멀면 느리게 접근
	else:
		velocity = dir.orthogonal() * speed * 0.4
	_face(dir)
	move_and_slide()

	if _summon_tel > 0.0:
		_summon_tel -= delta
		if _summon_tel <= 0.0:
			_do_summon()
	else:
		_summon_cd -= delta
		if _summon_cd <= 0.0:
			_summon_tel = SUMMON_TELEGRAPH
			_summon_cd = SUMMON_COOLDOWN * _cd_mult()


func _do_summon() -> void:
	if not _alive:
		return
	SoundManager.play("zombie_hit")
	_FXBurst.spawn(get_tree().current_scene, global_position, Color(0.4, 1.0, 0.5), 70.0, 0.35)
	# 소환은 스포너가 처리(살아있는 좀비 카운터·과밀 상한 일관성 유지).
	Events.boss_summon.emit(SUMMON_COUNT + _extra_count())
	# 소환진 부식 — 소환과 함께 발밑을 노리는 산성 장판을 깔아, 서머너를 무는 동안에도
	# 계속 움직이게 만든다(페이즈가 오를수록 장판 수 증가).
	var scene := get_tree().current_scene
	var pl: Node2D = get_tree().get_first_node_in_group("player")
	if is_instance_valid(pl):
		for i in range(1 + _phase):
			var pos: Vector2 = pl.global_position
			if i > 0:
				pos += Vector2.from_angle(randf() * TAU) * randf_range(80.0, 200.0)
			_BossShell.spawn(scene, pos, 0.9, 92.0, _bal.boss_bomb_damage, Color(0.5, 1.0, 0.6))


## 포격형(바머) — 멀리서 거리를 유지하며, 플레이어 주변에 지연 폭발 탄을 투하.
## 탄착 표식(BossShell)이 곧 텔레그래프 — 이동으로 회피. HP 50% 이하 격노 시 포격 격화.
func _behave_bomber(delta: float, player: Node2D) -> void:
	var to_p := player.global_position - global_position
	var dist := maxf(to_p.length(), 0.001)
	var dir := to_p / dist
	if dist < BOMB_KEEP_DIST - 60.0:
		velocity = -dir * speed
	elif dist > BOMB_KEEP_DIST + 60.0:
		velocity = dir * speed * 0.6
	else:
		velocity = dir.orthogonal() * speed * 0.4
	_face(dir)
	move_and_slide()

	_bomb_cd -= delta
	if _bomb_cd <= 0.0:
		_bomb_cd = BOMB_COOLDOWN * _cd_mult()
		_fire_barrage(player)


## 탄착 표식을 뿌린다. 첫 발은 "도망칠 곳"을 예측해 찍고(정지·직선 도주 차단),
## 나머지는 그 주변을 덮는다. 2단계에서는 플레이어를 둘러싸는 포위 링을 추가로 깐다.
func _fire_barrage(player: Node2D) -> void:
	if not _alive:
		return
	SoundManager.play("zombie_hit")
	var scene := get_tree().current_scene
	var dmg: int = _bal.boss_bomb_damage
	var shells := BOMB_SHELLS + _extra_count()
	var focus := _lead_point(player, 260.0)   # 경고 시간 동안 달아날 지점을 예측
	for i in range(shells):
		var target := focus
		if i > 0:
			target += Vector2.from_angle(randf() * TAU) * randf_range(70.0, 170.0)
		_BossShell.spawn(scene, target, BOMB_WARN, BOMB_RADIUS, dmg, _proj_color)
	if _phase >= 2:
		# 광란: 포위 포격 — 링을 두르고 한 칸만 비워 이동을 강제한다.
		var gap := randi() % BOMB_RING_COUNT
		for i in range(BOMB_RING_COUNT):
			if i == gap:
				continue
			var pos := player.global_position + Vector2.from_angle(TAU * float(i) / BOMB_RING_COUNT) * BOMB_RING_RADIUS
			_BossShell.spawn(scene, pos, BOMB_WARN + 0.4, BOMB_RADIUS * 0.85, dmg, _proj_color)


## 돌진형(버서커) — 느린 추적 → 텔레그래프 → 초고속 대시 → 경직 순환.
## HP 50% 이하 격노 시 추적/경직 단축·대시 가속으로 압박이 격화된다.
func _behave_berserk(delta: float, player: Node2D) -> void:
	var to_p := player.global_position - global_position
	var dir := to_p / maxf(to_p.length(), 0.001)
	var haste := 0.65 if _enraged else 1.0
	_bt += delta
	match _bstate:
		"stalk":
			velocity = dir * speed * 0.5
			_face(dir)
			move_and_slide()
			if _bt >= BERSERK_STALK_TIME * haste:
				_bstate = "wind"; _bt = 0.0
		"wind":
			velocity = Vector2.ZERO
			_aim_dir = dir              # 대시 직전까지 플레이어를 조준(발사 순간 방향 고정)
			_face(dir)
			if _bt >= BERSERK_WIND * haste:
				_bstate = "dash"; _bt = 0.0
				_face(_aim_dir)
		"dash":
			velocity = _aim_dir * (BERSERK_DASH_SPEED * (1.3 if _phase >= 2 else (1.15 if _enraged else 1.0)))
			move_and_slide()
			if _bt >= BERSERK_DASH_TIME:
				_dash_end()
				# 페이즈≥1: 연속 돌진 — 한 번 피했다고 안심할 수 없게 곧바로 재조준 후 재대시.
				if _dash_chain > 0:
					_dash_chain -= 1
					_bstate = "wind"; _bt = BERSERK_WIND * haste * 0.45   # 짧은 재조준
				else:
					_bstate = "recover"; _bt = 0.0
		"recover":
			velocity = velocity * 0.85   # 관성 감쇠(급정지 대신 미끄러짐)
			move_and_slide()
			if _bt >= BERSERK_RECOVER * haste:
				_bstate = "stalk"; _bt = 0.0
				_dash_chain = 0 if _phase == 0 else (1 if _phase == 1 else 2)


## 대시 종료 지점의 착지 충격파 — 대시를 피한 직후 붙어 있으면 대가를 치른다.
func _dash_end() -> void:
	if not _alive:
		return
	SoundManager.play("boom", 0.05, 0.95)
	Events.shake(4.5)
	_BossShell.spawn(get_tree().current_scene, global_position, 0.22, BERSERK_QUAKE_R,
			_bal.boss_slam_damage, Color(1.0, 0.35, 0.35))


## 자가 회복 진행. 시전 중이면 true 를 돌려주고, 호출부는 그 프레임의 아키타입 행동을 건너뛴다.
## 쿨타임은 "발동 체력 이하일 때만" 흐른다 — 회복으로 발동선 위까지 올라가면 다시 그 아래로
## 깎일 때까지 다음 시전 시계가 멈춰, 두 번의 회복 사이에 반드시 눈에 보이는 간격이 생긴다.
func _tick_heal(delta: float) -> bool:
	if _heal_t > 0.0:
		velocity = Vector2.ZERO   # 시전 중 완전 정지(대시 관성도 여기서 끊긴다)
		_heal_t -= delta
		if _heal_t <= 0.0:
			_finish_heal()
		return true
	if _heal_left <= 0 or _bal == null:
		return false
	if float(health) > float(max_health) * _bal.boss_heal_trigger:
		return false
	if _heal_cd > 0.0:
		_heal_cd -= delta
		return false
	if not _can_start_heal():
		return false   # 다른 예비 동작과 겹치지 않게 미룬다 — 끝나는 즉시 시전한다
	_start_heal()
	return true


## 텔레그래프는 한 번에 하나만 — 사격/소환/돌진 예고와 겹치면 무엇을 피해야 할지 읽히지 않는다.
func _can_start_heal() -> bool:
	if _telegraph_t > 0.0 or _summon_tel > 0.0 or _volley_pending > 0:
		return false
	if _archetype == "berserk" and _bstate != "stalk":
		return false   # 예고한 돌진 도중에 멈춰 서면 대시 경로 경고가 거짓말이 된다
	return true


func _start_heal() -> void:
	_heal_t = HEAL_CHANNEL
	_heal_taken = 0
	velocity = Vector2.ZERO
	SoundManager.play("revive", 0.0, 0.7)   # 회복 차임(보스라 낮은 피치)
	_FXBurst.spawn(get_tree().current_scene, global_position, HEAL_COLOR, 95.0, 0.45)


## 시전을 끝까지 버텨낸 경우 — 최대 체력 비율만큼 회복하고 횟수/쿨타임을 소모한다.
func _finish_heal() -> void:
	_heal_t = 0.0
	_heal_left -= 1
	_heal_cd = _bal.boss_heal_cooldown
	if not _alive:
		return
	var before := health
	health = mini(max_health, health + maxi(1, int(round(float(max_health) * _bal.boss_heal_ratio))))
	var gained := health - before
	if gained <= 0:
		return
	Events.boss_health_changed.emit(health, max_health)
	# 회복량은 피해 숫자와 같은 채널에 초록으로 띄운다(보스 표시라 우선 슬롯 사용).
	_DamageNumber.spawn(get_tree().current_scene, global_position + Vector2(0, -40), gained, true, HEAL_COLOR, true)
	SoundManager.play("revive", 0.0, 0.5)
	_FXBurst.spawn(get_tree().current_scene, global_position, HEAL_COLOR, 160.0, 0.55)
	Events.shake(3.0)


## 회복 저지 — 회복 없이 횟수와 쿨타임만 소모한다(끊을수록 보스의 남은 회복이 줄어든다).
func _break_heal() -> void:
	_heal_t = 0.0
	_heal_left -= 1
	_heal_cd = _bal.boss_heal_cooldown
	SoundManager.play("card_flip", 0.05, 0.65)   # 시전이 끊기는 파열음
	_FXBurst.spawn(get_tree().current_scene, global_position, Color(0.55, 0.62, 0.6), 75.0, 0.3)


## 시전을 깨는 데 필요한 누적 피해. 회복량보다 훨씬 적게 잡아 "맞불 딜"보다 "끊기"가 항상 이득.
func _heal_break_amount() -> int:
	return maxi(1, int(round(float(max_health) * _bal.boss_heal_break_ratio)))


func _process(delta: float) -> void:
	if not _alive:
		return
	# 피격 잔광 감쇠 — 흰색에서 기본 색으로 돌아온다(Tween 없이).
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		body.modulate = _base_color.lerp(Color(1, 1, 1), _flash / _HIT_FLASH)
	_pulse += delta
	queue_redraw()


## 머리 위 체력바 + 위협적인 오라 링 + (거너) 발사 예비 조준선.
func _draw() -> void:
	if not _alive:
		return
	# 스프라이트 실제 크기(2.7배 스케일)를 기준으로 오라·체력바 위치를 잡는다.
	var half_h := 58.0
	if body and body.texture:
		half_h = body.texture.get_size().y * body.scale.y * 0.5

	# 맥동하는 오라 링 — 보스 외곽을 감싸도록 스프라이트 크기에 맞춘다.
	var aura := Color(0.95, 0.25, 0.2, 0.5)
	if _phase >= 2:
		aura = Color(1.0, 0.15, 0.25, 0.7)   # 2단계 광란 — 핏빛 오라
	elif _enraged:
		aura = Color(1.0, 0.5, 0.1, 0.6)     # 1단계 격노 — 주황 오라
	var r := half_h * 0.98 + sin(_pulse * 4.0) * 4.0
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, aura, 3.0, true)

	# 거너 발사 예비 조준선 — 텔레그래프 동안 점멸하는 경고 라인(로컬 좌표).
	if _telegraph_t > 0.0:
		# 보스 루트(this)는 회전하지 않으므로 월드 방향 _aim_dir 이 곧 로컬 방향이다.
		var a := 0.35 + 0.45 * absf(sin(_pulse * 22.0))
		var start := _aim_dir * (half_h * 0.9)
		var end := _aim_dir * (half_h * 0.9 + 260.0)
		draw_line(start, end, Color(1.0, 0.85, 0.3, a), 3.0, true)
		draw_circle(end, 7.0, Color(1.0, 0.6, 0.2, a * 0.8))

	# 버서커 대시 예비 동작 — 돌진 경로를 붉게 예고(두꺼운 화살 라인).
	if _archetype == "berserk" and _bstate == "wind":
		var ba := 0.4 + 0.4 * absf(sin(_pulse * 26.0))
		var bstart := _aim_dir * (half_h * 0.9)
		var bend := _aim_dir * (half_h * 0.9 + 360.0)
		draw_line(bstart, bend, Color(1.0, 0.25, 0.3, ba), 6.0, true)
		draw_circle(bend, 10.0, Color(1.0, 0.3, 0.25, ba * 0.8))

	# 서머너 소환 예비 동작 — 발밑에 확장하는 초록 소환진(경고).
	if _summon_tel > 0.0:
		var sa := 0.3 + 0.4 * absf(sin(_pulse * 16.0))
		draw_arc(Vector2.ZERO, half_h * 1.25, 0.0, TAU, 40, Color(0.4, 1.0, 0.55, sa), 4.0, true)
		draw_arc(Vector2.ZERO, half_h * 0.75, 0.0, TAU, 32, Color(0.5, 1.0, 0.6, sa * 0.7), 2.5, true)

	# 자가 회복 시전 — 조여드는 초록 링 + 12시부터 채워지는 진행 게이지.
	# 게이지가 한 바퀴 차면 회복이 성립한다("남은 시간"이 눈에 보이게 — 지금 끊으라는 신호).
	if _heal_t > 0.0:
		var ht := 1.0 - clampf(_heal_t / HEAL_CHANNEL, 0.0, 1.0)
		var hglow := 0.35 + 0.35 * absf(sin(_pulse * 14.0))
		draw_arc(Vector2.ZERO, half_h * (1.55 - 0.45 * ht), 0.0, TAU, 40,
				Color(HEAL_COLOR.r, HEAL_COLOR.g, HEAL_COLOR.b, hglow), 4.0, true)
		draw_arc(Vector2.ZERO, half_h * 1.05, -PI * 0.5, -PI * 0.5 + TAU * ht, 36,
				Color(0.72, 1.0, 0.82, 0.95), 5.0, true)

	# 체력바 — 스프라이트 머리 위쪽에 확실히 떨어뜨려 그린다(겹침 방지).
	var bar_w := 96.0
	var bar_h := 9.0
	var bar_y := -(half_h + bar_h + 12.0)
	var ratio := clampf(float(health) / float(max_health), 0.0, 1.0)
	# 테두리/배경
	draw_rect(Rect2(-bar_w * 0.5 - 2.0, bar_y - 2.0, bar_w + 4.0, bar_h + 4.0), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, bar_h), Color(0.2, 0.05, 0.06, 0.9))
	# 채움 (체력 비율에 따라 색 변화: 녹색→노랑→빨강)
	var fill := Color(0.9, 0.2, 0.2).lerp(Color(1.0, 0.85, 0.2), ratio)
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * ratio, bar_h), fill)


func take_damage(amount: int, is_crit: bool = false) -> void:
	if not _alive:
		return
	if Events.trait_damage_mult != 1.0:   # 캐릭터 트레잇: 나가는 피해 배수(수신측에서 일괄 적용)
		amount = maxi(1, int(round(amount * Events.trait_damage_mult)))
	health = max(0, health - amount)
	# 보스 피해 숫자는 크게, 프레임 상한과 무관하게 항상 표시. 크리티컬은 주황으로 더 강조.
	var num_col := Color(1.0, 0.45, 0.12) if is_crit else Color(1.0, 0.85, 0.3)
	_DamageNumber.spawn(get_tree().current_scene, global_position + Vector2(0, -40), amount, true, num_col, true)
	Events.boss_health_changed.emit(health, max_health)
	SoundManager.play("zombie_hit")
	# 피격 잔광은 Tween 대신 잔여 시간을 _process 에서 감쇠한다(Zombie 와 동일한 방식).
	# 보스는 체인소·오브·드론·관통탄·스플래시에 초당 수십 번 맞으므로, 피격마다 Tween 을 만들면
	# 같은 body.modulate 를 놓고 다투는 트윈이 계속 쌓인다.
	_flash = _HIT_FLASH
	body.modulate = Color(1, 1, 1)
	# 다단계 전환: 체력 비율이 66%/33% 아래로 처음 내려갈 때마다 한 단계씩 격화한다.
	# (회복으로 비율이 올라가도 페이즈는 되돌아가지 않는다 — 임계선을 오르내리며 전환 연출이
	#  반복되면 화면이 시끄럽고, 이미 드러난 패턴이 도로 잠기는 것도 이상하다.)
	if health > 0:
		# 회복 시전 중이라면 누적 피해로 저지할 수 있다 — 이 창이 곧 반격 기회다.
		if _heal_t > 0.0:
			_heal_taken += amount
			if _heal_taken >= _heal_break_amount():
				_break_heal()
		var ratio := float(health) / float(max_health)
		if _phase < 2 and ratio <= 0.33:
			_enter_phase(2)
		elif _phase < 1 and ratio <= 0.66:
			_enter_phase(1)
	if health <= 0:
		_die()


## 페이즈 진입(1=격노, 2=광란). 공격 격화(_cd_mult/_extra_count) + 섬광, 2단계는 즉시 소환 파동 + 강한 흔들림.
func _enter_phase(n: int) -> void:
	_phase = n
	_enraged = true
	_fire_cd = minf(_fire_cd, 0.35)   # 전환 직후 빠르게 반격
	var col := Color(1.0, 0.5, 0.15) if n == 1 else Color(1.0, 0.2, 0.25)
	_FXBurst.spawn(get_tree().current_scene, global_position, col, 80.0 + 40.0 * n, 0.4)
	Events.shake(6.0 + 4.0 * n)
	SoundManager.play("boom", 0.0, 0.7 if n == 1 else 0.55)   # 페이즈 전환 저음 포효(2단계 더 낮게)
	if n >= 2:
		# 2단계 광란: 아키타입과 무관하게 호위 파동을 한 번 소환해 압박을 준다.
		Events.boss_summon.emit(4)


## 페이즈별 쿨다운 배수(작을수록 빠름): 평상 1.0 / 1단계 0.6 / 2단계 0.45.
## 여기에 지구전 격화(_rage_mult)를 곱해, 오래 끌수록 공격이 촘촘해진다 — 무한 카이팅 봉쇄.
func _cd_mult() -> float:
	var base := 1.0 if _phase == 0 else (0.6 if _phase == 1 else 0.45)
	return base / _rage_mult()


## 생존 시간 기반 격화 배수(1.0 → boss_rage_max). boss_rage_seconds 이후 60초에 걸쳐 상승.
func _rage_mult() -> float:
	if _bal == null or _alive_time <= _bal.boss_rage_seconds:
		return 1.0
	var t := (_alive_time - _bal.boss_rage_seconds) / 60.0
	return lerpf(1.0, _bal.boss_rage_max, clampf(t, 0.0, 1.0))


## 예측 조준 — 플레이어의 현재 속도로 착탄 시점 위치를 추정한다.
## 정지·직선 도주가 안전하지 않게 만들어 "보고 피하는" 회피를 요구한다.
func _lead_point(player: Node2D, travel_speed: float) -> Vector2:
	var to_p := player.global_position - global_position
	var pv: Vector2 = Vector2.ZERO
	if player is CharacterBody2D:
		pv = player.velocity
	var t: float = to_p.length() / maxf(travel_speed, 1.0)
	return player.global_position + pv * minf(t, 1.2)


## 페이즈별 추가 발사/소환 수: 평상 0 / 1단계 +2 / 2단계 +4.
func _extra_count() -> int:
	return 0 if _phase == 0 else (2 if _phase == 1 else 4)


func _die() -> void:
	_alive = false
	# _process 가 멈추므로 피격 잔광이 남아 죽는 순간이 하얗게 굳는다 — 기본 색으로 되돌린다.
	# (Tween 방식일 때는 트윈이 알아서 끝까지 복원했다)
	_flash = 0.0
	body.modulate = _base_color
	remove_from_group("zombies")
	remove_from_group("boss")
	SoundManager.play("zombie_die")
	Events.add_score(score_value)
	Events.boss_died.emit()
	Events.shake(11.0)      # 보스 폭사 — 강한 화면 흔들림
	Events.hit_stop()       # 순간 정지로 한 방의 무게감

	# 다중 충격파 — 흰 섬광 → 황금 링 → 주황 링이 시간차로 번지며 터진다.
	_burst(Color(1.0, 1.0, 0.85), 70.0,  0.28, 0.0)    # 중심 흰 섬광
	_burst(Color(1.0, 0.82, 0.25), 150.0, 0.6,  0.0)    # 큰 황금 링
	_burst(Color(1.0, 0.45, 0.15), 120.0, 0.5,  0.12)   # 주황 2차 파동
	_burst(Color(1.0, 0.88, 0.35), 190.0, 0.7,  0.24)   # 넓게 퍼지는 마지막 황금 링

	# 황금 동전 분수 — 보스 중심에서 사방으로 튀어 흩어졌다가 착지(시간차 분출). 보스 코인은 프리미엄(값2).
	for i in range(gold_drop):
		var g := Pool.acquire(GOLD, get_tree().current_scene)
		g.global_position = global_position
		g.set_value(2)
		var landing := global_position + Vector2.from_angle(randf() * TAU) * randf_range(45.0, 135.0)
		g.launch(landing, randf() * 0.18)

	# 보스 상자 보상 — 무료 레벨업 1회(강화/진화 카드가 즉시 뜬다). 최종 보스는 승리 처리라 제외.
	if not _is_final:
		Events.bonus_level()

	queue_free()


## 지정한 지연 후 한 번 터지는 확산 파동(FXBurst). 보스 처치 연출용 헬퍼.
## FXBurst 가 start_delay 로 스스로 시간차 재생하므로(타이머·콜백 불필요) 보스가 곧바로
## 해제돼도 안전하다 — 파동 노드는 현재 씬에 독립적으로 붙는다.
func _burst(c: Color, radius: float, dur: float, delay: float) -> void:
	_FXBurst.spawn(get_tree().current_scene, global_position, c, radius, dur, delay)
