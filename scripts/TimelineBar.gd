extends Control
## 런 타임라인 바 — 상단 바 아래쪽 가장자리에 걸린 얇은 띠. "지금 어디쯤이고 다음에 무엇이
## 오는가"를 한눈에 준다.
##
## 왜 필요한가: 30분 런의 마일스톤은 엘리트 5회 + 보스 2~3회뿐인데 그 리듬이 화면 어디에도
## 보이지 않았다. 남은 시간 카운트다운(TimeLabel)은 "언제 끝나는가"만 말할 뿐 "다음에 무엇이
## 오는가"는 말하지 않는다 — "버티는 것 말고 할 일이 없다"는 체감의 직접적 원인이다(HANDOFF P1-4).
##
## 눈금은 **스포너가 알려준 실제 예정 시각**(Events.forecast_changed)에서 그린다. 상수로 따로
## 계산하면 반드시 어긋난다 — 보스는 전투 중이면 미뤄지고, 치트(TIME +5 MIN)로도 밀린다.
## 그래서 지나간 마일스톤은 그리지 않는다(기록이 없으므로 추측이 되고, 추측은 거짓말이 된다).
## 왼쪽의 채움이 곧 "지나온 시간"이고, 오른쪽의 눈금이 "앞으로 올 것"이다.

const H := 8.0                       # 띠 높이
const TICK_W := 3.0                  # 눈금 폭
const BOSS_TICK_H := 8.0             # 보스 눈금은 띠를 꽉 채운다
const ELITE_TICK_H := 5.0            # 엘리트는 낮게 — 위계가 눈에 먼저 읽히도록
## 트랙은 진하게 깐다 — 상단 패널 위에 얹히므로 옅으면 빈 구간이 패널 배경과 구분되지 않아
## "앞으로 남은 길"이 읽히지 않는다(실렌더에서 확인).
const TRACK := Color(0.05, 0.06, 0.09, 0.95)
const FILL := Color(0.35, 0.55, 0.75, 0.75)
const FILL_OVER := Color(1.0, 0.82, 0.25, 0.85)   # 연장전에는 금색으로 가득 찬다
const ELITE_COL := Color(1.0, 0.55, 0.25, 0.95)
const BOSS_COL := Color(1.0, 0.28, 0.26, 1.0)
const CLEAR_COL := Color(1.0, 0.85, 0.3, 1.0)
const CURSOR_COL := Color(1.0, 1.0, 1.0, 0.9)
const CURSOR_W := 2.0

var _elapsed: float = 0.0
var _clear: float = 1800.0
var _next_boss: float = -1.0
var _next_elite: float = -1.0
var _boss_period: float = 600.0
var _elite_period: float = 300.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var d = GameData.difficulty
	if d != null:
		_clear = d.clear_seconds
		_boss_period = d.boss_seconds
		_elite_period = d.elite_seconds
	Events.run_progress.connect(_on_run_progress)
	Events.forecast_changed.connect(_on_forecast)


func _on_run_progress(elapsed: float, clear: float) -> void:
	_elapsed = elapsed
	_clear = maxf(clear, 1.0)
	queue_redraw()


func _on_forecast(next_boss: float, next_elite: float) -> void:
	_next_boss = next_boss
	_next_elite = next_elite
	queue_redraw()


## 경과 초 → 띠 위의 x 좌표.
func _x_of(t: float) -> float:
	return size.x * clampf(t / _clear, 0.0, 1.0)


func _draw() -> void:
	var w := size.x
	draw_rect(Rect2(0.0, 0.0, w, H), TRACK, true)

	var over := _elapsed >= _clear
	var fw := _x_of(_elapsed)
	if fw > 0.0:
		draw_rect(Rect2(0.0, 0.0, fw, H), FILL_OVER if over else FILL, true)
	if over:
		return   # 연장전에는 예정이 없다 — 가득 찬 금색 띠만 남긴다

	# 앞으로 올 엘리트/보스를 각자의 주기로 클리어 시점까지 찍는다.
	_draw_series(_next_elite, _elite_period, ELITE_TICK_H, ELITE_COL)
	_draw_series(_next_boss, _boss_period, BOSS_TICK_H, BOSS_COL)

	# 클리어 지점(오른쪽 끝) — 이 런의 목표.
	draw_rect(Rect2(w - TICK_W, 0.0, TICK_W, H), CLEAR_COL, true)

	# 현재 위치 — 채움의 끝에 얇은 흰 선. 눈금과의 거리가 곧 "얼마나 남았는가"다.
	draw_rect(Rect2(maxf(fw - CURSOR_W * 0.5, 0.0), -1.0, CURSOR_W, H + 2.0), CURSOR_COL, true)


func _draw_series(first: float, period: float, tick_h: float, col: Color) -> void:
	for t in series_times(first, period, _clear):
		draw_rect(Rect2(_x_of(t) - TICK_W * 0.5, H - tick_h, TICK_W, tick_h), col, true)


## 다음 예정 시각부터 주기마다 클리어 시점까지의 눈금 시각들. 그리기와 분리해 둔 이유는
## 이것이 이 컴포넌트에서 유일하게 틀릴 수 있는 계산이고, 화면 없이 검증할 수 있어야 해서다.
## first < 0 이면 "예정 없음"(보스전 중)이라 빈 배열이다.
static func series_times(first: float, period: float, clear: float) -> Array:
	var out: Array = []
	if first < 0.0 or period <= 0.0:
		return out
	var t := first
	# guard: 주기가 비정상적으로 작아도 무한 루프에 빠지지 않게 한다.
	while t <= clear and out.size() < 64:
		out.append(t)
		t += period
	return out
