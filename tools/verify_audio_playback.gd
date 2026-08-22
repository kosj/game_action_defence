extends SceneTree
## 오디오 재생 방식 게이트 (P0-5).
##
## 왜 필요한가
## -----------
## 배포 웹 빌드가 **wasm 힙 2GB 상한을 쳐서 죽었다.** 원인은 `AudioStreamPlayer` 가 웹 기본
## 재생 방식(샘플)을 쓰면 **`play()` 한 번마다 재생 객체가 통째로 새는 것**이었다.
## 브라우저 실측에서 효과음만 24,962번 재생하니 힙이 105MB → 2GB 로 올라가 사용자 로그의
## 오류가 그대로 재현됐다(재생 1회당 객체 약 2.6개 · 힙 약 73KB).
##
## `SoundManager._force_stream_playback()` 이 그것을 `PLAYBACK_TYPE_STREAM` 으로 고정해 막는다.
## 그 한 줄이 사라지면 **웹 빌드가 몇 분 만에 다시 죽는다.**
##
##   godot --headless --path . --script res://tools/verify_audio_playback.gd
##
## ⚠️ **이 결함은 데스크톱에서 재현되지 않는다.** 헤드리스는 Dummy 오디오 드라이버라 샘플
## 경로를 타지 않는다 — 스로틀 없이 84,000회 재생해도 RSS 가 평탄하다. 그래서 이 게이트는
## "메모리가 안 는다"를 확인하는 것이 아니라 **설정이 그대로 있는지**만 확인한다.
## 실제 누수 여부는 `tools/heap_web.sh` 로 브라우저에서 재야 한다.
##
## ⚠️ 열거형이 두 개고 서로 어긋난다 — 헷갈리지 말 것.
##     프로젝트 설정(`audio/general/default_playback_type*`): 0=Stream · 1=Sample
##     `AudioServer.PlaybackType`:                            0=DEFAULT · 1=STREAM · 2=SAMPLE
## 설정의 웹 기본값 1 은 STREAM 이 아니라 **SAMPLE** 이다. 그래서 아무것도 안 하면 새는 쪽이다.

## 웹 출력 지연 하한(ms). 실측으로 드롭아웃이 0 이 되는 가장 낮은 값이 160ms 였다.
const MIN_WEB_LATENCY_MS := 160.0

var _fail := 0


func _init() -> void:
	await process_frame
	var sm := root.get_node("SoundManager")

	var players: Dictionary = sm._players
	if players.is_empty():
		_fail += 1
		print("  FAIL SoundManager 에 효과음 플레이어가 하나도 없다 — 초기화가 깨졌다")

	var bad: Array = []
	for key in players:
		var p := players[key] as AudioStreamPlayer
		if p == null or p.playback_type != AudioServer.PLAYBACK_TYPE_STREAM:
			bad.append("%s(%s)" % [key, "null" if p == null else str(p.playback_type)])
	if bad.is_empty():
		print("  ok   효과음 %d종 전부 PLAYBACK_TYPE_STREAM" % players.size())
	else:
		_fail += 1
		print("  FAIL 효과음 %d종이 STREAM 이 아니다 → %s" % [bad.size(), ", ".join(bad)])

	var mp := sm._music_player as AudioStreamPlayer
	if mp != null and mp.playback_type == AudioServer.PLAYBACK_TYPE_STREAM:
		print("  ok   배경음악 플레이어도 PLAYBACK_TYPE_STREAM")
	else:
		_fail += 1
		print("  FAIL 배경음악 플레이어가 STREAM 이 아니다 (%s)"
			% ("없음" if mp == null else str(mp.playback_type)))

	# 새 플레이어가 나중에 추가돼도 걸리도록, 씬 트리 전체를 한 번 훑는다.
	var stray: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is AudioStreamPlayer and (n as AudioStreamPlayer).playback_type != AudioServer.PLAYBACK_TYPE_STREAM:
			stray.append(String(n.name))
	if stray.is_empty():
		print("  ok   트리 안의 AudioStreamPlayer 중 기본값으로 남은 것이 없다")
	else:
		_fail += 1
		print("  FAIL 기본 재생 방식으로 남은 플레이어 → %s" % ", ".join(stray))
		print("       웹에서는 재생 1회당 힙 약 73KB 가 샌다. SoundManager._force_stream_playback 참고.")

	# 재생 방식을 STREAM 으로 바꾼 대가로 **웹 소프트웨어 믹서를 타게 됐다.** 엔진 기본
	# 버퍼(50ms)로는 언더런이 나 소리가 끊긴다 — 브라우저에서 출력을 캡처해 재니 15초에
	# 드롭아웃 31회였고, 사용자도 "재생 중 끊긴다"고 보고했다. 버퍼를 키우면 0 이 된다:
	#
	#   출력지연        드롭아웃   소리 나는 블록      클릭
	#   50ms(엔진 기본)   31       493/648 (76%)      61
	#   120ms              1       635/648 (98%)      49
	#   160ms              0       648/648 (100%)     38   ← 채택
	#   200ms              0       648/648 (100%)     39
	#   (대조) SAMPLE      0       644/644 (100%)     34
	#
	# 160ms 를 고른 이유 — 0 이 되는 **가장 낮은** 값이다. 200ms 는 더 나아지지 않으면서
	# 조작-소리 지연만 커진다. 낮추면 소리가 다시 끊기므로 여기서 잠근다.
	var lat: float = float(ProjectSettings.get_setting("audio/driver/output_latency.web", 0))
	if lat >= MIN_WEB_LATENCY_MS:
		print("  ok   웹 출력 지연 %.0fms (하한 %.0fms)" % [lat, MIN_WEB_LATENCY_MS])
	else:
		_fail += 1
		print("  FAIL 웹 출력 지연이 %.0fms 다 — %.0fms 미만이면 STREAM 믹서가 언더런을 낸다"
			% [lat, MIN_WEB_LATENCY_MS])
		print("       project.godot 의 [audio] driver/output_latency.web 를 확인할 것.")

	if _fail == 0:
		print("\n오디오 재생 방식 OK")
		quit(0)
	else:
		print("\n오디오 재생 방식 실패 %d건" % _fail)
		quit(1)
