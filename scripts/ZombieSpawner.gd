extends Node
## 좀비 스포너: 웨이브 개념 없이 연속으로 스폰하며, "경과 시간"이 난이도를 구동한다(스펙).
## 시간이 갈수록 스폰 간격↓·동시 출현↑·체력/이속↑·강한 종 비중↑. 모든 수치는
## DifficultyData(res://data/difficulty.tres)에서 조정한다(하드코딩 금지).
## 보스는 _diff.boss_seconds 마다, 엘리트 팩은 _diff.elite_seconds 마다 등장하며 아키타입을 순환한다.
## _diff.clear_seconds(기본 30분) 생존 시 CLEAR 를 1회 알리고, 이후에는 무한 하드모드로 계속된다.

const ZOMBIE := preload("res://scenes/Zombie.tscn")
const BOSS := preload("res://scenes/Boss.tscn")

@export var spawn_margin: float = 80.0

## 보스 아키타입 테이블. archetype 은 Boss.gd 의 행동 분기 키.
const BOSS_TYPES: Dictionary = {
	"brute":    {"archetype": "melee",    "name": "BRUTE",    "hp_mul": 1.00, "speed_mul": 1.00, "contact": 2, "tint": Color(0.55, 0.12, 0.14), "proj": Color(1, 1, 1)},
	"gunner":   {"archetype": "gunner",   "name": "GUNNER",   "hp_mul": 0.78, "speed_mul": 0.80, "contact": 1, "tint": Color(0.16, 0.34, 0.62), "proj": Color(0.55, 0.85, 1.0)},
	"summoner": {"archetype": "summoner", "name": "SUMMONER", "hp_mul": 0.92, "speed_mul": 0.55, "contact": 2, "tint": Color(0.24, 0.52, 0.28), "proj": Color(0.5, 1.0, 0.6)},
	"bomber":   {"archetype": "bomber",   "name": "BOMBER",   "hp_mul": 0.85, "speed_mul": 0.65, "contact": 1, "tint": Color(0.62, 0.40, 0.14), "proj": Color(1.0, 0.55, 0.15)},
	"berserk":  {"archetype": "berserk",  "name": "BERSERKER","hp_mul": 1.05, "speed_mul": 1.00, "contact": 3, "tint": Color(0.60, 0.14, 0.34), "proj": Color(1, 1, 1)},
}
const BOSS_SEQUENCE: Array = ["brute", "gunner", "summoner", "bomber", "berserk"]

## 테마 전용 보스(Phase 6-C). ThemeData.boss_key → 보스 정의. 기존 아키타입 행동을 재사용(Boss.gd 무변경)해
## 프레젠테이션(이름/색/스탯)만 테마화한다. 선택 테마에 boss_key 가 있으면 해당 아레나의 모든 보스로 쓰인다.
##   교외=변이 사냥개(광폭 근접), 도심=견인 변이체(폭파형 탱커), 연구소=프라임 변이체(소환형 다단계).
const THEME_BOSSES: Dictionary = {
	"mutant_dog": {"archetype": "berserk",  "name": "MUTANT HOUND",   "hp_mul": 0.85, "speed_mul": 1.35, "contact": 2, "tint": Color(0.58, 0.40, 0.24), "proj": Color(1, 1, 1)},
	"wrecker":    {"archetype": "bomber",   "name": "THE WRECKER",    "hp_mul": 1.30, "speed_mul": 0.70, "contact": 3, "tint": Color(0.40, 0.42, 0.48), "proj": Color(1.0, 0.55, 0.15)},
	"mutation":   {"archetype": "summoner", "name": "PRIME MUTATION", "hp_mul": 1.20, "speed_mul": 0.60, "contact": 2, "tint": Color(0.42, 0.85, 0.35), "proj": Color(0.5, 1.0, 0.6)},
}

## 서머너 소환 시 전장 과밀 상한.
const SUMMON_ALIVE_CAP: int = 44

