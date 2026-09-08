extends CanvasLayer
## 씬 전환 페이드 (Autoload "SceneFade"). 검은 오버레이로 페이드아웃 → 씬 교체 → 페이드인 하여
## 메뉴↔게임↔게임오버 전환의 끊김을 없앤다. 오버레이는 최상단 레이어, 입력은 통과시킨다.

var _rect: ColorRect = null
var _busy: bool = false
var _tw: Tween = null


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS   # 정지 중 전환에도 동작
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0.0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


## 페이드아웃(→검정) 후 씬 교체, 다시 페이드인. 페이드아웃 중 재호출은 무시.
## 잠금(_busy)은 "실제 씬이 바뀌는 순간" 해제한다 — 페이드인 트윈이 어떤 이유로 끊겨도
## 잠금이 영구히 걸린 채 남지 않게 해, 이후 전환(예: 이어하기→새로하기)이 무시되어 멈추는 것을 막는다.
func transition_to(path: String, dur: float = 0.3) -> void:
	if _busy:
		return
	_busy = true
	# 그림이 검게 빠지는 동안 소리도 같이 뺀다 — 같은 시간을 준다.
	# 효과음 플레이어는 오토로드 자식이라 씬이 바뀌어도 계속 울린다. 여기서 끄지 않으면
	# 게임오버 스팅어가 메인 메뉴까지 따라 들어온다(P2-23). 배경음악은 대상이 아니다 —
	# 다음 씬의 play_music() 이 크로스페이드로 알아서 넘긴다.
	SoundManager.stop_sfx(dur)
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_rect, "color:a", 1.0, dur).set_trans(Tween.TRANS_SINE)
	_tw.tween_callback(func():
		get_tree().change_scene_to_file(path)
		_busy = false)
	_tw.tween_interval(0.05)
	_tw.tween_property(_rect, "color:a", 0.0, dur).set_trans(Tween.TRANS_SINE)
