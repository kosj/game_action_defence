extends Node
## 좀비 스포너: 웨이브 개념 없이 연속으로 스폰하며, "경과 시간"이 난이도를 구동한다(스펙).
## 시간이 갈수록 스폰 간격↓·동시 출현↑·체력/이속↑·강한 종 비중↑. 모든 수치는
## DifficultyData(res://data/difficulty.tres)에서 조정한다(하드코딩 금지).
## 보스는 _diff.boss_seconds 마다, 엘리트 팩은 _diff.elite_seconds 마다 등장하며 아키타입을 순환한다.
## _diff.clear_seconds(기본 30분) 생존 시 CLEAR 를 1회 알리고, 이후에는 무한 하드모드로 계속된다.

const ZOMBIE := preload("res://scenes/Zombie.tscn")
const BOSS := preload("res://scenes/Boss.tscn")
const _BossArena := preload("res://scripts/BossArena.gd")

@export var spawn_margin: float = 80.0

## 보스 정의는 **테마 보스 3종이 전부다**(P1-1, 2026-08).
## 예전에는 아키타입 5종 테이블(BOSS_TYPES)을 회차마다 순환시키는 경로가 따로 있었는데,
## 세 테마가 전부 boss_key 를 갖게 되면서 그 경로는 한 번도 실행되지 않았다 — 코드가 아니라
## 유지 대상만 늘리는 자산이었다. 보스를 늘리려면 아키타입을 되살리는 대신 여기에 테마를 추가한다.
##
## 테마 전용 보스(Phase 6-C). ThemeData.boss_key → 보스 정의. Boss.gd 의 아키타입 행동을 재사용해
## 프레젠테이션(이름/색/스탯)만 테마화한다. 선택 테마의 boss_key 가 해당 아레나의 모든 보스다.
##   교외=변이 사냥개(광폭 근접), 도심=견인 변이체(폭파형 탱커), 연구소=프라임 변이체(소환형 다단계).
## sprite: **필수**. 아키타입 기본 텍스처 폴백을 없앴으므로 비우면 보스가 투명해진다 —
## tools/verify_boss_arena.gd 가 세 항목의 sprite 존재를 CI 에서 검사한다. 사이드뷰·오른쪽 향함.
const THEME_BOSSES: Dictionary = {
	"mutant_dog": {"archetype": "berserk",  "name": "MUTANT HOUND",   "hp_mul": 0.85, "speed_mul": 1.35, "contact": 2, "tint": Color(0.58, 0.40, 0.24), "proj": Color(1, 1, 1),          "sprite": "res://assets/atlas/boss_mutant_dog.tres"},
	"wrecker":    {"archetype": "bomber",   "name": "THE WRECKER",    "hp_mul": 1.30, "speed_mul": 0.70, "contact": 3, "tint": Color(0.40, 0.42, 0.48), "proj": Color(1.0, 0.55, 0.15), "sprite": "res://assets/atlas/boss_wrecker.tres"},
	"mutation":   {"archetype": "summoner", "name": "PRIME MUTATION", "hp_mul": 1.20, "speed_mul": 0.60, "contact": 2, "tint": Color(0.42, 0.85, 0.35), "proj": Color(0.5, 1.0, 0.6),   "sprite": "res://assets/atlas/boss_mutation.tres"},
}

## 스웜 이벤트: 주기적으로 한 무리가 떼로 몰려온다(뱀서식 긴장 스파이크).
## 스웜/보스/스폰 예산 수치는 전부 밸런스 테이블(res://data/balance.tres)에서 조정한다.
var _swarm_cd: float = 0.0
var _swarm_tel: float = -1.0
var _swarm_elite: bool = false

## 밸런스 테이블 캐시(GameData.balance).
var _bal: BalanceData = null

## 스폰 큐: 대량 스폰(스웜/치트/호위)을 한 프레임에 다 만들지 않고 프레임당 예산만큼만
## 처리한다 — 수십~수백 인스턴스 동시 생성으로 인한 프레임 스파이크(웹에선 프리즈/크래시)를 없앤다.
var _spawn_queue: Array = []   # [{ "t": type_dict, "p": Vector2 }]

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
var _arena: Node2D = null       # 현재 보스전의 격리 구역(보스 처치 시 스스로 사라진다)
var _next_boss_at: float = 0.0  # 이 경과 시각(초)에 도달하면 보스 등장
var _next_elite_at: float = 0.0 # 이 경과 시각(초)에 도달하면 엘리트 팩 등장
var _cleared: bool = false      # 30분 생존 클리어를 이미 알렸는가(1회)
var _escort_accum: float = 0.0


