extends RefCounted
## 공통 팝업 셸 (POPUP_UI_PLAN Phase 2 / HANDOFF P2-1).
##
## 왜 필요한가: `MainMenu.gd` 안에 팝업 조립이 8번 복붙돼 있었다 — dim 8 · PanelContainer 8 ·
## MarginContainer 9 · HSeparator 11 · 닫기 버튼 6. 그래서 팝업마다 크기·여백·제목 크기·닫기
## 버튼이 조금씩 달랐고, 하나를 고쳐도 나머지 일곱은 그대로였다. 위계를 손보려면 여덟 군데를
## 같이 고쳐야 하는 구조 자체가 완성도가 유지되지 않는 원인이었다.
##
## 셸이 소유하는 것: 바깥 dim(탭하면 닫힘) · 프레임 · 여백 · 제목 · 선택적 힌트 · 구분선 ·
## 선택적 스크롤 · 닫기 버튼. 호출부는 **내용만** `body` 에 담는다.
##
## 크기는 전 팝업이 같다(전체 화면, 좌우 12 · 상하 30). 내용이 적은 팝업도 같은 틀을 쓰되
## `center_body` 로 본문을 세로 중앙에 두어 허전해 보이지 않게 한다(Phase 2-2).
##
## 사용:
##     var p := UIPopup.make(self, "popup_quests", UITheme.SEC_QUEST, UITheme.SEC_QUEST_TXT,
##             _on_quests_close, {"hint_key": "quest_hint", "scroll": true})
##     _quest_dim = p.dim ; _quest_panel = p.panel ; _quest_list = p.body
##     ...
##     UIPopup.open(_quest_dim, _quest_panel)     # 여는 쪽
##     UIPopup.close(_quest_dim, _quest_panel)    # 닫는 쪽
##
## **`visible` 을 직접 켜고 끄지 말 것.** 그렇게 하면 이 파일이 소유한 연출·사운드를 건너뛴다
## (예전에는 팝업 9종이 전부 그렇게 열리고 닫혀서 화면이 툭툭 바뀌었다 — UI_POLISH_PLAN §A-1).
##
## 반환: { dim, panel, body, close, vbox, title, hint }
##  - dim/panel 은 호출부가 UIPopup.open()/close() 에 그대로 넘긴다(연출은 셸이 소유한다).
##  - body 는 내용을 담을 컨테이너. scroll=true 면 ScrollContainer 안의 VBox 다.
##  - vbox 는 제목~닫기 사이의 세로 줄기. 닫기 버튼 위에 무언가를 더 붙여야 할 때 쓴다.
##  - title/hint 는 라벨. 언어 전환처럼 나중에 문구를 다시 넣는 화면이 쓴다(hint 는 없으면 null).

const _UIStyle := preload("res://scripts/UIStyle.gd")

const MARGIN_X := 12.0      # 화면 좌우 여백
const MARGIN_Y := 30.0      # 화면 상하 여백
const PAD := 22             # 프레임 안쪽 여백
const DIM_COLOR := Color(0, 0, 0, 0.6)
const TITLE_SIZE := 26
const HINT_SIZE := 14
const HINT_WIDTH := 440.0   # 힌트 줄바꿈 기준 폭
const CLOSE_H := 52.0
const CLOSE_BG := Color(0.18, 0.20, 0.26)
const CLOSE_ACCENT := Color(0.5, 0.55, 0.65)


