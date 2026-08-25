extends Control
class_name BitmapNumber
## 외곽선 있는 숫자를 **쿼드 한 번**으로 그리는 UI 노드 (P1-33).
##
## 왜 필요한가
## -----------
## `Label` 에 `outline_size` 를 켜면 엔진이 글리프를 두 번 그린다(외곽선 패스 → 본체 패스).
## 두 패스는 서로 배칭되지 않으므로 **라벨 하나가 정확히 드로우 콜 2개**다. 최소 재현에서
## 외곽선 없는 뱃지 15개가 2콜, 켜면 31콜이었다(OPTIMIZATION_PLAN §5-P).
##
## 배포 빌드에서 그 대가가 실측됐다(§5-R): HUD 를 통째로 숨기면 드로우 콜 130 → 60,
## **프레임 48.7 → 41.7ms · fps 20.5 → 24.0**. HUD 는 배포 빌드 프레임의 14% 다.
## (⚠️ 데스크톱 xvfb 소프트웨어 렌더로는 이게 안 보인다 — 래스터가 포화해 66.67ms 로 고정된다.
##  드로우 콜의 값어치는 **웹 빌드에서만** 잴 수 있다.)
##
## 어떻게
## ------
## P1-27 이 데미지 숫자에 쓴 방식을 그대로 쓴다: **검은 외곽선 + 흰 글리프를 한 장에 구운**
## 아틀라스(`assets/atlas/dmg_0..9.tres`)를 쿼드로 그리고 색은 `modulate` 로 곱한다.
## 외곽선은 `0 × c = 0` 이라 검정 그대로고 글리프만 색이 된다.
## 같은 텍스처를 쓰므로 **뱃지가 몇 개든 한 배치로 묶인다.**
##
## 쓰는 법
##   var n := BitmapNumber.new()
##   n.font_size = 13          # Label 의 font_size 와 같은 뜻(24pt 기준으로 환산해 그린다)
##   n.value = 7
##   n.number_color = Color(1.0, 0.95, 0.8)

## 구운 글리프의 기준 폰트 크기와 치수 — `tools/gen_damage_digits.gd` 산출물에 맞춘 값이라
## `DamageNumber` 와 같아야 한다. 저기가 바뀌면 여기도 같이 바뀐다.
## 글리프를 구운 폰트 — 디센트를 물어보는 용도다(UITheme.FONT_PATH 와 같아야 한다).
const _FONT_PATH := "res://assets/fonts/NotoSansCJK-Subset.otf"
const BASE_FONT_SIZE := 24.0
const GLYPH_ADVANCE := 13.0000
const GLYPH_OFFSET := Vector2(-1.3333, -19.6667)
const GLYPH_SIZE := Vector2(15.6667, 21.6667)

## ⚠️ 최상위 preload 로 두면 오토로드 등록 전에 컴파일되는 도구 스크립트에서 터진다.
## 여기는 UI 노드라 그럴 일이 없고, DamageNumber 와 같은 아틀라스를 preload 해야
## 같은 텍스처로 묶인다.
const _DIGIT_TEX := [
	preload("res://assets/atlas/dmg_0.tres"), preload("res://assets/atlas/dmg_1.tres"),
	preload("res://assets/atlas/dmg_2.tres"), preload("res://assets/atlas/dmg_3.tres"),
	preload("res://assets/atlas/dmg_4.tres"), preload("res://assets/atlas/dmg_5.tres"),
	preload("res://assets/atlas/dmg_6.tres"), preload("res://assets/atlas/dmg_7.tres"),
	preload("res://assets/atlas/dmg_8.tres"), preload("res://assets/atlas/dmg_9.tres"),
]

## 가로 정렬. 뱃지는 오른쪽 아래에 붙으므로 RIGHT 가 기본이다.
enum Align { LEFT, CENTER, RIGHT }

@export var value: int = 0: set = _set_value
@export var font_size: float = 13.0: set = _set_font_size
@export var number_color: Color = Color.WHITE: set = _set_color
@export var align: Align = Align.RIGHT

var _digits: PackedByteArray = PackedByteArray()


func _set_value(v: int) -> void:
	if v == value and not _digits.is_empty():
		return
	value = v
	_rebuild()


func _set_font_size(v: float) -> void:
	font_size = v
	queue_redraw()


func _set_color(c: Color) -> void:
	number_color = c
	# 색은 노드 modulate 로 곱한다 — 다시 그릴 필요가 없다(외곽선은 검정으로 남는다).
	modulate = c


func _rebuild() -> void:
	_digits.clear()
	var n: int = absi(value)
	if n == 0:
		_digits.append(0)
	else:
		while n > 0:
			_digits.insert(0, n % 10)
			n /= 10
	queue_redraw()


## 폰트 디센트(px). 글리프를 구운 그 폰트에서 받는다 — 여기서 글자를 그리는 것이 아니라
## 치수만 묻는 것이라 글리프 아틀라스가 바인딩되지 않는다(드로우 콜이 늘지 않는다).
static var _font: Font = null


func _descent(px: float) -> float:
	if _font == null:
		_font = load(_FONT_PATH) as Font
	return _font.get_descent(int(round(px))) if _font != null else px * 0.24


## 그려지는 숫자의 픽셀 폭 — 부모가 자리를 잡을 때 쓴다.
func number_width() -> float:
	return GLYPH_ADVANCE * (font_size / BASE_FONT_SIZE) * float(maxi(_digits.size(), 1))


func _draw() -> void:
	if _digits.is_empty():
		_rebuild()
		if _digits.is_empty():
			return
	var sc := font_size / BASE_FONT_SIZE
	var adv := GLYPH_ADVANCE * sc
	var qsz := GLYPH_SIZE * sc
	var qoff := GLYPH_OFFSET * sc
	# 세로: 구운 글리프는 펜 위치(베이스라인) 기준이라 GLYPH_OFFSET.y 가 음수다.
	#
	# ⚠️ 베이스라인을 노드 바닥에 그대로 두면 **`Label` 보다 디센트만큼 아래로 내려간다** —
	# 실측으로 13pt 에서 약 4px 이었고, 뱃지가 슬롯 테두리에 걸쳤다. `Label` 은 사각형 아래에
	# 디센트 자리를 비워 두고 그 위에 베이스라인을 놓기 때문이다. 같은 폰트에서 디센트를
	# 받아 빼면 라벨 시절과 픽셀이 맞는다(글리프도 이 폰트에서 구웠으므로 같은 값이다).
	var baseline := size.y - _descent(font_size)
	var total := adv * float(_digits.size())
	var x := 0.0
	match align:
		Align.CENTER:
			x = (size.x - total) * 0.5
		Align.RIGHT:
			x = size.x - total
		_:
			x = 0.0
	for i in _digits.size():
		draw_texture_rect(_DIGIT_TEX[_digits[i]], Rect2(Vector2(x, baseline) + qoff, qsz), false)
		x += adv
