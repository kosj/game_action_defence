extends SceneTree
## 무기 예산 게이트 (P1-19 도입 · P1-25 확장).
##
## 왜 필요한가
## -----------
## 후반 프레임을 먹는 것은 좀비가 아니라 **플레이어 자신이 만들어 내는 개체**다.
## 사람 기록 57표본에서 **좀비 수와 fps 의 상관은 +0.02** 로 사실상 무관했다 —
## 동시 좀비가 가장 많았던 5개 샘플은 전부 57~60fps 였고 그중엔 99마리 60fps 도 있다.
## 반대로 좀비를 5~15마리로 고정해 비교하면 레벨 67 이하는 27표본 중 24개가 60fps 인데
## 레벨 78 → 23.3ms, 97 → 38.3ms, 104 → 38.6ms 로 무너진다(`BALANCE.md` §3-13).
##
## P1-25 — 이 게이트에 구멍이 있었다
## ---------------------------------
## 처음 판(P1-19)은 `module == "projectile"` 인 무기의 **발사율**만 봤다. 그런데 카탈로그
## 30종 중 그 모듈은 7종뿐이다. 실제로 사람 기록에서 **38.3ms(26fps)까지 무너진 헌터 빌드**를
## 그 방식으로 재면 **4.2발/초**가 나왔다 — 그 빌드의 projectile 무기가 crossbow 하나여서다.
## **게이트는 초록인데 화면은 26fps** 였다.
##
## 발사율로는 애초에 잴 수 없는 것들이 있다. 장판(molotov·garlic·sanctuary)·궤도체(orb·drone)·
## 설치물(turret·mine)은 발사율이 0 이지만 상시 개체를 차지한다. **필요한 값은 발사율이 아니라
## 동시 존재 개체 수**다. 그래서 이 도구는 그것을 **실측**한다.
##
##   godot --headless --path . --fixed-fps 60 --script res://tools/verify_bullet_budget.gd
##
## 어떻게 재는가
## -------------
## `Main` 을 헤드리스로 띄우고 20분 시점으로 시계를 당긴 뒤, 스포너를 끄고 **죽지 않는 정지
## 좀비 30마리**를 고리 모양으로 세운다. 그 위에서 무기를 하나씩 만렙으로 갈아 끼우며
## 씬 안의 스크립트 노드 수를 매 프레임 세고, 측정 구간의 **평균**을 그 무기의 몫으로 삼는다.
##
## 왜 정지 좀비인가 — 스포너를 그대로 두면 좀비가 상한까지 차서 탄이 즉시 소멸한다(실측 16개).
## 그러면 "탄이 얼마나 쌓이나"가 아니라 "표적이 얼마나 빽빽한가"를 재게 된다. 사람 기록의
## 후반 동시 좀비는 13~56마리라 30마리가 그 한가운데다.
##
## 왜 최댓값이 아니라 평균인가 — 최댓값은 표본 간 편차가 ±12% 까지 벌어져 게이트가 흔들린다.
## 평균으로 바꾸면 최악 편차가 10% 로 줄고 대부분 ±2 안에 든다. 그래도 **잡음이 0 은 아니므로
## 상한은 실측 최악값 바로 위가 아니라 여유를 두고 잡았다**(아래 상수 주석 참고).
##
## ⚠️ 상한값은 **현재 최악값 위에 놓은 것**이지 최적값의 증명이 아니다.
## "오늘보다 나빠지지 않는다"를 잠그는 것이 목적이다. 올리려면 먼저 이 주석부터 다시 쓸 것.

## 무기 하나(만렙 + 패시브 만렙)가 동시에 살려 두는 개체 수 상한.
## 실측 최악은 gatling 76 이다. 무거운 무기일수록 값이 안정적이라(3회 실측 76/76/76,
## 상위 4종 편차 ±1) 여유를 크게 둘 이유가 없다 → 85(약 12%).
const MAX_ENTITIES_PER_WEAPON := 85

## 후반 빌드 하나가 동시에 살려 두는 개체 수 상한. 무기 하나하나가 예산 안이어도
## **합계는 얼마든지 커진다** — 후반 빌드는 7종을 동시에 만렙으로 들고 있다.
## 실측: 사람 크래시 빌드 최악 115(엔지니어 d5a7ffb · 18fps), 도구가 만든 최악 조합 176 → 200.
const MAX_ENTITIES_PER_BUILD := 200

## 한 무기가 최악 조건에서 낼 수 있는 초당 탄 수 상한(P1-19 의 원래 검사, 그대로 유지).
## 최악 조건 = 만렙 + 발사속도 패시브 만렙. 그때 `ProjectileWeapon._interval()` 의
## 하한(`fire_interval * 0.5`)이 걸리므로 상한은 `pellets / (fire_interval * 0.5)` 이다.
## 개체 수 실측이 이걸 대체하지는 않는다 — 발사율은 명중 판정 횟수도 함께 늘린다.
const MAX_SHOTS_PER_SEC := 32.0

