extends SceneTree
## 프레임 부하 프로파일러 — **실제 렌더러**로 난전을 돌리며 드로우 콜을 계통별로 쪼갠다.
##
## 왜 헤드리스가 아닌가
##   `--headless` 는 더미 렌더러라 드로우 콜·아이템 수가 전부 0 이고 fill-rate 비용이 아예
##   발생하지 않는다. 이 게임의 병목은 스크립트가 아니라 그리기 쪽이라 헤드리스로는 못 잡는다.
##   그래서 가상 디스플레이 + 소프트웨어 GL(llvmpipe)로 진짜 GL 컨텍스트를 띄운다.
##
##   LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
##   xvfb-run -a -s "-screen 0 720x1280x24" godot --path . --rendering-driver opengl3 \
##       --script res://tools/profile_frame.gd -- secs=30 skip=1500 [off=<태그>] [only=<태그>]
##
##   필요 패키지: xvfb, mesa(swrast). 없으면 apt 로 설치한다.
##
## 읽는 법
##   draw/items 는 **GPU 종류와 무관한 명령 수**라 실기기와 같은 값이다. 이게 이 도구의 산출물이다.
##   frame_ms 는 llvmpipe 기준이라 절대값이 실기기와 다르다 — 비교용으로만 쓴다.
##
## 시나리오
##   skip= 으로 난이도 시계를 당겨 후반 난전을 재현한다(좀비 상한 40 -> 320 은 1500초에 만렙).
##   초반 10분은 좀비가 10~30마리라 프레임 문제가 아예 안 드러난다. 그리고 매 프레임 플레이어
##   체력을 채우고 2초마다 좀비를 상한까지 채운다 — 안 그러면 20초 만에 죽어 **게임오버 화면을
##   측정하게 된다**(값이 통째로 얼어붙고 phys_ms 가 0.06 으로 떨어지는 것이 그 신호다).
##
## off=<태그> — 그 계통만 끄고 같은 시나리오를 돌린다. 기준선과의 차이가 그 계통의 몫이다.
##     ground / props / weather / daynight / hud / zombies / fxlayer
##     shadowmod — 좀비 그림자의 modulate 알파만 흰색으로(아래 참조)
##
## only=<태그> — 그 계통만 남기고 전부 숨긴다. off= 는 다른 것의 배칭까지 바꿔 놓아 몫이
##     과대평가된다(실제로 바닥이 격리 53 vs ablation 166 으로 3배 차이가 났다). 격리가 더 깨끗하다.
##     노드 이름(Ground/PropField/Weather/...) 또는 zombies 계열:
##       zombies                 — 좀비만
##       zombies_noshadow        — 좀비에서 그림자만 뺌
##       zombies_shadow_white    — 그림자를 그리되 modulate 만 흰색
##       zombies_shadow_notex    — 그림자 텍스처를 몸통과 통일
##
## ── 이 도구로 찾은 것 (2026-08) ────────────────────────────────────────────────
## 좀비 320마리 격리 측정:
##       기본                 draw 150 / items 182
##       그림자 modulate 흰색  draw  36 / items 181   <- 그림자는 그대로 그려지는데 콜만 무너짐
##       그림자 텍스처 통일    draw 150 / items 182   <- 텍스처는 원인이 아니다(아틀라스는 정상)
##       그림자 숨김          draw  38 / items 124
## 원인은 `Zombie.tscn` 의 `Shadow.modulate = Color(1,1,1,0.5)` 다. Godot 캔버스 배처는
## **연속된 아이템의 modulate 가 다르면 배치를 끊는다.** 좀비마다 그림자(α0.5) -> 몸통(흰색)이
## 번갈아 나와 아이템마다 배칭이 깨졌다. 전체 게임에서도 draw 390 -> 244 (-37%).
## 고치려면 알파를 shadow.png 에 베이크하고 modulate 를 흰색으로 둔다(화면은 동일).
## Boss.tscn·Player.tscn 도 같은 패턴이지만 개체가 1~2 라 영향은 작다.
##
## 바닥은 별개의 같은 계열 문제다 — `Ground._draw_decals` 가 색이 제각각인
## draw_circle 42 + draw_line 45 를 발행한다(재드로우 1회당 총 151개 명령). 이 명령 목록은
## **재드로우 빈도와 무관하게 매 프레임 GPU 에 재제출된다** — B1 의 재드로우 억제는 CPU
## 재구축 비용만 줄였고 프레임당 드로우 콜은 그대로다.

