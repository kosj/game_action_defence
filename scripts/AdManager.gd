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

## true 면 SDK 없이 내장 더미 광고로 동작(개발/웹/에디터 프리뷰용).
## 안드로이드 실광고 빌드에서만 false 로 바꾼다(SETUP_ADS.md 참고). 웹/PC 는 계속 true 권장.
const USE_STUB := true

## ── AdMob 설정 (자세한 절차는 SETUP_ADS.md) ─────────────────────────────
## 개발 중엔 반드시 true = 구글 공식 테스트 광고(자기 광고 클릭/노출로 인한 정지 위험 없음).
## 출시 시 false + 아래 REAL ID 를 실제 값으로 채운다.
const USE_TEST_ADS := true
## AdMob 앱 ID — AndroidManifest 의 meta-data 값과 반드시 동일해야 한다.
const ADMOB_APP_ID_TEST := "ca-app-pub-3940256099942544~3347511713"   # 구글 테스트 App ID
const ADMOB_APP_ID_REAL := "ca-app-pub-0000000000000000~0000000000"   # TODO: 내 AdMob 앱 ID
## 보상형 광고 단위 ID
const REWARDED_UNIT_TEST := "ca-app-pub-3940256099942544/5224354917"  # 구글 테스트 rewarded
const REWARDED_UNIT_REAL := "ca-app-pub-0000000000000000/0000000000"  # TODO: 내 보상형 광고단위

## 더미 광고 강제 시청 시간(초). 보상형의 "끝까지 봐야 보상" 흐름을 흉내.
const STUB_WATCH_SECONDS := 3

var _busy := false
var _placement := ""

# ── 실 SDK 상태 ──────────────────────────────────────────────────────
var _rewarded_loaded := false   # rewarded 광고 로드 완료 여부
var _consent_ok := true         # UMP 동의 절차 완료(개인화/비개인화 결정) 여부


static func admob_app_id() -> String:
	return ADMOB_APP_ID_TEST if USE_TEST_ADS else ADMOB_APP_ID_REAL


static func rewarded_unit_id() -> String:
	return REWARDED_UNIT_TEST if USE_TEST_ADS else REWARDED_UNIT_REAL


func _ready() -> void:
	if not USE_STUB:
		_admob_init()   # 실광고 빌드에서만 SDK 초기화 + 동의 + 첫 로드

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
# 실 SDK 연동은 아래 _admob_* 4개 메서드에만 존재한다(SETUP_ADS.md 의 스니펫으로 채운다).
# 이 함수들은 그 위의 얇은 어댑터라, 호출부(HUD·상점)와 공통 종료 처리(_grant/_dismiss)는
# SDK 유무를 전혀 몰라도 된다.

func _real_rewarded_ready() -> bool:
	# UMP 동의가 끝나고 rewarded 광고 로드가 완료돼야 노출 가능.
	return _consent_ok and _admob_is_loaded()


func _show_real_rewarded(placement: String) -> void:
	# 로드가 안 됐으면 즉시 보상 없이 닫고(_dismiss) 다음 광고를 미리 로드한다.
	if not _admob_is_loaded():
		_dismiss(placement)
		return
	_admob_show_rewarded(placement)


# ───────────────────────── AdMob(poing-studios) 어댑터 ─────────────────────────
# 플러그인이 미설치여도 스크립트가 파싱되도록, 여기서는 플러그인 클래스를 "직접 참조하지 않는다".
# 안드로이드 실광고 빌드에서 addon 을 설치한 뒤 SETUP_ADS.md 의 스니펫으로 아래 본문을 채운다.
# 채울 때 지켜야 할 계약:
#   · 보상 획득 콜백 → _grant(placement)   · 닫힘/노출 실패 콜백 → _dismiss(placement)
#   · 로드 완료 시 _rewarded_loaded = true, 노출/실패 후에는 _admob_load_rewarded() 로 재로드
#   · 두 종료 콜백 모두 CONNECT_ONE_SHOT 으로 연결(placement 별 중복 지급/닫힘 방지)

func _admob_init() -> void:
	# TODO(SETUP_ADS.md): MobileAds 초기화 + UMP 동의 요청. 동의 확정 시 _consent_ok = true 후
	# _admob_load_rewarded() 호출. 미연동 상태에선 아무 것도 하지 않아 스텁처럼 안전하다.
	pass


func _admob_load_rewarded() -> void:
	# TODO(SETUP_ADS.md): LoadAdRequest 로 rewarded_unit_id() 로드. 성공 콜백에서
	# _rewarded_loaded = true. 이 골격에서는 로드가 없으므로 항상 미로드로 남는다.
	pass


func _admob_is_loaded() -> bool:
	return _rewarded_loaded


func _admob_show_rewarded(placement: String) -> void:
	# TODO(SETUP_ADS.md): 로드된 rewarded 인스턴스에 콜백 연결 후 show().
	#   user_earned_reward     → _grant(placement)
	#   dismissed / show 실패   → _dismiss(placement)
	# 미연동 골격에서는 절대 여기 도달하지 않지만(위에서 미로드로 걸러짐) 안전하게 닫는다.
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
	# 실광고: 방금 소비한 rewarded 를 즉시 다음 노출용으로 다시 로드해 둔다(광고는 1회용).
	if not USE_STUB:
		_rewarded_loaded = false
		_admob_load_rewarded()


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
