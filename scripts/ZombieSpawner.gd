extends Node
## 좀비 스포너: 킬카운트 기반 웨이브. 웨이브 총 킬수 달성 시 wave_complete 신호 발생.
## BOSS_EVERY 웨이브마다 보스 웨이브 — 킬 목표 달성 후 보스+호위 좀비가 등장하고
## 보스를 처치해야 웨이브가 완료된다.

const ZOMBIE := preload("res://scenes/Zombie.tscn")
const BOSS := preload("res://scenes/Boss.tscn")

@export var spawn_margin: float = 80.0

## 몇 웨이브마다 보스가 등장하는지 (5, 10, 15, ...)
const BOSS_EVERY: int = 5

## 보스 아키타입 테이블. archetype 은 Boss.gd 의 행동 분기 키.
##   hp_mul/speed_mul — 타입별 균형(원거리 거너는 안전하므로 HP·이속 낮춤).
##   tint — 보스 몸체 색(타입 구분). proj — 발사체 색. name — HUD 라벨.
const BOSS_TYPES: Dictionary = {
	"brute":    {"archetype": "melee",    "name": "BRUTE",    "hp_mul": 1.00, "speed_mul": 1.00, "contact": 2, "tint": Color(0.55, 0.12, 0.14), "proj": Color(1, 1, 1)},
	"gunner":   {"archetype": "gunner",   "name": "GUNNER",   "hp_mul": 0.78, "speed_mul": 0.80, "contact": 1, "tint": Color(0.16, 0.34, 0.62), "proj": Color(0.55, 0.85, 1.0)},
	"summoner": {"archetype": "summoner", "name": "SUMMONER", "hp_mul": 0.92, "speed_mul": 0.55, "contact": 2, "tint": Color(0.24, 0.52, 0.28), "proj": Color(0.5, 1.0, 0.6)},
	"bomber":   {"archetype": "bomber",   "name": "BOMBER",   "hp_mul": 0.85, "speed_mul": 0.65, "contact": 1, "tint": Color(0.62, 0.40, 0.14), "proj": Color(1.0, 0.55, 0.15)},
	"berserk":  {"archetype": "berserk",  "name": "BERSERKER","hp_mul": 1.05, "speed_mul": 1.00, "contact": 3, "tint": Color(0.60, 0.14, 0.34), "proj": Color(1, 1, 1)},
}
## 등장 순서 풀 — 5종 전 아키타입(회차별로 순환).
const BOSS_SEQUENCE: Array = ["brute", "gunner", "summoner", "bomber", "berserk"]

## 서머너 소환 시 전장 과밀 상한 — 이 수를 넘겨 살아있으면 소환을 억제한다(성능·공정성).
const SUMMON_ALIVE_CAP: int = 44

## 스웜 이벤트: 웨이브 도중 한 무리가 한 방향에서 떼로 몰려온다(뱀서식 긴장 스파이크).
## 텔레그래프(경고) 후 클러스터로 스폰. 일부는 엘리트 팩(더 크고 강하고 보상 큼).
const SWARM_MIN_INTERVAL := 15.0
const SWARM_MAX_INTERVAL := 24.0
const SWARM_TELEGRAPH := 1.0        # 경고 배너~실제 등장까지 여유(대비 시간)
const SWARM_COUNT := 12             # 한 번에 몰려오는 수
const SWARM_ELITE_CHANCE := 0.35    # 엘리트 팩 확률
const SWARM_SPREAD := 70.0          # 클러스터 산개 반경
const SWARM_ELITE_HP_MULT := 1.7
const SWARM_ELITE_SCALE := 1.35
var _swarm_cd: float = 0.0
var _swarm_tel: float = -1.0        # >0 이면 경고 후 등장 대기 중
var _swarm_elite: bool = false