## 스웜 이벤트: 주기적으로 한 무리가 한 방향에서 떼로 몰려온다(뱀서식 긴장 스파이크).
const SWARM_MIN_INTERVAL := 15.0
const SWARM_MAX_INTERVAL := 24.0
const SWARM_TELEGRAPH := 1.0
const SWARM_COUNT := 12
const SWARM_ELITE_CHANCE := 0.35
const SWARM_SPREAD := 70.0
const SWARM_ELITE_HP_MULT := 1.7
const SWARM_ELITE_SCALE := 1.35
const SWARM_START_SECONDS := 30.0   # 이 시각(초) 이후부터 랜덤 스웜 발동
var _swarm_cd: float = 0.0
var _swarm_tel: float = -1.0
var _swarm_elite: bool = false

## 좀비 조합 티어. 경과 시간(_diff.tier_seconds 마다 +1)으로 골라진다.
##   0 Walker  1 Sprinter  2 Bloater  3 Gaunt(weaver)  4 Foreman  5 Toxic
##   6 Screamer  7 Cop  8 Soldier(spitter)  9 Longneck(spitter)  10 Suit
const WEIGHTS: Array = [
	[10, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1],
	[8,  2, 0, 2, 1, 1, 1, 0, 0, 0, 2],
	[6,  3, 1, 2, 2, 2, 1, 1, 1, 1, 2],
	[5,  3, 1, 2, 2, 2, 2, 2, 1, 1, 2],
	[4,  3, 2, 2, 2, 2, 2, 2, 2, 2, 2],
	[3,  3, 2, 2, 3, 2, 2, 3, 2, 2, 3],
]

## 난이도 곡선 데이터(경과 시간 기반). GameData 에서 로드.
var _diff: DifficultyData = null

# 좀비 종류 = 데이터 에셋(res://data/zombies.tres). 순서가 WEIGHTS 인덱스와 정렬된다.
# _ready 에서 GameData 로부터 dict 배열로 변환해 채운다(다운스트림 코드 형태는 그대로 유지).
var ZOMBIE_TYPES: Array = []


func _build_types() -> void:
	ZOMBIE_TYPES.clear()
	for zd in GameData.zombie_list:
		ZOMBIE_TYPES.append({
			"speed": zd.speed, "max_health": zd.max_health, "modulate": zd.modulate,
			"score": zd.score, "scale": zd.scale, "contact": zd.contact,
			"behavior": zd.behavior, "texture": zd.texture,
		})

var player: Node2D = null
var _accum: float = 0.0
var _elapsed: float = 0.0
var _last_second: int = -1
var _game_over: bool = false
## 살아있는 일반 좀비 수(스폰 +1 / 처치 -1 로 직접 추적, get_nodes_in_group O(n) 스캔 회피). 보스 별도.
var _alive_zombies: int = 0
var _start_delay: float = 5.0   # 초반 유예(플레이어 무적 시간과 정렬)

# 보스 상태
var _boss_alive: bool = false
var _boss_count: int = 0        # 지금까지 등장한 보스 수(아키타입 순환·강화에 사용)
var _next_boss_at: float = 0.0  # 이 경과 시각(초)에 도달하면 보스 등장
var _next_elite_at: float = 0.0 # 이 경과 시각(초)에 도달하면 엘리트 팩 등장
var _cleared: bool = false      # 30분 생존 클리어를 이미 알렸는가(1회)
var _escort_accum: float = 0.0


func _ready() -> void:
	_build_types()   # 데이터 에셋(GameData)에서 좀비 종류 테이블 구성
	_diff = GameData.difficulty
	player = get_tree().get_first_node_in_group("player")
	Events.player_died.connect(func(): _game_over = true)
	Events.player_revived.connect(func(): _game_over = false)
	Events.zombie_killed.connect(_on_zombie_killed)
	Events.boss_died.connect(_on_boss_died)
	Events.boss_summon.connect(_on_boss_summon)
	_elapsed = Events.elapsed_time
	# 이어하기 대비: 경과 시간 기준으로 다음 보스·엘리트 시점, 보스 회차, 클리어 여부를 정렬한다.
	_boss_count = int(_elapsed / _diff.boss_seconds)
	_next_boss_at = float(_boss_count + 1) * _diff.boss_seconds
	_next_elite_at = (floor(_elapsed / _diff.elite_seconds) + 1.0) * _diff.elite_seconds
	_cleared = Events.did_clear
	_swarm_cd = randf_range(SWARM_MIN_INTERVAL, SWARM_MAX_INTERVAL)
	Events.wave_changed.emit(Events.total_kills)                 # HUD 킬 카운트 초기화
	Events.run_progress.emit(_elapsed, _diff.clear_seconds)      # HUD 클리어 진행바 초기화


