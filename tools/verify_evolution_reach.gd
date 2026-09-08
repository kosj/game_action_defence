extends SceneTree
## 진화 도달성 가드 (P1-35).
##
## 왜 필요한가
## -----------
## 진화 11종은 **베이스 무기 만렙(Lv8) + 짝꿍 패시브 1** 이 조건이다
## (`Events.available_evolutions`). 그런데 강화 카드는 후보를 **균등하게 섞어** 3장을 뽑았고,
## 슬롯이 차면(무기 6 + 패시브 6) 후보가 12개라 특정 아이템이 뜰 확률이 25% 였다.
## 무기 하나를 Lv1→8 로 올리는 데 평균 **28번의 레벨업** — 캐릭터 레벨 40 근처다.
##
## 실측(2026-09-08 · 36판): Lv8 에 닿은 판 **2판** · 진화 **0판**.
## 사람 기록 3판(레벨 36·39·62)에서도 진화는 레벨 62 판 하나뿐이었다.
## 즉 **진화는 판이 끝나는 지점 너머에 있었다** — 만들어 두고 아무도 못 보는 콘텐츠였다.
##
## `BalanceData.levelup_focus_weight` 가 이미 올린 아이템의 등장 확률을 레벨에 비례해 높여
## 집중을 운이 아니라 **선택**으로 만든다. 이 파일은 그 성질이 데이터에서 깨지지 않는지 본다.
##
##   godot --headless --path . --script res://tools/verify_evolution_reach.gd
##
## ⚠️ 임계값은 **현재 값 바로 바깥**에 놓은 것이지 최적값의 증명이 아니다.
## 의도를 바꾸려면 상수를 고치기 전에 이 주석과 `BALANCE.md` §2 부터 다시 쓸 것.

## 뽑기 시뮬레이션 — **시작 무기에 집중하는** 플레이어가 그 무기를 만렙으로 만들기까지
## 걸리는 레벨업 횟수의 중앙값 상한.
##
## 왜 시작 무기인가 — 아직 갖지도 않은 무기에 미리 집중하는 플레이어는 없다. 미보유 아이템은
## 레벨 0 이라 가중치가 1 로 다른 신규 카드와 같고, 그것이 뽑히기까지의 대기는 집중과 무관한
## 별개의 지연이다(실측: `orb` 는 가중치를 8까지 올려도 27~32회에서 평평하다). 판정은 "집중이
## 보상받는가"를 물어야 하므로 **모든 판이 Lv1 로 갖고 시작하는 무기**를 기준으로 삼는다.
const FOCUS_TARGET := "gun"
## 실측에서 오토플레이는 레벨 21~27 에서 죽고 사람 3판은 36·39·62 였다.
## 이 값을 넘으면 진화가 다시 "판이 끝나는 지점 너머"로 간다.
const MAX_LEVELUPS_TO_EVOLVE := 22
## 균등 추출(가중치 0)이었을 때의 값 — 이 검사가 실제로 회귀를 잡는지 스스로 확인한다.
## 이 값 밑으로 내려가면 검사가 무의미해진 것이다(가드의 가드).
const UNIFORM_LEVELUPS_MIN := 30

const TRIALS := 150
const CARDS := 3            # LevelUpPanel._draw_choices(3)
const SEED := 20260908      # 판마다 값이 흔들리지 않게 고정한다

var _fail := 0
var _rng := RandomNumberGenerator.new()
## 카탈로그 스냅샷 — {id, max, is_weapon}. 루프 안에서 ItemDB 를 다시 조회하면
## 수백만 번 불려 검사가 분 단위로 늘어난다.
var _cat: Array = []
var _w_slots := 6
var _p_slots := 6


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   %s" % label)
	else:
		_fail += 1
		print("  FAIL %s%s" % [label, ("  — " + detail) if detail != "" else ""])


## `LevelUpPanel._draw_choices` 와 같은 후보 구성·가중치로 한 판을 흉내 낸다.
## 게임을 띄우지 않고 **뽑기만** 재현하므로 밀리초 단위로 끝난다.
func _levelups_to_max(target: String, focus: float) -> int:
	var weapons := {"gun": 1}                # 시작 무기(ItemDB 규약)
	var passives := {}
	var target_max := 0
	for c in _cat:
		if String(c["id"]) == target:
			target_max = int(c["max"])
	for n in range(400):
		if int(weapons.get(target, 0)) >= target_max:
			return n
		var pool := _pool(weapons, passives)
		if pool.is_empty():
			return n
		var drawn := _weighted_take(pool, CARDS, focus)
		# 집중형 플레이어: 목표 무기가 보이면 무조건 집고, 없으면 아무거나 집는다.
		var pick: Dictionary = drawn[_rng.randi() % drawn.size()]
		for c in drawn:
			if String(c["id"]) == target:
				pick = c
				break
		var inv: Dictionary = weapons if bool(pick["is_weapon"]) else passives
		inv[String(pick["id"])] = int(inv.get(String(pick["id"]), 0)) + 1
	return 999


## `LevelUpPanel._collect` 와 같은 규칙 — 보유(만렙 미만) + 슬롯 여유 시 미보유.
func _pool(weapons: Dictionary, passives: Dictionary) -> Array:
	var wfree: bool = weapons.size() < _w_slots
	var pfree: bool = passives.size() < _p_slots
	var out: Array = []
	for c in _cat:
		var is_w: bool = bool(c["is_weapon"])
		var lv: int = int((weapons if is_w else passives).get(c["id"], 0))
		if lv > 0:
			if lv < int(c["max"]):
				out.append({"id": c["id"], "lv": lv, "is_weapon": is_w})
		elif (wfree if is_w else pfree):
			out.append({"id": c["id"], "lv": 0, "is_weapon": is_w})
	return out