const MAIN_SCENE := "res://scenes/Main.tscn"
const WARMUP := 2.0            # 첫 프레임 셋업 비용 제외
const BUCKET := 10.0           # 이 간격으로 구간 통계를 낸다
const FILL_INTERVAL := 2.0     # 좀비를 상한까지 다시 채우는 주기

var _args := {}
var _events: Node = null
var _main: Node = null
var _started := false
var _t := 0.0
var _secs := 90.0
var _off := ""
var _only := ""
var _fill_t := 0.0
var _one_tex: Texture2D = load("res://assets/atlas/zombie_walker.tres")

var _b_frames := 0
var _b_ms := 0.0
var _b_worst := 0.0
var _b_draw := 0
var _b_items := 0
var _b_proc := 0.0
var _b_phys := 0.0
var _b_next := BUCKET
var _rows: Array = []


func _process(delta: float) -> bool:
	if not _started:
		_started = true
		_setup()
		return false
	_t += delta
	if _only.begins_with("zombies"):
		_keepalive(delta)      # 좀비 격리라도 스폰은 계속 돌려야 한다
		_isolate()
	elif _only != "":
		_isolate()
	else:
		_keepalive(delta)
		_ablate()
	if _t < WARMUP:
		return false

	_b_frames += 1
	_b_ms += delta * 1000.0
	_b_worst = maxf(_b_worst, delta * 1000.0)
	_b_proc += float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	_b_phys += float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	_b_draw += int(RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	_b_items += int(RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))

	if _t - WARMUP >= _b_next:
		_flush()
		_b_next += BUCKET
	if _t - WARMUP >= _secs:
		_flush()
		_report()
		quit(0)
		return true
	return false


## 좀비를 상한에 붙들어 두고 플레이어를 살려 둔다 — 시나리오가 유지되어야 측정이 성립한다.
func _keepalive(delta: float) -> void:
	var p = _main.get_node_or_null("Player")
	if p != null and "health" in p and "max_health" in p:
		p.health = p.max_health
		if "_hurt_timer" in p:
			p._hurt_timer = maxf(p._hurt_timer, 0.5)
	_fill_t += delta
	if _fill_t >= FILL_INTERVAL:
		_fill_t = 0.0
		root.get_node("Cheats").spawn_fill.emit()


## off= 중 런타임에 계속 새로 생기는 것들 — 매 프레임 손봐야 한다.
func _ablate() -> void:
	match _off:
		"shadowmod":
			for z in get_nodes_in_group("zombies"):
				var s = z.get_node_or_null("Shadow")
				if s != null and s.modulate != Color.WHITE:
					s.modulate = Color.WHITE
		"zombies":
			for z in get_nodes_in_group("zombies"):
				if z is CanvasItem:
					z.visible = false
		"fxlayer":
			var fx = _main.get_node_or_null("FXLayer")
			if fx != null and fx is CanvasItem:
				fx.visible = false


## only= 격리. 셋업 때 한 번만 숨기면 그 뒤 생긴 노드가 그대로 보여 측정이 오염된다.
func _isolate() -> void:
	var zombie_mode := _only.begins_with("zombies")
	for c in _main.get_children():
		if not (c is CanvasItem):
			continue
		if zombie_mode:
			c.visible = c.is_in_group("zombies")
			if c.visible:
				_tweak_zombie(c)
		else:
			c.visible = (String(c.name) == _only)
	if not zombie_mode:
		var fx = _main.get_node_or_null("FXLayer")
		if fx != null and fx is CanvasItem:
			fx.visible = false


