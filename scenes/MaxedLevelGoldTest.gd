extends Node
## 만렙 상태 레벨업 → 골드 보상 회귀 테스트.
##
## 실행:
##   godot --headless --path . res://scenes/MaxedLevelGoldTest.tscn
##
## 배경: 보유 아이템이 전부 만렙이고 슬롯도 꽉 차면 강화 카드가 한 장도 안 나온다.
## 예전에는 그 레벨업이 아무 보상 없이 조용히 소비돼, 후반에 젬을 주울 이유가 사라졌다.
## (게다가 패널은 뜨자마자 닫혀 정지·징글·폭죽만 깜빡였다.)
##
## 검사 항목
##   T1 고를 카드가 있으면 골드 보상이 나가지 않는다(기존 동작 유지)
##   T2 고를 카드가 없으면 레벨업이 골드로 보상된다
##   T3 그때 패널이 뜨지 않는다(트리가 정지되지 않는다)
##   T4 지급액이 밸런스 공식과 일치한다 — clamp(base + per_level × 레벨, 0, max)
##   T5 상한(max)이 실제로 걸린다

const MAIN := preload("res://scenes/Main.tscn")

var _ok: int = 0
var _total: int = 0
var _events: Array = []      # [[level, gold], ...] — maxed_level_gold 수신 기록


func _ready() -> void:
	add_child(MAIN.instantiate())
	Events.maxed_level_gold.connect(func(lv: int, g: int): _events.append([lv, g]))
	_run()


func _wait(sec: float) -> void:
	var until := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _check(name: String, cond: bool) -> void:
	_total += 1
	if cond:
		_ok += 1
	print("%s %s" % ["PASS" if cond else "FAIL", name])


## 밸런스 공식 그대로의 기대 지급액(메타 배수 적용 전).
func _expected(level: int) -> int:
	var b: BalanceData = GameData.balance
	return clampi(b.maxed_level_gold_base
		+ int(round(b.maxed_level_gold_per_level * float(level))), 0, b.maxed_level_gold_max)


## 강화 카드가 한 장도 안 나오는 "완성된 빌드" 를 만든다.
## 무기/패시브 슬롯을 만렙으로 채우고, 슬롯 규칙을 무시하는 캐릭터 궁극기까지 보유시킨다.
func _fill_maxed_build() -> void:
	Events.weapons = {}
	Events.passives = {}
	var n := 0
	for w in ItemDB.weapons():
		if bool(w.get("evolved", false)) or String(w["id"]).begins_with("ult_"):
			continue
		Events.weapons[w["id"]] = int(w["max"])
		n += 1
		if n >= ItemDB.MAX_WEAPON_SLOTS:
			break
	var c: CharacterData = CharacterManager.selected()
	if c != null and c.ultimate_weapon != "":
		var um := ItemDB.meta(c.ultimate_weapon)
		if not um.is_empty():
			Events.weapons[c.ultimate_weapon] = int(um["max"])
	var m := 0
	for p in ItemDB.passives():
		Events.passives[p["id"]] = int(p["max"])
		m += 1
		if m >= ItemDB.MAX_PASSIVE_SLOTS:
			break
	ItemDB.recompute(Events.weapons, Events.passives)


func _run() -> void:
	Events.reset()
	await _wait(0.5)
	var sp: Node = get_tree().current_scene.get_node_or_null("ZombieSpawner")
	if sp != null:
		sp.set_process(false)
	Cheats.autoplay = true       # 카드가 뜨는 경우 자동으로 골라 진행시킨다

	# --- T1: 아직 고를 게 남은 평범한 상태 ---
	_events.clear()
	var gold0: int = Events.total_gold
	Events.bonus_level()
	await _wait(1.5)
	_check("T1 카드가 있으면 골드 보상 없음", _events.is_empty())

	# --- T2/T3/T4: 완성된 빌드에서 레벨업 ---
	_fill_maxed_build()
	await get_tree().process_frame
	_check("사전조건: 뽑을 카드가 하나도 없음", ItemDB.weapons().size() > 0 and _no_choices())
	_events.clear()
	gold0 = Events.total_gold
	var lv0: int = Events.level
	Events.bonus_level()
	await get_tree().process_frame
	var paused_now: bool = get_tree().paused
	await _wait(1.5)

	print("  레벨 %d → %d / 골드 %d → %d / 이벤트 %d건"
		% [lv0, Events.level, gold0, Events.total_gold, _events.size()])
	_check("T2 만렙 레벨업이 골드로 보상됨",
		_events.size() == 1 and Events.total_gold > gold0)
	_check("T3 패널이 뜨지 않아 트리가 정지되지 않음", not paused_now)
	if _events.size() == 1:
		var want := _expected(int(_events[0][0]))
		print("  지급 %d / 공식 기대 %d (메타 배수 %.2f)" % [int(_events[0][1]), want, Events.gold_mult])
		_check("T4 지급액이 밸런스 공식과 일치 (배수 반영)", int(_events[0][1]) >= want)
	else:
		_check("T4 지급액이 밸런스 공식과 일치 (배수 반영)", false)

	# --- T5: 고레벨에서 상한이 걸리는가 ---
	_events.clear()
	Events.level = 500
	Events.bonus_level()
	await _wait(1.0)
	var cap: int = GameData.balance.maxed_level_gold_max
	print("  레벨 501 지급=%d / 상한=%d" % [int(_events[0][1]) if _events.size() > 0 else -1, cap])
	_check("T5 지급액 상한이 걸림",
		_events.size() == 1 and int(_events[0][1]) <= int(round(float(cap) * Events.gold_mult)) + 2)

	print("RESULT ok=%d/%d" % [_ok, _total])
	await get_tree().process_frame
	get_tree().quit(0 if _ok == _total else 1)


## LevelUpPanel._draw_choices 와 같은 조건 — 뽑을 후보가 하나도 없는가.
func _no_choices() -> bool:
	for w in ItemDB.weapons():
		var lv: int = int(Events.weapons.get(w["id"], 0))
		if lv > 0 and lv < int(w["max"]):
			return false
		if lv == 0 and not bool(w.get("evolved", false)) \
				and Events.weapons.size() < ItemDB.MAX_WEAPON_SLOTS:
			return false
	for p in ItemDB.passives():
		var lv2: int = int(Events.passives.get(p["id"], 0))
		if lv2 > 0 and lv2 < int(p["max"]):
			return false
		if lv2 == 0 and Events.passives.size() < ItemDB.MAX_PASSIVE_SLOTS:
			return false
	return true
