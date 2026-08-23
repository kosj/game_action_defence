extends SceneTree
## 후반 프레임 저하 측정 하네스 (P1-18).
##
## 왜 필요한가
## -----------
## 사람 기록의 `diag` 는 **종료 시점 한 장**뿐이라 "무엇이 비싼가"를 못 가른다. 실제로
## 좀비 수와 fps 는 상관이 없었다 — 34마리에서 18fps 인데 143마리에서 31fps 다.
## 눈으로 후보를 고르지 말고 하나씩 재라는 것이 이 레포의 교훈이다(`BALANCE.md` §3-5).
## 그래서 후반 상태를 **재현**해 놓고 프레임 예산을 항목별로 쪼갠다.
##
## 실행:
##   xvfb-run -a godot --path . --script res://tools/bench_lategame.gd -- \
##       min=26 warm=6 measure=20 build=engineer_late
##
## ⚠️ `--fixed-fps` 를 주지 말 것. 프레임 시간을 재는 것이 목적인데 고정 fps 는 그것을 지운다.
## ⚠️ 렌더 비용(드로우콜)은 실렌더에서만 의미가 있다. `--headless` 로 돌리면 로직 비용만 나온다.
##
## 인자:
##   min=26        난이도 시계를 이 분까지 당긴다
##   warm=6        측정 전 예열(초) — 스폰·풀 워밍이 끝나야 정상 상태다
##   measure=20    측정 구간(초)
##   build=...     인벤토리 프리셋 이름(아래 BUILDS)
##   seed=N        전역 RNG 시드 고정. 주면 같은 판을 재현한다 — A/B 에서 "두 조건이 서로
##                 다른 판이라 생긴 차이"를 지운다. 안 주면 매 실행이 다른 판이다.
##   fill=1        측정 시작 시 좀비를 동시 출현 상한까지 채운다
##   probe=gold:N  대조 실험 모드 — 스포너·오토플레이를 끄고 **그 개체만 N 개** 놓고 잰다.
##                 개체 수를 바꿔 가며 재면 개체당 프레임 비용(µs)이 직접 나온다.
##                 off= 로 재는 것보다 정확하다 — off 는 풀 반납까지 멈춰 개체 수가 같이 변한다.
##   hudscan=1     HUD 안에서 **요소 하나씩** 숨겨 가며 드로우 콜 몫을 잰다(실렌더 전용).
##                 hide=HUD 는 "HUD 전체가 몇 콜인가"만 알려 준다. 그 안에서 무엇이 내는지는
##                 이걸로 본다 — 한 프로세스에서 전부 돌므로 판 조건이 고정된다.
##   hide=Gold,Bullet **그리기만** 끈다(visible=false). 로직은 그대로 돈다 —
##                    드로우 콜 귀속용이다. only= 로는 못 가른다: 그것은 로직을 끄는 장치고
##                    드로우 콜은 로직이 아니라 캔버스 아이템에서 나온다(로직을 꺼도 그려진다).
##   off=Gold,Bullet  해당 스크립트의 _physics_process 만 끈다(노드는 그대로 둔다).
##                    켠 상태와의 차이가 곧 그 스크립트의 프레임 비용이다.
##
## ⚠️ 이 게임은 거의 모든 로직이 `_physics_process` 에 있다. 그래서 `physics_ms` 는
## "물리 엔진 비용"이 아니라 **물리 엔진 + 게임 로직 전부**다. 항목별로 가르려면 `off=` 를 쓴다.


## ── 물리 틱 1회의 진짜 비용 ────────────────────────────────────────────
## ⚠️ `Performance.TIME_PHYSICS_PROCESS` 는 "이번 틱의 비용"이 **아니다.**
## 엔진이 최근 1초 동안의 **최댓값**을 들고 있다가 1초마다 갱신·리셋하는 값이다
## (실측: 60틱에 1번만 17.6ms 를 쓰게 만들었더니 표본 180개 중 107개가 17.6ms 로 찍혔다).
## 즉 그 값은 **스파이크 지표**다. 프레임 드랍을 잡는 데는 오히려 알맞지만, 평상시 비용으로
## 읽으면 게임 전체 비용을 2~5배 부풀려 보게 된다 — 예전 기록이 그렇게 읽혀 왔다.
##
## 그래서 평상시 비용은 직접 잰다. 물리 우선순위를 최소/최대로 준 센티넬 노드 두 개를 트리에
## 두고, 둘의 시각 차이를 매 틱 기록한다. 그 사이에 이 게임의 모든 `_physics_process` 가 들어간다.
class TickProbe extends Node:
	var t_usec: int = 0
	var sink = null                 # 끝 센티넬만 Array 를 받는다(시작 센티넬은 null)
	var start_probe: TickProbe = null

	func _physics_process(_d: float) -> void:
		t_usec = Time.get_ticks_usec()
		if sink != null and start_probe != null:
			sink.append(float(t_usec - start_probe.t_usec) / 1000.0)


const MAIN_SCENE := "res://scenes/Main.tscn"
## ⚠️ 여기서 `preload` 를 쓰면 안 된다 — 하네스가 잰 것이 통째로 거짓이 된다.
##
## `--script` 로 실행되는 SceneTree 스크립트는 **오토로드가 등록되기 전에 컴파일**된다.
## 그때 preload 가 Bullet.tscn 을 끌어오면 Bullet.gd 가 같이 컴파일되는데, 그 안의 `Events`
## (오토로드)를 못 찾아 "Compile Error: Identifier not found: Events" 로 실패한다.
## 실패한 GDScript 가 그대로 리소스 캐시에 박히고, 이후 ProjectileWeapon 의 preload 도
## **같은 PackedScene 객체**를 받으므로 게임이 쏘는 탄 전부가 스크립트가 죽은 Node2D 가 된다.
##
## 증상: 콘솔에 `Invalid assignment of property 'direction' ... base object of type 'Node2D'`
## 가 쏟아지고, 탄이 움직이지도·명중하지도·반납되지도 않는다. 즉 **탄 비용이 0 으로 측정된다** —
## "후반 병목은 탄"이라고 결론 낸 P1-18 의 프레임 예산이 이 상태에서 나온 수치였다.
## 그래서 씬은 오토로드가 살아 있는 `_setup()`(=_process 안) 에서 `load()` 로 늦게 가져온다.
var _gold_scene: PackedScene = null
var _bullet_scene: PackedScene = null
var _zombie_scene: PackedScene = null

