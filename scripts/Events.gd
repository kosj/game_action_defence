extends Node
## 전역 이벤트 버스 / 재화·체력·웨이브·업그레이드 관리 (Autoload 싱글톤: "Events")

## 게임 버전 — 타이틀/메뉴에 표시.
const VERSION := "v1.0.0"

## 배포마다 CI 가 build_info.json 에 커밋 SHA·시각을 기록한다(로컬은 "dev build").
## 타이틀/메뉴에 함께 표시해 "지금 라이브가 어떤 빌드인지"를 눈으로 확인할 수 있게 한다.
const _BUILD_INFO_PATH := "res://build_info.json"
var _build_stamp_cache := ""


## 예: "v1.0.0 · a1b2c3d · 2026-07-03 10:00 UTC" (배포 빌드) / "v1.0.0 · dev build" (로컬)
func build_label() -> String:
	if _build_stamp_cache == "":
		_build_stamp_cache = _read_build_stamp()
	return "%s · %s" % [VERSION, _build_stamp_cache]


func _read_build_stamp() -> String:
	if not FileAccess.file_exists(_BUILD_INFO_PATH):
		return "dev build"
	var f := FileAccess.open(_BUILD_INFO_PATH, FileAccess.READ)
	if f == null:
		return "dev build"
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return "dev build"
	var sha: String = parsed.get("sha", "dev")
	var date: String = parsed.get("date", "")
	return ("%s · %s" % [sha, date]) if date != "" else sha


## 커밋 SHA(7자리)만 — 화면 디버그 표시에 "지금 이 빌드가 뭔지" 붙이는 용도.
func build_sha() -> String:
	if not FileAccess.file_exists(_BUILD_INFO_PATH):
		return "dev"
	var f := FileAccess.open(_BUILD_INFO_PATH, FileAccess.READ)
	if f == null:
		return "dev"
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		return str(parsed.get("sha", "dev"))
	return "dev"

signal gold_changed(total: int)
signal player_health_changed(health: int, max_health: int)
signal player_died
signal player_revived            # 보상형 광고 시청으로 사망 직후 부활
signal wave_changed(wave: int)
signal elapsed_changed(seconds: float)
signal wave_complete(wave: int)
signal wave_progress_changed(killed: int, total: int)
signal zombie_killed
signal shop_closed
signal weapon_equipped(stats: Dictionary)
signal score_changed(score: int)
signal high_score_changed(high_score: int)
signal boss_spawned(max_health: int)
signal boss_health_changed(health: int, max_health: int)
signal boss_died
signal boss_summon(count: int)   # 서머너 보스가 호위 좀비 소환 요청 — 스포너가 처리(카운터 일관성)
signal game_won                  # 최종 보스(REAPER) 처치 — 런 클리어(승리)

# 필드 버프 상태
signal weapon_timer_changed(time_left: float, total: float)   # 임시 무기 남은 사용 시간
signal gold_magnet_changed(active: bool, time_left: float)    # 골드 자동 줍기(자석) 버프

# 타격감 연출: 화면 흔들림 요청(플레이어의 카메라가 수신해 감쇠 오프셋을 적용).
signal screen_shake_requested(amount: float)

# 스웜 이벤트 경고 — 한 무리가 곧 몰려온다(HUD 가 배너로 경고). elite=엘리트 팩 여부.
signal swarm_incoming(elite: bool)

# 인게임 레벨업(뱀서식 성장). 코인 수집으로 경험치가 쌓이고, 임계 도달 시 레벨업 → 강화 카드 선택.
signal xp_changed(xp: int, xp_to_next: int, level: int)
signal level_up(level: int)

var total_gold: int = 0
var total_kills: int = 0
var player_health: int = 0
var player_max_health: int = 0
var current_wave: int = 1
var elapsed_time: float = 0.0

# 현재 보스의 표시 이름(타입) — HUD 체력바 라벨용. 보스가 setup() 에서 채우고 boss_spawned 직후 읽힌다.
var boss_display_name: String = "BOSS"
var wave_kill_progress: int = 0
var wave_kill_total: int = 0

# 골드 자동 줍기(자석) 버프 활성 여부 — Gold 이 매 프레임 참조하는 일시 상태(저장 안 함).
var gold_magnet_active: bool = false

# 메타 성장(영구 강화) 배수 — 런 시작 시 MetaManager 가 설정. 골드/경험치 획득에 곱한다.
var gold_mult: float = 1.0
var xp_mult: float = 1.0

# 점수: score=이번 판 점수, high_score=저장된 최고점, _prev_high=이번 판 시작 시점 최고점(갱신 판정용)
var score: int = 0
var high_score: int = 0
var _prev_high: int = 0

# 인게임 레벨: 코인 수집으로 xp 누적 → xp_to_next 도달 시 레벨업(강화 카드 선택). 판마다 초기화.
var xp: int = 0
var level: int = 1
var xp_to_next: int = 12

