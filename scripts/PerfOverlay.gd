extends Control
## 성능 디버그 오버레이 — 일시정지 메뉴의 CHEATS > PERF HUD 로 켠다.
##
## 왜 필요한가: 이 프로젝트의 성능 병목은 대부분 "그리기"쪽(바닥 재드로우·텍스트 렌더·
## fill-rate)에 있는데, 그건 헤드리스 측정으로는 드러나지 않는다. 실기기(특히 모바일
## 브라우저)에서 눈으로 확인할 수단이 필요해서 만든 화면이다.
##
## 표시 항목
##   FPS    현재 fps / 프레임 시간 평균 / 최근 구간 최악값(히칭 감지)
##   CPU    스크립트 _process·_physics_process 시간 — **평균 / 최악** 두 값
##   DRAW   프레임당 드로우 콜·아이템 수 (바닥 재드로우, y_sort, FX 상한의 효과가 여기 보인다)
##   MEM    비디오 메모리 / 텍스처 메모리 (텍스처 압축 판단용)
##   NODE   노드 수 / 고아 노드(누수 감지)
##   GAME   좀비·젬 수
##   FX     이펙트별 동시 활성 수와 상한 — 상한에 계속 붙어 있으면 상한이 낮다는 뜻이다
##
## ⚠️ CPU 수치를 Godot 의 `Performance.TIME_PROCESS` 로 읽으면 안 된다 — 그건 평균이 아니라
## **최근 1초의 최댓값**이다(엔진이 `process_max` 를 1초 누적했다가 갱신한다). 그걸 평균처럼
## 읽는 바람에 실기기 제보를 "상시 21ms" 로 오해했고, 실제로는 스파이크였다. 증거는 우리
## 프로파일러 안에 있었다 — 매 프레임 읽어 평균 낸 값(54.3ms)이 같은 구간의 프레임 평균
## (50.1ms)보다 컸다. 부분집합이 전체보다 클 수는 없다.
##
## 그래서 **직접 잰다.** 우선순위 양 끝에 탐침 노드를 하나씩 두면(가장 먼저 / 가장 나중),
## 그 사이가 곧 모든 노드의 `_process` 합이다. `_physics_process` 도 같은 방식이되, 한
## 렌더 프레임에 물리 틱이 여러 번 돌 수 있으므로 **누적**해서 "프레임당 물리 CPU" 로 낸다.
## 이러면 프레임 시간과 같은 창(WINDOW)에서 평균·최악을 함께 볼 수 있다.
##
## 표시 문자열은 전부 ASCII 다. CJK 폰트가 "쓰는 글자만" 남긴 서브셋이라, 새 한글을 넣으면
## 폰트를 다시 만들어야 한다(tools/subset_fonts.py). 디버그 화면 때문에 그럴 이유는 없다.

const _DamageNumber := preload("res://scripts/DamageNumber.gd")
const _FXBurst := preload("res://scripts/FXBurst.gd")
const _SpriteFX := preload("res://scripts/SpriteFX.gd")
const _FXLightning := preload("res://scripts/FXLightning.gd")
const _Gold := preload("res://scripts/Gold.gd")

## 텍스트 갱신 주기. 매 프레임 문자열을 다시 만들면 오버레이 자신이 부하가 된다.
const REFRESH := 0.25
## 프레임 시간 샘플 창(최악값 = 이 구간의 최대 프레임 시간). 60fps 기준 약 2초.
const WINDOW := 120

var _label: Label = null
var _bg: ColorRect = null
var _acc: float = 0.0
## 링 버퍼 — 매 프레임 배열을 늘리지 않도록 고정 크기로 돌려 쓴다.
var _samples := PackedFloat32Array()
var _proc_us := PackedFloat32Array()
var _phys_us := PackedFloat32Array()
var _idx: int = 0
var _filled: int = 0
var _probe_a: _Probe = null   # 가장 먼저 도는 탐침
var _probe_b: _Probe = null   # 가장 나중에 도는 탐침