## 사람 실측에서 fps 18 이 나온 그 빌드(엔지니어, 26분, 레벨 155)를 그대로 재현한다.
## 임의로 만든 빌드로 재면 "실제로 느린 그 상태"가 아니라 다른 상태를 재게 된다.
const BUILDS := {
	"engineer_late": {
		"character": "engineer",
		"weapons": {"garlic": 8, "gatling": 5, "molotov": 8, "railgun": 5,
			"shotgun": 8, "turret": 8, "ult_orbital": 8},
		"passives": {"ammo_belt": 6, "armor": 8, "battery": 6, "crit": 7,
			"gunpowder": 8, "rabbits_foot": 6},
	},
	"veteran_late": {
		"character": "veteran",
		"weapons": {"gun": 8, "inferno": 5, "molotov": 8, "orb": 8, "sawblade": 8,
			"thunderstorm": 5, "ult_quake": 8},
		"passives": {"ammo_belt": 6, "armor": 8, "battery": 6, "crit": 7,
			"haste": 8, "rabbits_foot": 6},
	},
	## 대조군 — 시작 인벤토리. 같은 시각·같은 개체 수에서 빌드만 뺐을 때의 비용.
	"baseline": {"character": "engineer", "weapons": {}, "passives": {}},
}

var _args: Dictionary = {}
var _started := false
var _finished := false
var _t := 0.0
var _warm := 6.0
var _measure := 20.0
var _events: Node = null
var _main: Node = null

var _frames: Array = []          # 측정 구간의 프레임 시간(ms)
var _proc_ms: Array = []
var _phys_ms: Array = []
var _draw_calls: Array = []
## 렌더 프레임 1장당 돌아간 물리 틱 수. 1 이 정상이고, 2 이상이면 **물리가 프레임 예산을
## 넘겨 엔진이 따라잡기 틱을 돌리는 중**이다 — 그 순간부터 비용이 스스로를 부풀린다.
## physics_ms 를 이것으로 나눠야 "틱 1회의 진짜 비용"이 나온다.
var _ticks: Array = []
var _zg_q: Array = []
var _tick_ms: Array = []          # 물리 틱 1회당 스크립트 비용(센티넬 실측)
var _tick_end: TickProbe = null
var _tick_head: TickProbe = null
var _zg_b: Array = []
var _prev_pf: int = -1
var _pairs: Array = []
var _counts_last: Dictionary = {}
var _off: Array = []
var _only: Array = []
var _hide: Array = []
## hudscan — HUD 요소별 드로우 콜 절제. _process 안의 상태 기계로 돈다
## (SceneTree 스크립트라 await 로 끊을 수 없다).
const _SCAN_SAMPLE := 30    # 대상 1개당 표본 프레임
const _SCAN_SETTLE := 3     # 숨긴 뒤 렌더가 안정될 때까지 버리는 프레임
var _hudscan := false
var _scan_targets: Array = []
var _scan_i := -2           # -2 = 미시작 · -1 = 기준선 · 0.. = 대상 인덱스
var _scan_settle := 0
var _scan_buf: Array = []
var _scan_base := 0
var _scan_out: Array = []
var _scan_frozen := false
var _scan_spread := 0
var _off_applied := false
var _kills0 := -1
## stress 모드 — 최대 부하(worst case) 재현. 아래 _stress_tick() 참고.
##
## ⚠️ **stress 는 스포너를 우회한다** — 매 초 좀비를 상한까지 직접 채우므로,
## `spawn_interval*` 계열 변경은 이 모드에서 **아무 차이도 안 난다**(P1-20 에서 실제로 겪었다).
## 스폰 throughput 을 바꾼 효과는 정상 모드로 재거나, 데이터에서 계산할 것
## (`tools/verify_late_hp.gd` 가 엔진과 같은 식으로 초당 스폰을 찍어 준다).
var _stress := false
var _pause_tags: Dictionary = {}
var _paused_ticks := 0
var _stress_t := 0.0
var _vram: Array = []
var _tex_mem: Array = []
var _items: Array = []


func _process(delta: float) -> bool:
	if _finished:
		return true
	if not _started:
		_started = true
		_setup()
		return false
	_t += delta
	if _stress:
		_stress_tick(delta)
	if _t < _warm:
		return false
	# 풀에서 새로 나온 노드는 다시 켜져 있으므로 매 프레임 다시 끈다.
	# 이 순회는 `_process` 에서 도므로 측정 대상인 physics_ms 에 섞이지 않는다.
	if not _off.is_empty():
		_apply_off(not _off_applied)
		_off_applied = true
	# only= 도 마찬가지다. 예전에는 setup 때 한 번만 껐는데, 그러면 **측정 중 풀에서 새로
	# 나온 노드는 켜진 채로 돈다** — stress=1 처럼 계속 스폰되는 판에서는 "하나만 켰다"는
	# 전제가 조용히 무너져 귀속이 통째로 틀린다(정지 절편이 0.01ms 가 아니게 된다).
	if not _only.is_empty():
		_apply_only()
	# hide= 도 같다. 풀에서 새로 나온 노드는 visible 이 true 로 돌아와 있다.
	if not _hide.is_empty():
		_apply_hide()
	if _hudscan:
		# 스캔 중에는 판을 **얼린다.** 안 그러면 창마다 좀비 사망·FX 팝으로 그리는 것이 달라져
		# 그 분산이 HUD 신호를 덮는다 — 실제로 얼리기 전에는 거의 모든 요소가 20~60콜씩
		# 줄이는 것으로 나왔다(합이 기준선의 몇 배). 얼린 판은 매 프레임 같은 것을 그린다.
		if not _scan_frozen:
			_freeze_for_scan()
			_scan_frozen = true
			return false
		_scan_tick()
		return _finished
	# 일시정지 중(레벨업 카드 등)에는 프레임 시간이 의미가 없다 — 측정에서 뺀다.
	if _kills0 < 0:
		_kills0 = int(_events.total_kills)
		_tick_ms.clear()   # 예열 구간의 틱은 버린다
		# 유도탄 명중률도 예열분을 뺀다 — 계측 카운터가 없는 예전 리비전과도 같은
		# 하네스로 비교할 수 있게 안전하게 읽는다(없으면 0 으로 남는다).
		var _bs: Variant = load("res://scripts/Bullet.gd")
		if _bs != null:
			_homing_gone0 = int(_bs.stat_homing_gone)
			_homing_hit0 = int(_bs.stat_homing_hit)
	# 정지 구간이 길면 표본이 사라진다 — **누가** 잡고 있는지 세어 둔다. 그게 없으면
	# "표본 114/1800" 만 보고 원인을 못 찾는다(실제로 레벨업인 줄 알고 헛다리를 짚었다).
	if paused:
		for tag in _events.pause_owner_tags():
			_pause_tags[tag] = int(_pause_tags.get(tag, 0)) + 1
		_paused_ticks += 1
	if not paused:
		_frames.append(delta * 1000.0)
		_proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_phys_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_items.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		# GPU "부하"를 헤드리스에서 직접 잴 수는 없지만, **GPU 에 보내는 양**은 기기와 무관한
		# 값이라 여기서 그대로 읽힌다 — 드로우 콜·캔버스 아이템·VRAM 이 그 대리 지표다.
		_vram.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
		_tex_mem.append(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
		var pf := Engine.get_physics_frames()
		if _prev_pf >= 0:
			_ticks.append(float(pf - _prev_pf))
		_prev_pf = pf
		_pairs.append(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS))
		# 공간 해시 질의 수와 그중 실제로 9칸을 돈 수 — 같은 셀 재질의 건너뛰기의 적중률.
		# 계측 카운터가 없는 예전 리비전과도 같은 하네스로 비교할 수 있게 안전하게 읽는다.
		var q = _events.get("zg_queries")
		var b = _events.get("zg_builds")
		_zg_q.append(float(q) if q != null else 0.0)
		_zg_b.append(float(b) if b != null else 0.0)
	if _t >= _warm + _measure:
		_counts_last = _count_nodes()
		_report()
		_finished = true
		quit(0)
	return false