func _ready() -> void:
	_build_types()   # 데이터 에셋(GameData)에서 좀비 종류 테이블 구성
	_diff = GameData.difficulty
	_bal = GameData.balance
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
	_swarm_cd = randf_range(_bal.swarm_interval_min, _bal.swarm_interval_max)
	Cheats.time_skip.connect(_on_time_skip)
	Cheats.spawn_fill.connect(_on_spawn_fill)
	Cheats.spawn_boss.connect(_on_spawn_boss_cheat)
	Events.wave_changed.emit(Events.total_kills)                 # HUD 킬 카운트 초기화
	Events.run_progress.emit(_elapsed, _diff.clear_seconds)      # HUD 클리어 진행바 초기화


## 치트: 경과 시간 점프 — 난이도 시계를 앞으로 당기고 보스/엘리트 예약 시각을 재정렬한다.
## 세 핸들러 모두 게이트를 한 번 더 본다(P0-1). Cheats.request_* 가 이미 막고 있지만, 신호를
## 직접 쏘는 우회 경로를 가정한 방어선이다 — 여기서 통과시키면 난이도 시계·보스 회차·킬 수가
## 그대로 점수와 랭킹에 들어간다.
func _on_time_skip(seconds: float) -> void:
	if not Cheats.enabled:
		return
	_elapsed += seconds
	Events.elapsed_time = _elapsed
	_boss_count = int(_elapsed / _diff.boss_seconds)
	_next_boss_at = float(_boss_count + 1) * _diff.boss_seconds
	_next_elite_at = (floor(_elapsed / _diff.elite_seconds) + 1.0) * _diff.elite_seconds
	Events.elapsed_changed.emit(_elapsed)
	Events.run_progress.emit(_elapsed, _diff.clear_seconds)


## 치트: 보스 즉시 등장. 마일스톤을 기다리지 않고 그 자리에서 다음 회차 보스를 부른다.
## 동시 1마리 규칙은 그대로라 이미 보스가 있으면 무시하고, 예약된 다음 마일스톤은 지금부터
## 다시 센다(치트로 부른 직후 정규 보스가 겹쳐 나오지 않게).
func _on_spawn_boss_cheat() -> void:
	if not Cheats.enabled:
		return
	if _boss_alive or _game_over or not is_instance_valid(player):
		return
	_next_boss_at = _elapsed + _diff.boss_seconds
	_spawn_boss()


## 치트: 좀비를 현재 동시 출현 상한(_max_z)까지 채운다 — 대량 전투/성능 확인용.
## 스폰 큐로 분산 생성되므로 수백 마리도 프레임 스파이크 없이 순차 등장한다.
func _on_spawn_fill() -> void:
	if not Cheats.enabled or not is_instance_valid(player):
		return
	var room := _max_z() - _effective_alive()
	for i in range(room):
		var d: Dictionary = _pick_type(WEIGHTS[_tier()]).duplicate()
		d["max_health"] = maxi(1, int(round(float(d["max_health"]) * _hp_mult())))
		d["speed"] = float(d["speed"]) * _speed_mult()
		_queue_spawn(d, _random_spawn_pos())
	if room > 0:
		Events.shake(4.0)


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
	var mins := _elapsed / 60.0
	# 선형 + 2차 가속 — 후반에 급격히 단단해져 플레이어의 곱연산 파워 성장을 따라잡는다.
	var m := 1.0 + mins * _diff.hp_per_min + mins * mins * _diff.hp_accel_per_min2
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
	_drain_spawn_queue()   # 대기 중인 대량 스폰을 프레임 예산만큼 처리

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
		if _effective_alive() < _max_z():
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
			if _effective_alive() < _max_z():
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


