extends SceneTree
## 힙 누수 추적 하네스 (P0-5).
##
## 왜 필요한가
## -----------
## 배포 웹 빌드가 **wasm 힙 2GB 상한을 쳐서 죽었다**(사용자 콘솔 로그, 2026-08-21):
##
##     Cannot enlarge memory, requested 2147487744 bytes, but the limit is 2147483648 bytes!
##     USER ERROR: Error initializing dsp state   at: _alloc_vorbis
##     Aborted(Runtime error: The application has corrupted its heap memory area (address zero)!)
##
## ⚠️ **`_alloc_vorbis` 는 범인이 아니라 피해자다.** 힙이 이미 꽉 찬 상태에서 마침 오디오가
## malloc 을 요청했을 뿐이다. 마지막 줄의 "address zero 손상"도 원인이 아니라 증상이다 —
## malloc 이 NULL 을 돌려줬는데 검사 없이 거기에 썼다는 뜻이다.
## (사운드를 스로틀 없이 84,000회 재생해도 RSS 가 평탄한 것을 이 하네스로 확인했다.)
##
## 무엇을 재나
## -----------
## 오토플레이로 계속 돌리며 분당 계수기를 콘솔로 흘린다. **RSS 를 함께 재는 것이 핵심이다** —
## `Performance.MEMORY_STATIC` 은 Godot 자기 할당자를 거친 것만 세므로 libvorbis 같은
## 서드파티가 자체 malloc 으로 잡은 것은 안 잡힌다. 프로세스 RSS 는 그것까지 본다.
##
##   godot --headless --path . --fixed-fps 60 --script res://tools/heap_hunt.gd -- run=1800 every=180
##
## ⚠️ **`--headless` 는 렌더링을 아예 하지 않는다**(VRAM 0.0 으로 찍힌다). 즉 이 모드로는
## 렌더러 쪽 누수를 **한 글자도 검사하지 못한다.** 웹에서만 터지는 문제를 헤드리스에서
## "안 샌다"고 결론 내리면 안 된다 — 실제로 그 함정에 한 번 빠졌다.
## 웹 힙 자체를 보려면 `tools/heap_web.sh` 를 쓴다.
##
## 인자:
##   run=1800     이 초만큼 돌린다(게임 시간)
##   every=180    표본 간격(초)
##   min=20       난이도 시계를 이 분으로 당긴다
##   fill=1       시작 시 좀비를 동시 상한까지 채운다
##   probe=sound  게임을 안 띄우고 그 계통만 최대 속도로 돌린다(sound·sound_api·music)
var _ev: Node = null
var _t := 0.0
var _next := 0.0
var _booted := false
var _run_limit := 0.0
var _probe := ""
var _sm: Node = null
var _probe_n := 0
const _SOUND_KEYS := ["shoot", "zombie_hit", "zombie_die", "gold", "laser", "boom", "swing"]
## 포맷을 가르는 대조군 — 크래시가 `_alloc_vorbis` 에서 났으니 ogg 만의 문제인지 본다.
const _SOUND_OGG := ["shoot", "zombie_hit", "zombie_die", "swing", "player_hurt", "ui_click", "spit"]
const _SOUND_WAV := ["gold", "laser", "boom"]

func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with(k + "="):
			return s.substr(k.length() + 1)
	return d

