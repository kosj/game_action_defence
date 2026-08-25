@tool
extends SceneTree
## 레벨업 모달 실제 렌더 확인 (P2-3).
##   xvfb-run -a godot --path . --fixed-fps 60 --script res://tools/shot_levelup.gd
## 언어를 지정하려면 뒤에 붙인다: ... res://tools/shot_levelup.gd en|ko|ja
## 저장 위치는 user:// (실행 시 절대경로를 출력한다).
##
## 왜 언어별로 보는가: 이 제목은 로케일화 전 영어 하드코딩이라 폭 검사 대상이 아니었고,
## 실제로 34px 에서 패널을 밀어 넓히고 있었다(P2-3 에서 발견). 언어마다 길이가 크게 달라
## 한 언어만 보고 끝내면 나머지 둘이 깨진 채 남는다.

const DT := 1.0 / 60.0
var _t := 0.0
var _started := false
var _fired := false
var _shot := false
var _lang := "en"


func _process(_d: float) -> bool:
	if not _started:
		_started = true
		var lang := "en"
		for a in OS.get_cmdline_user_args():
			if String(a) in ["en", "ko", "ja"]:
				lang = String(a)
		root.get_node("Locale").set_language(lang)
		_lang = lang
		var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
		root.add_child(main)
		current_scene = main
		return false
	_t += DT
	if not _fired and _t > 1.0:
		_fired = true
		root.get_node("Events").bonus_level()
		return false
	if _fired and not _shot and _t > 2.2:
		_shot = true
		var img := root.get_texture().get_image()
		var path := "user://levelup_shot_%s.png" % _lang
		img.save_png(path)
		print("저장: %s (%dx%d)" % [path, img.get_width(), img.get_height()])
		quit(0)
		return true
	return false