## 살아있는 좀비 + 스폰 대기열 — 상한 판정은 대기열까지 포함해야 큐가 쌓인 동안 초과 스폰이 없다.
func _effective_alive() -> int:
	return _alive_zombies + _spawn_queue.size()


## 대량 스폰 진입점 — 즉시 만들지 않고 큐에 넣는다(type_data 는 최종 스탯이 반영된 dict).
func _queue_spawn(type_data: Dictionary, pos: Vector2) -> void:
	_spawn_queue.append({"t": type_data, "p": pos})


## 스폰 큐 소화 — 프레임당 예산(_bal.spawn_budget_per_frame)만큼만 실제 인스턴스를 만든다.
func _drain_spawn_queue() -> void:
	var budget: int = _bal.spawn_budget_per_frame
	while budget > 0 and not _spawn_queue.is_empty():
		var req: Dictionary = _spawn_queue.pop_front()
		_spawn_at(req["t"], req["p"])
		budget -= 1


## 좀비 1마리를 지정 위치에 스폰(type_data 는 최종 스탯 dict).
func _spawn_at(type_data: Dictionary, pos: Vector2) -> void:
	if not is_instance_valid(player):
		return
	var z := Pool.acquire(ZOMBIE, get_tree().current_scene)
	z.global_position = pos
	z.setup(type_data)
	_alive_zombies += 1


## 좀비 1마리 즉시 스폰(연속 스폰·호위 등 소량용). 체력/이속은 난이도 배수로 강화한다.
func _spawn_one(type_data: Dictionary) -> void:
	if not is_instance_valid(player):
		return
	var d := type_data.duplicate()
	d["max_health"] = maxi(1, int(round(float(type_data["max_health"]) * _hp_mult())))
	d["speed"] = float(type_data["speed"]) * _speed_mult()
	_spawn_at(d, _random_spawn_pos())


## 스웜 이벤트 틱: 경고(swarm_incoming) → SWARM_TELEGRAPH 후 클러스터 등장. 보스 전투 중엔 발동 안 함.
func _tick_swarm(delta: float) -> void:
	if _swarm_tel > 0.0:   # 텔레그래프 진행 중이면 카운트다운 후 스폰(예약 엘리트 포함)
		_swarm_tel -= delta
		if _swarm_tel <= 0.0:
			_spawn_swarm()
		return
	if _boss_alive or _elapsed < _bal.swarm_start_seconds:
		return
	_swarm_cd -= delta
	if _swarm_cd <= 0.0 and _effective_alive() < _max_z():
		_trigger_swarm(randf() < _bal.swarm_elite_chance)


## 스웜 예약: 경고를 띄우고 텔레그래프를 시작한다. 랜덤/엘리트 팩 공통 진입점.
func _trigger_swarm(elite: bool) -> void:
	_swarm_cd = randf_range(_bal.swarm_interval_min, _bal.swarm_interval_max)
	_swarm_elite = elite
	_swarm_tel = _bal.swarm_telegraph
	Events.swarm_incoming.emit(_swarm_elite)


## 스웜 규모: 시간이 갈수록 떼가 커진다 — 초반 소수에서 후반 수십 마리로 불어난다.
func _swarm_count() -> int:
	return mini(_bal.swarm_base_count + int(_elapsed / 120.0) * _bal.swarm_count_per_2min, _bal.swarm_count_max)


