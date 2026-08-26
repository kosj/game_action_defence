extends SceneTree
## 자동 플레이테스트 — **게임을 실제로 플레이하면서** 화면과 수치를 함께 남긴다.
##
## 왜 필요한가
##   그동안 실기기 프레임 문제를 사람이 찍어 보내 주는 스크린샷으로 진단했다. 그러면 판마다
##   상태가 달라(레벨·킬 수·경과 시간) 비교가 안 되고, 왕복에 시간이 걸린다.
##   이 도구는 오토플레이로 같은 시나리오를 재현하고, **사람이 화면에서 보는 것과 같은 수치**를
##   구간마다 찍고 스크린샷도 같이 남긴다.
##
##   LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
##   xvfb-run -a -s "-screen 0 720x1280x24" godot --path . --rendering-driver opengl3 \
##       --script res://tools/playtest.gd -- secs=60 skip=1500 shots=10,30,60
##
## ⚠️ `--headless` 로는 의미가 없다(더미 렌더러 = 드로우 콜 0, fill-rate 0).
## ⚠️ **`phys` 는 "렌더 프레임 한 장에 들어간 물리 틱 시간의 합"이다.** 틱 1회 비용은 `tick`
##    이다. 프레임이 느려지면 한 프레임에 틱이 여러 번 들어가 `phys` 만 부풀어 오른다 —
##    실제로 llvmpipe(11fps)에서 phys 20ms 를 보고 "틱이 예산을 넘겼다"고 잘못 읽었다.
##    같은 판의 tick 은 4ms 였다. **둘을 같이 봐야 한다.**
##
## ⚠️ `frame_ms`·`fps` 는 소프트웨어 GL 값이라 **실기기 절대값이 아니다.** 같은 환경에서의
##    전후 비교와, GPU 와 무관한 값(draw/items/nodes/CPU ms)에만 쓴다.
##
## 수치는 `PerfOverlay.debug_stats()` 에서 받는다 — 게임 안 PERF HUD 와 **같은 계산**이다.
## 따로 재면 테스트가 보는 값과 사람이 보는 값이 갈라진다(5-R 진단이 그래서 헤맸다).
##
## 인자
##   secs=      플레이 시간(초, 기본 60)
##   skip=      난이도 시계를 당긴다(초). 0 이면 처음부터. 후반 난전은 1500
##   levels=    시작 시 부여할 레벨업 횟수(기본 0 — skip 만으로는 무기가 안 는다)
##   give=      무기 강제 부여(쉼표 구분). 예: give=orb,tesla
##   givelv=    give= 무기별 부여 횟수(기본 8)
##   fill=1     2초마다 좀비를 상한까지 채운다(기본 0 = 자연 스폰 그대로)
##   shots=     스크린샷을 찍을 시각(초, 쉼표 구분). 예: shots=10,30,60
##   out=       스크린샷 저장 폴더(기본 user://playtest)
##   every=     표본 출력 주기(초, 기본 10)
##   half=1     HALF RES 를 켜고 플레이한다(fill-rate 판정)
##   cheats=    쉼표 구분 토글 끄기: weather,props,decals,vignette,daynight
##
## 플레이어는 죽지 않게 매 프레임 체력을 채운다 — 안 그러면 후반 시나리오에서 20초 만에 죽어
## **게임오버 화면을 측정하게 된다.**

const MAIN_SCENE := "res://scenes/Main.tscn"
const WARMUP := 3.0     # 첫 프레임의 셰이더 컴파일·씬 구성 스파이크를 표본에서 뺀다

var _args := {}
var _main: Node = null
var _overlay: Node = null
var _t := 0.0
var _started := false
var _next_sample := 0.0
var _every := 10.0
var _secs := 60.0
var _fill := false
var _fill_t := 0.0
var _shots: Array = []
var _out := "user://playtest"
var _rows: Array = []


func _process(delta: float) -> bool:
	if not _started:
		_started = true
		_setup()
		return false
	_t += delta
	_keepalive(delta)
	if _t < WARMUP:
		return false
	var e := _t - WARMUP
	# 스크린샷 — 지정 시각을 지나면 한 장 찍고 목록에서 뺀다.
	if not _shots.is_empty() and e >= float(_shots[0]):
		_grab("t%03d" % int(_shots[0]))
		_shots.remove_at(0)
	if e >= _next_sample:
		_sample(e)
		_next_sample += _every
	if e >= _secs:
		_report()
		quit(0)
		return true
	return false