## 웨이브 테이블: total=이 웨이브에서 처치해야 할 총 좀비 수, max_z=최대 동시 출현 수.
## weights 의 인덱스는 ZOMBIE_TYPES 와 1:1 대응 — 후반 웨이브일수록 강한 종을 더 많이 섞는다.
## 1~2웨이브는 짧게(권총만 있는 초반이 늘어지지 않게), 6웨이브 이후에는 테이블이 고정되는 대신
## Events.wave_pressure_mult() 가 적 체력을 복리로 올려 무한히 어려워진다.
## max_z 상향: 좀비끼리 물리 충돌쌍 제거(collision_mask=0) 후 동시 개체 여유가 생겨,
## 화면을 더 빽빽하게 채워 "물량 압박" 긴장감을 준다(뱀서식 스웜). 값은 밸런스 손잡이.
const WAVES: Array = [
	{"total": 60,  "max_z": 42,  "interval": 0.9,  "weights": [10, 0, 0, 0, 0, 0, 0, 0, 0]},
	{"total": 100, "max_z": 64,  "interval": 0.70, "weights": [8,  2, 0, 2, 0, 0, 1, 0, 0]},
	{"total": 180, "max_z": 88,  "interval": 0.55, "weights": [6,  3, 1, 3, 1, 0, 2, 1, 1]},
	{"total": 240, "max_z": 112, "interval": 0.45, "weights": [5,  3, 2, 3, 2, 1, 2, 2, 2]},
	{"total": 320, "max_z": 140, "interval": 0.35, "weights": [4,  4, 2, 3, 3, 1, 2, 2, 2]},
	{"total": 400, "max_z": 170, "interval": 0.25, "weights": [3,  4, 3, 3, 3, 2, 3, 3, 3]},
]

## 좀비 종류 테이블. 0~5 는 근접 추격형, 6~8 은 고유 행동 패턴(behavior: weaver/spitter/bomber).
## 각 종은 Kenney Top-down Shooter 팩의 캐릭터 스프라이트(texture)로 시각 구분되며,
## modulate 는 사망 폭발 FX·투사체·피격 잔광 색으로 쓰인다(행동 타입은 전용 스프라이트가 없어
## 기존 스프라이트를 재활용하되 behavior·FX색으로 구분).
##   0 Walker  1 Runner  2 Brute  3 Swarmling  4 Charger  5 Juggernaut
##   6 Weaver(지그재그)  7 Spitter(원거리)  8 Bomber(자폭)
const ZOMBIE_TYPES: Array = [
	{"speed": 65,  "max_health": 3,  "modulate": Color(0.70, 0.95, 0.55), "score": 10, "scale": 1.00, "contact": 1, "texture": preload("res://assets/sprites/zombie_walker.png")},
	{"speed": 130, "max_health": 1,  "modulate": Color(0.85, 0.85, 0.95), "score": 15, "scale": 0.90, "contact": 1, "texture": preload("res://assets/sprites/zombie_runner.png")},
	{"speed": 40,  "max_health": 8,  "modulate": Color(0.95, 0.70, 0.45), "score": 30, "scale": 1.25, "contact": 1, "texture": preload("res://assets/sprites/zombie_brute.png")},
	{"speed": 95,  "max_health": 1,  "modulate": Color(1.00, 0.85, 0.70), "score": 8,  "scale": 0.70, "contact": 1, "texture": preload("res://assets/sprites/zombie_swarmling.png")},
	{"speed": 108, "max_health": 5,  "modulate": Color(0.90, 0.80, 0.55), "score": 25, "scale": 1.05, "contact": 2, "texture": preload("res://assets/sprites/zombie_charger.png")},
	{"speed": 32,  "max_health": 16, "modulate": Color(1.00, 0.65, 0.35), "score": 60, "scale": 1.45, "contact": 2, "texture": preload("res://assets/sprites/zombie_juggernaut.png")},
	{"speed": 80,  "max_health": 3,  "modulate": Color(0.40, 0.95, 0.95), "score": 18, "scale": 0.95, "contact": 1, "behavior": "weaver",  "texture": preload("res://assets/sprites/zombie_runner.png")},
	{"speed": 55,  "max_health": 3,  "modulate": Color(0.95, 0.45, 0.95), "score": 35, "scale": 0.90, "contact": 1, "behavior": "spitter", "texture": preload("res://assets/sprites/zombie_spitter.png")},
	{"speed": 90,  "max_health": 2,  "modulate": Color(1.00, 0.50, 0.20), "score": 30, "scale": 1.10, "contact": 2, "behavior": "bomber",  "texture": preload("res://assets/sprites/zombie_swarmling.png")},
]

