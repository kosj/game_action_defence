extends SceneTree
## 탄 예산 가드 (P1-19).
##
## 왜 필요한가
## -----------
## 후반 프레임을 실제로 먹는 것은 좀비가 아니라 **플레이어 자신의 투사체**다(`BALANCE.md` §3-10).
## 사람 기록의 후반 동시 좀비는 22~45마리인데(상한 320의 1/10) 탄은 200~450개였다.
## 그리고 그 대부분이 무기 두 종에서 나왔다 — 개틀링 하나가 동시 탄 113발로 나머지의 3~5배였다.
##
## 무기 하나의 파라미터를 조금 손대면 이 상태가 조용히 돌아온다. 그래서 **카탈로그에서 직접
## 최악 발사율을 계산해** 예산을 넘는 무기가 생기면 CI 에서 잡는다.
##
##   godot --headless --path . --script res://tools/verify_bullet_budget.gd
##
## ⚠️ 예산값은 **현재 최악값 바로 위**에 놓은 것이지 최적값의 증명이 아니다.
## "오늘보다 나빠지지 않는다"를 잠그는 것이 목적이다. 올리려면 먼저 이 주석부터 다시 쓸 것.

## 한 무기가 최악 조건에서 낼 수 있는 초당 탄 수 상한.
## 최악 조건 = 만렙 + 발사속도 패시브(에너지 드링크) 만렙. 그때 `ProjectileWeapon._interval()`
## 의 하한(`fire_interval * 0.5`)이 걸리므로, 상한은 `pellets / (fire_interval * 0.5)` 이다.
const MAX_SHOTS_PER_SEC := 32.0

## 만렙에서 레벨당 늘어나는 탄 수 규칙(`ProjectileWeapon._fire`): pellets + int((lvl-1)/4).
const PELLET_PER_LEVELS := 4
## 발사 간격 하한 배수(`ProjectileWeapon._interval`).
const INTERVAL_FLOOR_MUL := 0.5

var _fail := 0


func _init() -> void:
	await process_frame
	var gd := root.get_node("GameData")

	var rows: Array = []
	for w in gd.weapon_defs:
		if w == null or w.module != "projectile":
			continue
		var lvl: int = int(w.max_level)
		var pellets: int = int(w.pellets) + int((lvl - 1) / PELLET_PER_LEVELS)
		var floor_iv: float = float(w.fire_interval) * INTERVAL_FLOOR_MUL
		if floor_iv <= 0.0:
			_fail += 1
			print("  FAIL %-14s fire_interval 이 0 이다 — 발사율이 무한대가 된다" % w.id)
			continue
		var rate: float = float(pellets) / floor_iv
		rows.append({"id": String(w.id), "lvl": lvl, "pellets": pellets,
			"iv": float(w.fire_interval), "rate": rate})

	rows.sort_custom(func(a, b): return float(a["rate"]) > float(b["rate"]))
	print("무기별 최악 발사율 (만렙 + 발사속도 만렙 · 상한 %.0f발/초)" % MAX_SHOTS_PER_SEC)
	for r in rows:
		var over: bool = float(r["rate"]) > MAX_SHOTS_PER_SEC
		if over:
			_fail += 1
		print("  %-4s %-15s Lv%d  탄 %d / %.3fs  →  %5.1f 발/초"
			% [("FAIL" if over else "ok"), r["id"], r["lvl"], r["pellets"],
				float(r["iv"]) * INTERVAL_FLOOR_MUL, r["rate"]])

	if rows.is_empty():
		_fail += 1
		print("  FAIL 발사체 무기를 하나도 못 찾았다 — 카탈로그 로드가 깨졌다")

	# 카탈로그가 통째로 줄어드는 사고를 막는다. 실제로 생성기와 .tres 가 어긋나 있어서,
	# 규약대로 재생성했더니 무기 4종(부메랑·궁극기 3종)이 조용히 사라졌다(P1-19 에서 발견).
	# 궁극기는 캐릭터마다 하나씩 묶여 있어(`CharacterData.ultimate_weapon`) 사라지면 그 캐릭터가 반쪽이 된다.
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
		print("\n탄 예산 OK")
		quit(0)
	else:
		print("\n실패 %d건" % _fail)
		quit(1)