func _process(delta: float) -> bool:
	if not _booted:
		_boot(); _booted = true; return false
	_t += delta
	if _probe == "":
		for pl in get_nodes_in_group("player"):
			if pl.has_method("heal_full"):
				pl.heal_full()
	if _run_limit > 0.0 and _t >= _run_limit:
		return true
	if _probe != "":
		_drive_probe()
	if _t >= _next:
		_next += float(_arg("every", "60"))
		if _probe != "":
			print("HEAP t=%.0f rss=%.1f 호출 %d회 obj=%d res=%d"
				% [_t, _rss_mb(), _probe_n, Performance.get_monitor(Performance.OBJECT_COUNT),
					Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])
			return false
		print("HEAP t=%.0f rss=%.1f obj=%d res=%d nodes=%d orph=%d z=%d vram=%.1f"
			% [_t, _rss_mb(), Performance.get_monitor(Performance.OBJECT_COUNT),
				Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
				get_nodes_in_group("zombies").size(),
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	return false

## 계통 하나만 최대 속도로 돌린다 — 씬을 안 띄우므로 렌더 부하가 없어
## 브라우저에서도 빠르게 돈다(SwiftShader 로는 게임 씬이 실시간의 1/9 로 기어간다).
func _boot_probe(kind: String) -> void:
	_probe = kind
	_sm = root.get_node("SoundManager")
	_sm.muted = int(_arg("mute", "0")) != 0
	# pt=0|1|2 — 재생 방식을 명시 지정한다(DEFAULT/STREAM/SAMPLE).
	# 웹의 누수가 "샘플로 변환해 두고 안 버리는" 경로 때문인지 가르는 스위치다.
	var pt := int(_arg("pt", "-1"))
	if pt >= 0:
		for k in _sm._players:
			(_sm._players[k] as AudioStreamPlayer).playback_type = pt
		print("HEAP playback_type=%d 로 고정" % pt)
	var host := Node.new()
	root.add_child(host)
	current_scene = host
	print("HEAP probe=%s 시작 rss=%.1fMB" % [kind, _rss_mb()])


func _drive_probe() -> void:
	match _probe:
		"sound_ogg":
			for k in _SOUND_OGG:
				_sm._players[k].play()
				_probe_n += 1
		"sound_wav":
			for k in _SOUND_WAV:
				_sm._players[k].play()
				_probe_n += 1
		"sound":
			# 스로틀을 우회해 매 프레임 여러 번 재생한다 — play_ui 는 _MIN_INTERVAL 을 타지만
			# 소리를 돌아가며 쓰면 각 소리의 간격 제한에 걸리지 않는다.
			for k in _SOUND_KEYS:
				_sm._players[k].play()
				_probe_n += 1
		"sound_api":
			# 공개 API 경로 그대로(스로틀 포함) — 실제 게임이 부르는 방식.
			for k in _SOUND_KEYS:
				_sm.play_ui(k)
				_probe_n += 1
		"music":
			_sm.play_music("game" if (_probe_n % 2) == 0 else "title")
			_probe_n += 1


## 프로세스 RSS(MB). Godot 의 MEMORY_STATIC 은 **자기 할당자를 거친 것만** 센다 —
## libvorbis 같은 서드파티 라이브러리가 자체 malloc 으로 잡은 것은 안 잡힌다.
## 웹 크래시가 _alloc_vorbis 에서 났으므로 그쪽을 봐야 한다.
func _rss_mb() -> float:
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	if f == null:
		return -1.0
	while not f.eof_reached():
		var l := f.get_line()
		if l.begins_with("VmRSS:"):
			f.close()
			return float(l.split(":")[1].strip_edges().split(" ")[0]) / 1024.0
	f.close()
	return -1.0


func _boot() -> void:
	var probe := _arg("probe", "")
	if probe != "":
		_boot_probe(probe)
		return
	_ev = root.get_node("Events")
	if int(_arg("mute", "0")) != 0:
		root.get_node("SoundManager").muted = true
	root.get_node("SaveManager").delete_save()
	_ev.reset()
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main); current_scene = main
	var ch := root.get_node("Cheats")
	ch.autoplay_persona = "greedy"
	ch.autoplay = true
	var m := float(_arg("min", "0"))
	if m > 0.0:
		ch.request_time_skip(m * 60.0)
	if int(_arg("fill", "0")) != 0:
		ch.request_spawn_fill()
	print("HEAP boot ok min=%s rss=%.1fMB" % [_arg("min", "0"), _rss_mb()])
	if float(_arg("run", "0")) > 0.0:
		_run_limit = float(_arg("run", "0"))