## 측정 구간에서 소멸한 유도탄 수 / 그중 맞힌 수(예열 구간은 뺀다).
var _homing_gone0: int = -1
var _homing_hit0: int = -1
var _homing_gone: int = 0
var _homing_hit: int = 0


func _setup() -> void:
	_parse_args()
	# 전역 RNG 를 고정한다. Godot 은 시작할 때마다 자동으로 무작위 시드를 잡으므로,
	# 아무것도 안 하면 A/B 두 판이 **서로 다른 판**이 된다 — 실제로 같은 코드를 3번 재서
	# 명중률이 86.8~92.3% 로 5.5pp 흔들렸다. 그 산포보다 작은 차이는 판정할 수 없다.
	# 시드를 맞추면 두 조건이 같은 초기 상태에서 출발해 그 몫이 빠진다.
	# ⚠️ 완전한 결정론은 아니다 — 코드가 바뀌면 RNG 소비 순서가 달라져 궤적이 갈라진다.
	#    그래서 여러 시드로 재고 **시드별로 짝지어** 비교해야 한다(단일 시드는 우연일 수 있다).
	if _args.has("seed"):
		seed(int(_args.get("seed", "0")))
	_warm = float(_args.get("warm", "6"))
	_measure = float(_args.get("measure", "20"))
	_events = root.get_node("Events")
	_assert_scripts_live()

	var preset: Dictionary = BUILDS.get(String(_args.get("build", "engineer_late")), {})
	# w=gatling:5,shotgun:8 — 무기 하나만 놓고 재기 위한 임시 빌드(탄 예산 분해용).
	var wspec := String(_args.get("w", ""))
	if wspec != "":
		var wd: Dictionary = {}
		for e in wspec.split(","):
			var kv := String(e).split(":")
			wd[String(kv[0])] = int(kv[1]) if kv.size() > 1 else 8
		preset = {"character": String(_args.get("character", "engineer")),
			"weapons": wd, "passives": {}}
	_pick("CharacterManager", String(preset.get("character", "engineer")),
		func(gd, id): return gd.character(id))
	_pick("ThemeManager", String(_args.get("theme", "city")),
		func(gd, id): return _theme_by_id(gd, id))

	root.get_node("SaveManager").delete_save()
	_events.reset()

	_main = load(MAIN_SCENE).instantiate()
	root.add_child(_main)
	current_scene = _main

	var cheats := root.get_node("Cheats")
	cheats.autoplay_persona = "greedy"
	cheats.autoplay = true

	# 난이도 시계를 당긴다. 치트 경로를 쓰는 이유는 sim_balance 의 해금 우회와 같다 —
	# 26분 상태를 재려고 26분을 실제로 플레이할 수는 없다.
	var mins := float(_args.get("min", "26"))
	if mins > 0.0:
		cheats.request_time_skip(mins * 60.0)

	# 인벤토리는 dict 를 직접 세운다. grant_item 을 155번 부르면 레벨업 패널이 그만큼 뜨고
	# 진화 조건 순서까지 맞춰야 해서, 재현하려는 "상태"가 아니라 "경로"를 재게 된다.
	var w: Dictionary = preset.get("weapons", {})
	var p: Dictionary = preset.get("passives", {})
	if not w.is_empty():
		_events.weapons = w.duplicate()
	if not p.is_empty():
		_events.passives = p.duplicate()
	# ⚠️ `ItemDB.recompute(...)` 라고 쓰면 안 된다 — 전역 클래스명은 **컴파일 타임에 해석**되고,
	# `ItemDB.gd` 는 오토로드 `GameData` 를 참조한다. `--script` 로 실행되는 이 파일은 오토로드
	# 등록 전에 컴파일되므로 거기서 실패한다(위 `_gold_scene` 주석의 preload 함정과 같은 뿌리).
	#
	# 네이티브 헤드리스는 실패 후 다시 로드해 넘어가지만 **웹 빌드는 그대로 죽는다** —
	# `Failed to load script "res://tools/bench_lategame.gd"`. 즉 이렇게 쓰면 이 하네스는
	# 웹에서 한 번도 못 돈다. 런타임에 늦게 가져와 그 의존을 끊는다.
	var item_db: GDScript = load("res://scripts/ItemDB.gd")
	item_db.recompute(_events.weapons, _events.passives)
	_events.inventory_changed.emit()

	if int(_args.get("fill", "1")) != 0:
		cheats.request_spawn_fill()

	var probe := String(_args.get("probe", ""))
	if probe != "":
		_setup_probe(probe, cheats)
		# zn=N — 측정 대상 옆에 **가만히 있는 좀비 N 마리**를 세워 둔다(자기 로직은 끈 채로).
		# 공간 해시 질의 비용은 "격자에 몇 마리가 들어 있나"에 달려 있는데, 기존 probe 는 좀비가
		# 0 마리라 **질의가 가장 싼 상태만** 잰다. 유도탄처럼 반경 질의를 도는 개체는 그 상태에서
		# 재면 실제 비용의 일부만 보인다. 좀비를 세워 두면 개체 수를 고정한 채 질의 비용만 바뀐다.
		var zn := int(_args.get("zn", "0"))
		if zn > 0:
			_spawn_idle_zombies(zn)

	var off := String(_args.get("off", ""))
	if off != "":
		_off = Array(off.split(","))

	# only= 는 off= 의 반대다 — **전부 끄고 지정한 것만 켠다.**
	# off= 는 "그것만 뺀 나머지"를 재므로 남은 것들의 상호작용(개체 수 변화)이 섞이는데,
	# 실측 잡음이 ±1.3ms 라 1ms 급 항목은 그 안에 묻힌다. only= 는 절편이 0.1ms 인 정지 상태
	# 위에 한 계통만 얹으므로 그 계통의 몫이 그대로 읽힌다.
	_stress = int(_args.get("stress", "0")) != 0
	if _stress:
		_setup_stress(cheats)

	_hudscan = int(_args.get("hudscan", "0")) != 0

	var hide := String(_args.get("hide", ""))
	if hide != "":
		_hide = Array(hide.split(","))

	var only := String(_args.get("only", ""))
	if only != "":
		_only = Array(only.split(","))
		_quiesce()
		_enable_only()

	# 센티넬은 마지막에 만든다 — _quiesce() 보다 먼저 만들면 같이 꺼진다.
	_install_tick_probes()


