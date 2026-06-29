extends Node
## 보상형 광고 매니저 (Autoload 싱글톤: "AdManager").
##
## 광고 SDK 없이도 동작하는 "골격"이다. 호출부(HUD·상점)는 SDK 유무를 전혀 모른 채
## show_rewarded() 를 부르고 rewarded_granted 시그널로만 보상을 받는다.
## 실제 SDK(AdMob / AppLovin MAX / Unity LevelPlay)는 _show_real_rewarded() 자리에 끼우고
## USE_STUB 를 false 로 바꾸면 호출부 수정 없이 그대로 동작한다.
##
## 사용 예:
##   AdManager.rewarded_granted.connect(_on_reward)   # placement 로 어떤 보상인지 구분
##   if AdManager.is_rewarded_ready():
##       AdManager.show_rewarded("revive")

## 보상형 영상 시청 완료 → 보상 지급. placement 로 호출 맥락 구분("revive","shop_gold" 등).
signal rewarded_granted(placement: String)
## 광고가 보상 없이 닫힘(중도 종료) 또는 노출 실패.
signal rewarded_dismissed(placement: String)

## true 면 SDK 없이 내장 더미 광고로 동작(개발/웹 프리뷰용).
## 실제 SDK 연동 시 false 로 바꾸고 _show_real_rewarded() / _real_rewarded_ready() 를 구현한다.
const USE_STUB := true

## 더미 광고 강제 시청 시간(초). 보상형의 "끝까지 봐야 보상" 흐름을 흉내.
const STUB_WATCH_SECONDS := 3

var _busy := false
var _placement := ""

# 더미 광고 오버레이 (지연 생성). 오토로드 하위에 두면 씬 전환과 무관하게 유지된다.
var _layer: CanvasLayer
var _title: Label
var _count_label: Label
var _claim_btn: Button
var _count := 0


## 보상형 광고를 지금 노출할 수 있는 상태인지. (실 SDK 에선 load 완료 여부를 반환)
func is_rewarded_ready() -> bool:
	if _busy:
		return false
	return true if USE_STUB else _real_rewarded_ready()


## 보상형 광고 노출. 완료 시 rewarded_granted(placement), 중도종료/실패 시 rewarded_dismissed.
func show_rewarded(placement: String) -> void:
	if _busy:
		return
	_busy = true
	_placement = placement
	if USE_STUB:
		_show_stub_rewarded()
	else:
		_show_real_rewarded(placement)


# ───────────────────────── 실제 SDK 연동 지점 ─────────────────────────
# 아래 두 함수만 채우면 된다. 보상은 _grant(), 보상 없는 닫힘/실패는 _dismiss() 로 통일.

func _real_rewarded_ready() -> bool:
	# TODO: SDK 의 isRewardedReady() 결과를 반환.
	#   예) return _admob_rewarded != null and _admob_rewarded.is_loaded()
	return false


func _show_real_rewarded(placement: String) -> void:
	# TODO: 여기서 실제 SDK 의 rewarded.show() 호출 후 콜백을 연결한다.
	#   AdMob(poing-studios/godot-admob-android) 예시:
	#     _admob_rewarded.user_earned_rewarded.connect(func(_t, _a): _grant(placement), CONNECT_ONE_SHOT)
	#     _admob_rewarded.rewarded_ad_dismissed_full_screen_content.connect(func(): _dismiss(placement), CONNECT_ONE_SHOT)
	#     _admob_rewarded.show()
	# SDK 미연동 상태이므로 안전하게 보상 없이 종료한다.
	_dismiss(placement)


# ───────────────────────── 더미(스텁) 구현 ─────────────────────────

func _show_stub_rewarded() -> void:
	_ensure_overlay()
	_count = STUB_WATCH_SECONDS
	_title.text = Locale.t("ad_title")
	_claim_btn.visible = false
	_layer.visible = true
	_tick()


## 1초마다 카운트다운. 0 이 되면 "보상 받기" 버튼을 띄워 유저가 닫으며 보상 확정.
func _tick() -> void:
	if _count <= 0:
		_count_label.text = Locale.t("ad_finished")
		_claim_btn.visible = true
		return
	_count_label.text = Locale.t("ad_watch_fmt") % _count
	_count -= 1
	# process_always 타이머라 트리가 일시정지돼도 흐른다.
	get_tree().create_timer(1.0).timeout.connect(_tick, CONNECT_ONE_SHOT)


func _on_claim_pressed() -> void:
	_layer.visible = false
	_grant(_placement)


# ───────────────────────── 공통 종료 처리 ─────────────────────────

func _grant(placement: String) -> void:
	_finish()
	rewarded_granted.emit(placement)


func _dismiss(placement: String) -> void:
	_finish()
	rewarded_dismissed.emit(placement)


func _finish() -> void:
	_busy = false
	_placement = ""


# ───────────────────────── 더미 오버레이 UI (코드로 생성) ─────────────────────────

func _ensure_overlay() -> void:
	if _layer != null:
		return
	_layer = CanvasLayer.new()
	_layer.layer = 100   # 상점(10)·HUD 보다 위
	_layer.visible = false
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.92)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP   # 뒤쪽 입력 차단
	_layer.add_child(dim)

	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -200.0
	box.offset_right = 200.0
	box.offset_top = -150.0
	box.offset_bottom = 150.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	_layer.add_child(box)

	_title = _make_label(Locale.t("ad_title"), 30)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	box.add_child(_title)

	_count_label = _make_label(Locale.t("ad_watch_fmt") % STUB_WATCH_SECONDS, 22)
	box.add_child(_count_label)

	var hint := _make_label(Locale.t("ad_demo_hint"), 13)
	hint.add_theme_color_override("font_color", Color(0.65, 0.67, 0.72))
	box.add_child(hint)

	_claim_btn = Button.new()
	_claim_btn.text = Locale.t("ad_claim")
	_claim_btn.custom_minimum_size = Vector2(0, 56)
	_claim_btn.add_theme_font_size_override("font_size", 22)
	_claim_btn.visible = false
	_claim_btn.pressed.connect(_on_claim_pressed)
	box.add_child(_claim_btn)


func _make_label(txt: String, size: int) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", size)
	return lbl
