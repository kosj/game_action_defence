extends Node
## 전역 이벤트 버스 / 재화·체력·웨이브·업그레이드 관리 (Autoload 싱글톤: "Events")

## 게임 버전 — 타이틀/메뉴에 표시.
const VERSION := "v1.0.0"

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

# 필드 버프 상태
signal weapon_timer_changed(time_left: float, total: float)   # 임시 무기 남은 사용 시간
signal gold_magnet_changed(active: bool, time_left: float)    # 골드 자동 줍기(자석) 버프

var total_gold: int = 0
var total_kills: int = 0
var player_health: int = 0
var player_max_health: int = 0
var current_wave: int = 1
var elapsed_time: float = 0.0
var wave_kill_progress: int = 0
var wave_kill_total: int = 0

# 골드 자동 줍기(자석) 버프 활성 여부 — Gold 이 매 프레임 참조하는 일시 상태(저장 안 함).
var gold_magnet_active: bool = false

# 점수: score=이번 판 점수, high_score=저장된 최고점, _prev_high=이번 판 시작 시점 최고점(갱신 판정용)
var score: int = 0
var high_score: int = 0
var _prev_high: int = 0

# 난이도 (0=Easy, 1=Normal, 2=Hard) — 메인 메뉴에서 선택하며 디스크에 보존된다.
# Events.reset() 으로 초기화되지 않는다(판이 바뀌어도 유지되는 설정값).
var difficulty: int = 1
const DIFFICULTY_NAMES: Array = ["Easy", "Normal", "Hard"]
const _DIFF_ENEMY_HP: Array    = [0.70, 1.00, 1.55]   # 좀비 체력 배수(Hard 는 아래 램프 참고)
const _DIFF_ENEMY_SPEED: Array = [0.90, 1.00, 1.18]   # 좀비 이동속도 배수
const _DIFF_SPAWN_MULT: Array  = [1.15, 1.00, 0.78]   # 스폰 간격 배수(낮을수록 빠르게 몰림)
const _DIFF_BOSS_HP: Array     = [0.70, 1.00, 1.60]   # 보스 체력 배수
const _DIFF_TOTAL_MULT: Array  = [0.75, 1.00, 1.00]   # 웨이브 킬 목표 배수 — Easy 는 짧고 가볍게
const _DIFF_SCORE_MULT: Array  = [0.80, 1.00, 1.30]   # 점수 배수 — 위험(Hard)에 보상
# Hard 초반 완화 램프: 1웨이브 스파이크(권총 DPS 고정 구간) 방지를 위해
# 체력 배수를 1~5웨이브에 걸쳐 1.15 → 1.55 로 서서히 올린다.
const _HARD_HP_RAMP_START := 1.15

## 무한 스케일링: 테이블이 끝나는 6웨이브 이후 매 웨이브 +12% 체력(복리).
## 업그레이드가 만렙에 도달해도 언젠가는 반드시 한계가 오도록 하는 점수 러시 장치.
const _PRESSURE_PER_WAVE := 1.12
const _PRESSURE_SPEED_CAP := 1.30   # 이속은 최대 +30% 까지만(반응 불가능해지지 않게)


func diff_enemy_hp_mult() -> float:
	if difficulty == 2:
		var t := clampf(float(current_wave - 1) / 4.0, 0.0, 1.0)
		return lerpf(_HARD_HP_RAMP_START, _DIFF_ENEMY_HP[2], t)
	return _DIFF_ENEMY_HP[clampi(difficulty, 0, 2)]

func diff_enemy_speed_mult() -> float: return _DIFF_ENEMY_SPEED[clampi(difficulty, 0, 2)]
func diff_spawn_mult() -> float:       return _DIFF_SPAWN_MULT[clampi(difficulty, 0, 2)]
func diff_boss_hp_mult() -> float:     return _DIFF_BOSS_HP[clampi(difficulty, 0, 2)]
func diff_total_mult() -> float:       return _DIFF_TOTAL_MULT[clampi(difficulty, 0, 2)]
func diff_score_mult() -> float:       return _DIFF_SCORE_MULT[clampi(difficulty, 0, 2)]
func difficulty_name() -> String:      return DIFFICULTY_NAMES[clampi(difficulty, 0, 2)]


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
var upgrade_lightning_damage: int = 0
var upgrade_max_health: int = 0
var upgrade_multi_bullet: int = 0
var upgrade_orbs: int = 0
var upgrade_lightning: int = 0
var upgrade_lightning_count: int = 0   # 낙뢰 1회당 동시에 때리는 번개 가닥 수(+1 per level)


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


func add_gold(amount: int = 1) -> void:
	total_gold += amount
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
	upgrade_speed = 0
	upgrade_atk_speed = 0
	upgrade_bullet_damage = 0
	upgrade_orb_damage = 0
	upgrade_lightning_damage = 0
	upgrade_max_health = 0
	upgrade_multi_bullet = 0
	upgrade_orbs = 0
	upgrade_lightning = 0
	upgrade_lightning_count = 0
	gold_changed.emit(total_gold)
	score_changed.emit(score)