## 한 방향에서 한 종을 떼로 스폰. 엘리트면 더 크고 강하며 보상도 크다.
## 떼가 충분히 커지면(후반) 한 방향 클러스터 대신 화면 가장자리를 빙 둘러 사방에서 등장해
## 조여드는 포위망이 화면을 꽉 채운다. 실제 생성은 스폰 큐가 프레임 예산으로 분산 처리.
func _spawn_swarm() -> void:
	if not is_instance_valid(player):
		return
	var base_type: Dictionary = _pick_type(WEIGHTS[_tier()])
	var count := _swarm_count()
	var ring := count >= _bal.swarm_ring_threshold
	var center := _random_spawn_pos()
	var ring_r := get_viewport().get_visible_rect().size.length() * 0.5 + spawn_margin
	var d := base_type.duplicate()
	var hp_mult := _hp_mult()
	if _swarm_elite:
		hp_mult *= _bal.swarm_elite_hp_mult
		d["scale"] = float(base_type.get("scale", 1.0)) * _bal.swarm_elite_scale
		d["score"] = int(base_type.get("score", 10)) * 3
		d["contact"] = int(base_type.get("contact", 1)) + 1
	d["max_health"] = maxi(1, int(round(float(base_type["max_health"]) * hp_mult)))
	d["speed"] = float(base_type["speed"]) * _speed_mult()
	for i in range(count):
		var pos: Vector2
		if ring:
			var a := TAU * (float(i) + randf() * 0.6) / float(count)
			pos = player.global_position + Vector2.from_angle(a) * (ring_r + randf_range(0.0, 140.0))
		else:
			pos = center + Vector2(randf_range(-_bal.swarm_spread, _bal.swarm_spread), randf_range(-_bal.swarm_spread, _bal.swarm_spread))
		_queue_spawn(d, pos)
	Events.shake(4.0)   # 떼 스폰은 화면 흔들림으로만 알린다(전용 효과음은 쓰지 않는다)


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

	# 선택 테마의 전용 보스를 쓴다. 세 테마 모두 boss_key 를 가지므로 항상 채워진다 —
	# 그래도 빈 dict 면 데이터 사고이므로 조용히 넘기지 않고 여기서 멈춘다(투명 보스 방지).
	var bt: Dictionary = _theme_boss()
	if bt.is_empty():
		push_error("보스 정의를 찾지 못했습니다 — ThemeData.boss_key 가 THEME_BOSSES 에 없습니다.")
		_boss_alive = false
		_boss_count -= 1
		return
	var boss := BOSS.instantiate()
	get_tree().current_scene.add_child(boss)
	boss.global_position = _random_spawn_pos()
	# 좀비 체력 곡선을 boss_curve_scale 만큼 반영해 보스도 후반까지 녹지 않게 한다.
	# (예전의 분당 +3% 는 후반 보스를 순삭되게 만들었다.)
	var time_scale := 1.0 + (_hp_mult() / Events.diff_enemy_hp_mult() - 1.0) * _diff.boss_curve_scale
	var boss_hp := int(round(float(_bal.boss_base_hp + _bal.boss_hp_per_count * (_boss_count - 1)) * Events.diff_boss_hp_mult() * time_scale * float(bt["hp_mul"])))
	var stats := {
		"max_health": boss_hp,
		"speed": (_bal.boss_base_speed + _bal.boss_speed_per_count * float(_boss_count)) * Events.diff_enemy_speed_mult() * float(bt["speed_mul"]),
		"contact_damage": int(bt["contact"]),
		"score": 200 * _boss_count,
		"gold": 12 + 4 * _boss_count,
		"archetype": bt["archetype"],
		"tint": bt["tint"],
		"proj_color": bt["proj"],
		"name": bt["name"],
		"sprite": bt.get("sprite", ""),   # 테마 보스 전용 아트(없으면 아키타입 기본)
	}
	boss.setup(stats)

	# 격리 구역 — 플레이어를 중심으로 전개해 도주로를 막는다. 보스는 가두지 않는다(어차피
	# 플레이어를 향해 오고, 대시로 잠깐 넘어가도 곧 돌아온다). 회차가 오를수록 좁아진다.
	if is_instance_valid(_arena):
		_arena.queue_free()   # 이전 보스가 처치 없이 사라진 예외 상황 대비
	var arena_r: float = maxf(_bal.boss_arena_radius_min,
			_bal.boss_arena_radius - _bal.boss_arena_shrink_per_count * float(_boss_count - 1))
	_arena = _BossArena.spawn(get_tree().current_scene, player.global_position, arena_r)

	# 호위 정예 좀비 — 빠른(스프린터)/탱커(공사장) 혼합.
	var escorts := _bal.boss_escort_base + _boss_count
	for i in range(escorts):
		_spawn_one(ZOMBIE_TYPES[1] if i % 2 == 0 else ZOMBIE_TYPES[4])