var player: Node2D = null
var _accum: float = 0.0
var _elapsed: float = 0.0
var _last_second: int = -1
var _wave_idx: int = 0     # 설정 테이블 인덱스 (최대 WAVES.size()-1 로 고정)
var _wave_num: int = 1     # 표시용 웨이브 번호 (계속 증가)
var _spawned: int = 0      # 현재 웨이브에서 스폰한 수
var _killed: int = 0       # 현재 웨이브에서 처치한 수
var _wave_active: bool = false
var _wave_total: int = 0   # 이번 웨이브의 실효 킬 목표(난이도 배수 적용)
var _game_over: bool = false
## 살아있는 일반 좀비 수. 매 프레임 get_nodes_in_group() O(n) 스캔을 피하려고
## 스폰 시 +1 / 처치 시 -1 로 직접 추적한다(대량 좀비 환경 최적화). 보스는 별도.
var _alive_zombies: int = 0
var _start_delay: float = 5.0   # first-wave spawn delay matches player grace period

# 보스 웨이브 상태
var _is_boss_wave: bool = false
var _boss_spawned: bool = false   # 이번 보스 웨이브에서 보스를 이미 소환했는가
var _boss_alive: bool = false     # 소환된 보스가 아직 살아있는가
var _escort_accum: float = 0.0    # 보스 전투 중 호위 좀비 트리클 타이머


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	Events.player_died.connect(func(): _game_over = true)
	Events.player_revived.connect(func(): _game_over = false)   # 부활 시 스폰/웨이브 진행 재개
	Events.zombie_killed.connect(_on_zombie_killed)
	Events.boss_died.connect(_on_boss_died)
	Events.boss_summon.connect(_on_boss_summon)
	Events.shop_closed.connect(_start_wave)
	# 이어하기 시 저장된 웨이브/경과시간부터 재개 (새 게임은 Events.reset() 직후라 1 / 0.0).
	_elapsed = Events.elapsed_time
	_wave_num = Events.current_wave
	_wave_idx = mini(_wave_num - 1, WAVES.size() - 1)
	_start_wave()


func _start_wave() -> void:
	_spawned = 0
	_killed = 0
	_accum = 0.0
	_wave_active = true
	_is_boss_wave = (_wave_num % BOSS_EVERY == 0)
	_boss_spawned = false
	_boss_alive = false
	_escort_accum = 0.0
	_swarm_cd = randf_range(SWARM_MIN_INTERVAL, SWARM_MAX_INTERVAL)
	_swarm_tel = -1.0
	# Easy 는 킬 목표를 줄여 웨이브가 늘어지지 않게 한다(스폰도 느려 총 시간이 길어지던 문제).
	_wave_total = maxi(1, int(round(float(WAVES[_wave_idx]["total"]) * Events.diff_total_mult())))
	Events.current_wave = _wave_num
	Events.wave_kill_progress = 0
	Events.wave_kill_total = _wave_total
	Events.wave_changed.emit(_wave_num)
	Events.wave_progress_changed.emit(0, _wave_total)


func _process(delta: float) -> void:
	if _game_over:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	_elapsed += delta
	_tick_elapsed()

	if not _wave_active:
		return

	var wave: Dictionary = WAVES[_wave_idx]

	# 아직 스폰할 좀비가 남아있으면 스폰 시도
	if _spawned < _wave_total:
		if _start_delay > 0.0:
			_start_delay -= delta
		else:
			_accum += delta
			if _accum >= wave["interval"] * Events.diff_spawn_mult():
				if _alive_zombies < wave["max_z"]:
					_accum = 0.0
					_try_spawn()

	# 보스 전투 중에는 호위 좀비를 가볍게 계속 보충
	if _boss_alive:
		_escort_accum += delta
		if _escort_accum >= 1.6:
			_escort_accum = 0.0
			if _alive_zombies < wave["max_z"]:
				_spawn_one(_pick_type(wave["weights"]))

	# 스웜 이벤트(비-보스 웨이브, 2웨이브부터) — 주기적으로 한 무리가 떼로 몰려온다.
	_tick_swarm(delta, wave)

	# 웨이브 완료 판정
	if _killed >= _wave_total:
		if _is_boss_wave:
			# 킬 목표 달성 → 보스 소환 (1회). 보스를 잡아야 완료.
			if not _boss_spawned:
				_spawn_boss()
			elif not _boss_alive:
				_wave_complete()
		else:
			_wave_complete()


