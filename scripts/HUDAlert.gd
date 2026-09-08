class_name HUDAlert
extends Control
## 화면 상단 위험 경고 띠 — 좀비 무리·정예 무리·보스 예고/등장이 함께 쓴다.
##
## 왜 만들었나: 예고가 **색만 다른 글자 한 줄**이었다. 스웜도 보스도 같은 라벨에 글자만
## 바뀌었고, 위험의 크기는 글자색(노랑/주황/빨강)으로만 구분됐다 — 전투 중 화면 가운데를
## 보고 있는 눈에는 그 차이가 거의 안 읽힌다. 위험을 **형태**로도 말하게 한다.
##
## 그리는 것(전부 이 노드의 `_draw` 하나 = 캔버스 아이템 하나라 배칭이 끊기지 않는다):
##   1. 어두운 띠 — 양끝으로 갈수록 투명해져 화면을 가로막지 않는다.
##   2. 위아래 강조선 — 가운데(글자가 있는 곳)에서 가장 진하다.
##   3. 위험 사선 3줄 × 양끝 — 안쪽으로 천천히 흐른다(공사장 위험 테이프의 문법).
##   4. 경고 삼각형 양끝 — 글자를 못 읽어도 "위험"이 읽히는 유일한 기호다.
##
## 위험도(level)가 색·머무는 시간·맥동 주기를 한꺼번에 정한다. 색만 바꾸던 것과 달리
## **보스는 더 빨리 뛰고 더 오래 남는다** — 같은 화면을 봐도 급함이 다르게 읽힌다.
##
## **띠는 화면에 하나뿐이다.** 보스 등장까지 이 하나를 같이 쓴다 — 예전에는 보스 이름이
## 별도 라벨(y210)이었고 예고 배너가 y260 이라 둘이 겹쳤다. 하나로 합치면서 규칙을 둔다:
## **더 큰 위험이 이긴다.** 같거나 높은 위험도만 지금 것을 덮어쓸 수 있어, 보스 등장이
## 뜬 순간에 무리 경고가 끼어들어 이름을 지우는 일이 없다(`_on_forecast` 가 이미 쓰던 원칙).
##
## 사용:
##     _alert = HUDAlert.make(self, 232.0, 58.0)
##     _alert.flash(Locale.t("hud_swarm"), HUDAlert.LV_SWARM, 30)

enum { LV_SWARM = 0, LV_ELITE = 1, LV_BOSS = 2 }

## 위험도별 색 — 기존 배너가 쓰던 세 색을 그대로 옮겼다(플레이어가 이미 익힌 신호다).
const ACCENT := [
	Color(1.00, 0.85, 0.25),   # 무리
	Color(1.00, 0.55, 0.25),   # 정예
	Color(1.00, 0.30, 0.26),   # 보스
]
## 머무는 시간. 보스는 대비할 것이 많아 더 오래 남는다.
const HOLD := [0.7, 0.9, 1.3]
## 맥동 반주기(초). 짧을수록 급하게 읽힌다.
const PULSE := [0.50, 0.38, 0.26]
## 경고음(P2-27). 한 악기의 세 구절 — 펄스 2·3·4 개로 위험도가 들린다(tools/gen_sfx.py).
const SOUND := ["warn_swarm", "warn_elite", "warn_boss"]

const BAND_COLOR := Color(0.04, 0.024, 0.03)   # 띠 바탕 — 무채색 검정보다 살짝 붉다
const BAND_ALPHA := 0.80
const FADE := 110.0        # 양끝 알파 페이드 폭
const RULE_H := 3.0        # 위아래 강조선 두께
const CHEV_W := 11.0       # 사선 하나의 폭
const CHEV_GAP := 19.0     # 사선 간격
const CHEV_N := 3          # 한쪽 사선 개수
const CHEV_X0 := 22.0
const CHEV_SPEED := 26.0   # 사선이 흐르는 속도(px/s)
const TRI := 20.0          # 경고 삼각형 크기
const TRI_X := 96.0        # 양끝에서 삼각형 중심까지
const TEXT_INSET := 130.0  # 글자가 삼각형·사선을 침범하지 않게 두는 여백

