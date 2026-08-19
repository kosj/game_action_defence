@tool
extends SceneTree
## 메인 메뉴 팝업 실제 렌더 확인 (P2-1 공통 팝업 셸).
##
## 팝업 8종을 공통 셸로 이관하면 크기·여백·제목·닫기가 한곳에서 정해진다 — 바꿔 말하면
## **한 곳이 틀리면 여덟 개가 같이 틀어진다.** 헤드리스는 레이아웃이 화면 밖으로 나갔는지,
## 요소가 서로 덮였는지 알려주지 않으므로 실제 픽셀을 본다(CLAUDE.md §3).
##
##   xvfb-run -a godot --path . --fixed-fps 60 --script res://tools/shot_menu_popups.gd
##
## 저장 위치는 user:// (실행 시 절대경로를 출력한다).

const DT := 1.0 / 60.0
const OUT := "user://menu_popup_"
## 팝업 열기 함수 이름 → 저장 태그. MainMenu 의 버튼 핸들러를 직접 부른다.
## [열기 함수, 저장 태그, 닫기 함수]. 닫지 않고 다음을 열면 앞 팝업이 위에 남아 엉뚱한
## 화면을 찍는다(실제로 그랬다) — 실게임에서는 dim 이 입력을 막아 생기지 않는 상황이다.
const PANELS := [
	["_on_quests_pressed", "quests", "_on_quests_close"],
	["_on_achievements_pressed", "achievements", "_on_achievements_close"],
	["_on_rewards_pressed", "rewards", "_on_rewards_close"],
	["_on_ranking_pressed", "ranking", "_on_close_ranking"],
	["_on_options_pressed", "options", "_on_close_options"],
	["_on_power_pressed", "power", "_on_power_close"],
	["_on_character_pressed", "character", "_on_character_close"],
	["_on_theme_pressed", "theme", "_on_theme_close"],
]

var _t := 0.0
var _started := false
var _menu: Node = null
var _i := 0
var _opened := false


func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_menu = (load("res://scenes/MainMenu.tscn") as PackedScene).instantiate()
		root.add_child(_menu)
		current_scene = _menu
		return false
	_t += DT
	if _t < 0.8:
		return false
	if _i >= PANELS.size():
		quit(0)
		return true

	var fn: String = PANELS[_i][0]
	var tag: String = PANELS[_i][1]
	if not _opened:
		_opened = true
		if _menu.has_method(fn):
			_menu.call(fn)
		else:
			print("건너뜀(핸들러 없음): %s" % fn)
			_i += 1
			_opened = false
		_t = 0.6   # 열림 직후 한 프레임 레이아웃이 확정되도록 여유
		return false
	if _t > 1.0:
		_grab(tag)
		var closer: String = PANELS[_i][2]
		if _menu.has_method(closer):
			_menu.call(closer)
		_i += 1
		_opened = false
		_t = 0.75
	return false


func _grab(tag: String) -> void:
	var img := root.get_texture().get_image()
	var path := OUT + tag + ".png"
	img.save_png(path)
	print("저장: %s  (%dx%d)" % [path, img.get_width(), img.get_height()])