# ── 난이도 곡선(경과 시간 기준) ──────────────────────────────────────
func _tier() -> int:
	return clampi(int(_elapsed / _diff.tier_seconds), 0, WEIGHTS.size() - 1)

func _spawn_interval() -> float:
	var t := clampf(_elapsed / _diff.spawn_interval_full_at, 0.0, 1.0)
	return lerpf(_diff.spawn_interval_base, _diff.spawn_interval_min, t)

func _max_z() -> int:
	var t := clampf(_elapsed / _diff.max_z_full_at, 0.0, 1.0)
	return int(round(lerpf(float(_diff.max_z_base), float(_diff.max_z_cap), t)))

func _hp_mult() -> float:
	var m := 1.0 + (_elapsed / 60.0) * _diff.hp_per_min
	if _elapsed > _diff.clear_seconds:   # 클리어 이후 무한 하드모드 — 분당 추가 체력
		m += ((_elapsed - _diff.clear_seconds) / 60.0) * _diff.overtime_hp_per_min
	return m * Events.diff_enemy_hp_mult()

func _speed_mult() -> float:
	return minf(_diff.speed_cap, 1.0 + (_elapsed / 60.0) * _diff.speed_per_min) * Events.diff_enemy_speed_mult()


func _process(delta: float) -> void:
	if _game_over:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	_elapsed += delta
	_tick_elapsed()

	# 30분 생존 = 클리어(1회 알림). 승리 조건은 아니며, 이후 무한 하드모드로 계속된다.
	if not _cleared and _elapsed >= _diff.clear_seconds:
		_cleared = true
		Events.did_clear = true
		Events.run_cleared.emit()

	if _start_delay > 0.0:
		_start_delay -= delta
		return

	# 연속 스폰 — 간격과 동시 출현 상한은 경과 시간에 따라 계속 강화된다.
	_accum += delta
	if _accum >= _spawn_interval():
		if _alive_zombies < _max_z():
			_accum = 0.0
			_spawn_one(_pick_type(WEIGHTS[_tier()]))

	# 보스 마일스톤 — _diff.boss_seconds 마다 1마리(동시 1마리).
	if not _boss_alive and _elapsed >= _next_boss_at:
		_next_boss_at += _diff.boss_seconds
		_spawn_boss()

	# 엘리트 팩 — _diff.elite_seconds 마다 강제 엘리트 스웜(보스전 중엔 미룬다).
	if _elapsed >= _next_elite_at:
		_next_elite_at += _diff.elite_seconds
		if not _boss_alive and _swarm_tel <= 0.0:
			_trigger_swarm(true)
			Events.elite_pack.emit()   # 진화 보물상자 드롭 트리거

	# 보스 전투 중 호위 좀비 가벼운 보충.
	if _boss_alive:
		_escort_accum += delta
		if _escort_accum >= 1.6:
			_escort_accum = 0.0
			if _alive_zombies < _max_z():
				_spawn_one(_pick_type(WEIGHTS[_tier()]))

	_tick_swarm(delta)


func _tick_elapsed() -> void:
	var sec := int(_elapsed)
	if sec != _last_second:
		_last_second = sec
		Events.elapsed_time = _elapsed
		Events.elapsed_changed.emit(_elapsed)
		Events.run_progress.emit(_elapsed, _diff.clear_seconds)   # HUD 클리어 진행바(초당 1회)


func _on_zombie_killed() -> void:
	_alive_zombies = maxi(0, _alive_zombies - 1)
	Events.total_kills += 1
	Events.wave_changed.emit(Events.total_kills)   # HUD 킬 카운트


