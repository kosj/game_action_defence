extends Node
## 전역 이벤트 버스 / 재화·체력·웨이브·업그레이드 관리 (Autoload 싱글톤: "Events")

## 게임 버전 — 타이틀/메뉴에 표시.
const VERSION := "v1.0.0"

## 배포마다 CI 가 build_info.json 에 커밋 SHA·시각을 기록한다(로컬은 "dev build").
## 타이틀/메뉴에 함께 표시해 "지금 라이브가 어떤 빌드인지"를 눈으로 확인할 수 있게 한다.
const _BUILD_INFO_PATH := "res://build_info.json"
var _build_stamp_cache := ""


## 일시정지 워치독이 정지 중에도 돌아야 하므로 이벤트 버스는 항상 처리한다.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


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
signal run_progress(elapsed: float, clear: float)   # 시간 기반 진행(HUD 클리어 진행바)
signal run_cleared                                  # 30분 생존 = 클리어 달성(1회)
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
signal inventory_changed        # 무기/패시브 인벤토리 변경 — HUD 장착 표시 갱신
signal evolution_offer          # 진화 보물상자 개봉 — LevelUpPanel 이 진화 선택지를 띄운다
signal elite_pack               # 예약 엘리트 팩 등장(주기적) — 진화 상자 드롭 트리거
signal weather_changed(key: String)          # 날씨 전환("" = 맑음) — HUD 가 짧은 배너로 알린다
signal achievement_unlocked(title: String)   # 도전과제 달성 — HUD 토스트 알림
signal quest_completed(title: String, reward: int)   # 끝없는 과제 완료 — HUD 토스트 + 메타 골드 보상

var total_gold: int = 0
var total_kills: int = 0
var did_clear: bool = false   # 이번 런에서 30분 클리어를 달성했는가
var player_health: int = 0
var player_max_health: int = 0
var current_wave: int = 1
var elapsed_time: float = 0.0

## 이번 런의 환경 시드 — 날씨 스케줄이 (이 값 + 슬롯 인덱스)만으로 결정된다.
## 세이브에 실려 이어하기가 같은 날씨 타임라인을 복원하고, 검증 스크립트가 재현할 수 있다.
var env_seed: int = 0

# 현재 보스의 표시 이름(타입) — HUD 체력바 라벨용. 보스가 setup() 에서 채우고 boss_spawned 직후 읽힌다.
var boss_display_name: String = "BOSS"
var wave_kill_progress: int = 0
var wave_kill_total: int = 0

# 골드 자동 줍기(자석) 버프 활성 여부 — Gold 이 매 프레임 참조하는 일시 상태(저장 안 함).
var gold_magnet_active: bool = false

# 메타 성장(영구 강화) 배수 — 런 시작 시 MetaManager 가 설정. 골드/경험치 획득에 곱한다.
var gold_mult: float = 1.0
var xp_mult: float = 1.0
var revives_left: int = 0   # 이번 런 남은 무료 부활 횟수(메타 'revive') — 사망 시 소비

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
	# 광역 궁극기(ult_*)는 캐릭터 전용 1종만 — 다른 캐릭터의 궁극기는 어떤 경로로도 획득 불가.
	if id.begins_with("ult_"):
		var c: CharacterData = CharacterManager.selected()
		if c == null or c.ultimate_weapon != id:
			return
	if ItemDB.is_weapon(id):
		weapons[id] = int(weapons.get(id, 0)) + 1
	else:
		passives[id] = int(passives.get(id, 0)) + 1
	ItemDB.recompute(weapons, passives)
	inventory_changed.emit()


## 진화 발동 가능 규칙 목록 — ① 베이스 무기 만렙 ② 짝꿍 패시브 보유(Lv1+) ③ 아직 미진화.
## 진화 상자 개봉(ItemPickup)과 진화 선택 패널(LevelUpPanel)이 공유한다.
func available_evolutions() -> Array:
	var out: Array = []
	for e in ItemDB.evolutions():
		var bm := ItemDB.meta(e["base"])
		if bm.is_empty():
			continue
		if int(weapons.get(e["base"], 0)) >= int(bm["max"]) \
				and int(passives.get(e["passive"], 0)) >= 1 \
				and not weapons.has(e["into"]):
			out.append(e)
	return out


## 진화: 원본 무기를 제거하고 진화 무기(Lv1)로 교체 후 재계산. 패시브는 유지된다.
func evolve(base_id: String, into_id: String) -> void:
	weapons.erase(base_id)
	weapons[into_id] = 1
	ItemDB.recompute(weapons, passives)
	inventory_changed.emit()


## 다음 레벨까지 필요한 경험치 곡선 — 초반은 자주, 갈수록 뜸하게(레벨업 연출 과다 방지).
func _xp_curve(lvl: int) -> int:
	return int(round(10.0 + (lvl - 1) * 8.0 + pow(float(lvl), 1.5) * 2.0))


