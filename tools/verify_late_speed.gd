extends SceneTree
## 후반 이속 밸런스 가드 (P1-5).
##
## 이 게임의 적 이속은 시간에 비례해 오른다(`ZombieSpawner._speed_mult()`).
## 언젠가 가장 빠른 좀비가 플레이어를 추월하는데, **그 자체는 의도된 압박이다** —
## 30분을 끝까지 도망만 쳐서 클리어할 수 있으면 화력 빌드가 의미를 잃는다.
## 문제가 되는 건 그 지점이 너무 이르거나(런 대부분이 강제 추격), 반대로
## 어떤 투자로도 뿌리칠 수 없어서(이속 스탯이 죽은 스탯) 선택이 사라지는 경우다.
##
## 아래 4가지가 그 설계 의도다. 좀비 speed·difficulty.tres·위협 등급·패시브 최대치
## 어느 하나를 손대도 여기서 걸린다. 수치를 바꾸고 싶으면 **먼저 이 파일의 의도를
## 다시 정하고** 상수를 고칠 것 — 조용히 통과시키면 가드가 아니라 장식이 된다.
##
##   godot --headless --path . --script res://tools/verify_late_speed.gd
##
## 근거 수치와 사람 실측은 BALANCE.md §3-7 참고.

## Player.gd:528 — move_speed = _base_move_speed + 30.0 * Events.upgrade_speed
const PER_LEVEL_SPEED := 30.0
## 클리어 포맷(30분). 이 시점의 힘 관계가 후반 밸런스의 기준선이다.
const CLEAR_MINUTES := 30.0
## 투자 0 에서 추월당하기 시작하는 최소 시점. 이보다 이르면 런 절반 이상이 강제 추격이 된다.
const MIN_CROSSOVER_MIN := 15.0
## 30분 시점에 "해법이 있다"를 보장하는 이속 합계(패시브+메타+캐릭터 보정).
## 이 정도 투자로도 못 뿌리치면 이속은 선택지가 아니라 세금이다.
const SOLVABLE_SPEED_LV := 3

var _fail := 0


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   %s" % label)
	else:
		_fail += 1
		print("  FAIL %s%s" % [label, ("  — " + detail) if detail != "" else ""])