func _weighted_take(pool: Array, n: int, focus: float) -> Array:
	var out: Array = []
	var rest: Array = pool.duplicate()
	while out.size() < n and not rest.is_empty():
		var total := 0.0
		for a in rest:
			total += 1.0 + float(a["lv"]) * focus
		var roll := _rng.randf() * total
		var idx := rest.size() - 1
		for i in rest.size():
			roll -= 1.0 + float(rest[i]["lv"]) * focus
			if roll <= 0.0:
				idx = i
				break
		out.append(rest[idx])
		rest.remove_at(idx)
	return out


func _median_levelups(target: String, focus: float) -> float:
	var xs: Array = []
	for i in TRIALS:
		xs.append(_levelups_to_max(target, focus))
	xs.sort()
	return float(xs[xs.size() / 2])


## ⚠️ `_initialize()` 가 아니라 `_init()` + `await process_frame` 이다 — 오토로드의 `_ready`
## 는 그 다음 프레임에 돈다. `_initialize` 에서 읽으면 `GameData.balance` 가 아직 null 이다
## (`verify_late_hp.gd` 도 같은 이유로 이 꼴이다).
func _init() -> void:
	await process_frame
	_rng.seed = SEED
	var gd = root.get_node("GameData")
	# ⚠️ `ItemDB.X` 라고 쓰면 안 된다 — 전역 클래스명은 컴파일 타임에 해석되고 `ItemDB.gd` 는
	# 오토로드 `GameData` 를 참조한다. `--script` 로 도는 이 파일에서는 그 시점에 오토로드가
	# 없어 컴파일이 통째로 깨진다(`verify_bullet_budget.gd` 에 같은 주석이 있다).
	var itemdb := load("res://scripts/ItemDB.gd")
	_w_slots = int(itemdb.MAX_WEAPON_SLOTS)
	_p_slots = int(itemdb.MAX_PASSIVE_SLOTS)
	for w in gd.weapon_defs:
		if not w.evolved:                          # 진화 무기는 카드로 등장하지 않는다
			_cat.append({"id": w.id, "max": w.max_level, "is_weapon": true})
	for pd in gd.passive_defs:
		_cat.append({"id": pd.id, "max": pd.max_level, "is_weapon": false})
	var focus: float = float(gd.balance.levelup_focus_weight)

	print("── 진화 도달성 ─────────────────────────────────────")
	print("  강화 카드 %d장 · 무기 슬롯 %d · 패시브 슬롯 %d · 집중 가중치 %.2f · 표본 %d"
		% [CARDS, _w_slots, _p_slots, focus, TRIALS])

	# 진화 표 정합성 — 베이스·짝꿍·진화체가 전부 카탈로그에 있고 방향이 맞는가.
	# `item_catalog.tres` 는 생성기 산출물이고 과거에 손편집으로 어긋난 적이 있다(CLAUDE.md §2).
	var evos: Array = []
	for e in gd.evolution_defs:
		evos.append({"base": e.base_id, "passive": e.passive_id, "into": e.into_id})
	var bad: Array = []
	for e in evos:
		var bw = gd.weapon_def(String(e["base"]))
		var pp = gd.passive_def(String(e["passive"]))
		var iw = gd.weapon_def(String(e["into"]))
		if bw == null or pp == null or iw == null or bw.evolved or not iw.evolved:
			bad.append("%s+%s→%s" % [e["base"], e["passive"], e["into"]])
	_check("진화 %d종의 베이스·짝꿍·진화체가 카탈로그와 맞는다" % evos.size(),
		bad.is_empty() and evos.size() > 0, ", ".join(bad))

	# 시작 무기에 진화 짝꿍이 있는가 — 없으면 이 검사의 전제가 무너진다.
	var has_pair := false
	for e in evos:
		if String(e["base"]) == FOCUS_TARGET:
			has_pair = true
	_check("시작 무기 '%s' 에 진화 경로가 있다" % FOCUS_TARGET, has_pair)

	# 도달성 — 집중이 실제로 보상받는가.
	var focused := _median_levelups(FOCUS_TARGET, focus)
	print("  '%s' 집중 시 만렙까지 레벨업 %.0f회 (중앙값)" % [FOCUS_TARGET, focused])
	_check("집중하면 %d 레벨업 안에 진화 조건(무기 만렙)에 닿는다" % MAX_LEVELUPS_TO_EVOLVE,
		focused <= float(MAX_LEVELUPS_TO_EVOLVE), "실제 %.0f회" % focused)

	# 가드의 가드 — 균등 추출로 되돌리면 이 검사가 실제로 FAIL 하는가.
	var uniform := _median_levelups(FOCUS_TARGET, 0.0)
	print("  (대조) 균등 추출이면 %.0f회" % uniform)
	_check("균등 추출은 %d회를 넘는다 — 이 검사가 회귀를 실제로 잡는다는 확인"
		% UNIFORM_LEVELUPS_MIN,
		uniform >= float(UNIFORM_LEVELUPS_MIN), "실제 %.0f회" % uniform)

	if _fail == 0:
		print("\n진화 도달성 OK")
		quit(0)
	else:
		print("\n실패 %d건" % _fail)
		quit(1)