## 보스 상자 보상 — 무료 레벨업 1회(경험치 소모 없이 강화 카드가 뜬다).
func bonus_level() -> void:
	level += 1
	xp_to_next = _xp_curve(level)
	level_up.emit(level)
	xp_changed.emit(xp, xp_to_next, level)


## 광역/오라 무기 효과 반경 배수 — 패시브 '배터리'(upgrade_area)로 커진다.
func area_mult() -> float:
	return 1.0 + 0.08 * float(upgrade_area)


## 코인 수집 시 호출(코인 1개 = 경험치 1). 임계 도달 시 레벨업 신호(연속 레벨업도 처리).
func add_xp(amount: int) -> void:
	xp += maxi(1, int(round(amount * xp_mult * (1.0 + 0.08 * float(upgrade_greed)))))   # 메타 '성장' × 패시브 '토끼발'
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
var upgrade_area: int = 0              # 광역/오라 무기 효과 반경 (+8%/레벨) — 패시브 '배터리'
var upgrade_greed: int = 0             # 인게임 골드/경험치 획득 (+8%/레벨) — 패시브 '토끼발'
var upgrade_garlic: int = 0            # 마늘 오라 무기 레벨(0=미보유)
var upgrade_holy: int = 0              # 성수 무기 레벨(0=미보유)

# 캐릭터 조건부 트레잇(Phase 4-B) — Player 가 매 프레임 갱신하는 동적 상태.
var trait_damage_mult: float = 1.0    # 나가는 피해 배수(베테랑 저체력↑ 등) — 좀비/보스가 피격 시 곱함
var trait_crit_bonus: float = 0.0     # 추가 치명타 확률(사냥꾼 정지 시↑) — crit_chance() 에 합산


## 현재 치명타 확률(패시브 조준경 + 캐릭터 트레잇 보너스, 상한 60%). 발사 코드가 공유한다.
func crit_chance() -> float:
	return minf(0.08 * float(upgrade_crit) + trait_crit_bonus, 0.6)


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


# ── 좀비 공간 해시(발사체 광역 판정 가속) ────────────────────────────────
# 총알마다 전체 좀비를 훑으면 O(총알×좀비)라 대량 난전에서 급격히 느려진다. 물리 프레임당
# 1회만 격자에 담아두고, 근접 판정은 주변 3×3 셀만 보게 해 O(총알×이웃)로 낮춘다.
const _ZG_CELL := 64.0
const _ZG_GC_FRAMES := 600   # 빈 셀 키 정리 주기(60fps 기준 10초) — 맵을 돌아다니면 키가 계속 쌓인다
var _zg_frame: int = -1
var _zg: Dictionary = {}     # Vector2i -> Array[Node2D]. 셀 배열 객체는 프레임 간 재사용한다.
# 질의 결과용 재사용 버퍼. 호출부는 즉시 순회하고 보관하지 않는다는 전제이며,
# 같은 함수를 순회 도중 다시 호출하면 안 된다(버퍼가 덮인다). 총알 순회 중 스플래시가
# 겹치는 실제 사례가 있어 near/radius 는 서로 다른 버퍼를 쓴다.
var _near_buf: Array = []
var _radius_buf: Array = []


func _ensure_zgrid() -> void:
	var f := Engine.get_physics_frames()
	if f == _zg_frame:
		return
	_zg_frame = f
	# 셀 배열을 통째로 버리지 않고 비워서 재사용한다. _zg.clear() 로 매 프레임 점유 셀 수만큼
	# (좀비 300+ 에서 150~300개) 새 Array 를 만드는 것이 이 시스템의 최대 상시 할당원이었다.
	for key in _zg:
		(_zg[key] as Array).clear()
	for z in live_zombies():
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		var p: Vector2 = z.global_position
		var key := Vector2i(int(floor(p.x / _ZG_CELL)), int(floor(p.y / _ZG_CELL)))
		var arr: Variant = _zg.get(key)
		if arr == null:
			_zg[key] = [z]
		else:
			arr.append(z)
	# 빈 셀을 계속 들고 있으면 위 clear 루프와 딕셔너리가 무한히 커진다 — 주기적으로 회수.
	if f % _ZG_GC_FRAMES == 0:
		var dead: Array = []
		for key in _zg:
			if (_zg[key] as Array).is_empty():
				dead.append(key)
		for key in dead:
			_zg.erase(key)


