@tool
extends SceneTree
## 타임라인 바 + 마일스톤 카운트다운 실제 렌더 확인 (P1-4).
##
## **헤드리스로는 잡을 수 없는 것을 잡기 위한 도구다.** 헤드리스에서도 _draw 는 호출되고
## 오류도 안 나지만, 그려진 것이 다른 레이어에 덮였는지·좌표가 화면 밖인지는 알 수 없다.
## HUD 는 CanvasLayer 라 상단 패널·라벨과 겹칠 여지가 있어 실제 픽셀을 봐야 한다.
##
##   xvfb-run -a godot --path . --fixed-fps 60 --script res://tools/shot_timeline.gd
##
## 치트로 시간을 밀어 세 장면을 잡는다: 런 초반 · 보스 60초 전(카운트다운) · 보스전 중.
## 저장 위치는 user:// (실행 시 절대경로를 출력한다).

const DT := 1.0 / 60.0
const OUT := "user://timeline_shot_"

var _t := 0.0
var _started := false
var _shots := 0
var _skipped := false
var _spawned := false


func _process(_d: float) -> bool:
	if not _started:
		_started = true
		var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
		root.add_child(main)
		current_scene = main
		return false
	_t += DT

	# ① 런 초반 — 눈금이 전부 앞에 있는 상태.
	if _shots == 0 and _t > 1.2:
		_grab("early")
		return false

	# ② 보스 60초 전 — 시간을 540초로 밀어 카운트다운 배너를 띄운다.
	# 한 번만 — 매 프레임 부르면 시계가 545초씩 계속 밀린다(실제로 그랬다).
	if _shots == 1 and not _skipped and _t > 1.4:
		_skipped = true
		root.get_node("Cheats").request_time_skip(545.0)
		return false
	if _shots == 1 and _t > 2.6:
		_grab("boss_warn")
		return false

	# ③ 보스전 중 — 보스 눈금이 꺼지는지(예정 미정 = -1) 본다.
	if _shots == 2 and not _spawned and _t > 2.8:
		_spawned = true
		root.get_node("Cheats").request_spawn_boss()
		return false
	if _shots == 2 and _t > 4.2:
		_grab("boss_fight")
		quit(0)
		return true
	return false


func _grab(tag: String) -> void:
	var img := root.get_texture().get_image()
	var path := OUT + tag + ".png"
	img.save_png(path)
	print("저장: %s  (%dx%d)  실제경로=%s" % [path, img.get_width(), img.get_height(),
			ProjectSettings.globalize_path(path)])
	_shots += 1