# 인벤토리(뱀서식 슬롯 성장): 무기/패시브 아이템의 보유 레벨. gun 은 시작 시 Lv1 보유.
# ItemDB.recompute 가 이 인벤토리를 upgrade_* 로 반영한다(전투 코드는 upgrade_* 만 읽는다).
var weapons: Dictionary = {"gun": 1}
var passives: Dictionary = {}


## 레벨업 카드 선택 — 무기/패시브 아이템 1레벨 획득 후 스탯 재계산.
func grant_item(id: String) -> void:
	if ItemDB.is_weapon(id):
		weapons[id] = int(weapons.get(id, 0)) + 1
	else:
		passives[id] = int(passives.get(id, 0)) + 1
	ItemDB.recompute(weapons, passives)


## 진화: 원본 무기를 제거하고 진화 무기(Lv1)로 교체 후 재계산. 패시브는 유지된다.
func evolve(base_id: String, into_id: String) -> void:
	weapons.erase(base_id)
	weapons[into_id] = 1
	ItemDB.recompute(weapons, passives)


## 다음 레벨까지 필요한 경험치 곡선 — 초반은 자주, 갈수록 뜸하게(레벨업 연출 과다 방지).
func _xp_curve(lvl: int) -> int:
	return int(round(10.0 + (lvl - 1) * 8.0 + pow(float(lvl), 1.5) * 2.0))


## 보스 상자 보상 — 무료 레벨업 1회(경험치 소모 없이 강화 카드가 뜬다).
func bonus_level() -> void:
	level += 1
	xp_to_next = _xp_curve(level)
	level_up.emit(level)
	xp_changed.emit(xp, xp_to_next, level)


## 코인 수집 시 호출(코인 1개 = 경험치 1). 임계 도달 시 레벨업 신호(연속 레벨업도 처리).
func add_xp(amount: int) -> void:
	xp += maxi(1, int(round(amount * xp_mult)))   # 메타 '성장' 배수
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = _xp_curve(level)
		level_up.emit(level)
	xp_changed.emit(xp, xp_to_next, level)

# 난이도 모드는 제거됨 — 단일 통합 모드(뱀서식, 시간이 갈수록 압박이 커지는 하나의 곡선).
# difficulty 는 랭킹 모드 키 호환용으로만 남겨 항상 0 으로 고정한다.
var difficulty: int = 0
const DIFFICULTY_NAMES: Array = ["Standard"]

# 단일 모드 밸런스 배수(고정). 하드/헬 없이 접근성 있는 중간 곡선 — 후반 압박은 wave_pressure 로.
const _MODE_ENEMY_HP := 0.95
const _MODE_ENEMY_SPEED := 0.98
const _MODE_SPAWN := 1.02
const _MODE_BOSS_HP := 1.00
const _MODE_TOTAL := 0.95
const _MODE_SCORE := 1.00

## 무한 스케일링: 테이블이 끝나는 6웨이브 이후 매 웨이브 +12% 체력(복리).
## 업그레이드가 만렙에 도달해도 언젠가는 반드시 한계가 오도록 하는 점수 러시 장치.
const _PRESSURE_PER_WAVE := 1.12
const _PRESSURE_SPEED_CAP := 1.30   # 이속은 최대 +30% 까지만(반응 불가능해지지 않게)


func diff_enemy_hp_mult() -> float:    return _MODE_ENEMY_HP
func diff_enemy_speed_mult() -> float: return _MODE_ENEMY_SPEED
func diff_spawn_mult() -> float:       return _MODE_SPAWN
func diff_boss_hp_mult() -> float:     return _MODE_BOSS_HP
func diff_total_mult() -> float:       return _MODE_TOTAL
func diff_score_mult() -> float:       return _MODE_SCORE
func difficulty_name() -> String:      return "Standard"


## 6웨이브 이후 적 체력에 곱하는 복리 압박 배수(보스 포함).
func wave_pressure_mult(wave: int) -> float:
	return pow(_PRESSURE_PER_WAVE, maxi(wave - 6, 0))


## 6웨이브 이후 적 이속 압박 배수 — 매 웨이브 +1.5%, 상한 +30%.
func wave_speed_pressure(wave: int) -> float:
	return minf(1.0 + 0.015 * maxi(wave - 6, 0), _PRESSURE_SPEED_CAP)

# 업그레이드 레벨 (0 = 미구매)
var upgrade_speed: int = 0
var upgrade_atk_speed: int = 0
var upgrade_bullet_damage: int = 0
var upgrade_orb_damage: int = 0
var upgrade_orb_speed: int = 0         # 오브 공전 회전속도 (+35%/레벨)
var upgrade_lightning_damage: int = 0
var upgrade_max_health: int = 0
var upgrade_multi_bullet: int = 0
var upgrade_orbs: int = 0
var upgrade_lightning: int = 0
var upgrade_lightning_count: int = 0   # 낙뢰 1회당 동시에 때리는 번개 가닥 수(+1 per level)
var upgrade_pickup_range: int = 0      # 코인 자석 범위 (+30%/레벨)
var upgrade_regen: int = 0             # 체력 재생 속도 (레벨 높을수록 빠름)
var upgrade_crit: int = 0              # 크리티컬 확률 (+8%/레벨, 데미지 2배)
var upgrade_garlic: int = 0            # 마늘 오라 무기 레벨(0=미보유)
var upgrade_holy: int = 0              # 성수 무기 레벨(0=미보유)