## pos 주변(3×3 셀 ≈ ±96px)에 있는 좀비 후보만 반환. 정밀 거리 판정은 호출부가 수행한다.
## 셀(64px)이 최대 판정 반경(보스 38+총알 반경)보다 커서 3×3 스캔이면 누락 없이 커버된다.
## 반환값은 공유 버퍼다 — 즉시 순회용이며, 다음 zombies_near() 호출 시 내용이 덮인다.
func zombies_near(pos: Vector2) -> Array:
	_ensure_zgrid()
	var cx := int(floor(pos.x / _ZG_CELL))
	var cy := int(floor(pos.y / _ZG_CELL))
	_near_buf.clear()
	for ox in range(-1, 2):
		for oy in range(-1, 2):
			var arr: Variant = _zg.get(Vector2i(cx + ox, cy + oy))
			if arr != null and not (arr as Array).is_empty():
				_near_buf.append_array(arr)
	return _near_buf


## pos 반경 r 안의 살아있는 좀비를 반환(거리 판정까지 포함). 오라·폭발·터렛 조준처럼 반경이
## 셀(64px)보다 큰 광역 질의용 — 전체 좀비를 훑는 대신 필요한 셀 범위만 순회한다.
## 반환값은 공유 버퍼다 — 즉시 순회용이며, 다음 zombies_in_radius() 호출 시 내용이 덮인다.
## (풀 반납된 좀비는 인스턴스가 유효한 채 그룹만 빠지므로 호출부의 is_in_group 확인은 계속 필요하다)
func zombies_in_radius(pos: Vector2, r: float) -> Array:
	_ensure_zgrid()
	_radius_buf.clear()
	var r_sq := r * r
	var span := int(ceil(r / _ZG_CELL))
	# 반경이 아주 크면 셀 순회(25×25 이상)가 전수 스캔보다 비싸다 — 훑는 대상만 스냅샷으로 바꾸고
	# 거리 필터는 그대로 적용한다(어느 경로로 오든 "반경 안"이라는 반환 계약은 동일해야 한다).
	if span >= 12:
		for z in live_zombies():
			if not is_instance_valid(z):
				continue
			if pos.distance_squared_to(z.global_position) <= r_sq:
				_radius_buf.append(z)
		return _radius_buf
	var cx := int(floor(pos.x / _ZG_CELL))
	var cy := int(floor(pos.y / _ZG_CELL))
	for ox in range(-span, span + 1):
		for oy in range(-span, span + 1):
			var arr: Variant = _zg.get(Vector2i(cx + ox, cy + oy))
			if arr == null:
				continue
			for z in arr:
				if not is_instance_valid(z):
					continue
				if pos.distance_squared_to(z.global_position) <= r_sq:
					_radius_buf.append(z)
	return _radius_buf


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
	total_gold += maxi(1, int(round(amount * gold_mult * (1.0 + 0.08 * float(upgrade_greed)))))   # 메타 '탐욕' × 패시브 '토끼발'
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
	did_clear = false
	player_health = 0
	player_max_health = 0
	current_wave = 1
	elapsed_time = 0.0
	env_seed = randi()   # 런마다 새 날씨 타임라인
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
	upgrade_area = 0
	upgrade_greed = 0
	trait_damage_mult = 1.0
	trait_crit_bonus = 0.0
	upgrade_regen = 0
	upgrade_crit = 0
	upgrade_garlic = 0
	upgrade_holy = 0
	# 시작 인벤토리 — 기본 자동총(gun) + 선택 캐릭터의 시작 무기/시그니처 패시브.
	weapons = {"gun": 1}
	passives = {}
	var _char: CharacterData = CharacterManager.selected()
	if _char != null:
		if _char.start_weapon != "" and _char.start_weapon != "gun":
			weapons[_char.start_weapon] = 1
		if _char.signature_passive != "":
			passives[_char.signature_passive] = 1
		# 궁극기(ultimate_weapon)는 시작 지급하지 않는다 — 중후반(레벨 8+) 레벨업 카드로 해금.
	MetaManager.apply_run_start()         # 영구 강화 배수(골드/경험치) 설정
	ItemDB.recompute(weapons, passives)   # 인벤토리 → upgrade_* 정합화(메타 시작 보정 포함)
	gold_changed.emit(total_gold)
	score_changed.emit(score)
	xp_changed.emit(xp, xp_to_next, level)
	inventory_changed.emit()


# ── 일시정지 소유권 레지스트리 + 워치독 ─────────────────────────────────────────
## 여러 모달(레벨업/보물상자/상점/게임오버/일시정지 메뉴)이 각자 get_tree().paused 를 켜고 끄면,
## 어느 하나가 해제를 빠뜨렸을 때 "화면엔 아무것도 없는데 게임만 멈춘" 상태로 영구히 갇힌다
## (장시간 웹 플레이 중 보고된 프리즈 증상). 그래서 정지는 여기서만 소유권 기반으로 관리한다.
##  · pause_push(owner) / pause_pop(owner) — 살아있는 소유자가 하나라도 있으면 정지, 비면 자동 해제.
##  · 워치독 — 매 프레임 소유자를 검증(해제됨/트리 밖/오래 숨겨짐)해 유령 소유자를 걷어내고,
##    소유자 없는 정지가 유예 시간을 넘기면 강제로 해제한다. 원인을 몰라도 하드 프리즈는 막는다.
##  · 히트스톱 감시 — Engine.time_scale 이 낮은 채로 남아 "멈춘 듯" 보이는 것도 함께 복구한다.

