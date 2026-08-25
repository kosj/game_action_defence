@tool
extends SceneTree
## 2D 배칭 최소 재현 (P1-30) — **무엇이 배치를 끊는지 조합별로 직접 잰다.**
##
## 왜 — P1-28·P1-29 가 로드아웃의 잔여 29콜을 두 번 추론으로 설명하려다 둘 다 틀렸다
## (나인패치·filter_clip). 게임 안에서 재면 변수가 너무 많다. 같은 텍스처·같은 노드 종류로
## 최소 재현을 세우고 구조만 바꿔 가며 재면 원인이 한 줄로 나온다.
##
##   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 720x1280x24" \
##     godot --path . --rendering-driver opengl3 --script res://tools/probe_batching.gd
##
## 각 판은 **직전 판을 지우고** 새로 세운 뒤 같은 프레임 수로 잰다. 기준선(빈 화면)을 빼서
## 그 구조가 내는 콜만 남긴다.

const N := 15                    # 로드아웃 슬롯 수와 같게
const FRAME := "res://assets/atlas/ui/weapon_pistol.tres"
const ICON := "res://assets/atlas/ui/weapon_gatling.tres"
const SAMPLE := 24
const SETTLE := 4

var _host: CanvasLayer = null
var _cases: Array = []
var _i := -1
var _buf: Array = []
var _settle := 0
var _base := 0
var _out: Array = []


func _init() -> void:
	_cases = [
		"빈 화면(기준선)",
		"프레임 15 (아틀라스 A)",
		"프레임 15 + 아이콘 15, **평평하게 종류별로**",
		"프레임 15 + 아이콘 15, 슬롯마다 번갈아",
		"슬롯 15 × (프레임+아이콘), z 없음",
		"슬롯 15 × (프레임+아이콘), z 0/1",
		"뱃지 15 (Label)",
		"슬롯 15 × (프레임+아이콘+뱃지), z 0/1/2",
		"평평하게: 프레임 15 → 아이콘 15 → 뱃지 15",
		"뱃지 15 (Label + 외곽선 4)",
		"슬롯 15 × (프레임+아이콘+**외곽선 뱃지**), z 0/1/2",
		"위 구조를 PanelContainer(StyleBoxFlat 둥근) 안에",
		"위 구조를 PanelContainer 안에 + HBox 두 줄로",
	]


func _process(_d: float) -> bool:
	if _settle > 0:
		_settle -= 1
		return false
	if _i >= 0 and _buf.size() < SAMPLE:
		_buf.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		return false
	if _i >= 0:
		var med := _median(_buf)
		if _i == 0:
			_base = med
		_out.append([_cases[_i], med, med - _base])
		_buf.clear()
	_i += 1
	if _i >= _cases.size():
		_report()
		return true
	_build(_i)
	_settle = SETTLE
	return false


func _clear() -> void:
	if _host != null:
		_host.queue_free()
	_host = CanvasLayer.new()
	root.add_child(_host)


func _frame_rect(tex: Texture2D, x: int, y: int, z: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.position = Vector2(x, y)
	t.size = Vector2(44, 44)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.z_index = z
	return t


func _badge(x: int, y: int, z: int, outline: bool = false) -> Label:
	var l := Label.new()
	l.text = "7"
	l.position = Vector2(x + 30, y + 26)
	l.add_theme_font_size_override("font_size", 13)
	if outline:
		# HUD 의 뱃지와 같은 설정 — 외곽선은 글리프를 한 번 더 그린다.
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		l.add_theme_constant_override("outline_size", 4)
	l.z_index = z
	return l


## HUD 로드아웃과 같은 슬롯 하나(프레임 + 아이콘 + 뱃지).
func _slot(fa: Texture2D, ib: Texture2D, x: int, outline: bool) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(44, 44)
	slot.position = Vector2(x, 0)
	slot.size = Vector2(44, 44)
	slot.add_child(_frame_rect(fa, 0, 0, 0))
	slot.add_child(_frame_rect(ib, 0, 0, 1))
	slot.add_child(_badge(0, 0, 2, outline))
	return slot


## HUD 와 같은 반투명 둥근 패널 배경.
func _panel() -> PanelContainer:
	var pc := PanelContainer.new()
	pc.position = Vector2(8, 100)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.40)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 7.0
	sb.content_margin_right = 7.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	pc.add_theme_stylebox_override("panel", sb)
	return pc


func _build(idx: int) -> void:
	_clear()
	var fa := load(FRAME) as Texture2D
	var ib := load(ICON) as Texture2D
	match idx:
		0:
			pass
		1:
			for i in N:
				_host.add_child(_frame_rect(fa, 10 + i * 46, 100, 0))
		2:
			for i in N:
				_host.add_child(_frame_rect(fa, 10 + i * 46, 100, 0))
			for i in N:
				_host.add_child(_frame_rect(ib, 10 + i * 46, 100, 0))
		3:
			for i in N:
				_host.add_child(_frame_rect(fa, 10 + i * 46, 100, 0))
				_host.add_child(_frame_rect(ib, 10 + i * 46, 100, 0))
		4, 5:
			var z_on: bool = idx == 5
			for i in N:
				var slot := Control.new()
				slot.position = Vector2(10 + i * 46, 100)
				slot.size = Vector2(44, 44)
				_host.add_child(slot)
				slot.add_child(_frame_rect(fa, 0, 0, 0 if z_on else 0))
				slot.add_child(_frame_rect(ib, 0, 0, 1 if z_on else 0))
		6:
			for i in N:
				_host.add_child(_badge(10 + i * 46, 100, 0))
		7:
			for i in N:
				var slot2 := Control.new()
				slot2.position = Vector2(10 + i * 46, 100)
				slot2.size = Vector2(44, 44)
				_host.add_child(slot2)
				slot2.add_child(_frame_rect(fa, 0, 0, 0))
				slot2.add_child(_frame_rect(ib, 0, 0, 1))
				slot2.add_child(_badge(0, 0, 2))
		8:
			for i in N:
				_host.add_child(_frame_rect(fa, 10 + i * 46, 100, 0))
			for i in N:
				_host.add_child(_frame_rect(ib, 10 + i * 46, 100, 0))
			for i in N:
				_host.add_child(_badge(10 + i * 46, 100, 0))
		9:
			for i in N:
				_host.add_child(_badge(10 + i * 46, 100, 0, true))
		10:
			for i in N:
				_host.add_child(_slot(fa, ib, 10 + i * 46, true))
		11:
			var pc := _panel()
			_host.add_child(pc)
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 5)
			pc.add_child(hb)
			for i in N:
				hb.add_child(_slot(fa, ib, 0, true))
		12:
			var pc2 := _panel()
			_host.add_child(pc2)
			var vb := VBoxContainer.new()
			vb.add_theme_constant_override("separation", 5)
			pc2.add_child(vb)
			for row in 2:
				var hb2 := HBoxContainer.new()
				hb2.add_theme_constant_override("separation", 5)
				vb.add_child(hb2)
				for i in 8 if row == 0 else 7:
					hb2.add_child(_slot(fa, ib, 0, true))


func _median(v: Array) -> int:
	if v.is_empty():
		return 0
	var t := v.duplicate()
	t.sort()
	return int(t[t.size() / 2])


func _report() -> void:
	print("")
	print("── 2D 배칭 최소 재현 (N=%d) ──────────────────────────" % N)
	for r in _out:
		print("  %-46s %3d 콜  (기준선 대비 %+3d)" % [r[0], r[1], r[2]])
	print("")
	print("  아틀라스 A/B 는 같은 ui.png 의 다른 region 이다.")
	quit(0)