func _tick_elapsed() -> void:
	var sec := int(_elapsed)
	if sec != _last_second:
		_last_second = sec
		Events.elapsed_time = _elapsed
		Events.elapsed_changed.emit(_elapsed)


func _on_zombie_killed() -> void:
	# 살아있는 좀비 카운터는 웨이브 상태와 무관하게 항상 감소시켜야 한다.
	_alive_zombies = maxi(0, _alive_zombies - 1)
	if not _wave_active:
		return
	_killed += 1
	Events.total_kills += 1
	# 보스 웨이브의 호위 좀비 처치로 목표 초과 표시되지 않도록 진행도는 목표치로 클램프
	Events.wave_kill_progress = mini(_killed, _wave_total)
	Events.wave_progress_changed.emit(mini(_killed, _wave_total), _wave_total)


func _wave_complete() -> void:
	_wave_active = false
	Events.wave_complete.emit(_wave_num)
	_wave_num += 1
	_wave_idx = mini(_wave_idx + 1, WAVES.size() - 1)


func _try_spawn() -> void:
	if not is_instance_valid(player):
		return
	var wave: Dictionary = WAVES[_wave_idx]
	_spawn_one(_pick_type(wave["weights"]))
	_spawned += 1


## 좀비 1마리 스폰 (스폰 카운트와 무관 — 호위 좀비 보충에도 재사용).
func _spawn_one(type_data: Dictionary) -> void:
	if not is_instance_valid(player):
		return
	var z := Pool.acquire(ZOMBIE, get_tree().current_scene)
	z.global_position = _random_spawn_pos()
	# 난이도 배수 + 6웨이브 이후 복리 압박 배수 적용 (원본 상수 테이블은 복제본으로 보호).
	var d := type_data.duplicate()
	var hp_mult := Events.diff_enemy_hp_mult() * Events.wave_pressure_mult(_wave_num)
	d["max_health"] = maxi(1, int(round(float(type_data["max_health"]) * hp_mult)))
	d["speed"] = float(type_data["speed"]) * Events.diff_enemy_speed_mult() * Events.wave_speed_pressure(_wave_num)
	z.setup(d)
	_alive_zombies += 1


## 스웜 이벤트 틱: 경고(swarm_incoming) → SWARM_TELEGRAPH 후 클러스터 등장.
## 보스 웨이브·1웨이브에서는 발동하지 않고, 막판(킬 목표 85% 도달)엔 새 무리를 부르지 않는다.
func _tick_swarm(delta: float, wave: Dictionary) -> void:
	if _is_boss_wave or _wave_num < 2:
		return
	if _swarm_tel > 0.0:
		_swarm_tel -= delta
		if _swarm_tel <= 0.0:
			_spawn_swarm(wave)
		return
	if _killed >= int(_wave_total * 0.85):
		return
	_swarm_cd -= delta
	if _swarm_cd <= 0.0 and _alive_zombies < wave["max_z"]:
		_swarm_cd = randf_range(SWARM_MIN_INTERVAL, SWARM_MAX_INTERVAL)
		_swarm_elite = randf() < SWARM_ELITE_CHANCE
		_swarm_tel = SWARM_TELEGRAPH
		Events.swarm_incoming.emit(_swarm_elite)


