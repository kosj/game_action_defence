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
##   fill=1        측정 시작 시 좀비를 동시 출현 상한까지 채운다
##   probe=gold:N  대조 실험 모드 — 스포너·오토플레이를 끄고 **그 개체만 N 개** 놓고 잰다.
##                 개체 수를 바꿔 가며 재면 개체당 프레임 비용(µs)이 직접 나온다.
##                 off= 로 재는 것보다 정확하다 — off 는 풀 반납까지 멈춰 개체 수가 같이 변한다.
##   off=Gold,Bullet  해당 스크립트의 _physics_process 만 끈다(노드는 그대로 둔다).
##                    켠 상태와의 차이가 곧 그 스크립트의 프레임 비용이다.
##
## ⚠️ 이 게임은 거의 모든 로직이 `_physics_process` 에 있다. 그래서 `physics_ms` 는
## "물리 엔진 비용"이 아니라 **물리 엔진 + 게임 로직 전부**다. 항목별로 가르려면 `off=` 를 쓴다.

const MAIN_SCENE := "res://scenes/Main.tscn"
const GOLD_SCENE := preload("res://scenes/Gold.tscn")
const BULLET_SCENE := preload("res://scenes/Bullet.tscn")

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
var _pairs: Array = []
var _counts_last: Dictionary = {}
var _off: Array = []
var _off_applied := false
var _kills0 := -1


func _process(delta: float) -> bool:
	if _finished:
		return true
	if not _started:
		_started = true
		_setup()
		return false
	_t += delta
	if _t < _warm:
		return false
	# 풀에서 새로 나온 노드는 다시 켜져 있으므로 매 프레임 다시 끈다.
	# 이 순회는 `_process` 에서 도므로 측정 대상인 physics_ms 에 섞이지 않는다.
	if not _off.is_empty():
		_apply_off(not _off_applied)
		_off_applied = true
	# 일시정지 중(레벨업 카드 등)에는 프레임 시간이 의미가 없다 — 측정에서 뺀다.
	if _kills0 < 0:
		_kills0 = int(_events.total_kills)
	if not paused:
		_frames.append(delta * 1000.0)
		_proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_phys_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_pairs.append(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS))
	if _t >= _warm + _measure:
		_counts_last = _count_nodes()
		_report()
		_finished = true
		quit(0)
	return false


func _setup() -> void:
	_parse_args()
	_warm = float(_args.get("warm", "6"))
	_measure = float(_args.get("measure", "20"))
	_events = root.get_node("Events")

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
	ItemDB.recompute(_events.weapons, _events.passives)
	_events.inventory_changed.emit()

	if int(_args.get("fill", "1")) != 0:
		cheats.request_spawn_fill()

	var probe := String(_args.get("probe", ""))
	if probe != "":
		_setup_probe(probe, cheats)

	var off := String(_args.get("off", ""))
	if off != "":
		_off = Array(off.split(","))


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
func _setup_probe(spec: String, cheats: Node) -> void:
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
	var pos := Vector2(360, 640)
	for i in n:
		# 플레이어에서 멀리(자석 범위 밖) 흩어 둔다 — 즉시 수집되면 개체 수가 유지되지 않는다.
		var a := TAU * float(i) / float(n)
		var at := pos + Vector2(cos(a), sin(a)) * (900.0 + 400.0 * float(i % 7))
		match kind:
			"gold":
				var g: Node2D = root.get_node("Pool").acquire(GOLD_SCENE, _main)
				g.global_position = at
			"bullet":
				var b: Node2D = root.get_node("Pool").acquire(BULLET_SCENE, _main)
				b.global_position = at
				b.direction = Vector2(cos(a), sin(a))
				b.lifetime = 9999.0
				b.speed = 1.0            # 화면 밖으로 날아가 버리지 않게(수명 판정만 돌게)
	print("  [probe] %s %d 개 — 스포너·오토플레이 정지" % [kind, n])


## 지정한 스크립트의 _physics_process 만 끈다 — 노드·렌더는 그대로 두고 **로직만** 뺀다.
## 켠 상태와의 physics_ms 차이가 그 스크립트가 매 프레임 쓰는 시간이다.
## (풀 반납도 그 로직 안에서 일어나므로, 끈 항목은 개체 수가 늘어난다 — 결과의 개체 내역을
##  함께 볼 것. 그래서 이건 "얼마나 비싼가"의 상한 추정이지 정밀 측정이 아니다.)
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
	var rec := {
		"build": String(_args.get("build", "engineer_late")),
		"min": float(_args.get("min", "26")),
		"frames": _frames.size(),
		"fps_med": snappedf(fps_med, 0.1),
		"frame_ms": f,
		"process_ms": _stat(_proc_ms),
		"physics_ms": _stat(_phys_ms),
		"draw_calls": _stat(_draw_calls),
		"collision_pairs": _stat(_pairs),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
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
	print("  physics     중앙 %6.2fms  p95 %6.2fms" % [rec["physics_ms"]["med"], rec["physics_ms"]["p95"]])
	print("  드로우콜    중앙 %6.0f    최악 %6.0f" % [rec["draw_calls"]["med"], rec["draw_calls"]["max"]])
	print("  충돌쌍      중앙 %6.0f    최악 %6.0f" % [rec["collision_pairs"]["med"], rec["collision_pairs"]["max"]])
	print("  노드 %d · 레벨 %d · **초당 처치 %.1f**" % [rec["nodes"], rec["level"], rec["kills_per_s"]])
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