func _ready() -> void:
	# 일시정지 중에도 수치가 갱신되어야 한다(정지 상태에서 메모리·노드 수를 확인할 때 필요).
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(10, 104)   # 상단 바(높이 96) 바로 아래
	_samples.resize(WINDOW)
	_proc_us.resize(WINDOW)
	_phys_us.resize(WINDOW)
	# 탐침은 이 노드보다 먼저/나중에 돌아야 하므로 우선순위를 양 끝으로 벌린다.
	# 일시정지 중에도 함께 돌아야 "정지 중에는 스크립트 시간이 0" 이 제대로 보인다.
	_probe_a = _Probe.new()
	_probe_a.process_priority = -100000
	_probe_a.process_physics_priority = -100000
	_probe_a.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_probe_a)
	_probe_b = _Probe.new()
	_probe_b.first = _probe_a
	_probe_b.process_priority = 100000
	_probe_b.process_physics_priority = 100000
	_probe_b.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_probe_b)

	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.55)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.position = Vector2(8, 6)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 3)
	add_child(_label)

	visible = false
	_refresh()


func _process(delta: float) -> void:
	if not visible:
		return   # 꺼져 있으면 오버레이가 스스로 부하가 되지 않도록 아무것도 하지 않는다
	             # (= 표본도 안 쌓인다. debug_stats() 를 쓰려면 먼저 visible 을 켜야 한다)
	# 프레임 시간은 매 프레임 기록해야 히칭(순간 스파이크)을 놓치지 않는다.
	_samples[_idx] = delta
	# _process 합은 뒤쪽 탐침이 이 노드보다 **나중에** 돌므로 한 프레임 늦은 값이다(무해).
	# 물리는 렌더 프레임 시작 전에 그 프레임 몫의 틱이 전부 끝나 있으므로 지금 값이 정확하다.
	_proc_us[_idx] = float(_probe_b.proc_us)
	_phys_us[_idx] = float(_probe_b.phys_us)
	_probe_b.phys_us = 0            # 다음 프레임 몫을 다시 누적하도록 비운다
	_idx = (_idx + 1) % WINDOW
	_filled = mini(_filled + 1, WINDOW)
	_acc += delta
	if _acc < REFRESH:
		return
	_acc = 0.0
	_refresh()


## 샘플 창의 평균/최악 프레임 시간(ms).
func _frame_stats() -> Vector2:
	if _filled == 0:
		return Vector2.ZERO
	var sum := 0.0
	var worst := 0.0
	for i in _filled:
		var v := _samples[i]
		sum += v
		worst = maxf(worst, v)
	return Vector2(sum / float(_filled) * 1000.0, worst * 1000.0)


## 링 버퍼의 평균/최댓값(us -> ms).
func _avg_max(buf: PackedFloat32Array) -> Vector2:
	if _filled == 0:
		return Vector2.ZERO
	var sum := 0.0
	var worst := 0.0
	for i in _filled:
		var v := buf[i]
		sum += v
		worst = maxf(worst, v)
	return Vector2(sum / float(_filled) * 0.001, worst * 0.001)


func _mb(bytes: float) -> String:
	return "%.1fMB" % (bytes / 1048576.0)