## 좀비 격리 변형 — 그림자의 어떤 속성이 배칭을 깨는지 가르기 위한 실험용.
func _tweak_zombie(z: Node) -> void:
	var sh = z.get_node_or_null("Shadow")
	if sh == null:
		return
	match _only:
		"zombies_noshadow":     sh.visible = false
		"zombies_shadow_white": sh.modulate = Color.WHITE
		"zombies_shadow_notex": sh.texture = _one_tex


func _flush() -> void:
	if _b_frames == 0:
		return
	var n := float(_b_frames)
	_rows.append({
		"t": int(_b_next),
		"zombies": get_nodes_in_group("zombies").size(),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"draw": int(_b_draw / n),
		"items": int(_b_items / n),
		"frame_ms": _b_ms / n,
		"worst_ms": _b_worst,
		"proc_ms": _b_proc / n,
		"phys_ms": _b_phys / n,
	})
	_b_frames = 0; _b_ms = 0.0; _b_worst = 0.0; _b_draw = 0; _b_items = 0
	_b_proc = 0.0; _b_phys = 0.0


func _report() -> void:
	var tag := _only if _only != "" else ("off=" + _off if _off != "" else "baseline")
	print("\n#PROFILE %s" % tag)
	print("%5s %8s %7s %7s %8s %9s %9s %9s %9s"
		% ["t(s)", "zombies", "nodes", "draw", "items", "frame_ms", "worst_ms",
		   "proc_ms", "phys_ms"])
	for r in _rows:
		print("%5d %8d %7d %7d %8d %9.2f %9.2f %9.3f %9.3f"
			% [r["t"], r["zombies"], r["nodes"], r["draw"], r["items"],
			   r["frame_ms"], r["worst_ms"], r["proc_ms"], r["phys_ms"]])
	# 뒤쪽 절반 평균 — 좀비가 충분히 쌓인 뒤의 정상 상태
	var half := _rows.slice(_rows.size() / 2)
	var f := 0.0; var d := 0.0; var it := 0.0; var pr := 0.0; var ph := 0.0
	for r in half:
		f += r["frame_ms"]; d += r["draw"]; it += r["items"]
		pr += r["proc_ms"]; ph += r["phys_ms"]
	var n := float(max(1, half.size()))
	print("#STEADY %s frame_ms=%.2f draw=%.0f items=%.0f proc_ms=%.3f phys_ms=%.3f"
		% [tag, f / n, d / n, it / n, pr / n, ph / n])


func _setup() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			_args[kv[0]] = kv[1]
	_secs = float(_args.get("secs", "90"))
	_off = String(_args.get("off", ""))
	_only = String(_args.get("only", ""))
	seed(int(_args.get("seed", "12345")))

	_events = root.get_node("Events")
	root.get_node("SaveManager").delete_save()
	_events.reset()
	_main = load(MAIN_SCENE).instantiate()
	root.add_child(_main)
	current_scene = _main
	root.get_node("Cheats").autoplay = (_only == "" or _only.begins_with("zombies"))

	var skip := float(_args.get("skip", "1500"))
	if skip > 0.0:
		root.get_node("Cheats").time_skip.emit(skip)
	# 무기를 여러 개 붙여 실제 난전의 FX/투사체 부하를 재현한다 — 기본 총 한 자루로는
	# 장판·설치물·연쇄가 안 돌아 그리기 부하가 과소평가된다.
	if _only == "":
		for i in int(_args.get("levels", "20")):
			_events.bonus_level()

	match _off:
		"ground":   _hide("Ground")
		"props":    _hide("PropField")
		"weather":  root.get_node("Cheats").weather = false; _hide("Weather")
		"daynight": root.get_node("Cheats").daynight = false; _hide("DayNight")
		"hud":      _hide("HUD")
	Engine.max_fps = 0   # 상한을 풀어 실제로 낼 수 있는 프레임을 본다


func _hide(n: String) -> void:
	var node = _main.get_node_or_null(n)
	if node != null:
		node.visible = false
		node.set_process(false)
		node.set_physics_process(false)