signal pause_watchdog_fired(reason: String, detail: String)

const PAUSE_ORPHAN_GRACE_MS := 1000    # 소유자 없는 정지를 이만큼 견디면 강제 해제
const PAUSE_HIDDEN_GRACE_MS := 3000    # 등록 후 이 시간이 지나도 안 보이는 소유자는 유령으로 간주
const TIMESCALE_GRACE_MS := 1000       # 히트스톱 배속이 이만큼 남아있으면 강제 복구

var _pause_owners: Dictionary = {}     # instance_id(int) -> {"node": Node, "tag": String, "since": int}
var _pause_orphan_since: int = -1
var _timescale_low_since: int = -1


## 정지 소유권 획득 — 모달이 열릴 때 호출한다(같은 소유자의 중복 호출은 무해).
func pause_push(owner: Node, tag: String = "") -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var id := owner.get_instance_id()
	if not _pause_owners.has(id):
		_pause_owners[id] = {"node": owner, "tag": (tag if tag != "" else owner.name),
			"since": Time.get_ticks_msec()}
	_apply_pause()


## 정지 소유권 반납 — 모달이 닫힐 때/트리에서 빠질 때 호출한다(미등록 소유자여도 무해).
func pause_pop(owner: Node) -> void:
	if owner == null:
		return
	if _pause_owners.erase(owner.get_instance_id()):
		_apply_pause()


## 모든 소유권 해제 — 씬 전환·재시작처럼 판 자체가 끝나는 지점에서 호출한다.
func pause_release_all() -> void:
	_pause_owners.clear()
	_apply_pause()


func pause_owner_tags() -> PackedStringArray:
	var out := PackedStringArray()
	for id in _pause_owners:
		out.append(String(_pause_owners[id]["tag"]))
	return out


func _apply_pause() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var want := not _pause_owners.is_empty()
	if tree.paused != want:
		tree.paused = want
	if want:
		_pause_orphan_since = -1


## 유령 소유자 제거 — 해제됐거나, 트리 밖이거나, 등록 후 유예 시간이 지나도 보이지 않는 소유자.
func _prune_pause_owners(now: int) -> int:
	var dropped := 0
	for id in _pause_owners.keys():
		var e: Dictionary = _pause_owners[id]
		var n = e["node"]
		var dead: bool = not is_instance_valid(n) or not n.is_inside_tree()
		if not dead and (n is CanvasItem or n is CanvasLayer) and not n.visible \
				and now - int(e["since"]) >= PAUSE_HIDDEN_GRACE_MS:
			dead = true
		if dead:
			_pause_owners.erase(id)
			dropped += 1
	return dropped


func _process(_delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var now := Time.get_ticks_msec()

	if not _pause_owners.is_empty() and _prune_pause_owners(now) > 0:
		_apply_pause()

	# 소유자 없는 정지 = 아무도 해제해 줄 수 없는 상태. 유예 후 강제 해제한다.
	if tree.paused and _pause_owners.is_empty():
		if _pause_orphan_since < 0:
			_pause_orphan_since = now
		elif now - _pause_orphan_since >= PAUSE_ORPHAN_GRACE_MS:
			_pause_orphan_since = -1
			tree.paused = false
			var detail := "level=%d elapsed=%.1f" % [level, elapsed_time]
			push_warning("[PauseWatchdog] 소유자 없는 일시정지를 강제 해제했다 — " + detail)
			pause_watchdog_fired.emit("orphan_pause", detail)
	else:
		_pause_orphan_since = -1

	# 히트스톱이 복구되지 않은 채 남으면 게임이 멈춘 것처럼 보인다 — 실시간 기준으로 감시한다.
	if Engine.time_scale < 0.999:
		if _timescale_low_since < 0:
			_timescale_low_since = now
		elif now - _timescale_low_since >= TIMESCALE_GRACE_MS:
			_timescale_low_since = -1
			var ts := Engine.time_scale
			Engine.time_scale = 1.0
			_hitstop_active = false
			push_warning("[PauseWatchdog] 히트스톱 배속(%.3f)이 남아있어 복구했다" % ts)
			pause_watchdog_fired.emit("stuck_time_scale", "%.3f" % ts)
	else:
		_timescale_low_since = -1