## 만렙에서 레벨당 늘어나는 탄 수 규칙(`ProjectileWeapon._fire`): pellets + int((lvl-1)/4).
const PELLET_PER_LEVELS := 4
## 발사 간격 하한 배수(`ProjectileWeapon._interval`).
const INTERVAL_FLOOR_MUL := 0.5

## 측정 조건 ─────────────────────────────────────────────────────────
const IDLE_ZOMBIES := 30       # 사람 기록의 후반 동시 좀비(13~56)의 한가운데
const SKIP_MIN := 20.0         # 난이도 시계를 이 분으로 당긴다
const DRAIN_S := 1.5           # 무기를 내려놓고 풀 반납을 기다리는 시간
const SETTLE_S := 3.0          # 새 무기가 정상 상태에 도달할 시간
const MEASURE_S := 5.0         # 평균을 내는 구간
const SEED := 20260821         # 판마다 값이 흔들리지 않게 전역 RNG 를 고정한다

## 후반 빌드 — **사람 기록에서 실제로 프레임이 무너진 판**을 그대로 옮겼다.
## 임의로 만든 빌드로 재면 "실제로 느린 그 상태"가 아니라 다른 상태를 재게 된다.
const HUMAN_BUILDS := {
	"헌터 f0e3e90 (23.6분 43fps)": {"chainsaw": 8, "crossbow": 8, "drone": 8, "inferno": 5,
		"railgun": 5, "tesla": 8, "ult_arrowstorm": 8},
	"베테랑 c711f84 (23.3분 32fps)": {"boomerang": 8, "drone": 8, "gun": 8, "sanctuary": 5,
		"sawblade": 8, "shotgun": 8, "ult_quake": 8},
	"엔지니어 d5a7ffb (26.2분 18fps)": {"garlic": 8, "gatling": 5, "molotov": 8, "railgun": 5,
		"shotgun": 8, "turret": 8, "ult_orbital": 8},
	"베테랑 9b79bdc (24.3분 30fps)": {"gun": 8, "inferno": 5, "molotov": 8, "orb": 8,
		"sawblade": 8, "thunderstorm": 5, "ult_quake": 8},
}
## 후반 패시브 만렙 — 사람 기록의 후반 판이 전부 이 언저리다(탄 수·발사속도를 함께 올린다).
const PASSIVES := {"ammo_belt": 6, "armor": 8, "battery": 6, "crit": 7,
	"gunpowder": 8, "haste": 8, "rabbits_foot": 6}
## 도구가 스스로 만드는 최악 조합의 무기 수. 후반 빌드가 대체로 무기 7종이다.
const WORST_MIX_SIZE := 7

var _ev: Node = null
var _main: Node = null
var _queue: Array = []          # [라벨, 인벤토리 dict, 종류("무기"/"빌드")]
var _i := -1
var _stage := 0                 # 0=반납 1=안정화 2=측정
var _t := 0.0
var _sum := 0
var _n := 0
var _base := 0
var _solo: Array = []           # [id, 개체 수]
var _builds: Array = []         # [라벨, 개체 수]
var _worst_queued := false
var _booted := false
var _fail := 0


func _process(delta: float) -> bool:
	if not _booted:
		_boot()
		_booted = true
		return false
	_t += delta
	match _stage:
		0:
			if _t >= DRAIN_S:
				# 큐가 바닥나기 직전에 최악 조합을 만들어 붙인다 — 단독 실측이 다 끝난
				# 뒤라야 상위 N 종을 고를 수 있다.
				if _i + 1 >= _queue.size() and not _worst_queued:
					_queue_worst_mix()
				_i += 1
				if _i >= _queue.size():
					_report()
					return true
				_ev.weapons = (_queue[_i][1] as Dictionary).duplicate()
				_ev.passives = PASSIVES.duplicate()
				_recompute()
				_stage = 1
				_t = 0.0
		1:
			if _t >= SETTLE_S:
				_sum = 0
				_n = 0
				_stage = 2
				_t = 0.0
		2:
			_sum += _entities()
			_n += 1
			if _t >= MEASURE_S:
				var v := int(round(float(_sum) / maxf(_n, 1) - _base))
				if String(_queue[_i][2]) == "무기":
					_solo.append([String(_queue[_i][0]), v])
				else:
					_builds.append([String(_queue[_i][0]), v])
				_ev.weapons = {}
				_ev.passives = {}
				_recompute()
				_stage = 0
				_t = 0.0
	return false