## 핫패스 씬의 스크립트가 실제로 살아 있는지 확인하고, 아니면 **측정하지 않고 실패한다.**
##
## 스크립트가 죽은 채로도 하네스는 끝까지 돌아가 그럴듯한 표를 찍는다 — 탄이 움직이지도
## 않는데 "탄은 싸다"는 결론이 나온다. 조용히 틀린 수치를 내는 것이 이 도구의 최악의 실패라
## 여기서 종료 코드 1 로 끊는다. (원인은 위 `_gold_scene` 주석 참고)
func _assert_scripts_live() -> void:
	var bad: Array = []
	for path in ["res://scenes/Bullet.tscn", "res://scenes/Gold.tscn", "res://scenes/Zombie.tscn"]:
		var ps := load(path) as PackedScene
		if ps == null:
			bad.append("%s (로드 실패)" % path)
			continue
		var n := ps.instantiate()
		var sc = n.get_script()
		# `can_instantiate()` 는 컴파일에 실패한 GDScript 에서 false 다 — 스크립트 유무만으로는
		# 못 가른다(실패한 스크립트도 객체로는 붙어 있다).
		if sc == null or not (sc as GDScript).can_instantiate():
			bad.append("%s (스크립트 컴파일 실패)" % path)
		n.free()
	if bad.is_empty():
		return
	push_error("핫패스 스크립트가 죽어 있다: %s" % str(bad))
	print("")
	print("❌ 측정 중단 — 핫패스 스크립트가 죽어 있다: %s" % str(bad))
	print("   이 상태로 재면 그 개체의 비용이 0 으로 나온다. 대개 원인은 이 파일 상단의")
	print("   최상위 preload 다(오토로드 등록 전에 컴파일된다). load() 로 늦게 가져올 것.")
	_finished = true
	quit(1)


## probe 모드 전용 — 측정 대상 말고 **매 프레임 도는 것을 전부 멈춘다.**
## 남기는 것은 이벤트 버스(일시정지 워치독)와 풀(반납 큐)뿐이고, 그 둘은 _physics_process 가
## 없다. 이렇게 해야 절편이 상수가 되어 두 지점의 차이가 곧 개체당 비용이 된다.
##
## 여기서 끄고 나서 개체를 스폰한다 — 순서가 바뀌면 측정 대상까지 같이 꺼진다.
func _quiesce() -> void:
	var stack: Array = [root]
	var n := 0
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
		if node.is_physics_processing() or node.is_processing():
			node.set_physics_process(false)
			node.set_process(false)
			n += 1
	print("  [probe] 트리 정지 — %d 노드의 _process/_physics_process 를 껐다" % n)


## probe=zombie:N 용 좀비 종 데이터 — 스포너의 첫 티어 종을 그대로 가져온다.
## (임의로 만든 dict 를 넘기면 setup() 이 기대하는 키가 빠져 실제와 다른 개체가 된다)
func _zombie_type() -> Dictionary:
	var gd := root.get_node("GameData")
	for z in gd.zombie_list:
		return {
			"id": z.id, "speed": z.speed, "max_health": z.max_health,
			"modulate": z.modulate, "score": z.score, "contact": z.contact,
			"behavior": z.behavior, "scale": z.scale, "texture": z.texture,
		}
	return {"id": "x", "speed": 65.0, "max_health": 3, "modulate": Color.WHITE,
		"score": 1, "contact": 1, "behavior": "chase", "scale": 1.0}


## only= 대상 스크립트를 가진 노드만 다시 켠다(_quiesce 직후에 부른다).
## 부모가 꺼져 있어도 자식은 독립적으로 돌므로, 무기 모듈처럼 Player 의 자식인 계통도
## 단독으로 잴 수 있다.
func _enable_only() -> void:
	var stack: Array = [root]
	var n := 0
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
		var sc = node.get_script()
		if sc == null:
			continue
		if _only.has(String(sc.resource_path).get_file().get_basename()):
			node.set_physics_process(true)
			node.set_process(true)
			n += 1
	print("  [only] %s — %d 노드만 켰다" % [str(_only), n])


## 물리 틱의 시작/끝을 잡는 센티넬 두 개를 트리에 심는다.
## 순서는 트리 위치가 아니라 `process_physics_priority` 로 못 박는다 — 같은 우선순위 안의
## 호출 순서는 엔진 구현에 달렸지만, 우선순위가 다르면 낮은 쪽이 먼저인 것은 보장된다.
func _install_tick_probes() -> void:
	var head := TickProbe.new()
	head.name = "BenchTickHead"
	head.process_physics_priority = -10000
	root.add_child(head)
	var tail := TickProbe.new()
	tail.name = "BenchTickTail"
	tail.process_physics_priority = 10000
	tail.start_probe = head
	tail.sink = _tick_ms
	root.add_child(tail)
	_tick_end = tail
	_tick_head = head


## ── 최대 부하(worst case) 모드 ────────────────────────────────────────
## 평상시 판은 오토플레이가 좀비를 계속 녹여서 **최악이 재현되지 않는다**(후반 동시 좀비가
## 상한 320 의 1/10 인 25~40마리인 이유가 그것이다). 프레임 드랍은 평상시가 아니라 최악에서
## 나므로, 최악을 일부러 만들어 놓고 재는 모드가 따로 필요하다.
##
## 만드는 것: 좀비 상한까지 + 보스 + 만렙 빌드 + 젬 상한. 그리고 **계속 그 상태로 유지한다** —
## 한 번만 채우면 몇 초 만에 녹아 다시 평상시가 된다.
func _setup_stress(cheats: Node) -> void:
	cheats.request_spawn_fill()
	cheats.request_spawn_boss()
	print("  [stress] 최대 부하 모드 — 좀비 상한 + 보스 + 젬 상한을 계속 유지한다")