## 서머너 보스의 소환 요청 처리 — 스포너가 직접 스폰해 살아있는 좀비 카운터를 일관 유지.
## 보스 호위 소환 — 화면 밖이 아니라 플레이어를 둘러싼 링에 즉시 나타난다.
## (기존엔 화면 가장자리에서 걸어와 소환이 위협으로 느껴지지 않았다.)
func _on_boss_summon(count: int) -> void:
	if not _boss_alive or _game_over or not is_instance_valid(player):
		return
	var room := maxi(0, _bal.summon_alive_cap - _effective_alive())
	var n := mini(count, room)
	var base_a := randf() * TAU
	for i in range(n):
		var t: Dictionary = (ZOMBIE_TYPES[3] if i % 2 == 0 else ZOMBIE_TYPES[1]).duplicate()
		t["max_health"] = maxi(1, int(round(float(t["max_health"]) * _hp_mult())))
		t["speed"] = float(t["speed"]) * _speed_mult()
		# 링 위 균등 배치 + 약간의 산개 — 한쪽으로 뚫고 나가되 공짜는 아니게.
		var a: float = base_a + TAU * float(i) / float(maxi(1, n))
		var r: float = _bal.boss_summon_ring + randf_range(-40.0, 40.0)
		_spawn_at(t, player.global_position + Vector2.from_angle(a) * r)


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
const SEP_STRENGTH := 0.55   # 2프레임에 1번 실행하므로 1회 밀어내는 양을 2배 근사로 키운다
const SEP_MAX_PUSH := 8.0
const SEP_MAX_NEIGHBORS := 6
## 플레이어로부터 이 거리 안의 좀비만 분리 처리한다. 화면 밖 좀비는 겹쳐도 보이지 않으므로
## 계산할 이유가 없다 — 좀비가 수천이어도 실제 처리 대상은 화면 주변 수백으로 묶인다.
const SEP_ACTIVE_R := 760.0

# 프레임마다 새 Dictionary/Array 를 만들면(좀비 1만 → 소배열 1만 개 할당) 할당·GC 부담이 폭증한다.
# 버퍼를 멤버로 두고 clear() 재사용하며, 위치는 PackedVector2Array 로 담아 per-entry 할당을 없앤다.
var _sep_grid: Dictionary = {}
var _sep_nodes: Array = []
var _sep_pos: PackedVector2Array = PackedVector2Array()


func _physics_process(_delta: float) -> void:
	if _game_over or not is_instance_valid(player):
		return
	# 분리는 30Hz(2 물리 프레임에 1번)로 충분하다 — 겹침 해소는 누적 효과라 시각 차이가 없고,
	# 대량 좀비에서 프레임 비용이 절반으로 준다(SEP_STRENGTH/MAX_PUSH 로 1회 보정량을 키움).
	if Engine.get_physics_frames() % 2 != 0:
		return
	var zs := Events.live_zombies()
	if zs.size() < 2:
		return
	var pc: Vector2 = player.global_position
	var act_sq := SEP_ACTIVE_R * SEP_ACTIVE_R
	_sep_grid.clear()
	_sep_nodes.clear()
	_sep_pos.clear()
	for z in zs:
		if not is_instance_valid(z) or z.is_in_group("boss"):
			continue
		var p: Vector2 = z.global_position
		if p.distance_squared_to(pc) > act_sq:
			continue   # 화면 밖 — 분리 생략
		var key := Vector2i(int(floor(p.x / SEP_CELL)), int(floor(p.y / SEP_CELL)))
		var arr: Variant = _sep_grid.get(key)
		if arr == null:
			_sep_grid[key] = [_sep_nodes.size()]
		else:
			arr.append(_sep_nodes.size())
		_sep_nodes.append(z)
		_sep_pos.append(p)
	for i in _sep_nodes.size():
		var p: Vector2 = _sep_pos[i]
		var cx := int(floor(p.x / SEP_CELL))
		var cy := int(floor(p.y / SEP_CELL))
		var push := Vector2.ZERO
		var checked := 0
		for ox in range(-1, 2):
			for oy in range(-1, 2):
				var arr2: Variant = _sep_grid.get(Vector2i(cx + ox, cy + oy))
				if arr2 == null:
					continue
				for j in arr2:
					if j == i:
						continue
					var d: Vector2 = p - _sep_pos[j]
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
			_sep_nodes[i].global_position += (push * SEP_STRENGTH).limit_length(SEP_MAX_PUSH)