func _boot() -> void:
	seed(SEED)
	_ev = root.get_node("Events")
	root.get_node("SaveManager").delete_save()
	_ev.reset()
	_main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(_main)
	current_scene = _main
	root.get_node("Cheats").request_time_skip(SKIP_MIN * 60.0)
	# 스포너를 멈춰 측정 중 개체 수가 바뀌지 않게 한다. 좀비가 상한까지 차면 탄이 즉시
	# 소멸해 "탄이 얼마나 쌓이나"가 아니라 "표적이 얼마나 빽빽한가"를 재게 된다.
	for n in _main.get_children():
		if String(n.name) in ["ZombieSpawner", "ItemPickupSpawner", "GimmickSpawner"]:
			n.set_physics_process(false)
			n.set_process(false)
	_spawn_targets()
	_ev.weapons = {}
	_ev.passives = {}
	_recompute()

	var gd := root.get_node("GameData")
	var ids: Array = []
	for w in gd.weapon_defs:
		if w != null:
			ids.append(String(w.id))
	ids.sort()
	for id in ids:
		var w = gd.weapon_def(id)
		_queue.append([id, {id: int(w.max_level)}, "무기"])
	for label in HUMAN_BUILDS:
		_queue.append([String(label), HUMAN_BUILDS[label], "빌드"])

	_base = _entities()
	print("무기 예산 게이트 — 동시 존재 개체 수 실측")
	print("  조건: %d분 시점 · 정지 좀비 %d마리 · 패시브 만렙 · 안정화 %.0fs 후 %.0fs 평균"
		% [int(SKIP_MIN), IDLE_ZOMBIES, SETTLE_S, MEASURE_S])
	print("  기준선(무기 0종) %d개 — 아래 수치는 전부 이 값을 뺀 것이다\n" % _base)
	_stage = 0
	_t = 0.0


## 단독 실측 상위 N 종을 한 빌드로 묶어 다시 잰다.
## **하드코딩하지 않는 이유** — 무기가 추가·조정되면 최악 조합도 바뀐다. 목록을 손으로
## 적어 두면 그때부터 이 검사는 옛 조합만 지키게 된다. 실측에서 직접 뽑아야 자동으로 따라온다.
func _queue_worst_mix() -> void:
	_worst_queued = true
	var s := _solo.duplicate()
	s.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	var mix: Dictionary = {}
	var gd := root.get_node("GameData")
	for i in mini(WORST_MIX_SIZE, s.size()):
		var id := String(s[i][0])
		mix[id] = int(gd.weapon_def(id).max_level)
	_queue.append(["최악 조합(단독 상위 %d종)" % WORST_MIX_SIZE, mix, "빌드"])


func _recompute() -> void:
	# ⚠️ `ItemDB.recompute(...)` 라고 쓰면 안 된다 — 전역 클래스명은 컴파일 타임에 해석되고
	# `ItemDB.gd` 는 오토로드 `GameData` 를 참조한다. `--script` 로 도는 이 파일은 오토로드
	# 등록 전에 컴파일되므로 거기서 실패한다(`bench_lategame.gd` 에 같은 함정 기록이 있다).
	load("res://scripts/ItemDB.gd").recompute(_ev.weapons, _ev.passives)
	_ev.inventory_changed.emit()


## 죽지 않는 정지 좀비를 고리 모양으로 세운다. 체력을 크게 주는 이유는 측정 중 표적 수가
## 변하면 안 되기 때문이다 — 표적이 줄면 탄 수명이 늘어 값이 위로 흐른다.
func _spawn_targets() -> void:
	var zs := load("res://scenes/Zombie.tscn") as PackedScene
	var gd := root.get_node("GameData")
	var z0 = gd.zombie_list[0]
	var td := {"id": z0.id, "speed": 0.0, "max_health": 1000000000,
		"modulate": z0.modulate, "score": 0, "contact": 0,
		"behavior": z0.behavior, "scale": z0.scale, "texture": z0.texture}
	var pc := _player_pos()
	for i in IDLE_ZOMBIES:
		var z: Node2D = root.get_node("Pool").acquire(zs, _main)
		var a := TAU * float(i) / float(IDLE_ZOMBIES)
		z.global_position = pc + Vector2(cos(a), sin(a)) * (90.0 + 300.0 * float(i % 7) / 7.0)
		z.setup(td)
		z.set_physics_process(false)
		z.set_process(false)


func _player_pos() -> Vector2:
	for p in get_nodes_in_group("player"):
		return (p as Node2D).global_position
	return Vector2.ZERO


## 씬 안의 스크립트 달린 노드 수. 탄·장판·궤도체·설치물·데미지 숫자·FX 가 전부 여기 들어간다.
## 프레임 비용은 "무엇인가"가 아니라 "몇 개가 매 틱 도는가"에 달려 있으므로 종류를 가르지 않는다.
func _entities() -> int:
	var n := 0
	var stack: Array = [_main]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		for c in x.get_children():
			stack.append(c)
		if x.get_script() != null:
			n += 1
	return n