## 한 방향(off-screen 한 지점 근처)에서 한 종을 떼로 스폰. 엘리트면 더 크고 강하며 보상도 크다.
func _spawn_swarm(wave: Dictionary) -> void:
	if not is_instance_valid(player):
		return
	var base_type: Dictionary = _pick_type(wave["weights"])
	var center := _random_spawn_pos()
	var hp_pressure := Events.wave_pressure_mult(_wave_num)
	for i in range(SWARM_COUNT):
		var z := Pool.acquire(ZOMBIE, get_tree().current_scene)
		z.global_position = center + Vector2(randf_range(-SWARM_SPREAD, SWARM_SPREAD), randf_range(-SWARM_SPREAD, SWARM_SPREAD))
		var d := base_type.duplicate()
		var hp_mult := Events.diff_enemy_hp_mult() * hp_pressure
		if _swarm_elite:
			hp_mult *= SWARM_ELITE_HP_MULT
			d["scale"] = float(base_type.get("scale", 1.0)) * SWARM_ELITE_SCALE
			d["score"] = int(base_type.get("score", 10)) * 3
			d["contact"] = int(base_type.get("contact", 1)) + 1
		d["max_health"] = maxi(1, int(round(float(base_type["max_health"]) * hp_mult)))
		d["speed"] = float(base_type["speed"]) * Events.diff_enemy_speed_mult() * Events.wave_speed_pressure(_wave_num)
		z.setup(d)
		_alive_zombies += 1
	Events.shake(4.0)   # 무리 등장 진동


## 보스 소환 + 호위 정예 좀비. 보스 처치 시까지 웨이브 완료가 보류된다.
func _spawn_boss() -> void:
	if not is_instance_valid(player):
		return
	_boss_spawned = true
	_boss_alive = true
	var boss_count := _wave_num / BOSS_EVERY   # 1, 2, 3, ...

	# 회차별로 아키타입을 순환 — 1차 브루트, 2차 거너, 이후 반복(구현되면 풀 확장).
	var bt: Dictionary = BOSS_TYPES[BOSS_SEQUENCE[(boss_count - 1) % BOSS_SEQUENCE.size()]]

	var boss := BOSS.instantiate()
	get_tree().current_scene.add_child(boss)
	boss.global_position = _random_spawn_pos()
	# 보스는 플레이어(이속 220)를 압박할 수 있도록 일반 좀비보다 빠르게 — 회차/난이도/타입에 따라 가속.
	var boss_hp := int(round(float(80 + 60 * (boss_count - 1)) * Events.diff_boss_hp_mult() \
		* Events.wave_pressure_mult(_wave_num) * float(bt["hp_mul"])))
	boss.setup({
		"max_health": boss_hp,
		"speed": (104.0 + 9.0 * boss_count) * Events.diff_enemy_speed_mult() * float(bt["speed_mul"]),
		"contact_damage": int(bt["contact"]) + (1 if Events.difficulty == 2 else 0),
		"score": 200 * boss_count,
		"gold": 12 + 4 * boss_count,
		"archetype": bt["archetype"],
		"tint": bt["tint"],
		"proj_color": bt["proj"],
		"name": bt["name"],
	})

	# 호위 정예 좀비 — 빠른/탱커 혼합 (보스 회차가 높을수록 더 많이)
	var escorts := 3 + boss_count
	for i in range(escorts):
		_spawn_one(ZOMBIE_TYPES[1] if i % 2 == 0 else ZOMBIE_TYPES[2])


## 서머너 보스의 소환 요청 처리 — 스포너가 직접 스폰해 살아있는 좀비 카운터를 일관 유지.
## 과밀 시(SUMMON_ALIVE_CAP 초과) 억제. 빠르고 약한 종(스웜링/러너)을 섞어 압박만 준다.
func _on_boss_summon(count: int) -> void:
	if not _boss_alive or _game_over:
		return
	var room := maxi(0, SUMMON_ALIVE_CAP - _alive_zombies)
	var n := mini(count, room)
	for i in range(n):
		_spawn_one(ZOMBIE_TYPES[3] if i % 2 == 0 else ZOMBIE_TYPES[1])


func _on_boss_died() -> void:
	_boss_alive = false


func _pick_type(weights: Array) -> Dictionary:
	var total: int = 0
	for w in weights:
		total += w
	var roll := randi() % total
	var cum := 0
	for i in weights.size():
		cum += weights[i]
		if roll < cum:
			return ZOMBIE_TYPES[i]
	return ZOMBIE_TYPES[0]


func _random_spawn_pos() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	var radius := vp.length() * 0.5 + spawn_margin
	var angle := randf() * TAU
	return player.global_position + Vector2.from_angle(angle) * radius
