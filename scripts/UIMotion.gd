class_name UIMotion
extends RefCounted
## 공용 UI 모션 — 등장·퇴장 트윈의 **지속 시간과 곡선을 한곳에 모은다**.
##
## 왜 필요한가(UI_POLISH_PLAN §C-1·C-2): easing 은 `TRANS_BACK + EASE_OUT` 으로 잘 통일돼
## 있는데 지속 시간이 0.16 / 0.18 / 0.2 / 0.22 / 0.24 / 0.25 / 0.28 / 0.3 / 0.35 로 **아홉 가지**다.
## 상수가 없으니 새로 연출을 넣는 사람마다 값이 또 하나 늘어난다. 여기 있는 세 개(POP·FADE·CLOSE)와
## 세 개(HOLD_*)만 쓰면 화면이 늘어도 리듬이 흔들리지 않는다.
##
## 기존 파일의 리터럴은 **그 파일을 건드리는 PR에서 함께** 이 상수로 바꾼다(HUD.gd·MainMenu.gd 는
## 충돌 1순위라 한꺼번에 고치지 않는다 — CLAUDE.md §1).
##
## 사용:
##     UIMotion.pop_in(panel)                 # 등장(스케일 + 알파)
##     UIMotion.fade_in(dim)                  # 어둠 깔기
##     UIMotion.fade_out_hide(dim)            # 페이드 후 visible=false 까지
##     UIMotion.stop(node)                    # 이 노드에 걸린 모션 트윈 중단

## 등장 — 스케일 팝. 짧아야 "빠릿"하고 길면 굼뜨다.
const DUR_POP := 0.18
## 알파 페이드(딤·라벨).
const DUR_FADE := 0.15
## 퇴장 — 등장보다 **짧게**. 닫기는 기다리는 동작이라 길면 답답하다.
const DUR_CLOSE := 0.12
## 스스로 사라지는 것의 퇴장(토스트·배너). 닫기보다 길다 — 사용자가 없앤 것이 아니라
## 저절로 사라지는 것이라, 급하게 빠지면 "방금 뭐였지"가 된다.
const DUR_OUT := 0.4

## 머무는 시간 3종 — 의미별로 나눈다(경고는 짧게, 알림은 읽을 만큼, 축하는 그 사이).
const HOLD_WARN := 0.8
const HOLD_INFO := 2.0
const HOLD_CELEBRATE := 1.4

## 등장 시작 배율. 기본은 살짝 작게 시작해 튀어나온다.
const SCALE_IN := 0.96
## "한 단계 앞으로" — 새 게임 흐름처럼 앞선 화면을 밀어내고 들어올 때. 크게 시작해 자리를 잡는다.
const SCALE_FORWARD := 1.05

const _META_TW := "_ui_motion_tw"


## 이 노드에 걸린 모션 트윈을 중단한다(다시 열기·연속 호출 시 두 트윈이 같은 속성을 다투지 않게).
static func stop(node: Node) -> void:
	if not is_instance_valid(node) or not node.has_meta(_META_TW):
		return
	var tw = node.get_meta(_META_TW)
	if tw is Tween and tw.is_valid():
		tw.kill()
	node.remove_meta(_META_TW)


## 스케일 팝 + 알파. from_scale 로 "튀어나옴(0.96)"과 "앞으로 나옴(1.05)"을 가른다.
static func pop_in(node: Control, from_scale: float = SCALE_IN, dur: float = DUR_POP) -> Tween:
	stop(node)
	# 트리 밖 검사가 _center_pivot 보다 **먼저**다 — 피벗 폴백이 get_viewport_rect() 를 쓰는데
	# 트리 밖에서는 뷰포트가 없어 그쪽이 먼저 죽는다.
	if not node.is_inside_tree():
		node.visible = true
		return _no_tween(node, 1.0)
	_center_pivot(node)
	node.scale = Vector2(from_scale, from_scale)
	node.modulate.a = 0.0
	node.visible = true
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, dur * 0.9)
	tw.tween_property(node, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	node.set_meta(_META_TW, tw)
	return tw


## 알파 0 → 1. 시작 전에 visible 을 켠다.
static func fade_in(node: CanvasItem, dur: float = DUR_FADE) -> Tween:
	stop(node)
	node.modulate.a = 0.0
	node.visible = true
	if not node.is_inside_tree():
		return _no_tween(node, 1.0)
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, dur)
	node.set_meta(_META_TW, tw)
	return tw


## 알파 → 0 후 **visible=false 까지** 한다.
##
## 마지막의 visible=false 가 이 함수의 존재 이유다. 전체 화면 ColorRect 는 알파 0 이어도
## visible 이면 매 프레임 풀스크린 블렌딩을 한다(720x1280 ≈ 92만 픽셀) — HUD._flash_hurt 가
## 같은 이유로 끝에 visible 을 끈다. 딤을 알파만 0 으로 두고 남기면 메뉴가 조용히 무거워진다.
static func fade_out_hide(node: CanvasItem, dur: float = DUR_CLOSE) -> Tween:
	stop(node)
	if not node.is_inside_tree():
		node.visible = false
		return _no_tween(node, 1.0)
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 0.0, dur)
	tw.tween_callback(func() -> void:
		if is_instance_valid(node):
			node.visible = false
			node.modulate.a = 1.0)   # 다음 열기가 알파를 다시 세팅하지만, 남겨두면 디버깅이 헷갈린다
	node.set_meta(_META_TW, tw)
	return tw


## 트리 밖 노드는 트윈을 만들 수 없다(create_tween 이 에러를 내고 null 을 준다 — 그대로 쓰면
## 그 자리에서 스크립트가 죽는다). 연출만 건너뛰고 **최종 상태로 즉시 확정**해, 팝업이 안 열리는
## 것보다는 연출 없이 열리는 쪽으로 떨어진다.
static func _no_tween(node: CanvasItem, final_alpha: float) -> Tween:
	node.modulate.a = final_alpha
	if node is Control:
		node.scale = Vector2.ONE
	return null


## 스케일이 중심 기준이 되도록 피벗을 잡는다.
##
## 아직 한 번도 배치되지 않은(=쭉 숨어 있던) 컨트롤은 size 가 0 일 수 있다. 그때 피벗을 0 으로
## 두면 좌상단에서 커지는 이상한 팝이 된다 — 뷰포트 크기로 근사해 중앙에서 커지게 한다.
## (전체 화면 팝업이라 실제로 그 근사가 정확에 가깝다)
static func _center_pivot(node: Control) -> void:
	var s := node.size
	if s.x <= 0.0 or s.y <= 0.0:
		s = node.get_viewport_rect().size
	node.pivot_offset = s * 0.5