func _report() -> void:
	var gd := root.get_node("GameData")

	# ── 1) 무기별 동시 존재 개체 수 ──────────────────────────────────
	_solo.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	print("[1/3] 무기 단독 만렙 · 동시 존재 개체 수 (상한 %d)" % MAX_ENTITIES_PER_WEAPON)
	for r in _solo:
		var over: bool = int(r[1]) > MAX_ENTITIES_PER_WEAPON
		if over:
			_fail += 1
		print("  %-4s %-16s %4d" % [("FAIL" if over else "ok"), r[0], r[1]])
	# 커버리지를 명시한다. P1-25 가 생긴 이유가 "초록이 무엇을 보장하는지 출력만 봐서는
	# 알 수 없었다" 이므로, 몇 종 중 몇 종을 쟀는지 항상 찍는다.
	print("  → 카탈로그 %d종 중 %d종 측정 (커버리지 %.0f%%)"
		% [gd.weapon_defs.size(), _solo.size(),
			100.0 * float(_solo.size()) / maxf(gd.weapon_defs.size(), 1)])
	if _solo.size() != gd.weapon_defs.size():
		_fail += 1
		print("  FAIL 측정하지 못한 무기가 있다 — 커버리지 구멍이 다시 생겼다(P1-25)")

	# ── 2) 빌드 합계 ────────────────────────────────────────────────
	_builds.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	print("\n[2/3] 후반 빌드 합계 · 동시 존재 개체 수 (상한 %d)" % MAX_ENTITIES_PER_BUILD)
	for r in _builds:
		var over: bool = int(r[1]) > MAX_ENTITIES_PER_BUILD
		if over:
			_fail += 1
		print("  %-4s %-32s %4d" % [("FAIL" if over else "ok"), r[0], r[1]])

	# ── 3) 발사율 (P1-19 의 원래 검사) ──────────────────────────────
	var rows: Array = []
	for w in gd.weapon_defs:
		if w == null or String(w.module) != "projectile":
			continue
		var lvl: int = int(w.max_level)
		var pellets: int = int(w.pellets) + int((lvl - 1) / PELLET_PER_LEVELS)
		var floor_iv: float = float(w.fire_interval) * INTERVAL_FLOOR_MUL
		if floor_iv <= 0.0:
			_fail += 1
			print("  FAIL %-14s fire_interval 이 0 이다 — 발사율이 무한대가 된다" % w.id)
			continue
		rows.append({"id": String(w.id), "lvl": lvl, "pellets": pellets,
			"iv": float(w.fire_interval), "rate": float(pellets) / floor_iv})
	rows.sort_custom(func(a, b): return float(a["rate"]) > float(b["rate"]))
	print("\n[3/3] 발사율 (projectile 모듈 %d종만 · 상한 %.0f발/초)"
		% [rows.size(), MAX_SHOTS_PER_SEC])
	for r in rows:
		var over: bool = float(r["rate"]) > MAX_SHOTS_PER_SEC
		if over:
			_fail += 1
		print("  %-4s %-15s Lv%d  탄 %d / %.3fs  →  %5.1f 발/초"
			% [("FAIL" if over else "ok"), r["id"], r["lvl"], r["pellets"],
				float(r["iv"]) * INTERVAL_FLOOR_MUL, float(r["rate"])])
	if rows.is_empty():
		_fail += 1
		print("  FAIL 발사체 무기를 하나도 못 찾았다 — 카탈로그 로드가 깨졌다")

	# 카탈로그가 통째로 줄어드는 사고를 막는다. 실제로 생성기와 .tres 가 어긋나 있어서,
	# 규약대로 재생성했더니 무기 4종(부메랑·궁극기 3종)이 조용히 사라졌다(P1-19 에서 발견).
	# 궁극기는 캐릭터마다 하나씩 묶여 있어(`CharacterData.ultimate_weapon`) 사라지면 반쪽이 된다.
	var ults: Array = []
	for c in gd.characters:
		if c != null and String(c.ultimate_weapon) != "":
			ults.append(String(c.ultimate_weapon))
	for id in ults:
		if gd.weapon_def(id) == null:
			_fail += 1
			print("  FAIL 궁극기 '%s' 가 카탈로그에 없다 — 그 캐릭터가 궁극기 없이 플레이된다" % id)
	print("  ok   캐릭터 궁극기 %d종 전부 카탈로그에 있다" % ults.size())

	if _fail == 0:
		print("\n무기 예산 OK")
		quit(0)
	else:
		print("\n무기 예산 실패 %d건" % _fail)
		quit(1)
