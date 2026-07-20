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

const GOLD := preload("res://scenes/Gold.tscn")
const _FXBurst := preload("res://scripts/FXBurst.gd")
const _BossShell := preload("res://scripts/BossShell.gd")
const ENEMY_BULLET := preload("res://scenes/EnemyBullet.tscn")

@onready var body: Node2D = $Body

var speed: float = 55.0
var max_health: int = 80
var health: int = 80
var contact_damage: int = 2
var score_value: int = 200
var gold_drop: int = 12

var _alive: bool = false
var _archetype: String = "melee"
var _base_color: Color = Color(0.55, 0.12, 0.14)
var _proj_color: Color = Color(0.55, 0.8, 1.0)
var _pulse: float = 0.0
var _enraged: bool = false      # HP 50% 이하 격노 진입 여부(1회성 트리거)

# ── 거너(gunner) 전용 상태 ────────────────────────────────────────────
const GUNNER_RANGE := 520.0        # 발사 사거리
const GUNNER_KEEP_DIST := 300.0    # 유지하려는 거리(카이팅)
const GUNNER_COOLDOWN := 2.0       # 발사 간격(초)
const GUNNER_TELEGRAPH := 0.45     # 발사 예비 동작(총구 점멸) 시간 — 보고 피할 여지
const GUNNER_PROJ_SPEED := 300.0   # 투사체 속도(플레이어 이속 220 대비 회피 가능)
var _fire_cd: float = 0.0
var _telegraph_t: float = 0.0      # >0 이면 발사 예비 동작 중
var _aim_dir: Vector2 = Vector2.RIGHT

# ── 서머너(summoner) 전용 상태 ───────────────────────────────────────
const SUMMON_KEEP_DIST := 260.0    # 유지 거리(플레이어에게서 물러나며 소환)
const SUMMON_COOLDOWN := 5.0       # 소환 간격(초)
const SUMMON_TELEGRAPH := 0.6      # 소환 예비 동작(소환진 점멸) 시간
const SUMMON_COUNT := 3            # 1회 소환 수(격노 시 +2)
var _summon_cd: float = 0.0
var _summon_tel: float = 0.0       # >0 이면 소환 예비 동작 중

# ── 바머(bomber) 전용 상태 ───────────────────────────────────────────
const BOMB_KEEP_DIST := 340.0      # 유지 거리(멀리서 포격)
const BOMB_COOLDOWN := 3.2         # 포격 간격(초)
const BOMB_WARN := 1.0             # 탄착 경고→폭발 지연(초) — 보고 피할 여지
const BOMB_RADIUS := 88.0          # 폭발 반경
const BOMB_DAMAGE := 2             # 폭발 피해
const BOMB_SHELLS := 2             # 1회 포격 탄 수(격노 시 +2)
var _bomb_cd: float = 0.0

# ── 버서커(berserk) 전용 상태 ────────────────────────────────────────
# 느린 추적(stalk) → 예비 동작(wind, 대시 방향 고정) → 초고속 대시(dash) → 경직(recover) 순환.
# 대시 중 접촉 피해는 기존 접촉 시스템(높은 contact)이 그대로 처리한다.
const BERSERK_STALK_TIME := 1.3
const BERSERK_WIND := 0.5          # 대시 예비 동작(텔레그래프) 시간
const BERSERK_DASH_SPEED := 640.0  # 대시 속도(플레이어 이속 220 대비 압도적 — 예측 회피 요구)
const BERSERK_DASH_TIME := 0.4
const BERSERK_RECOVER := 0.7
var _bstate: String = "stalk"
var _bt: float = 0.0               # 현재 상태 경과 시간


func _ready() -> void:
	add_to_group("zombies")
	add_to_group("boss")