## 매 프레임 플레이어를 살려 두고, 1초마다 좀비·젬을 다시 채운다.
##
## ⚠️ **체력을 안 채우면 최악이 아니라 게임오버 화면을 재게 된다.** 좀비 상한(320) + 보스를
## 붙여 놓으면 접촉 피해로 몇 초 만에 죽고, 그 뒤로는 정지 화면이라 물리 틱이 아예 안 돈다.
## 실제로 그렇게 나왔다 — 표본 98/1200, 정지 소유자 `gameover` 1098프레임.
## `tools/profile_frame.gd` 가 같은 함정을 이미 겪고 같은 처방을 쓰고 있다.
func _stress_tick(delta: float) -> void:
	var p := get_first_node_in_group("player")
	if p != null and p.has_method("heal_full"):
		p.heal_full()
	_stress_t += delta
	if _stress_t < 1.0:
		return
	_stress_t = 0.0
	# 레벨업을 막는다 — 안 그러면 이 모드가 스스로를 못 재게 만든다.
	# 상한까지 채운 좀비가 계속 죽으면서 경험치가 폭주하고, 레벨업 카드가 뜰 때마다
	# LevelUpPanel 이 **0.7초 동안 게임을 정지**시킨 뒤에야 자동 선택한다(LevelUpPanel._auto_t).
	# 그 결과 측정 구간의 90% 가 일시정지가 되고(표본 145/1800), 물리 틱은 몇 개 못 건진 채
	# CPU 사용률만 낮게 나온다. 빌드는 이미 만렙으로 주입해 뒀으므로 레벨업은 이 시나리오에
	# 아무것도 더하지 않는다 — 경험치를 그냥 비워 둔다.
	_events.xp = 0
	var cheats := root.get_node("Cheats")
	cheats.request_spawn_fill()
	# 젬도 상한까지 밀어 올린다 — 좀비를 즉사시키면 젬이 안 쌓여 최악이 안 만들어진다.
	var need: int = int(root.get_node("GameData").balance.gem_live_cap) - _gem_count()
	if need > 0:
		var gs: PackedScene = _gold_scene if _gold_scene != null else load("res://scenes/Gold.tscn")
		_gold_scene = gs
		var pc: Vector2 = _player_pos()
		for i in mini(need, 40):
			var g: Node2D = root.get_node("Pool").acquire(gs, _main)
			var a := TAU * float(i) / 40.0
			# 자석 범위(130px) 밖 + **오토플레이 젬 탐색 반경(Cheats._GEM_R = 480px) 밖**에 둔다.
			# 안쪽에 두면 조종 AI 가 주우러 가서 경험치가 폭주하고, 레벨업 카드가 계속 떠서
			# 측정 구간의 80% 가 일시정지가 된다(표본 112/1500 이 그렇게 나왔다).
			# 여기 젬은 "필드에 떠 있는 140개의 매 프레임 비용"을 재는 것이 목적이라 위치는 무관하다.
			g.global_position = pc + Vector2(cos(a), sin(a)) * (620.0 + 60.0 * float(i % 5))


func _gem_count() -> int:
	return (load("res://scripts/Gold.gd") as GDScript).live_gems().size()


func _player_pos() -> Vector2:
	var p := get_first_node_in_group("player")
	return (p as Node2D).global_position if p != null else Vector2.ZERO


## probe 옆에 세워 둘 좀비 — 격자에는 들어가되 자기 비용은 0 이어야 하므로 처리를 꺼 둔다.
## 플레이어 주변에 흩어 놓는다(반경 질의가 실제로 후보를 찾도록).
func _spawn_idle_zombies(n: int) -> void:
	if _zombie_scene == null:
		_zombie_scene = load("res://scenes/Zombie.tscn")
	var td := _zombie_type()
	var pc := _player_pos()
	for i in n:
		var z: Node2D = root.get_node("Pool").acquire(_zombie_scene, _main)
		var a := TAU * float(i) / float(n)
		var r := 60.0 + 420.0 * float(i % 11) / 11.0
		z.global_position = pc + Vector2(cos(a), sin(a)) * r
		z.setup(td)
		z.set_physics_process(false)
		z.set_process(false)
	print("  [probe] 정지 좀비 %d 마리를 세웠다(격자에만 들어간다)" % n)


func _theme_by_id(gd, id: String):
	for t in gd.themes:
		if t.id == id:
			return t
	return null


func _pick(mgr_name: String, id: String, finder: Callable) -> void:
	if id == "":
		return
	var mgr := root.get_node(mgr_name)
	var data = finder.call(root.get_node("GameData"), id)
	if data == null:
		return
	if not mgr.is_unlocked(data):
		mgr._bought[id] = true
	mgr.select(id)


## 대조 실험 — 게임을 정지 상태로 만들고 원하는 개체만 N 개 놓는다.
## "무엇이 비싼가"를 재는 유일하게 믿을 만한 방법이다. 개체 수를 바꿔 두 번 재면
## 기울기가 곧 개체당 비용이고, 절편은 그 외 고정 비용이다.
##
## ⚠️ 스포너·오토플레이만 끄는 것으로는 부족했다. 오토플레이를 꺼도 **무기는 계속 발사된다**
## (뱀서식 자동 사격이라 Player._handle_attack 은 입력과 무관하다). 그래서 probe=gold:N 을
## 재는 동안에도 탄 141발이 계속 나고 죽으며 프레임을 흔들었고, 측정값이 개체 수와 무관해졌다
## (실측: gold:0 → 10.38ms, gold:140 → 9.54ms — 젬을 140개 얹었는데 더 빨라졌다).
## 그래서 probe 모드는 **트리 전체를 정지**시키고 측정 대상만 남긴다.
func _setup_probe(spec: String, cheats: Node) -> void:
	_gold_scene = load("res://scenes/Gold.tscn")
	_bullet_scene = load("res://scenes/Bullet.tscn")
	_zombie_scene = load("res://scenes/Zombie.tscn")
	var parts := spec.split(":")
	var kind := String(parts[0])
	var n := int(parts[1]) if parts.size() > 1 else 100
	cheats.autoplay = false
	# 스포너를 멈춘다 — 새 좀비가 계속 들어오면 대조군이 아니다.
	var sp := _main.find_child("ZombieSpawner", true, false)
	if sp != null:
		sp.set_physics_process(false)
		sp.set_process(false)
	for z in get_nodes_in_group("zombies"):
		root.get_node("Pool").release(z)
	_quiesce()
	var pos := Vector2(360, 640)
	for i in n:
		# 플레이어에서 멀리(자석 범위 밖) 흩어 둔다 — 즉시 수집되면 개체 수가 유지되지 않는다.
		var a := TAU * float(i) / float(n)
		var at := pos + Vector2(cos(a), sin(a)) * (900.0 + 400.0 * float(i % 7))
		match kind:
			"gold":
				var g: Node2D = root.get_node("Pool").acquire(_gold_scene, _main)
				g.global_position = at
			"bullet":
				var b: Node2D = root.get_node("Pool").acquire(_bullet_scene, _main)
				b.global_position = at
				b.direction = Vector2(cos(a), sin(a))
				b.lifetime = 9999.0
				b.speed = 1.0            # 화면 밖으로 날아가 버리지 않게(수명 판정만 돌게)
			"homing":
				# 유도탄 — 매 프레임 조준 대상을 찾느라 반경 질의를 돈다. 직진탄과 비용이
				# 완전히 다르므로 따로 잰다(직진탄만 재면 이 게임에서 가장 비싼 개체를 놓친다).
				var h: Node2D = root.get_node("Pool").acquire(_bullet_scene, _main)
				h.global_position = at
				h.direction = Vector2(cos(a), sin(a))
				h.lifetime = 9999.0
				h.speed = 1.0
				h.homing = 3.2          # gatling 과 같은 값
				h.homing_arc = deg_to_rad(55.0)
			"zombie":
				# 좀비는 스포너 경로를 그대로 쓴다 — setup() 이 스프라이트·반경·행동을 채운다.
				var z: Node2D = root.get_node("Pool").acquire(_zombie_scene, _main)
				z.global_position = at
				z.setup(_zombie_type())
	print("  [probe] %s %d 개 — 스포너·오토플레이 정지" % [kind, n])