const IN_SEC := 0.20
const OUT_SEC := 0.40
const SCALE_IN := 0.72

var label: Label = null

var _accent: Color = ACCENT[0]
var _march: float = 0.0
var _tween: Tween = null
var _level: int = -1   # 지금 떠 있는 위험도(-1 = 없음)


## `_process` 를 정의하면 엔진이 기본으로 켠다 — 뜨기 전부터 매 프레임 돌 이유가 없다.
func _ready() -> void:
	set_process(false)


static func make(parent: Node, y: float, height: float) -> HUDAlert:
	var a := HUDAlert.new()
	a.set_anchors_preset(Control.PRESET_TOP_WIDE)
	a.offset_top = y
	a.offset_bottom = y + height
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a.visible = false   # 알파 0 인 풀와이드 사각형을 렌더에 남겨두지 않는다

	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.offset_left = TEXT_INSET
	lbl.offset_right = -TEXT_INSET
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.02, 0.95))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a.add_child(lbl)
	a.label = lbl

	parent.add_child(a)
	return a


## 경고 한 번. 이미 떠 있으면 **더 큰(또는 같은) 위험만** 덮어쓴다 — 이 자리에 두 줄이
## 겹치면 무엇을 피해야 할지 읽히지 않고, 낮은 쪽이 이기면 보스 이름이 무리 경고에
## 지워진다. 무시된 경우 false 를 돌려준다(호출부가 상태를 되돌릴 수 있게).
##
## 소리는 **띠가 실제로 뜰 때만** 난다 — 위의 조기 반환이 소리까지 함께 막으므로, 화면에
## 안 보이는 경고가 소리만 내는 일이 없다. `with_sound=false` 는 호출부에 이미 다른 소리가
## 있을 때 쓴다(보스 **등장**에는 `boss_alarm` 이 있다 — 예고와 등장은 다른 사건이다).
func flash(text: String, level: int, font_size: int, with_sound: bool = true) -> bool:
	var lv := clampi(level, 0, ACCENT.size() - 1)
	if visible and lv < _level:
		return false
	if with_sound:
		SoundManager.play(SOUND[lv], 0.02)
	_level = lv
	_accent = ACCENT[lv]
	label.add_theme_font_size_override("font_size", font_size)
	label.text = text
	label.add_theme_color_override("font_color", _accent)

	if _tween and _tween.is_valid():
		_tween.kill()
	visible = true
	set_process(true)
	modulate.a = 0.0
	self_modulate = Color.WHITE
	pivot_offset = size * 0.5
	scale = Vector2(SCALE_IN, SCALE_IN)
	queue_redraw()

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, IN_SEC)
	_tween.parallel().tween_property(self, "scale", Vector2.ONE, IN_SEC + 0.04)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 띠만 맥동한다. `self_modulate` 는 이 노드 자신의 그리기에만 곱해지고 자식(글자)에는
	# 번지지 않아, 글자는 밝기가 흔들리지 않고 그대로 읽힌다.
	# 상수 배열의 원소는 Variant 라 `:=` 로는 타입을 못 정한다 — 엔진 파서가 거부한다
	# (`check_gdscript.py` 는 문법만 보므로 여기서는 안 걸린다. CLAUDE.md §3).
	var half: float = PULSE[lv]
	var hold: float = HOLD[lv]
	var beats := int(ceil(hold / (half * 2.0)))
	for i in maxi(beats, 1):
		_tween.tween_property(self, "self_modulate", Color(1.5, 1.5, 1.5), half)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property(self, "self_modulate", Color.WHITE, half)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, OUT_SEC)
	_tween.tween_callback(_retire)
	return true


func _retire() -> void:
	visible = false
	_level = -1
	set_process(false)   # 안 보이는 동안 매 프레임 다시 그리지 않는다


