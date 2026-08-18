extends SceneTree
## 밸런스 측정 하네스 — 오토플레이로 한 판을 끝까지 돌리고 결과 1줄(JSON)을 찍는다.
##
## 실행(한 판):
##   godot --headless --path . --fixed-fps 60 --script res://tools/sim_balance.gd -- \
##       character=veteran theme=suburb maxmin=30 seed=1
##
## 여러 판 반복·집계·판정은 `tools/sim_balance.py` 가 한다 — 이 스크립트는 한 판만 본다.
## 판을 프로세스마다 새로 띄우는 이유: 오토로드(메타 골드·과제·퀘스트)와 오브젝트 풀이
## 판 사이에 남아 뒤 판의 수치를 오염시킨다. 프로세스를 분리하면 그 걱정이 없다.
##
## 왜 엔진을 그대로 돌리나
##   예전 BALANCE.md 는 DPS 를 수식으로 추정했다. 지금은 무기 21종이 각자 모듈로 동작하고
##   장판·설치물·연쇄의 실효 DPS 가 좀비 밀집도에 따라 몇 배씩 달라진다 — 수식으로는 안 잡힌다.
##   그래서 추정하지 않고 측정한다.
##
## ⚠️ 이 측정치는 "하한선"이다
##   오토플레이는 레벨업 카드를 **무작위로** 고른다(`LevelUpPanel`). 이 게임 파워의 대부분이
##   빌드 품질에서 나오는데 그걸 운에 맡긴 값이다. 절대값을 "이 게임의 난이도"로 읽지 말고,
##   **조정 전/후 비교**와 **캐릭터·테마 간 상대 비교**에 쓴다.

const MAIN_SCENE := "res://scenes/Main.tscn"
const SAMPLE_INTERVAL := 60.0     # 분당 스냅샷
const FRAME_CAP := 400000         # 무한 루프 방어(60fps 기준 약 111분)

var _args: Dictionary = {}
var _max_s: float = 1800.0
var _started: bool = false
var _finished: bool = false
var _frames: int = 0

var _events: Node = null
var _main: Node = null

# 측정치
var _hits: int = 0
var _first_hit: float = -1.0
var _last_hp: int = -1
var _boss_spawn_t: float = -1.0
var _boss_fights: Array = []
var _boss_kills: int = 0
var _peak_z: int = 0
var _samples: Array = []
var _next_sample: float = SAMPLE_INTERVAL
var _died: bool = false
var _cleared: bool = false


func _process(delta: float) -> bool:
	if _finished:
		return true
	if not _started:
		_started = true
		_setup()
		return false
	_frames += 1
	var el: float = float(_events.elapsed_time)
	_peak_z = maxi(_peak_z, get_nodes_in_group("zombies").size())
	if el >= _next_sample:
		_samples.append({
			"min": int(round(_next_sample / 60.0)),
			"kills": int(_events.total_kills),
			"level": int(_events.level),
			"hp": int(_events.player_health),
			"zombies": get_nodes_in_group("zombies").size(),
		})
		_next_sample += SAMPLE_INTERVAL
	if _died or _frames >= FRAME_CAP or el >= _max_s:
		_finish(el)
		return true
	return false


func _setup() -> void:
	_parse_args()
	var sd := int(_args.get("seed", "0"))
	if sd != 0:
		seed(sd)
	_events = root.get_node("Events")
	_max_s = float(_args.get("maxmin", "30")) * 60.0

	_pick("CharacterManager", "character", func(gd, id): return gd.character(id))
	_pick("ThemeManager", "theme", func(gd, id): return _theme_by_id(gd, id))

	_events.player_died.connect(_on_died)
	_events.player_health_changed.connect(_on_hp)
	_events.boss_spawned.connect(_on_boss_spawned)
	_events.boss_died.connect(_on_boss_died)
	_events.run_cleared.connect(func(): _cleared = true)

	# MainMenu._start_new_game 과 같은 순서 — Main.gd 는 Events 가 이미 준비됐다고 전제한다.
	root.get_node("SaveManager").delete_save()
	_events.reset()

	_main = load(MAIN_SCENE).instantiate()
	root.add_child(_main)
	current_scene = _main   # SceneTree 의 속성이다(root 는 Window). Events.fx_layer() 가 이걸 본다
	root.get_node("Cheats").autoplay = true


## 캐릭터/테마 선택. 해금 게이트(구매·도전과제)는 측정 목적상 우회한다 —
## `_bought` 를 직접 세우는 것은 게임 경로가 아니라 이 하네스 전용이다.
func _pick(mgr_name: String, arg: String, finder: Callable) -> void:
	var id := String(_args.get(arg, ""))
	if id == "":
		return
	var mgr := root.get_node(mgr_name)
	var data = finder.call(root.get_node("GameData"), id)
	if data == null:
		push_warning("sim_balance: %s '%s' 를 찾을 수 없다 — 기본값으로 진행" % [arg, id])
		return
	if not mgr.is_unlocked(data):
		mgr._bought[id] = true
	mgr.select(id)


func _theme_by_id(gd, id: String):
	for t in gd.themes:
		if t.id == id:
			return t
	return null


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=", true, 1)
		if kv.size() == 2:
			_args[kv[0]] = kv[1]


func _on_died() -> void:
	_died = true


func _on_hp(health: int, _mx: int) -> void:
	if _last_hp >= 0 and health < _last_hp:
		_hits += 1
		if _first_hit < 0.0:
			_first_hit = float(_events.elapsed_time)
	_last_hp = health


func _on_boss_spawned(_mx: int) -> void:
	_boss_spawn_t = float(_events.elapsed_time)


func _on_boss_died() -> void:
	_boss_kills += 1
	if _boss_spawn_t >= 0.0:
		_boss_fights.append(snappedf(float(_events.elapsed_time) - _boss_spawn_t, 0.1))
		_boss_spawn_t = -1.0


## 사망 시점의 적 체력 배수 — ZombieSpawner._hp_mult() 와 같은 식(난이도 데이터 기반).
func _hp_mult(el: float) -> float:
	var d = root.get_node("GameData").difficulty
	var m := el / 60.0
	var v: float = 1.0 + m * float(d.hp_per_min) + m * m * float(d.hp_accel_per_min2)
	if el > float(d.clear_seconds):
		v += ((el - float(d.clear_seconds)) / 60.0) * float(d.overtime_hp_per_min)
	return snappedf(v * float(_events.diff_enemy_hp_mult()), 0.01)


func _finish(el: float) -> void:
	_finished = true
	var cm := root.get_node("CharacterManager")
	var tm := root.get_node("ThemeManager")
	print("SIMRESULT " + JSON.stringify({
		"character": cm.selected_id(),
		"theme": tm.selected_id(),
		"seed": int(_args.get("seed", "0")),
		"survived_s": snappedf(el, 0.1),
		"died": _died,
		"cleared": _cleared,
		"level": int(_events.level),
		"kills": int(_events.total_kills),
		"score": int(_events.score),
		"hits": _hits,
		"first_hit_s": snappedf(_first_hit, 0.1),
		"boss_spawns": _boss_fights.size() + (1 if _boss_spawn_t >= 0.0 else 0),
		"boss_kills": _boss_kills,
		"boss_fight_s": _boss_fights,
		"weapons": _events.weapons,
		"passives": _events.passives,
		"peak_zombies": _peak_z,
		"hp_mult_at_end": _hp_mult(el),
		"samples": _samples,
	}))
	quit(0)