## 스포너가 인스턴스 직후 호출 — 등장 회차/타입에 따른 스탯 주입 후 등장 연출.
func setup(stats: Dictionary) -> void:
	max_health = stats.get("max_health", 80)
	health = max_health
	speed = stats.get("speed", 55.0)
	contact_damage = stats.get("contact_damage", 2)
	score_value = stats.get("score", 200)
	gold_drop = stats.get("gold", 12)
	_archetype = stats.get("archetype", "melee")
	_base_color = stats.get("tint", Color(0.55, 0.12, 0.14))
	_proj_color = stats.get("proj_color", Color(0.55, 0.8, 1.0))
	_alive = true
	_enraged = false
	_fire_cd = GUNNER_COOLDOWN * 0.6   # 등장 직후 즉시 난사 방지
	_telegraph_t = 0.0
	_summon_cd = SUMMON_COOLDOWN * 0.5
	_summon_tel = 0.0
	_bomb_cd = BOMB_COOLDOWN * 0.5
	_bstate = "stalk"
	_bt = 0.0
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
	_FXBurst.spawn(get_tree().current_scene, global_position, Color(0.9, 0.2, 0.2), 90.0, 0.5)


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return
	match _archetype:
		"gunner":   _behave_gunner(delta, player)
		"summoner": _behave_summoner(delta, player)
		"bomber":   _behave_bomber(delta, player)
		"berserk":  _behave_berserk(delta, player)
		_:          _behave_melee(player)   # melee 및 아직 미구현 아키타입의 기본 동작


## 근접 돌격(브루트) — 플레이어를 향해 직진. 기존 동작 그대로.
func _behave_melee(player: Node2D) -> void:
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * speed
	body.rotation = dir.angle()
	move_and_slide()


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
	body.rotation = dir.angle()
	move_and_slide()

	if _telegraph_t > 0.0:
		# 예비 동작 중 — 조준 방향을 계속 갱신하다 종료 시 발사.
		_aim_dir = dir
		_telegraph_t -= delta
		if _telegraph_t <= 0.0:
			_fire_volley()
	else:
		_fire_cd -= delta
		if _fire_cd <= 0.0 and dist <= GUNNER_RANGE:
			_aim_dir = dir
			_telegraph_t = GUNNER_TELEGRAPH
			_fire_cd = GUNNER_COOLDOWN * (0.6 if _enraged else 1.0)


## 조준 방향 기준 스프레드 발사. 평상시 3발(±14°), 격노 시 방사형 9발.
func _fire_volley() -> void:
	if not _alive:
		return
	SoundManager.play("zombie_hit")
	if _enraged:
		var n := 9
		for i in range(n):
			_fire_bullet(Vector2.from_angle(_aim_dir.angle() + TAU * i / n))
	else:
		var spread := deg_to_rad(14.0)
		for off in [-spread, 0.0, spread]:
			_fire_bullet(_aim_dir.rotated(off))


func _fire_bullet(dir: Vector2) -> void:
	var p := Pool.acquire(ENEMY_BULLET, get_tree().current_scene)
	p.global_position = global_position + dir * 24.0
	p.direction = dir
	p.speed = GUNNER_PROJ_SPEED
	p.damage = 1
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
	body.rotation = dir.angle()
	move_and_slide()

	if _summon_tel > 0.0:
		_summon_tel -= delta
		if _summon_tel <= 0.0:
			_do_summon()
	else:
		_summon_cd -= delta
		if _summon_cd <= 0.0:
			_summon_tel = SUMMON_TELEGRAPH
			_summon_cd = SUMMON_COOLDOWN * (0.6 if _enraged else 1.0)


func _do_summon() -> void:
	if not _alive:
		return
	SoundManager.play("zombie_hit")
	_FXBurst.spawn(get_tree().current_scene, global_position, Color(0.4, 1.0, 0.5), 70.0, 0.35)
	# 소환은 스포너가 처리(살아있는 좀비 카운터·과밀 상한 일관성 유지).
	Events.boss_summon.emit(SUMMON_COUNT + (2 if _enraged else 0))


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
	body.rotation = dir.angle()
	move_and_slide()

	_bomb_cd -= delta
	if _bomb_cd <= 0.0:
		_bomb_cd = BOMB_COOLDOWN * (0.6 if _enraged else 1.0)
		_fire_barrage(player)