## 지정한 스크립트의 _physics_process 만 끈다 — 노드·렌더는 그대로 두고 **로직만** 뺀다.
## 켠 상태와의 physics_ms 차이가 그 스크립트가 매 프레임 쓰는 시간이다.
## (풀 반납도 그 로직 안에서 일어나므로, 끈 항목은 개체 수가 늘어난다 — 결과의 개체 내역을
##  함께 볼 것. 그래서 이건 "얼마나 비싼가"의 상한 추정이지 정밀 측정이 아니다.)
## 스캔 전 판을 **완전히** 고정한다. 세 겹이 다 필요했다:
##  ① `_quiesce()` — 스크립트의 _process/_physics_process. 이것만으로는 부족했다.
##  ② `Engine.time_scale = 0` — 트윈·애니메이션은 노드 process 플래그가 아니라 시간으로 돈다.
##  ③ **월드를 통째로 숨긴다** — HUD 는 별도 CanvasLayer 라 월드와 배치가 섞이지 않는다.
##     남은 흔들림(FX 팝·좀비 사망)의 출처가 전부 월드였다. 숨기면 기준선이 곧 "HUD 만의 콜"이
##     되어 요소별 몫을 정확히 뺄 수 있다.
##
## ①②만 했을 때 기준선 진폭이 4 였고, 그 표에서는 Control 15개가 나란히 12콜로 나왔다 —
## 신호가 아니라 잡음이었다.
func _freeze_for_scan() -> void:
	_quiesce()
	_stress = false            # 좀비 보충도 멈춘다 — 개체 수가 변하면 안 된다
	Engine.time_scale = 0.0
	var hud := _find_by_name(root, "HUD")
	var hidden := 0
	for c in root.get_children():
		if c == hud:
			continue
		if c is CanvasItem or c is CanvasLayer:
			c.set("visible", false)
			hidden += 1
		else:
			# Main 같은 컨테이너 아래에 월드가 들어 있다 — 그 자식들을 본다.
			for g in c.get_children():
				if g == hud:
					continue
				if g is CanvasItem or g is CanvasLayer:
					g.set("visible", false)
					hidden += 1
	print("  [hudscan] 판 고정 — 로직 정지 · time_scale 0 · 월드 %d개 숨김(HUD 만 남긴다)" % hidden)


## ── hudscan — HUD 요소별 드로우 콜 절제 ──────────────────────────────
## `hide=HUD` 는 "HUD 전체가 몇 콜인가"만 알려 준다. **그 안에서 무엇이 내는지**를 알아야
## 고칠 곳을 고를 수 있는데, 요소마다 판을 새로 띄우면 판 조건(좀비 수·보스 유무)이 달라져
## 비교가 안 된다. 그래서 한 프로세스 안에서 하나씩 숨겼다 되돌리며 잰다.
##
## SceneTree 스크립트는 `await` 로 프레임을 끊을 수 없으므로 `_process` 안의 상태 기계다.
func _scan_tick() -> void:
	if _scan_i == -2:
		var hud := _find_by_name(root, "HUD")
		if hud == null:
			print("  [hudscan] HUD 를 못 찾았다")
			_finished = true
			return
		_scan_targets.clear()
		_collect_canvas_items(hud, _scan_targets)
		_scan_i = -1               # 먼저 기준선
		_scan_settle = _SCAN_SETTLE
		_scan_buf.clear()
		print("  [hudscan] HUD 아래 캔버스 아이템 %d개를 하나씩 절제한다" % _scan_targets.size())
		return
	if _scan_settle > 0:
		_scan_settle -= 1
		return
	_scan_buf.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	if _scan_buf.size() < _SCAN_SAMPLE:
		return

	var med := _median_int(_scan_buf)
	if _scan_i == -1:
		# ⚠️ `var lo := _scan_buf.min()` 로 쓰면 안 된다 — Array.min() 은 Variant 라
		# "추론 타입이 Variant" 경고가 에러로 승격돼 스크립트가 통째로 안 뜬다.
		# check_gdscript.py 도 --import 도 이걸 못 잡는다(OPTIMIZATION_PLAN §5-L).
		var lo: int = int(_scan_buf.min())
		var hi: int = int(_scan_buf.max())
		_scan_spread = hi - lo
	_scan_buf.clear()
	if _scan_i == -1:
		_scan_base = med
	else:
		var prev = _scan_targets[_scan_i]
		if is_instance_valid(prev):
			(prev as CanvasItem).visible = true
		_scan_out.append([_scan_base - med, String((prev as Node).name), (prev as Node).get_class()])

	# 다음 대상 — 이미 안 보이는 것은 건너뛴다(보스바처럼 조건부로 꺼져 있는 UI).
	_scan_i += 1
	while _scan_i < _scan_targets.size():
		var t = _scan_targets[_scan_i]
		if is_instance_valid(t) and (t as CanvasItem).is_visible_in_tree():
			(t as CanvasItem).visible = false
			_scan_settle = _SCAN_SETTLE
			return
		_scan_i += 1
	_scan_report()


