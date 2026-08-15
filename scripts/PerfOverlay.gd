extends Control
## 성능 디버그 오버레이 — 일시정지 메뉴의 CHEATS > PERF HUD 로 켠다.
##
## 왜 필요한가: 이 프로젝트의 성능 병목은 대부분 "그리기"쪽(바닥 재드로우·텍스트 렌더·
## fill-rate)에 있는데, 그건 헤드리스 측정으로는 드러나지 않는다. 실기기(특히 모바일
## 브라우저)에서 눈으로 확인할 수단이 필요해서 만든 화면이다.
##
## 표시 항목
##   FPS    현재 fps / 프레임 시간 평균 / 최근 구간 최악값(히칭 감지)
##   CPU    스크립트 _process·_physics_process 시간
##   DRAW   프레임당 드로우 콜·아이템 수 (바닥 재드로우, y_sort, FX 상한의 효과가 여기 보인다)
##   MEM    비디오 메모리 / 텍스처 메모리 (텍스처 압축 판단용)
##   NODE   노드 수 / 고아 노드(누수 감지)
##   GAME   좀비·젬 수
##   FX     이펙트별 동시 활성 수와 상한 — 상한에 계속 붙어 있으면 상한이 낮다는 뜻이다
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
var _idx: int = 0
var _filled: int = 0


func _ready() -> void:
	# 일시정지 중에도 수치가 갱신되어야 한다(정지 상태에서 메모리·노드 수를 확인할 때 필요).
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(10, 104)   # 상단 바(높이 96) 바로 아래
	_samples.resize(WINDOW)

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
	# 프레임 시간은 매 프레임 기록해야 히칭(순간 스파이크)을 놓치지 않는다.
	_samples[_idx] = delta
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


func _mb(bytes: float) -> String:
	return "%.1fMB" % (bytes / 1048576.0)


func _refresh() -> void:
	if _label == null:
		return
	var fs := _frame_stats()
	var lines := [
		"FPS  %d   frame %.1f / worst %.1f ms" % [
			int(Performance.get_monitor(Performance.TIME_FPS)), fs.x, fs.y],
		"CPU  proc %.2f  phys %.2f ms" % [
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0],
		"DRAW calls %d  items %d" % [
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))],
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


func _zombie_count() -> int:
	var t := get_tree()
	return t.get_nodes_in_group("zombies").size() if t != null else 0