func _process(delta: float) -> void:
	# 사선이 안쪽으로 흐른다. 보이는 동안에만 돈다(_retire 가 끈다).
	_march = fmod(_march + delta * CHEV_SPEED, CHEV_GAP)
	queue_redraw()


## 가로 그라데이션 사각형 하나. `draw_polygon` 은 정점마다 색을 받아 삼각형 안에서
## 보간해 준다 — 픽셀마다 사각형을 찍지 않고 명령 하나로 끝난다.
func _grad_quad(x0: float, x1: float, y0: float, y1: float, c0: Color, c1: Color) -> void:
	draw_polygon(
		PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]),
		PackedColorArray([c0, c1, c1, c0]))


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return

	# 1) 어두운 띠. 양끝은 완전히 투명해져 화면 가장자리를 막지 않는다.
	var b0 := Color(BAND_COLOR.r, BAND_COLOR.g, BAND_COLOR.b, 0.0)
	var b1 := Color(BAND_COLOR.r, BAND_COLOR.g, BAND_COLOR.b, BAND_ALPHA)
	_grad_quad(0.0, FADE, 0.0, h, b0, b1)
	_grad_quad(FADE, w - FADE, 0.0, h, b1, b1)
	_grad_quad(w - FADE, w, 0.0, h, b1, b0)

	# 2) 위아래 강조선 — 가운데가 가장 진하다(글자가 있는 곳으로 눈을 모은다).
	var r0 := Color(_accent.r, _accent.g, _accent.b, 0.0)
	var r1 := Color(_accent.r, _accent.g, _accent.b, 0.92)
	# 배열 리터럴을 그대로 돌면 원소가 Variant 다. Packed 배열은 원소 타입이 서 있어
	# 아래 `_grad_quad(float, ...)` 호출이 런타임 변환을 거치지 않는다.
	for band in PackedVector2Array([Vector2(0.0, RULE_H), Vector2(h - RULE_H, h)]):
		_grad_quad(0.0, w * 0.5, band.x, band.y, r0, r1)
		_grad_quad(w * 0.5, w, band.x, band.y, r1, r0)

	# 3) 위험 사선 — 양끝에서 안쪽으로 흐른다. 안쪽으로 갈수록 옅어져 글자를 방해하지 않는다.
	var slant := h * 0.42
	for i in CHEV_N:
		var a := 0.92 * pow(1.0 - float(i) / float(CHEV_N), 1.2)
		var col := Color(_accent.r, _accent.g, _accent.b, a)
		var x := CHEV_X0 + float(i) * CHEV_GAP + _march
		var pts := PackedVector2Array([
			Vector2(x, RULE_H), Vector2(x + CHEV_W, RULE_H),
			Vector2(x + CHEV_W - slant, h - RULE_H), Vector2(x - slant, h - RULE_H)])
		draw_colored_polygon(pts, col)
		var mir := PackedVector2Array()
		for p in pts:
			mir.append(Vector2(w - p.x, p.y))
		draw_colored_polygon(mir, col)

	# 4) 경고 삼각형 — 글자를 못 읽어도 이것 하나는 읽힌다.
	for cx in PackedFloat32Array([TRI_X, w - TRI_X]):
		var cy := h * 0.5
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx, cy - TRI * 0.62),
			Vector2(cx + TRI * 0.66, cy + TRI * 0.50),
			Vector2(cx - TRI * 0.66, cy + TRI * 0.50)]),
			Color(_accent.r, _accent.g, _accent.b, 0.96))
		# 느낌표는 삼각형을 파내는 방식이다 — 밝은 삼각형 위에 띠 색을 얹는다.
		var punch := Color(BAND_COLOR.r, BAND_COLOR.g, BAND_COLOR.b, 1.0)
		draw_rect(Rect2(cx - 1.6, cy - TRI * 0.20, 3.2, TRI * 0.34), punch)
		draw_rect(Rect2(cx - 1.6, cy + TRI * 0.24, 3.2, TRI * 0.12), punch)