func _scan_report() -> void:
	print("")
	print("── HUD 요소별 드로우 콜 (기준선 %d 콜 · 표본 진폭 %d) ──────" % [_scan_base, _scan_spread])
	if _scan_spread > 0:
		print("  ⚠️ 기준선이 %d 만큼 흔들린다 — 판이 덜 얼었다. 아래 표를 믿지 말 것." % _scan_spread)
	if _scan_base <= 1:
		print("  ⚠️ 기준선이 %d 이다 — 헤드리스(더미 렌더러)로 돌렸다. 실렌더가 필요하다:" % _scan_base)
		print("     LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s \"-screen 0 720x1280x24\" \\")
		print("       godot --path . --rendering-driver opengl3 --script res://tools/bench_lategame.gd -- hudscan=1")
	_scan_out.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	var shown := 0
	for r in _scan_out:
		if int(r[0]) <= 0:
			continue
		shown += 1
		print("  %3d 콜  %-24s %s" % [r[0], r[1], r[2]])
	if shown == 0:
		print("  (몫이 0 보다 큰 요소가 없다)")
	print("  — 0 이하는 생략. 절제는 가산적이지 않다(하나를 빼면 양옆이 합쳐진다).")
	_finished = true
	quit(0)


func _find_by_name(n: Node, nm: String) -> Node:
	if n.name == nm:
		return n
	for c in n.get_children():
		var r := _find_by_name(c, nm)
		if r != null:
			return r
	return null