func _init() -> void:
	await process_frame

	var gd := root.get_node("GameData")
	var ev := root.get_node("Events")
	var tm := root.get_node("ThreatManager")
	var diff = gd.difficulty

	# ── 적 쪽 수치 ────────────────────────────────────────────────
	# 가장 빠른 좀비 하나가 곧 "뿌리칠 수 있는가"의 기준이다(느린 놈은 어차피 안 따라온다).
	var fastest := 0.0
	var fastest_id := ""
	for z in gd.zombie_list:
		if z != null and float(z.speed) > fastest:
			fastest = float(z.speed)
			fastest_id = String(z.id)
	# 모드 보정(Events._MODE_ENEMY_SPEED)만 떼어 낸다 — 공식을 여기서 다시 쓰지 않기 위함.
	var mode_mult: float = ev.diff_enemy_speed_mult() / tm.enemy_speed_mult()
	var threat_min: float = float(tm.data(1).enemy_speed_mult)
	var threat_max := threat_min
	for r in range(1, tm.count() + 1):
		threat_max = maxf(threat_max, float(tm.data(r).enemy_speed_mult))

	# ── 플레이어 쪽 수치 ──────────────────────────────────────────
	var p = load("res://scripts/Player.gd").new()
	var base_speed: float = float(p.move_speed)
	p.free()
	# 이속 합계의 상한 = 패시브 운동화 + 메타 신속 + 캐릭터 보정.
	var passive_max := 0
	for pd in gd.passive_defs:
		if pd != null and pd.effect == "move_speed":
			passive_max += int(round(float(pd.max_level) * pd.per_level))
	var meta_max := 0
	for mu in gd.meta_upgrades:
		if mu != null and mu.effect_kind == "move_speed":
			meta_max += int(round(float(mu.max_level) * mu.effect_per_level))
	var char_max := 0
	for c in gd.characters:
		if c != null:
			char_max = maxi(char_max, int(c.bonus_move_speed))
	var lv_max := passive_max + meta_max + char_max

	print("적: %s %.0f · 모드 x%.2f · 위협 x%.2f~x%.5f · 램프 %.3f/분 · 캡 x%.2f"
		% [fastest_id, fastest, mode_mult, threat_min, threat_max, diff.speed_per_min, diff.speed_cap])
	print("플레이어: 기본 %.0f · 레벨당 +%.0f · 이속 합계 최대 %d (패시브 %d + 메타 %d + 캐릭터 %d)"
		% [base_speed, PER_LEVEL_SPEED, lv_max, passive_max, meta_max, char_max])
	print("")

	# ── 1. 최대 투자로는 뿌리칠 수 있어야 한다 ────────────────────
	# 최고 위협 등급 + 속도 캡(런 끝) 기준. 여기서 넘기면 이속 패시브·메타가 통째로 죽은 스탯이다.
	var enemy_top := _enemy_speed(fastest, diff.speed_cap, INF, diff, mode_mult, threat_max)
	var player_top := _player_speed(base_speed, lv_max)
	_check("최대 투자(%d)로 최고 위협의 최속 좀비를 뿌리친다" % lv_max, player_top > enemy_top,
		"적 %.1f ≥ 플레이어 %.1f" % [enemy_top, player_top])

	# ── 2. 투자 0 이어도 초중반은 뿌리칠 수 있어야 한다 ───────────
	var cross0 := _crossover_min(fastest, base_speed, 0, diff, mode_mult, threat_min)
	_check("이속 투자 0 의 추월 시점이 %.0f분 이후" % MIN_CROSSOVER_MIN, cross0 >= MIN_CROSSOVER_MIN,
		"실제 %.1f분" % cross0)

	# ── 3. 30분 시점에 압박과 해법이 둘 다 존재한다 ───────────────
	var e30 := _enemy_speed(fastest, diff.speed_cap, CLEAR_MINUTES, diff, mode_mult, threat_min)
	_check("%.0f분에 투자 0 은 추월당한다(도망 클리어 봉쇄)" % CLEAR_MINUTES,
		e30 > _player_speed(base_speed, 0),
		"적 %.1f ≤ 플레이어 %.1f" % [e30, _player_speed(base_speed, 0)])
	_check("%.0f분에 이속 합계 %d 면 뿌리친다(해법 존재)" % [CLEAR_MINUTES, SOLVABLE_SPEED_LV],
		e30 < _player_speed(base_speed, SOLVABLE_SPEED_LV),
		"적 %.1f ≥ 플레이어 %.1f" % [e30, _player_speed(base_speed, SOLVABLE_SPEED_LV)])

	# ── 4. 속도 캡이 런 안에서 걸리지 않는다 ──────────────────────
	# 캡에 닿는 순간 후반 압박 증가가 평평해진다 — 클리어 시점 이후여야 곡선이 끝까지 산다.
	var cap_at: float = (diff.speed_cap - 1.0) / diff.speed_per_min if diff.speed_per_min > 0.0 else INF
	_check("속도 캡 도달이 %.0f분 이후" % CLEAR_MINUTES, cap_at >= CLEAR_MINUTES,
		"실제 %.1f분" % cap_at)

	print("")
	print("추월 시점(위협 1등급) — 이속 합계별")
	for lv in range(0, 5):
		var m := _crossover_min(fastest, base_speed, lv, diff, mode_mult, threat_min)
		print("  합계 %d  플레이어 %.0f  →  %s"
			% [lv, _player_speed(base_speed, lv), ("영구 안전" if m == INF else "%.1f분" % m)])

	if _fail == 0:
		print("\n후반 이속 밸런스 OK")
		quit(0)
	else:
		print("\n실패 %d건" % _fail)
		quit(1)


## ZombieSpawner._speed_mult() 와 같은 식. minutes = INF 면 캡에 닿은 최종 속도.
func _enemy_speed(base: float, cap: float, minutes: float, diff, mode_mult: float, threat: float) -> float:
	var ramp: float = cap if minutes == INF else minf(cap, 1.0 + minutes * diff.speed_per_min)
	return base * ramp * mode_mult * threat


func _player_speed(base: float, lv: int) -> float:
	return base + PER_LEVEL_SPEED * float(lv)


## 최속 좀비가 플레이어를 추월하는 시점(분). 캡에 닿아도 못 넘으면 INF.
func _crossover_min(base: float, p_base: float, lv: int, diff, mode_mult: float, threat: float) -> float:
	var target := _player_speed(p_base, lv)
	var unit: float = base * mode_mult * threat
	if unit <= 0.0:
		return INF
	var need: float = target / unit          # 필요한 램프 배율
	if need >= diff.speed_cap:
		return INF                            # 캡에 닿아도 못 따라잡는다
	if need <= 1.0:
		return 0.0                            # 시작부터 더 빠르다
	return (need - 1.0) / diff.speed_per_min