func _setup() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			_args[kv[0]] = kv[1]
	_secs = float(_args.get("secs", "60"))
	_every = maxf(1.0, float(_args.get("every", "10")))
	_fill = String(_args.get("fill", "0")) == "1"
	_out = String(_args.get("out", "user://playtest"))
	for s in String(_args.get("shots", "")).split(",", false):
		_shots.append(float(s))
	_shots.sort()
	DirAccess.make_dir_recursive_absolute(_out)

	var events := root.get_node("Events")
	var cheats := root.get_node("Cheats")
	root.get_node("SaveManager").delete_save()
	events.reset()
	_main = load(MAIN_SCENE).instantiate()
	root.add_child(_main)
	current_scene = _main

	cheats.autoplay = true          # 사람 대신 조종 AI 가 논다
	cheats.perf_overlay = true      # PERF HUD 를 켜야 표본이 쌓인다(debug_stats 전제)
	for c in String(_args.get("cheats", "")).split(",", false):
		match c:
			"weather":  cheats.weather = false
			"daynight": cheats.daynight = false
			"props":    cheats.props = false
			"decals":   cheats.decals = false
			"vignette": cheats.vignette = false
	if String(_args.get("half", "0")) == "1":
		cheats.half_res = true
	cheats.changed.emit()           # HUD 가 토글을 실제로 적용하게 한다

	var skip := float(_args.get("skip", "0"))
	if skip > 0.0:
		cheats.time_skip.emit(skip)
	var give := String(_args.get("give", ""))
	if give != "":
		for id in give.split(",", false):
			for _lv in int(_args.get("givelv", "8")):
				events.grant_item(id)
	for _i in int(_args.get("levels", "0")):
		events.bonus_level()

	_overlay = _find_overlay()
	if _overlay == null:
		print("[PLAY] PerfOverlay 를 못 찾았습니다 — HUD 구조가 바뀌었는지 확인하세요.")
		quit(1)
		return
	Engine.max_fps = 0              # 상한을 풀어 실제로 낼 수 있는 프레임을 본다
	print("[PLAY] 시작 — secs=%.0f skip=%.0f fill=%s half=%s"
		% [_secs, skip, _fill, _args.get("half", "0")])


func _find_overlay() -> Node:
	var hud := _main.get_node_or_null(^"HUD")
	if hud == null:
		return null
	for c in hud.get_children():
		var sc = c.get_script()
		if sc != null and String(sc.resource_path).ends_with("PerfOverlay.gd"):
			return c
	return null


## 플레이어를 살려 둔다. fill=1 이면 좀비도 상한까지 채운다.
func _keepalive(delta: float) -> void:
	var p = _main.get_node_or_null(^"Player")
	if p != null and "health" in p and "max_health" in p:
		p.health = p.max_health
	if not _fill:
		return
	_fill_t += delta
	if _fill_t >= 2.0:
		_fill_t = 0.0
		root.get_node("Cheats").spawn_fill.emit()


func _sample(e: float) -> void:
	var d: Dictionary = _overlay.debug_stats()
	d["t"] = e
	_rows.append(d)
	print("[PLAY] t=%5.1f  fps %3d  frame %6.2f/%6.2f  proc %5.2f/%5.2f  phys %5.2f tick %5.2f  draw %4d  items %5d  zomb %3d  nodes %4d"
		% [e, d["fps"], d["frame_avg"], d["frame_worst"], d["proc_avg"], d["proc_max"],
		   d["phys_avg"], d["tick_avg"], d["draw"], d["items"], d["zombies"], d["nodes"]])


func _grab(tag: String) -> void:
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out, tag]
	img.save_png(ProjectSettings.globalize_path(path))
	print("[PLAY] 스크린샷 %s" % ProjectSettings.globalize_path(path))


## 중앙값으로 낸다 — 평균은 초반 한 번의 스파이크에 끌려간다.
func _median(key: String) -> float:
	var v: Array = []
	for r in _rows:
		v.append(float(r[key]))
	if v.is_empty():
		return 0.0
	v.sort()
	return v[v.size() / 2]


func _report() -> void:
	if _rows.is_empty():
		print("[PLAY] 표본이 없습니다(secs 가 WARMUP 보다 짧습니다).")
		return
	var last: Dictionary = _rows[_rows.size() - 1]
	print("\n[PLAY] ── 요약 (표본 %d개 중앙값) ──────────────────────────" % _rows.size())
	print("[PLAY] fps %.0f  frame %.2fms  worst %.2fms"
		% [_median("fps"), _median("frame_avg"), _median("frame_worst")])
	print("[PLAY] CPU  proc %.2f/%.2f  phys %.2f/%.2f ms (avg/max)  틱1회 %.2f ms"
		% [_median("proc_avg"), _median("proc_max"), _median("phys_avg"), _median("phys_max"),
		   _median("tick_avg")])
	print("[PLAY] DRAW %.0f calls  %.0f items  @%dx%d"
		% [_median("draw"), _median("items"), int(last["render"].x), int(last["render"].y)])
	print("[PLAY] zombies %.0f  nodes %.0f  tex %.1fMB"
		% [_median("zombies"), _median("nodes"), last["tex_mb"]])
	# 기계가 읽을 형태로도 한 줄 — 전후 비교를 스크립트로 돌릴 때 쓴다.
	print("#PLAYTEST fps=%.0f frame_ms=%.2f worst_ms=%.2f proc_avg=%.2f proc_max=%.2f phys_avg=%.2f phys_max=%.2f draw=%.0f items=%.0f zombies=%.0f"
		% [_median("fps"), _median("frame_avg"), _median("frame_worst"),
		   _median("proc_avg"), _median("proc_max"), _median("phys_avg"), _median("phys_max"),
		   _median("draw"), _median("items"), _median("zombies")])