# ── 좀비 스냅샷 캐시 ─────────────────────────────────────────────────
# get_nodes_in_group() 은 호출마다 새 Array 를 할당한다. 총알·오브·번개·플레이어가
# 각자 매 프레임 호출하면(총알 수십 발 × 좀비 100+) 할당·순회 비용이 커지므로,
# 물리 프레임당 1회만 스캔해 공유한다. 같은 프레임 안에서 죽은 좀비가 남아 있을 수
# 있으므로 사용처는 is_instance_valid + is_in_group("zombies") 로 걸러야 한다.
var _z_frame: int = -1
var _z_cache: Array = []


func live_zombies() -> Array:
	var f := Engine.get_physics_frames()
	if f != _z_frame:
		_z_frame = f
		_z_cache = get_tree().get_nodes_in_group("zombies")
	return _z_cache


## 화면 흔들림 요청 — 타격감이 필요한 순간(플레이어 피격·보스 사망·폭발 등)에 호출한다.
## 실제 오프셋 적용은 Player 의 카메라가 담당(감쇠). amount 는 대략 흔들림 픽셀 세기.
func shake(amount: float) -> void:
	screen_shake_requested.emit(amount)


## 히트스톱(순간 정지) — 큰 한 방(보스 사망 등)에 짧게 시간을 멈춰 타격감을 준다.
## 시간 배율에 영향받지 않는 타이머로 복구하므로 확실히 원상 복귀한다(중첩 방지).
var _hitstop_active: bool = false
func hit_stop(duration: float = 0.07, scale: float = 0.05) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = scale
	var t := get_tree().create_timer(duration, true, false, true)   # ignore_time_scale=true
	t.timeout.connect(_end_hit_stop)


func _end_hit_stop() -> void:
	Engine.time_scale = 1.0
	_hitstop_active = false


func add_gold(amount: int = 1) -> void:
	total_gold += maxi(1, int(round(amount * gold_mult)))   # 메타 '탐욕' 배수
	gold_changed.emit(total_gold)


func spend_gold(amount: int) -> bool:
	if total_gold < amount:
		return false
	total_gold -= amount
	gold_changed.emit(total_gold)
	return true


func update_player_health(health: int, max_health: int) -> void:
	player_health = health
	player_max_health = max_health
	player_health_changed.emit(health, max_health)


## 좀비 처치 등으로 점수 획득(난이도 배수 적용). 최고점 초과 시 즉시(실시간) 최고점도 갱신.
func add_score(amount: int) -> void:
	score += maxi(1, int(round(amount * diff_score_mult())))
	score_changed.emit(score)
	if score > high_score:
		high_score = score
		high_score_changed.emit(high_score)


## 디스크에서 불러온 최고점을 주입(시작 시 SaveManager 가 호출).
func set_high_score(value: int) -> void:
	high_score = value
	_prev_high = value
	high_score_changed.emit(high_score)


## 이번 판이 기존 최고점을 새로 갱신했는지(신기록 여부).
func is_new_record() -> bool:
	return score > _prev_high and score > 0


func reset() -> void:
	total_gold = 0
	total_kills = 0
	player_health = 0
	player_max_health = 0
	current_wave = 1
	elapsed_time = 0.0
	wave_kill_progress = 0
	wave_kill_total = 0
	gold_magnet_active = false
	score = 0
	_prev_high = high_score   # 이번 판이 깨야 할 기준점 = 현재 최고점 (high_score 는 유지)
	xp = 0
	level = 1
	xp_to_next = 12
	upgrade_speed = 0
	upgrade_atk_speed = 0
	upgrade_bullet_damage = 0
	upgrade_orb_damage = 0
	upgrade_orb_speed = 0
	upgrade_lightning_damage = 0
	upgrade_max_health = 0
	upgrade_multi_bullet = 0
	upgrade_orbs = 0
	upgrade_lightning = 0
	upgrade_lightning_count = 0
	upgrade_pickup_range = 0
	upgrade_regen = 0
	upgrade_crit = 0
	upgrade_garlic = 0
	upgrade_holy = 0
	weapons = {"gun": 1}         # 시작 무기(자동총 Lv1)만 보유
	passives = {}
	MetaManager.apply_run_start()         # 영구 강화 배수(골드/경험치) 설정
	ItemDB.recompute(weapons, passives)   # 인벤토리 → upgrade_* 정합화(메타 시작 보정 포함)
	gold_changed.emit(total_gold)
	score_changed.emit(score)
	xp_changed.emit(xp, xp_to_next, level)