func _refresh() -> void:
	if _label == null:
		return
	var fs := _frame_stats()
	var pr := _avg_max(_proc_us)
	var ph := _avg_max(_phys_us)
	var rt: Vector2 = get_viewport().get_texture().get_size()
	var lines := [
		"FPS  %d   frame %.1f / worst %.1f ms" % [
			int(Performance.get_monitor(Performance.TIME_FPS)), fs.x, fs.y],
		# avg / max 를 함께 낸다. 한 값만 보이면 최댓값을 평상시 부하로 오해한다(실제로 그랬다).
		"CPU  proc %.1f/%.1f  phys %.1f/%.1f ms (avg/max)" % [
			pr.x, pr.y, ph.x, ph.y],
		# 렌더 크기를 같이 찍는다 — HALF RES 토글이 실제로 먹었는지 이 값으로만 확인된다
		# (전체화면이나 웹 페이지가 캔버스 크기를 강제하면 토글이 무시될 수 있다).
		"DRAW calls %d  items %d  @%dx%d" % [
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
			int(rt.x), int(rt.y)],
		"MEM  video %s  tex %s" % [
			_mb(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
			_mb(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))],
		# 고아 노드 = 트리 밖 노드. 이 게임은 오브젝트 풀이 반납한 노드를 트리에서 떼어
		# 보관하므로 수백 개가 정상이다("pooled" 로 표기). 판단 기준은 절대값이 아니라
		# "시간이 지나도 계속 늘어나는가"다 — 계속 늘면 그때가 진짜 누수다.
		"NODE tree %d  pooled %d" % [
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))],
		"GAME zombies %d  gems %d" % [_zombie_count(), _Gold.live_gems().size()],
		"FX   dmg %d/%d  burst %d/%d  spr %d/%d  lit %d/%d" % [
			_DamageNumber.debug_active(), _DamageNumber.debug_cap(),
			_FXBurst.debug_active(), _FXBurst.debug_cap(),
			_SpriteFX.debug_active(), _SpriteFX.debug_cap(),
			_FXLightning.debug_active(), _FXLightning.debug_cap()],
	]
	_label.text = "\n".join(lines)
	# 배경은 글자 크기에 맞춰 따라간다(줄 수·폰트가 바뀌어도 어긋나지 않게).
	# get_minimum_size() 는 레이아웃을 기다리지 않고 텍스트 기준 크기를 바로 준다.
	_bg.size = _label.get_minimum_size() + Vector2(16, 12)


## 우선순위 양 끝에 놓는 탐침. 앞쪽은 시각만 찍고, 뒤쪽이 차이를 계산한다.
## 이 사이에 있는 모든 노드의 콜백 시간이 곧 "스크립트 CPU" 다.
class _Probe extends Node:
	var first: _Probe = null   # 뒤쪽 탐침만 채운다
	var t0: int = 0            # 앞쪽: 이번 _process 시작 시각(us)
	var ph_t0: int = 0         # 앞쪽: 이번 물리 틱 시작 시각(us)
	var proc_us: int = 0       # 뒤쪽: 직전 _process 한 바퀴에 걸린 시간
	var phys_us: int = 0       # 뒤쪽: 이번 렌더 프레임의 물리 틱 시간 **합**

	func _process(_d: float) -> void:
		if first == null:
			t0 = Time.get_ticks_usec()
		else:
			proc_us = Time.get_ticks_usec() - first.t0

	func _physics_process(_d: float) -> void:
		if first == null:
			ph_t0 = Time.get_ticks_usec()
		else:
			phys_us += Time.get_ticks_usec() - first.ph_t0


## 화면에 찍는 것과 **같은 수치**를 자동 플레이테스트(`tools/playtest.gd`)에 넘긴다.
## 별도로 다시 재지 않는 이유가 곧 요점이다 — 테스트가 보는 값과 사람이 화면에서 보는 값이
## 갈라지면, 재현이 안 되는 제보를 쫓게 된다(이번 5-R 진단이 정확히 그랬다).
## 표시가 갱신 주기(REFRESH)에 묶여 있는 것과 달리 이 함수는 부르는 즉시 현재 창을 계산한다.
func debug_stats() -> Dictionary:
	var fs := _frame_stats()
	var pr := _avg_max(_proc_us)
	var ph := _avg_max(_phys_us)
	var rt: Vector2 = get_viewport().get_texture().get_size()
	return {
		"fps": int(Performance.get_monitor(Performance.TIME_FPS)),
		"frame_avg": fs.x, "frame_worst": fs.y,
		"proc_avg": pr.x, "proc_max": pr.y,
		"phys_avg": ph.x, "phys_max": ph.y,
		"draw": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"items": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"render": rt,
		"tex_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"zombies": _zombie_count(),
		"gems": _Gold.live_gems().size(),
	}


func _zombie_count() -> int:
	var t := get_tree()
	return t.get_nodes_in_group("zombies").size() if t != null else 0