## 플레이어 현재 위치 + 주변 무작위 지점에 탄착 표식을 뿌린다(첫 발은 발밑 조준).
func _fire_barrage(player: Node2D) -> void:
	if not _alive:
		return
	SoundManager.play("zombie_hit")
	var scene := get_tree().current_scene
	var shells := BOMB_SHELLS + (2 if _enraged else 0)
	for i in range(shells):
		var target := player.global_position
		if i > 0:
			target += Vector2.from_angle(randf() * TAU) * randf_range(60.0, 180.0)
		_BossShell.spawn(scene, target, BOMB_WARN, BOMB_RADIUS, BOMB_DAMAGE, _proj_color)


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
			body.rotation = dir.angle()
			move_and_slide()
			if _bt >= BERSERK_STALK_TIME * haste:
				_bstate = "wind"; _bt = 0.0
		"wind":
			velocity = Vector2.ZERO
			_aim_dir = dir              # 대시 직전까지 플레이어를 조준(발사 순간 방향 고정)
			body.rotation = dir.angle()
			if _bt >= BERSERK_WIND * haste:
				_bstate = "dash"; _bt = 0.0
				body.rotation = _aim_dir.angle()
		"dash":
			velocity = _aim_dir * (BERSERK_DASH_SPEED * (1.15 if _enraged else 1.0))
			move_and_slide()
			if _bt >= BERSERK_DASH_TIME:
				_bstate = "recover"; _bt = 0.0
		"recover":
			velocity = velocity * 0.85   # 관성 감쇠(급정지 대신 미끄러짐)
			move_and_slide()
			if _bt >= BERSERK_RECOVER * haste:
				_bstate = "stalk"; _bt = 0.0


func _process(delta: float) -> void:
	if not _alive:
		return
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
	if _enraged:
		aura = Color(1.0, 0.5, 0.1, 0.6)   # 격노 시 더 강렬한 오라
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


func take_damage(amount: int) -> void:
	if not _alive:
		return
	health = max(0, health - amount)
	Events.boss_health_changed.emit(health, max_health)
	SoundManager.play("zombie_hit")
	body.modulate = Color(1, 1, 1)
	var tw := create_tween()
	tw.tween_property(body, "modulate", _base_color, 0.12)
	# 페이즈 전환: 체력 50% 이하로 처음 내려가면 격노(공격 격화 + 오라 강화 + 섬광).
	if not _enraged and health > 0 and float(health) / float(max_health) <= 0.5:
		_enter_enrage()
	if health <= 0:
		_die()


func _enter_enrage() -> void:
	_enraged = true
	_fire_cd = minf(_fire_cd, 0.4)   # 격노 진입 직후 빠르게 반격
	_FXBurst.spawn(get_tree().current_scene, global_position, Color(1.0, 0.5, 0.15), 80.0, 0.35)


func _die() -> void:
	_alive = false
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

	# 황금 동전 분수 — 보스 중심에서 사방으로 튀어 흩어졌다가 착지(시간차 분출).
	for i in range(gold_drop):
		var g := Pool.acquire(GOLD, get_tree().current_scene)
		g.global_position = global_position
		var landing := global_position + Vector2.from_angle(randf() * TAU) * randf_range(45.0, 135.0)
		g.launch(landing, randf() * 0.18)

	queue_free()


## 지정한 지연 후 한 번 터지는 확산 파동(FXBurst). 보스 처치 연출용 헬퍼.
## FXBurst 가 start_delay 로 스스로 시간차 재생하므로(타이머·콜백 불필요) 보스가 곧바로
## 해제돼도 안전하다 — 파동 노드는 현재 씬에 독립적으로 붙는다.
func _burst(c: Color, radius: float, dur: float, delay: float) -> void:
	_FXBurst.spawn(get_tree().current_scene, global_position, c, radius, dur, delay)