## opts:
##   scroll        bool   — body 를 ScrollContainer 로 감싼다(항목이 늘어나는 목록형). 기본 false
##   hint_key      String — 제목 아래 회색 안내 한 줄
##   center_body   bool   — 내용이 적은 팝업. body 를 세로 중앙에 둔다
##   separation    int    — vbox 간격(기본 12)
##   close_key     String — 닫기 버튼 문구 키(기본 "menu_close")
static func make(parent: Node, title_key: String, accent: Color, accent_txt: Color,
		on_close: Callable, opts: Dictionary = {}) -> Dictionary:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = DIM_COLOR
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = false
	# 바깥 영역 탭 시 닫기. 터치와 마우스를 함께 본다(웹은 둘 다 들어온다).
	# 소리는 여기서 내지 않는다 — close() 가 닫힘음을 내므로 여기서도 내면 두 번 난다.
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed):
			on_close.call())
	parent.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = MARGIN_X
	panel.offset_right = -MARGIN_X
	panel.offset_top = MARGIN_Y
	panel.offset_bottom = -MARGIN_Y
	panel.add_theme_stylebox_override("panel", _UIStyle.panel(UITheme.BG_PANEL, accent))
	panel.visible = false
	parent.add_child(panel)

	var margin := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + m, PAD)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(opts.get("separation", 12)))
	margin.add_child(vb)

	var title := Label.new()
	title.text = Locale.t(title_key)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	title.add_theme_color_override("font_color", accent_txt)
	UITheme.heading(title)
	vb.add_child(title)

	var hint_label: Label = null
	var hint_key := String(opts.get("hint_key", ""))
	if hint_key != "":
		var hint := Label.new()
		hint.text = Locale.t(hint_key)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(HINT_WIDTH, 0)
		hint.add_theme_font_size_override("font_size", HINT_SIZE)
		hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		vb.add_child(hint)
		hint_label = hint

	vb.add_child(HSeparator.new())

	# 본문. 스크롤형은 목록이 길어져도 닫기 버튼이 화면 밖으로 밀리지 않게 한다.
	var body: VBoxContainer
	if bool(opts.get("scroll", false)):
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.scroll_deadzone = 24
		vb.add_child(scroll)
		body = VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(body)
	else:
		body = VBoxContainer.new()
		# 내용이 적어도 팝업은 전체 화면이다 — 본문을 가운데로 밀어 위쪽에 뭉치지 않게 한다.
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if bool(opts.get("center_body", false)):
			body.alignment = BoxContainer.ALIGNMENT_CENTER
		body.add_theme_constant_override("separation", int(opts.get("separation", 12)))
		vb.add_child(body)

	var close := Button.new()
	close.text = Locale.t(String(opts.get("close_key", "menu_close")))
	close.custom_minimum_size = Vector2(0, CLOSE_H)
	close.add_theme_font_size_override("font_size", 22)
	_UIStyle.apply_button_style(close, CLOSE_BG, CLOSE_ACCENT)
	close.pressed.connect(on_close)
	vb.add_child(close)

	return {"dim": dim, "panel": panel, "body": body, "close": close, "vbox": vb,
		"title": title, "hint": hint_label}


## ── 열기 / 닫기 ────────────────────────────────────────────────────────────
## 셸이 연출을 소유한다. 예전에는 호출부가 dim·panel 의 `visible` 을 직접 켜고 껐고, 그래서
## 팝업 9종이 전부 한 프레임에 튀어나왔다 — 연출을 넣으려면 20줄을 똑같이 고쳐야 하는 구조
## 자체가 원인이었다(UI_POLISH_PLAN §A-1·D-1).
##
## forward=true 는 **한 단계 앞으로 나아가는** 열기다(새 게임 흐름: 생존자 → 아레나 → 위협).
## 크게 시작해 제자리를 찾으므로 "다음 화면이 앞에서 다가온다"로 읽히고, 평소의 열기(작게
## 시작해 튀어나옴)와 구분된다. 앞 팝업의 닫힘(0.12s)과 겹쳐 재생돼 크로스페이드가 된다.
##
## 소리도 셸이 소유한다(Phase 3-1). 버튼 탭음(`ui_click`)은 **누른 손가락**의 소리고,
## 여기서 내는 `ui_open`/`ui_close` 는 **화면이 열리고 닫히는** 소리다 — 성격이 달라
## (넓은 대역의 딱 소리 vs 활공하는 음) 겹쳐도 플램으로 뭉치지 않는다.
##
## silent=true 는 **다른 소리가 이미 그 전환을 말하고 있을 때** 쓴다. 새 게임 흐름에서
## 카드를 고르면 `ui_select` 가 울리는데, 그 순간 앞 팝업이 닫히고 뒷 팝업이 열리므로
## 그냥 두면 한 번의 탭에 네 소리(탭·선택·닫힘·열림)가 겹친다. 확정음 하나만 남긴다.
static func open(dim: Control, panel: Control, forward: bool = false,
		silent: bool = false) -> void:
	if not is_instance_valid(panel):
		return
	if is_instance_valid(dim):
		UIMotion.fade_in(dim)
	UIMotion.pop_in(panel, UIMotion.SCALE_FORWARD if forward else UIMotion.SCALE_IN)
	if not silent:
		SoundManager.play_ui("ui_open", 0.04)


## 닫기 — 딤과 패널을 함께 페이드아웃하고 visible 까지 끈다.
## 이미 닫혀 있으면 아무것도 하지 않는다(딤 탭은 터치·마우스가 둘 다 들어와 두 번 불릴 수 있다).
## silent 는 open() 과 같은 뜻이다.
static func close(dim: Control, panel: Control, silent: bool = false) -> void:
	if not is_instance_valid(panel) or not panel.visible:
		return
	if is_instance_valid(dim):
		UIMotion.fade_out_hide(dim)
	UIMotion.fade_out_hide(panel)
	if not silent:
		SoundManager.play_ui("ui_close", 0.04)


## 닫기 버튼 **위**에 요소를 덧붙인다(합계 라벨·일괄 수령 버튼 등).
## 셸이 닫기를 마지막에 붙이므로 그냥 add_child 하면 닫기 아래로 들어간다 — 그 실수를
## 호출부마다 반복하지 않도록 자리를 여는 쪽을 셸이 제공한다.
static func add_above_close(p: Dictionary, node: Control) -> void:
	var vb: VBoxContainer = p["vbox"]
	vb.add_child(node)
	vb.move_child(p["close"], -1)
