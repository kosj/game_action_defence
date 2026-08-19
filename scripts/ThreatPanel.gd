extends RefCounted
## 위협 등급 선택 화면 (HANDOFF P1-12).
##
## 새 게임 흐름의 마지막 단계다: 생존자 → 아레나 → **위협 등급** → 인트로 → 시작.
## 다만 **등급 1만 해금된 상태에서는 이 단계를 건너뛴다**(MainMenu 가 판단한다) —
## 선택지가 하나뿐인 화면은 새 플레이어에게 단계 하나를 더 세우는 것 외에 하는 일이 없다.
## 사다리를 오르기 시작한 사람에게만 나타난다.
##
## 목록은 잠긴 등급까지 전부 보여준다. **다음 칸에 무엇이 붙는지 보이는 것**이 다음 판의
## 이유가 되기 때문이다(도감이 빈 칸으로 하는 일과 같다) — 대신 고를 수는 없다.
##
## MainMenu.gd 밖에 두는 이유는 CodexPanel 과 같다: 그 파일은 충돌 1순위다(CLAUDE.md §1).

const _UIPopup := preload("res://scripts/UIPopup.gd")
const _UIStyle := preload("res://scripts/UIStyle.gd")

const ROW_H := 62.0

var dim: ColorRect = null
var panel: PanelContainer = null

var _rows: Array = []          # [{rank, btn, title, rule, best, lock}]
var _on_pick: Callable


## on_pick 은 등급을 고른 뒤 흐름을 이어받는다(닫기는 호출부가 한다).
func build(parent: Node, on_close: Callable, on_pick: Callable) -> void:
	_on_pick = on_pick
	var p := _UIPopup.make(parent, "popup_threat", UITheme.SEC_THREAT, UITheme.SEC_THREAT_TXT,
		on_close, {"scroll": true, "hint_key": "threat_hint", "separation": 10})
	dim = p["dim"]
	panel = p["panel"]

	var body: VBoxContainer = p["body"]
	body.add_theme_constant_override("separation", 8)

	for i in range(ThreatManager.count()):
		_rows.append(_make_row(body, i + 1))


func refresh() -> void:
	var sel := ThreatManager.selected_rank()
	var maxr := ThreatManager.max_rank()
	for row in _rows:
		var rank: int = row["rank"]
		var unlocked := rank <= maxr
		row["btn"].disabled = not unlocked
		row["lock"].visible = not unlocked
		row["title"].text = Locale.t("threat_rank_fmt") % rank
		row["title"].add_theme_color_override("font_color",
			UITheme.SEC_THREAT_TXT if rank == sel else (UITheme.TEXT if unlocked else UITheme.TEXT_DIM))
		row["rule"].text = _rule_text(rank)
		row["rule"].add_theme_color_override("font_color",
			UITheme.TEXT_DIM if unlocked else Color(0.45, 0.47, 0.54))
		var best := ThreatManager.best_seconds(rank)
		row["best"].text = (Locale.t("threat_best_fmt") % _mmss(best)) if best > 0.0 else ""


func apply_language() -> void:
	refresh()


## 이 등급에서 **새로 붙는** 규칙 한 줄. 등급 1은 규칙이 없으므로 기준선임을 알린다.
func _rule_text(rank: int) -> String:
	var d := ThreatManager.data(rank)
	if d == null or d.rule_key == "":
		return Locale.t("threat_base")
	return Locale.t(d.rule_key) % d.rule_amount


func _make_row(body: VBoxContainer, rank: int) -> Dictionary:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, ROW_H)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	btn.clip_contents = true
	_UIStyle.apply_button_style(btn, UITheme.BTN_BG, UITheme.SEC_THREAT, 16, "dark")
	btn.pressed.connect(_on_pressed.bind(rank))
	body.add_child(btn)

	# 아레나 카드와 같은 이유로 내용을 text 가 아니라 앵커 자식으로 얹는다 —
	# autowrap 라벨의 최소 크기가 컨테이너로 전파되면 행 하나가 목록을 다 차지한다.
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 14)
	pad.add_theme_constant_override("margin_right", 14)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)

	var lock := UIIcon.make("lock", 18, Color(0.95, 0.86, 0.55))
	lock.visible = false
	head.add_child(lock)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 19)
	title.clip_text = true
	# clip_text 를 켠 Label 은 **최소 폭이 0** 이다. 폭을 따로 주지 않으면 옆의 확장 라벨(기록)이
	# 남는 자리를 전부 가져가 제목이 통째로 잘려 사라진다 — 실렌더에서 실제로 그렇게 나왔다.
	title.custom_minimum_size = Vector2(130, 0)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.heading(title)
	head.add_child(title)

	var best := Label.new()
	best.add_theme_font_size_override("font_size", 14)
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	best.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	best.clip_text = true
	best.add_theme_color_override("font_color", UITheme.SEC_REWARD)
	best.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(best)

	var rule := Label.new()
	rule.add_theme_font_size_override("font_size", 14)
	rule.clip_text = true
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule)

	return {"rank": rank, "btn": btn, "title": title, "rule": rule, "best": best, "lock": lock}


func _on_pressed(rank: int) -> void:
	if not ThreatManager.select(rank):
		SoundManager.play_ui("player_hurt", 0.2, 1.0)   # 잠긴 등급
		return
	SoundManager.play_ui("gold", 0.03, 1.2)
	refresh()
	if _on_pick.is_valid():
		_on_pick.call()


func _mmss(seconds: float) -> String:
	var s := int(round(seconds))
	return "%d:%02d" % [s / 60, s % 60]