func _collect_canvas_items(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is CanvasItem:
			out.append(c)
		_collect_canvas_items(c, out)


func _median_int(v: Array) -> int:
	if v.is_empty():
		return 0
	var t := v.duplicate()
	t.sort()
	return int(t[t.size() / 2])


## hide= 대상 캔버스 아이템을 안 보이게 한다. 로직은 건드리지 않는다 — 개체 수도 그대로다.
## 총계에서 이 차이가 곧 그 계통이 내는 드로우 콜이다(P1-22 의 "격리값이 아니라 절제와의 차이").
func _apply_hide() -> void:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var sc = n.get_script()
		# HUD 처럼 루트가 CanvasLayer 인 계통도 있다 — 둘 다 visible 을 가진다.
		if sc == null or not (n is CanvasItem or n is CanvasLayer):
			continue
		if _hide.has(String(sc.resource_path).get_file().get_basename()):
			n.set("visible", false)


## only= 대상만 켜고 나머지는 끈다. 센티넬 두 개는 건드리지 않는다 — 끄면 측정이 사라진다.
## `_process` 에서 돌므로 이 순회 자체는 물리 틱 측정에 섞이지 않는다.
func _apply_only() -> void:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n == _tick_head or n == _tick_end:
			continue
		var sc = n.get_script()
		var base: String = String(sc.resource_path).get_file().get_basename() if sc != null else ""
		var want: bool = base != "" and _only.has(base)
		# ⚠️ stress=1 에서는 ZombieSpawner 의 `_process` 를 끄면 안 된다. 좀비 보충은
		# Cheats.request_spawn_fill() → 스포너의 스폰 큐 → `_drain_spawn_queue()`(=`_process`)
		# 로 이어지는데, 그 마지막 칸을 끄면 큐가 비워지지 않아 **좀비가 320마리에서 7마리로
		# 사라진다.** 최대 부하 판 자체가 없어지므로 귀속을 잴 대상이 남지 않는다.
		# `_process` 는 물리 틱 센티넬 바깥이라 이 예외가 측정값에 섞이지 않는다.
		var keep_proc: bool = _stress and base == "ZombieSpawner"
		if want:
			if not n.is_physics_processing():
				n.set_physics_process(true)
			if not n.is_processing():
				n.set_process(true)
		else:
			if n.is_physics_processing():
				n.set_physics_process(false)
			if n.is_processing() and not keep_proc:
				n.set_process(false)
			elif keep_proc and not n.is_processing():
				n.set_process(true)


func _apply_off(verbose: bool) -> void:
	var stack: Array = [root]
	var n_off := 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var sc = n.get_script()
		if sc == null:
			continue
		if _off.has(String(sc.resource_path).get_file().get_basename()):
			n.set_physics_process(false)
			n_off += 1
	if verbose:
		print("  [off] %s — %d 노드의 _physics_process 를 껐다" % [str(_off), n_off])


## 살아있는 노드를 스크립트 파일별로 센다. "무엇이 몇 개 있나"가 곧 비용의 후보 목록이다.
func _count_nodes() -> Dictionary:
	var out: Dictionary = {}
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var sc = n.get_script()
		if sc == null:
			continue
		var key := String(sc.resource_path).get_file().get_basename()
		out[key] = int(out.get(key, 0)) + 1
	return out


func _stat(a: Array) -> Dictionary:
	if a.is_empty():
		return {"med": 0.0, "p95": 0.0, "max": 0.0}
	var s := a.duplicate()
	s.sort()
	return {
		"med": snappedf(float(s[int(s.size() * 0.5)]), 0.01),
		"p95": snappedf(float(s[mini(s.size() - 1, int(s.size() * 0.95))]), 0.01),
		"max": snappedf(float(s[s.size() - 1]), 0.01),
	}


func _report() -> void:
	var f := _stat(_frames)
	var fps_med: float = (1000.0 / float(f["med"])) if float(f["med"]) > 0.0 else 0.0
	var _bs2: Variant = load("res://scripts/Bullet.gd")
	if _bs2 != null and _homing_gone0 >= 0:
		_homing_gone = int(_bs2.stat_homing_gone) - _homing_gone0
		_homing_hit = int(_bs2.stat_homing_hit) - _homing_hit0
	var rec := {
		"build": String(_args.get("build", "engineer_late")),
		"min": float(_args.get("min", "26")),
		"frames": _frames.size(),
		"fps_med": snappedf(fps_med, 0.1),
		"frame_ms": f,
		"process_ms": _stat(_proc_ms),
		# ⚠️ 엔진 모니터 = 최근 1초의 **최댓값**(스파이크 지표). 이름을 그렇게 바꿔 둔다.
		"physics_worst_per_sec_ms": _stat(_phys_ms),
		# 센티넬로 직접 잰 틱 1회당 스크립트 비용(평상시 비용).
		"tick_ms": _stat(_tick_ms),
		"tick_samples": _tick_ms.size(),
		"ticks_per_frame": _stat(_ticks),
		"items": _stat(_items),
		"vram_mb": _stat(_vram),
		"tex_mb": _stat(_tex_mem),
		"zg_queries": _stat(_zg_q),
		"zg_builds": _stat(_zg_b),
		"draw_calls": _stat(_draw_calls),
		"collision_pairs": _stat(_pairs),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		# 유도탄 명중률 — 조준 주기를 건드릴 때의 안전망. kills_per_s 는 전체 무기가 섞여
		# 유도탄의 명중 변화를 못 가른다(런간 산포가 유도탄 몫보다 크다).
		"homing_gone": _homing_gone,
		"homing_hit": _homing_hit,
		"homing_hit_rate": snappedf(float(_homing_hit) / maxf(float(_homing_gone), 1.0), 0.001),
		"kills_per_s": snappedf(float(int(_events.total_kills) - maxi(_kills0, 0)) / maxf(_measure, 0.001), 0.1),
		"level": int(_events.level),
		"counts": _counts_last,
	}
	print("")
	print("── 후반 프레임 예산 (%s · %.0f분) ─────────────────────" % [rec["build"], rec["min"]])
	# 표본이 적으면 중앙값이 흔들린다 — 몇 개로 낸 수치인지 항상 같이 찍는다.
	# (헤드리스는 렌더가 없어 유휴 프레임이 드물게 돌 때가 있다. 표본 30 미만이면 믿지 말 것.)
	print("  프레임      중앙 %6.2fms  p95 %6.2fms  최악 %6.2fms   → %.1f fps   [표본 %d%s]"
		% [f["med"], f["p95"], f["max"], fps_med, _frames.size(),
			"  ⚠️믿을 수 없음" if _frames.size() < 30 else ""])
	print("  _process    중앙 %6.2fms  p95 %6.2fms" % [rec["process_ms"]["med"], rec["process_ms"]["p95"]])
	# 측정 구간 대부분이 일시정지(레벨업 카드 등)였으면 표본이 확 준다 — 그런 판은 상태가
	# 달라서 다른 판과 나란히 놓으면 안 된다. 스스로 그렇다고 찍는다.
	var want_ticks := int(_measure * 60.0)
	var thin: bool = int(rec["tick_samples"]) < want_ticks / 2
	print("  물리 틱     중앙 %6.3fms  p95 %6.3fms  최악 %6.3fms   [틱 %d/%d개%s]  ← 평상시 비용"
		% [rec["tick_ms"]["med"], rec["tick_ms"]["p95"], rec["tick_ms"]["max"],
			rec["tick_samples"], want_ticks,
			"  ⚠️구간 대부분이 일시정지 — 다른 판과 비교하지 말 것" if thin else ""])
	print("  physics     중앙 %6.2fms  p95 %6.2fms   ← 엔진 모니터 = 최근 1초의 **최댓값**"
		% [rec["physics_worst_per_sec_ms"]["med"], rec["physics_worst_per_sec_ms"]["p95"]])
	# 렌더 1프레임당 물리 틱. 1 이 아니면 physics_ms 는 여러 틱의 합이다 — 틱 단가로 환산해 같이 찍는다.
	var tk: float = maxf(float(rec["ticks_per_frame"]["med"]), 1.0)
	print("  물리틱/프레임 중앙 %6.2f %s"
		% [rec["ticks_per_frame"]["med"],
			"⚠️ 따라잡기 틱 발생 — 스스로를 부풀리는 구간이다" if tk > 1.05 else ""])
	var q: float = float(rec["zg_queries"]["med"])
	var b: float = float(rec["zg_builds"]["med"])
	print("  공간해시    질의 %6.0f/프레임  그중 9칸 순회 %6.0f  → 건너뜀 %4.0f%%"
		% [q, b, (1.0 - b / maxf(q, 1.0)) * 100.0])
	if int(rec["homing_gone"]) > 0:
		print("  유도탄      소멸 %5d발  그중 명중 %5d발  → 명중률 %4.1f%%"
			% [rec["homing_gone"], rec["homing_hit"], float(rec["homing_hit_rate"]) * 100.0])
	# GPU 로 나가는 양(기기 무관). 실제 GPU 사용률은 여기서 못 잰다 — 실기기/브라우저에서 볼 것.
	if float(rec["items"]["max"]) <= 0.0:
		print("  GPU 제출량  — 헤드리스(더미 렌더러)라 0 이다. 실렌더로 재려면:")
		print("              LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s \"-screen 0 720x1280x24\" \\")
		print("                godot --path . --rendering-driver opengl3 --script res://tools/bench_lategame.gd -- stress=1")
	else:
		print("  GPU 제출량  드로우콜 중앙 %5.0f 최악 %5.0f · 아이템 중앙 %5.0f 최악 %5.0f · VRAM %.1fMB(텍스처 %.1fMB)"
			% [rec["draw_calls"]["med"], rec["draw_calls"]["max"],
				rec["items"]["med"], rec["items"]["max"],
				float(rec["vram_mb"]["max"]) / 1048576.0, float(rec["tex_mb"]["max"]) / 1048576.0])
	print("  충돌쌍      중앙 %6.0f    최악 %6.0f" % [rec["collision_pairs"]["med"], rec["collision_pairs"]["max"]])
	if _paused_ticks > 0:
		var pk := _pause_tags.keys()
		pk.sort_custom(func(a, b): return int(_pause_tags[a]) > int(_pause_tags[b]))
		var parts: Array = []
		for k in pk:
			parts.append("%s %d" % [k, int(_pause_tags[k])])
		print("  일시정지    프레임 %d회 — 소유자: %s" % [_paused_ticks, ", ".join(parts)])
	print("  노드 %d · 레벨 %d · **초당 처치 %.1f**" % [rec["nodes"], rec["level"], rec["kills_per_s"]])
	# only= 로 잰 판은 "정말 그것만 켜져 있었나"를 같이 찍는다. 예전에 이 전제가 조용히
	# 무너져(풀에서 새로 나온 노드가 켜진 채로 돌았다) 귀속 표가 통째로 틀린 적이 있다.
	# 세어 두면 표를 읽는 사람이 그 판을 믿어도 되는지 한 줄로 판단할 수 있다.
	if not _hide.is_empty():
		print("  hide=%s — 그리기를 끈 상태의 값이다" % ",".join(PackedStringArray(_hide)))
	if not _only.is_empty():
		var on: Dictionary = {}
		var stack: Array = [root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for c in n.get_children():
				stack.append(c)
			if n == _tick_head or n == _tick_end or not n.is_physics_processing():
				continue
			var sc = n.get_script()
			var base: String = String(sc.resource_path).get_file().get_basename() if sc != null else "(스크립트 없음)"
			on[base] = int(on.get(base, 0)) + 1
		var parts2: Array = []
		for k in on:
			parts2.append("%s %d" % [k, on[k]])
		parts2.sort()
		print("  only=%s — 물리 처리 중인 노드: %s" % [
			",".join(PackedStringArray(_only)), ", ".join(parts2) if not parts2.is_empty() else "없음"])
	print("  개체 내역(스크립트별, 5개 이상만):")
	var keys := _counts_last.keys()
	keys.sort_custom(func(a, b): return int(_counts_last[a]) > int(_counts_last[b]))
	for k in keys:
		if int(_counts_last[k]) >= 5:
			print("    %-22s %4d" % [k, int(_counts_last[k])])
	print("")
	print("BENCH %s" % JSON.stringify(rec))


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.contains("="):
			var kv := s.split("=", true, 1)
			_args[kv[0]] = kv[1]