## 좀비 1마리 스폰. 체력/이속은 총 처치 수 기반 난이도 배수로 강화한다.
func _spawn_one(type_data: Dictionary) -> void:
	if not is_instance_valid(player):
		return
	var z := Pool.acquire(ZOMBIE, get_tree().current_scene)
	z.global_position = _random_spawn_pos()
	var d := type_data.duplicate()
	d["max_health"] = maxi(1, int(round(float(type_data["max_health"]) * _hp_mult())))
	d["speed"] = float(type_data["speed"]) * _speed_mult()
	z.setup(d)
	_alive_zombies += 1


## 스웜 이벤트 틱: 경고(swarm_incoming) → SWARM_TELEGRAPH 후 클러스터 등장. 보스 전투 중엔 발동 안 함.
func _tick_swarm(delta: float) -> void:
	if _swarm_tel > 0.0:   # 텔레그래프 진행 중이면 카운트다운 후 스폰(예약 엘리트 포함)
		_swarm_tel -= delta
		if _swarm_tel <= 0.0:
			_spawn_swarm()
		return
	if _boss_alive or _elapsed < SWARM_START_SECONDS:
		return
	_swarm_cd -= delta
	if _swarm_cd <= 0.0 and _alive_zombies < _max_z():
		_trigger_swarm(randf() < SWARM_ELITE_CHANCE)


## 스웜 예약: 경고를 띄우고 텔레그래프를 시작한다. 랜덤/엘리트 팩 공통 진입점.
func _trigger_swarm(elite: bool) -> void:
	_swarm_cd = randf_range(SWARM_MIN_INTERVAL, SWARM_MAX_INTERVAL)
	_swarm_elite = elite
	_swarm_tel = SWARM_TELEGRAPH
	Events.swarm_incoming.emit(_swarm_elite)


## 한 방향에서 한 종을 떼로 스폰. 엘리트면 더 크고 강하며 보상도 크다.
func _spawn_swarm() -> void:
	if not is_instance_valid(player):
		return
	var base_type: Dictionary = _pick_type(WEIGHTS[_tier()])
	var center := _random_spawn_pos()
	for i in range(SWARM_COUNT):
		var z := Pool.acquire(ZOMBIE, get_tree().current_scene)
		z.global_position = center + Vector2(randf_range(-SWARM_SPREAD, SWARM_SPREAD), randf_range(-SWARM_SPREAD, SWARM_SPREAD))
		var d := base_type.duplicate()
		var hp_mult := _hp_mult()
		if _swarm_elite:
			hp_mult *= SWARM_ELITE_HP_MULT
			d["scale"] = float(base_type.get("scale", 1.0)) * SWARM_ELITE_SCALE
			d["score"] = int(base_type.get("score", 10)) * 3
			d["contact"] = int(base_type.get("contact", 1)) + 1
		d["max_health"] = maxi(1, int(round(float(base_type["max_health"]) * hp_mult)))
		d["speed"] = float(base_type["speed"]) * _speed_mult()
		z.setup(d)
		_alive_zombies += 1
	Events.shake(4.0)


## 선택 테마의 전용 보스 정의(없으면 빈 dict).
func _theme_boss() -> Dictionary:
	var t: ThemeData = ThemeManager.selected()
	if t != null and THEME_BOSSES.has(t.boss_key):
		return THEME_BOSSES[t.boss_key]
	return {}


