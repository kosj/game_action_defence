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

	# ── 씬 전환 정지(P2-23) — 되돌리기가 빠지면 그 소리가 영영 작아진다 ──
	#
	# stop_sfx() 는 볼륨을 낮췄다가 정지하고 다시 되돌린다. 되돌리기를 빠뜨리면
	# **화면상 아무 증상 없이 그 효과음만 영구히 작아진 채로 남는다** — 사람이 알아채기
	# 어렵고, 알아채도 원인을 찾기 어려운 종류의 결함이라 여기서 잠근다.
	#
	# ⚠️ 트윈이 실제로 볼륨을 내리기까지는 프레임이 지나야 한다. 만든 직후에 검사하면
	# 아직 원래 값이라 **무엇을 고장 내도 통과하는 검사**가 된다 — 그래서 아래 두 검사는
	# 트윈 진행에 기대지 않고, 낮아진 상태를 직접 만들거나 실제 시간을 기다린다.
	var probe := "defeat"
	var pp: AudioStreamPlayer = sm._players.get(probe)
	var vols: Dictionary = sm.get_script().get_script_constant_map()["_VOLUMES"]
	if pp == null or pp.stream == null:
		print("  --   정지 검사 건너뜀 (%s 스트림 없음)" % probe)
	else:
		var want: float = vols.get(probe, 0.0)

		# 1) 즉시 정지 경로 — 멈추고, 볼륨을 되돌린다.
		sm.play_ui(probe, 0.0, 1.0)
		sm.stop_sfx(0.0)
		if pp.playing:
			_fail += 1
			print("  FAIL stop_sfx(0.0) 뒤에도 %s 가 재생 중이다" % probe)
		elif absf(pp.volume_db - want) > 0.01:
			_fail += 1
			print("  FAIL stop_sfx 가 %s 볼륨을 되돌리지 않았다 (%.2f, 기대 %.2f)"
				% [probe, pp.volume_db, want])
			print("       이 상태로 배포되면 그 효과음만 조용히 작아진 채 남는다.")
		else:
			print("  ok   stop_sfx 가 정지 후 볼륨을 설정값으로 되돌린다")

		# 2) 낮아진 상태에서 재생 — play() 가 볼륨을 되찾아야 한다.
		#    페이드 도중을 흉내 내려고 값을 직접 낮춘다(트윈 타이밍에 의존하지 않는다).
		pp.volume_db = want - 30.0
		sm.play_ui(probe, 0.0, 1.0)
		if absf(pp.volume_db - want) > 0.01:
			_fail += 1
			print("  FAIL 볼륨이 낮아진 플레이어로 재생했는데 설정값으로 복구되지 않았다 (%.2f, 기대 %.2f)"
				% [pp.volume_db, want])
		else:
			print("  ok   낮아진 플레이어로 재생하면 볼륨이 설정값으로 복구된다")

		# 3) 정지 페이드가 걸린 뒤 다시 재생하면, **그 페이드가 새 소리를 끊으면 안 된다.**
		#    페이드 시간이 다 지나도록 실제로 기다려 콜백이 살아 있는지 본다.
		sm.play_ui(probe, 0.0, 1.0)
		sm.stop_sfx(0.20)
		sm.play_ui(probe, 0.0, 1.0)          # 페이드를 취소하고 다시 울린 소리
		await get_tree().create_timer(0.35, true, false, true).timeout
		if not pp.playing:
			_fail += 1
			print("  FAIL 취소했어야 할 정지 페이드가 새로 재생한 %s 를 끊었다" % probe)
		elif absf(pp.volume_db - want) > 0.01:
			_fail += 1
			print("  FAIL 정지 페이드 취소 뒤 %s 볼륨이 설정값이 아니다 (%.2f, 기대 %.2f)"
				% [probe, pp.volume_db, want])
		else:
			print("  ok   재생이 진행 중이던 정지 페이드를 취소한다")
		sm.stop_sfx(0.0)

	if _fail == 0:
		print("\n오디오 재생 방식 OK")
		quit(0)
	else:
		print("\n오디오 재생 방식 실패 %d건" % _fail)
		quit(1)