## 보스 소환 + 호위 정예 좀비. 경과 시간·회차에 따라 강화. 테마 보스 우선. 승리 조건 없음(엔들리스).
func _spawn_boss() -> void:
	if not is_instance_valid(player):
		return
	_boss_alive = true
	_boss_count += 1

	# 선택 테마에 전용 보스가 있으면 그 아레나의 보스로 사용, 없으면 기존 아키타입 순환.
	var bt: Dictionary = _theme_boss()
	if bt.is_empty():
		bt = BOSS_TYPES[BOSS_SEQUENCE[(_boss_count - 1) % BOSS_SEQUENCE.size()]]
	var boss := BOSS.instantiate()
	get_tree().current_scene.add_child(boss)
	boss.global_position = _random_spawn_pos()
	var time_scale := 1.0 + (_elapsed / 60.0) * 0.03   # 분당 +3% 체력(경과 시간 강화)
	var boss_hp := int(round(float(90 + 70 * (_boss_count - 1)) * Events.diff_boss_hp_mult() * time_scale * float(bt["hp_mul"])))
	var stats := {
		"max_health": boss_hp,
		"speed": (104.0 + 9.0 * _boss_count) * Events.diff_enemy_speed_mult() * float(bt["speed_mul"]),
		"contact_damage": int(bt["contact"]),
		"score": 200 * _boss_count,
		"gold": 12 + 4 * _boss_count,
		"archetype": bt["archetype"],
		"tint": bt["tint"],
		"proj_color": bt["proj"],
		"name": bt["name"],
	}
	boss.setup(stats)

	# 호위 정예 좀비 — 빠른(스프린터)/탱커(공사장) 혼합.
	var escorts := 3 + _boss_count
	for i in range(escorts):
		_spawn_one(ZOMBIE_TYPES[1] if i % 2 == 0 else ZOMBIE_TYPES[4])


## 서머너 보스의 소환 요청 처리 — 스포너가 직접 스폰해 살아있는 좀비 카운터를 일관 유지.
func _on_boss_summon(count: int) -> void:
	if not _boss_alive or _game_over:
		return
	var room := maxi(0, SUMMON_ALIVE_CAP - _alive_zombies)
	var n := mini(count, room)
	for i in range(n):
		_spawn_one(ZOMBIE_TYPES[3] if i % 2 == 0 else ZOMBIE_TYPES[1])


func _on_boss_died() -> void:
	_boss_alive = false   # 엔들리스 — 승리 없이 계속 진행, 다음 마일스톤에 새 보스.


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


# ── 몬스터 분리(anti-overlap) ─────────────────────────────────────────
# 좀비끼리 물리 충돌(move_and_slide)은 O(n²)라 쓰지 않고, 공간 해시 그리드로 근접 이웃만
# 훑어 살짝 밀어내 겹쳐 쌓이는 것을 막는다. 이웃 검사 수를 상한 처리해 대량에서도 O(n·k).
const SEP_RADIUS := 26.0
const SEP_CELL := 26.0
const SEP_STRENGTH := 0.30
const SEP_MAX_PUSH := 5.0
const SEP_MAX_NEIGHBORS := 6


func _physics_process(_delta: float) -> void:
	if _game_over:
		return
	var zs := get_tree().get_nodes_in_group("zombies")
	if zs.size() < 2:
		return
	var grid: Dictionary = {}
	var pts: Array = []
	for z in zs:
		if not is_instance_valid(z) or z.is_in_group("boss"):
			continue
		var p: Vector2 = z.global_position
		var key := Vector2i(int(floor(p.x / SEP_CELL)), int(floor(p.y / SEP_CELL)))
		if not grid.has(key):
			grid[key] = []
		grid[key].append(pts.size())
		pts.append([z, p])
	for i in pts.size():
		var p: Vector2 = pts[i][1]
		var cx := int(floor(p.x / SEP_CELL))
		var cy := int(floor(p.y / SEP_CELL))
		var push := Vector2.ZERO
		var checked := 0
		for ox in range(-1, 2):
			for oy in range(-1, 2):
				var key := Vector2i(cx + ox, cy + oy)
				if not grid.has(key):
					continue
				for j in grid[key]:
					if j == i:
						continue
					var d: Vector2 = p - pts[j][1]
					var dl := d.length()
					if dl > 0.001 and dl < SEP_RADIUS:
						push += (d / dl) * (SEP_RADIUS - dl)
						checked += 1
						if checked >= SEP_MAX_NEIGHBORS:
							break
				if checked >= SEP_MAX_NEIGHBORS:
					break
			if checked >= SEP_MAX_NEIGHBORS:
				break
		if push != Vector2.ZERO:
			pts[i][0].global_position += (push * SEP_STRENGTH).limit_length(SEP_MAX_PUSH)
