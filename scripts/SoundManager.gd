extends Node
## 효과음/배경음악 싱글톤 (Autoload "SoundManager")
## 효과음: SoundManager.play("이름") — 피치 랜덤으로 반복 효과 방지.
## 배경음악: SoundManager.play_music("title"|"game") — 씬 진입 시 호출하면 크로스페이드로
## 전환되고, 같은 트랙이면 이어 재생된다(타이틀→메뉴 전환에서 음악이 끊기지 않음).

const _SOUNDS: Dictionary = {
	"shoot":       "res://assets/audio/sfx_shoot.ogg",
	"laser":       "res://assets/audio/sfx_laser.wav",   # 플라스마 등 에너지 무기
	"boom":        "res://assets/audio/sfx_boom.wav",    # 샷건/로켓 등 폭발성 무기
	"zombie_hit":  "res://assets/audio/sfx_zombie_hit.ogg",
	"zombie_die":  "res://assets/audio/sfx_zombie_die.ogg",
	"gold":        "res://assets/audio/sfx_coin.wav",    # 마리오풍 코인 획득음(띠링)
	"player_hurt": "res://assets/audio/sfx_player_hurt.ogg",
	# 선택 사운드 — 파일이 아직 없으면 조용히 생략되고, 넣는 순간 자동 적용된다.
	"card_flip":   "res://assets/audio/sfx_card_flip.ogg",   # 보상 카드 플립 스냅
	"fanfare":     "res://assets/audio/sfx_fanfare.ogg",     # 보물상자 공개 팡파르
	"level_up":    "res://assets/audio/sfx_level_up.ogg",    # 레벨업 카드 등장 징글
	"boss_alarm":  "res://assets/audio/sfx_boss_alarm.ogg",  # 보스 등장 경보
	"defeat":      "res://assets/audio/sfx_defeat.ogg",      # 사망(게임오버) 스팅어
	"victory":     "res://assets/audio/sfx_victory.ogg",     # 20분 클리어 징글
	"ui_click":    "res://assets/audio/sfx_ui_click.ogg",    # 메뉴/버튼 탭
	# UI 전용 4종(P2-24). 예전에는 선택 성공에 gold(동전)를, 거부에 player_hurt(피격음)를
	# 돌려썼다 — 살 돈이 없을 때 맞는 소리가 났다. tools/gen_sfx.py 로 절차 생성한다.
	"ui_open":     "res://assets/audio/sfx_ui_open.ogg",     # 팝업 열림
	"ui_close":    "res://assets/audio/sfx_ui_close.ogg",    # 팝업 닫힘
	"ui_select":   "res://assets/audio/sfx_ui_select.ogg",   # 선택 확정
	"ui_deny":     "res://assets/audio/sfx_ui_deny.ogg",     # 잠김·잔액 부족
	# 상단 경고 띠의 위험도 3단계(P2-27). 한 경보 악기를 세 구절로 나눈 것이라
	# 음색은 같고 펄스 수(2·3·4)와 빠르기·음정이 다르다 — gen_sfx.py 참고.
	"warn_swarm":  "res://assets/audio/sfx_warn_swarm.ogg",  # 좀비 무리 예고
	"warn_elite":  "res://assets/audio/sfx_warn_elite.ogg",  # 정예 무리 예고
	"warn_boss":   "res://assets/audio/sfx_warn_boss.ogg",   # 보스 예고(등장은 boss_alarm)
	"ult_quake":   "res://assets/audio/sfx_ult_quake.ogg",  # 궁극기: 지진(베테랑)
	"ult_arrow":   "res://assets/audio/sfx_ult_arrow.ogg",  # 궁극기: 화살비(헌터)
	"ult_orbital": "res://assets/audio/sfx_ult_orbital.ogg",# 궁극기: 궤도 폭격(엔지니어)
	"fly_swarm":   "res://assets/audio/sfx_fly_swarm.ogg",  # 흡혈 파리떼 출현 윙윙
	"lightning":   "res://assets/audio/sfx_lightning.ogg",  # 번개 낙뢰 타격
	"tesla_arc":   "res://assets/audio/sfx_tesla_arc.ogg",  # 테슬라 방전(연쇄 번개·코일)
	"bomber_fuse": "res://assets/audio/sfx_bomber_fuse.ogg", # 자폭 좀비 점화(0.55초 도망 경고)
	"bomber_blast":"res://assets/audio/sfx_bomber_blast.ogg",# 자폭 좀비 폭발
	"evolve":      "res://assets/audio/sfx_evolve.ogg",      # 무기 진화 팡파르
	# 마일스톤(보스 처치) 스팅어. 파일명은 웨이브 시절 그대로다 — 오디오 에셋을 개명하면
	# import_sfx.py 매핑과 임포트 산출물까지 함께 갈아야 해서 이름만 남겨 둔다(P2-6).
	"wave_clear":  "res://assets/audio/sfx_wave_clear.ogg",
	"revive":      "res://assets/audio/sfx_revive.ogg",      # 무료 부활(재기) 차임
	"spit":        "res://assets/audio/sfx_spit.ogg",        # 스피터 좀비 산성 발사
	# ── P2-12: 비어 있던 자리 ──
	"chainsaw":    "res://assets/audio/sfx_chainsaw.ogg",   # 전기톱이 무는 순간
	"drone_shot":  "res://assets/audio/sfx_drone_shot.ogg", # 드론 사격(총성과 대역을 갈라 둠)
	"magnet":      "res://assets/audio/sfx_magnet.ogg",     # 골드 자석 버프 발동
	"boss_die":    "res://assets/audio/sfx_boss_die.ogg",   # 보스 처치(잡몹 사망음과 분리)
	# 아직 파일이 없다 — 생물의 포효는 합성으로 만들면 악기가 된다(SOUND_GUIDE §9).
	# 프롬프트는 SOUND_PROMPTS.md 에 있고, 파일이 들어오면 자동으로 붙는다(그때까지는
	# Boss.gd 가 기존 boom 피치다운으로 폴백한다).
	"boss_roar":   "res://assets/audio/sfx_boss_roar.ogg",  # 보스 페이즈 전환 포효
}

const _VOLUMES: Dictionary = {
	# 게임에서 가장 자주 나는 소리인데 파일 자체가 조용해(파고율 20dB 라 기준 RMS 에 못 닿는다)
	# 볼륨까지 -10 이면 폰 실효 -40dB — 세트 중앙값보다 14dB 아래였다. 파일 보강과 함께 올린다.
	"shoot":        -2.0,
	"laser":       -9.0,
	"boom":         -2.0,   # 16개 호출부 공용 임팩트 — 중앙값 부근에 둔다
	# 새 피격음은 중역 위주라 A-가중 체감이 4.8dB 커졌다(초당 최대 18회 울리는 소리).
	# 4dB 만 되돌려 기존과 비슷한 크기로 두되, 존재감은 약간 남긴다.
	"zombie_hit": -10.0,
	"zombie_die":  -3.0,
	"gold":        -8.0,
	"player_hurt":  0.0,
	"card_flip":   -6.0,
	"fanfare":     -9.0,
	"level_up":    -8.0,
	"boss_alarm":   0.0,
	# 파일이 규격(-16dB)보다 5.6dB 높게 커밋돼 있어 볼륨을 -5.0 으로 눌러 쓰고 있었다.
	# P2-23 에서 길이를 줄이며 규격에 맞췄고, 그만큼 여기서 되돌려 **플레이어가 듣는 크기는
	# 그대로**다(실효 -20.2dB, 세트 최대 — 런이 끝나는 순간이라 의도된 값이다).
	"defeat":       0.8,
	"victory":     -7.0,
	"ui_click":     -3.0,   # 버튼 피드백 — 들리되 전투음을 덮지 않는 선
	# 아래 넷은 **A-가중이 아니라 폰 스피커 체감으로 맞춘 값**이다(SOUND_GUIDE §8).
	# 파일 RMS 는 넷 다 -16dB 로 같지만 대역이 달라 체감이 다르다 — open/close/select 는
	# 0.8~3kHz 중심이라 체감 -17dB, deny 는 200~800Hz 중심이라 -21.6dB 다. 여기서 그 차이를
	# 되돌려 넷이 ui_click 과 같은 크기로 들리게 한다(체감 -29~-31dB 대에 모인다).
	"ui_open":     -13.0,
	"ui_close":    -14.0,   # 닫힘은 열림보다 조용하게 — 결과가 아니라 정리하는 동작이다
	"ui_select":   -12.0,   # 넷 중 가장 중요한 신호(확정)라 살짝 앞에 둔다
	"ui_deny":      -8.0,   # 저역 중심이라 크게 줘야 같은 크기로 들린다
	# 경고음 셋도 폰 체감으로 맞춘다(파일 RMS 는 -16dB 로 같지만 체감은 -21.4/-19.0/-17.5).
	# 실효(체감+볼륨)를 -27.9 / -25.0 / -22.0 으로 계단지게 둔다 — 무리 경고는 15~24초마다
	# 울리는 상시 신호라 세트 중앙값(-26.3) 근처에, 보스 예고는 600초에 한 번이라 위쪽에.
	"warn_swarm":   -6.5,
	"warn_elite":   -6.0,
	"warn_boss":    -4.5,
	"ult_quake":   -3.0,
	"ult_arrow":   -3.0,
	"ult_orbital": -3.0,
	"fly_swarm":   -7.0,
	"lightning":   -7.0,
	"tesla_arc":   -9.5,   # 기존 연쇄 번개(laser -9.0)와 같은 체감이 되도록 맞춤
	"bomber_fuse":  -8.3,   # 경고 신호 — 전투음에 묻히면 안 되므로 파일의 1.7dB 부족분을 보정
	"bomber_blast": -4.0,   # boom 과 동급 임팩트
	"evolve":       -5.0,   # 런 최대 파워업 — level_up(-8)보다 확실히 크게
	"wave_clear":   -8.0,
	"revive":       -5.0,
	"spit":        -14.0,   # 다수 스피터가 동시 발사 — 아주 작게
	# 아래 값은 "파일의 폰 체감 + 이 값" 이 세트 중앙값(-26.3dB) 부근에 오도록 잡았다.
	# 자주 나는 것은 아래로, 큰 사건은 위로 둔다(SOUND_GUIDE §8·§12).
	"chainsaw":    -8.0,    # 물기 틱마다 — 실효 -27.9
	"drone_shot": -16.0,    # 드론 여러 기가 동시 사격 — 실효 -32.1, 얇게 깔린다
	"magnet":      -5.0,    # 버프 발동은 놓치면 안 된다 — 실효 -24.7
	"boss_die":    -1.5,    # 런 최대 사건 — 실효 -21.0(defeat -20.2 와 같은 층)
	"boss_roar":   -2.0,
}

## 배경음악 트랙 — 트랙 이름 → 파일 목록. 게임 BGM 은 선택 테마로 곡이 결정되어(테마 인덱스
## % 곡 수) 시작 시 한 곡으로 고정되고, 그 곡이 심리스 루프된다. 타이틀은 단일 곡 루프.
const _MUSIC: Dictionary = {
	"title": ["res://assets/audio/bgm_title.mp3"],                                   # Ashes over Dune(타이틀·메뉴)
	"game":  ["res://assets/audio/bgm_game_1.mp3", "res://assets/audio/bgm_game_2.mp3"],   # Iron Siege / Iron Faultline
}
const _MUSIC_VOL: Dictionary = {"title": -20.0, "game": -22.0}
const _MUSIC_FADE := 0.9        # 트랙 전환 크로스페이드(초)
const _DUCK_DB := -14.0         # 사망 시 음악을 낮추는 상대량(dB)

const SETTING_PATH := "user://sound.save"
## 음악만 따로 끄는 설정(P2-33). 예전에는 스위치가 하나라 음악을 끄면 효과음도 같이 꺼졌다 —
## 모바일에서 가장 흔한 요구가 "음악만 끄기"인데 그것이 불가능했다. 파일 형식은 sound.save 와
## 같다("0"=끔). 서명 대상(SaveGuard 9종)이 아닌 것도 같다 — 값을 고쳐 봐야 얻는 것이 없다.
const MUSIC_SETTING_PATH := "user://music.save"

# 연속 재생 스로틀 — 같은 프레임에 대량으로 몰리는 효과음(스플래시 다중 피격·다중 총알·군집
# 사망·동전 자석 흡수)은 프레임당 play() 호출이 수십 번 터져 특히 웹에서 프레임 드랍을 유발한다.
# 사운드별 최소 재생 간격(ms)을 둬 그 안의 재호출은 건너뛴다 — 소리도 깔끔해지고 부하도 준다.
# (예: zombie_hit 55ms ⇒ 초당 최대 ~18회. 청감상 연속처럼 들리면서 호출 폭주는 막힌다.)
const _MIN_INTERVAL := {
	"gold": 110,
	"zombie_hit": 55,
	"zombie_die": 70,
	"shoot": 45,
	"boom": 60,
	"laser": 45,
	"player_hurt": 90,
	"lightning": 120,
	"tesla_arc": 90,
	"spit": 130,           # 스피터 다수가 동시 발사해도 산발적으로만
	"bomber_fuse": 200,    # 여러 마리가 동시 점화해도 경고음은 하나로
	"bomber_blast": 70,
	"chainsaw": 90,        # 체인소 여러 자루가 동시에 물어도 톱소리는 하나로
	"drone_shot": 55,      # 드론 다수가 같은 프레임에 쏜다
}
const _COMBO_WINDOW := 380   # ms — 이 안에 연속되면 콤보로 보고 음을 살짝 올린다(마리오 동전 느낌)

var _players: Dictionary = {}
var _last_play: Dictionary = {}   # sound -> 마지막 재생 시각(ms)
var _combo: Dictionary = {}       # sound -> 콤보 단계
var _stop_tweens: Dictionary = {} # sound -> 진행 중인 정지 페이드 트윈
var muted: bool = false   # 옵션에서 끄면 효과음·배경음악 모두 음소거
var music_muted: bool = false   # 음악만 음소거(효과음은 그대로). muted 와 독립이다.

# ── 배경음악 상태 ──
var _music_player: AudioStreamPlayer
var _music_current: String = ""      # 재생 중(또는 음소거 해제 시 재생할) 트랙 이름
var _music_tween: Tween
var _music_ducked: bool = false      # 사망 연출로 볼륨을 낮춘 상태


func _ready() -> void:
	# 레벨업/게임오버에서 트리를 일시정지해도 음악(과 그 페이드 트윈)은 계속 흘러야 한다.
	process_mode = Node.PROCESS_MODE_ALWAYS
	muted = _read_setting()
	music_muted = _read_flag_off(MUSIC_SETTING_PATH)
	for key in _SOUNDS:
		var p := AudioStreamPlayer.new()
		_force_stream_playback(p)
		if ResourceLoader.exists(_SOUNDS[key]):   # 선택 사운드는 파일이 있을 때만 로드
			var stream = load(_SOUNDS[key])
			if stream:
				p.stream = stream
				p.volume_db = _VOLUMES.get(key, 0.0)
		add_child(p)
		_players[key] = p

	_music_player = AudioStreamPlayer.new()
	_force_stream_playback(_music_player)
	add_child(_music_player)
	# 루프 설정이 실패하는 환경(웹 등)을 위한 폴백 — 끝나면 즉시 재시작.
	_music_player.finished.connect(_on_music_finished)

	# 사망 시 음악을 낮춰 게임오버 연출을 살리고, 부활하면 복구한다.
	Events.player_died.connect(_duck_music.bind(true))
	Events.player_revived.connect(_duck_music.bind(false))

	_setup_web_visibility()


## ⛔ **웹 빌드가 이것 없이는 몇 분 만에 죽는다 — 되돌리지 말 것** (P0-5).
##
## 무슨 일이 있었나
## ----------------
## 배포 웹 빌드가 플레이 중 **wasm 힙 2GB 상한을 쳐서 죽었다.** 사용자 콘솔 로그:
##
##     Cannot enlarge memory, requested 2147487744 bytes, but the limit is 2147483648 bytes!
##     USER ERROR: Error initializing dsp state   at: _alloc_vorbis
##     Aborted(Runtime error: The application has corrupted its heap memory area (address zero)!)
##
## 원인은 **`play()` 한 번마다 재생 객체가 통째로 새는 것**이었다. 브라우저 실측
## (`tools/heap_web.sh`)에서 효과음만 24,962번 재생하니 힙이 105MB → 2GB 로 올라가
## 위 오류가 **그대로 재현**됐다. 재생 1회당 객체 약 2.6개 · 힙 약 73KB 다.
##
## 왜 그런가 — 열거형이 한 칸 어긋나 있다
## --------------------------------------
## `AudioStreamPlayer.playback_type` 의 기본값은 `PLAYBACK_TYPE_DEFAULT`(0)이고,
## 그러면 프로젝트 설정 `audio/general/default_playback_type.web` 을 따라간다.
## 그 값은 `1` 인데 — **그 설정의 열거형은 `AudioServer.PlaybackType` 과 다르다.**
##
##     설정 열거형:              0=Stream · 1=Sample
##     AudioServer.PlaybackType: 0=DEFAULT · 1=STREAM · 2=SAMPLE
##
## 즉 설정값 1 은 STREAM 이 아니라 **SAMPLE** 이다. 웹 기본이 샘플 경로인 것이고,
## 그 경로가 재생할 때마다 스트림을 샘플로 변환해 두고 놓아주지 않는다.
## ogg 는 변환 결과가 통 PCM 이라 1회당 73KB, wav 는 1.1KB 였다(66배 차이) —
## 그래서 크래시가 `_alloc_vorbis` 에서 났다. **vorbis 는 범인이 아니라 피해자다.**
##
## 실측 — 조건을 갈라 보면 이렇다 (`tools/heap_web.sh` · ogg 효과음만)
## ---------------------------------------------------------------------
##
##     AudioContext   이 수정   결과
##     ------------   -------   ----------------------------------------
##     잠김            없음      2GB (150초)
##     활성            없음      2GB
##     잠김            있음      2GB          ← ⚠️ 이 수정만으로는 못 막는다
##     활성            있음      46.1MB 완전 평탄 (15,099회 재생)
##
## ⚠️ **`PLAYBACK_TYPE_STREAM` 은 필요조건이지 충분조건이 아니다.** AudioContext 가
## 잠겨 있으면 재생이 배수되지 않아 어떤 재생 방식이든 쌓인다. 실제 플레이어는 화면을
## 탭하므로 Godot 웹 셸이 컨텍스트를 재개하고, **그 조건에서는 완전히 듣는다** —
## 실제 게임을 11분 돌려 힙 46.1MB 평탄 · 객체 증가 게임 60초당 +21(수정 전 +1,113)을 확인했다.
##
## ⚠️ **이 수정에는 대가가 있고, 그 보정이 함께 있어야 한다.**
## STREAM 은 wasm 안 소프트웨어 믹서를 타므로 엔진 기본 웹 버퍼(50ms)로는 언더런이 난다 —
## 브라우저에서 실제 출력을 캡처해 재니 15초에 **드롭아웃 31회**였고, 사용자도 "재생 중
## 끊긴다"고 보고했다. `project.godot` 의 `audio/driver/output_latency.web` 를 **160ms** 로
## 올려 0 으로 만들었다(`tools/verify_audio_playback.gd` 가 하한을 잠근다).
##
##   출력지연         드롭아웃   소리 나는 블록      클릭
##   50ms(엔진 기본)    31       493/648 (76%)      61
##   160ms               0       648/648 (100%)     38   ← 채택
##   (대조) SAMPLE       0       644/644 (100%)     34
##
## 음량은 두 방식이 같다 — 소리 하나만 재생해 비교하니 RMS 0.0668 vs 0.0693(0.3dB)로
## 사실상 동일했다. "소리가 작아졌다"는 인상은 끊김 때문이지 음량 회귀가 아니다.
##
## ⚠️ 샘플을 미리 등록해 두면(`AudioServer.register_stream_as_sample`) SAMPLE 의 음질을
## 지키면서 누수를 막을 수 있을까 — **안 된다.** 시험해 보니 그대로 2GB 를 친다.
## 누수는 샘플 생성이 아니라 **재생마다** 일어난다.
##
## ⚠️ 이 표를 만들기 전에 한 번 오판했다. `pt=1` 과 `AUDIO=1` 을 **동시에** 켠 실험 하나만
## 보고 "STREAM 고정이 답"이라고 적었는데, 두 변수를 분리하니 위와 같았다.
## **교란변수를 못 가른 채 결론 내지 말 것.**
##
## ⚠️ **데스크톱 헤드리스로는 절대 못 잡는다.** 헤드리스는 Dummy 오디오 드라이버라
## 이 경로를 타지 않는다. 실제로 스로틀 없이 84,000회 재생해도 RSS 가 평탄해서
## 한 번 "오디오는 결백"으로 오판했다. **이 문제만은 웹 실측이 유일한 안전망이다.**
## `tools/verify_audio_playback.gd` 가 이 설정이 사라지지 않는지 CI 에서 지킨다.
func _force_stream_playback(p: AudioStreamPlayer) -> void:
	p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM


## 이 사운드의 스트림이 실제로 로드되어 있는가(선택 사운드의 폴백 분기용).
func has_stream(sound: String) -> bool:
	var p: AudioStreamPlayer = _players.get(sound)
	return p != null and p.stream != null


# 웹(브라우저)에서는 탭을 백그라운드로 보내도 NOTIFICATION_APPLICATION_FOCUS_OUT 이 확실히
# 오지 않아 BGM 이 계속 재생된다. Page Visibility API(document.visibilitychange)를 직접 걸어
# 탭이 숨겨지면 마스터 버스를 음소거하고, 돌아오면 해제한다(모바일/데스크톱은 _notification 이 처리).
var _visibility_cb: JavaScriptObject = null   # 콜백 GC 방지용 참조 유지
func _setup_web_visibility() -> void:
	if not OS.has_feature("web"):
		return
	var document := JavaScriptBridge.get_interface("document")
	if document == null:
		return
	_visibility_cb = JavaScriptBridge.create_callback(_on_web_visibility_change)
	document.addEventListener("visibilitychange", _visibility_cb)


func _on_web_visibility_change(_args: Array) -> void:
	var document := JavaScriptBridge.get_interface("document")
	if document == null:
		return
	AudioServer.set_bus_mute(0, bool(document.hidden))


func _on_music_finished() -> void:
	# 루프 설정이 통하지 않는 환경 폴백 — 같은 트랙(테마 고정 곡)을 즉시 재시작한다.
	if not muted and not music_muted and _music_current != "":
		_start_music(_music_current, _MUSIC_VOL.get(_music_current, -9.0))


## 앱이 백그라운드로 가면(모바일 홈 버튼 / 웹 탭 전환 / 창 포커스 아웃) 소리를 전부 끄고,
## 돌아오면 복구한다. 마스터 버스 음소거라 효과음·배경음악이 한 번에 조용해지고,
## 옵션의 사운드 On/Off 설정(muted)과는 독립적으로 동작한다.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			AudioServer.set_bus_mute(0, true)
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			AudioServer.set_bus_mute(0, false)


## UI 효과음 — 일시정지 중에도 재생된다(메뉴/패널/보상 연출 전용).
func play_ui(sound: String, pitch_vary: float = 0.1, base_pitch: float = 1.0) -> void:
	play(sound, pitch_vary, base_pitch, true)


## base_pitch: 무기 특성별 기준 음높이(1.0=원음). pitch_vary: 매 발 랜덤 변주(반복 단조로움 방지).
## 게임이 멈춰 있는 동안(레벨업/보물상자/일시정지 등) 전투 효과음은 재생하지 않는다 — UI 피드백은
## play_ui() 를 통해서만 통과한다.
func play(sound: String, pitch_vary: float = 0.1, base_pitch: float = 1.0, ui: bool = false) -> void:
	if muted:
		return
	if not ui and get_tree().paused:
		return   # 정지 화면 뒤에서 전투음이 새어 나오지 않게
	var p: AudioStreamPlayer = _players.get(sound)
	if p == null or p.stream == null:
		return

	var min_iv: int = _MIN_INTERVAL.get(sound, 0)
	if min_iv > 0:
		var now := Time.get_ticks_msec()
		var last: int = _last_play.get(sound, -100000)
		if now - last < min_iv:
			return   # 간격 내 재호출은 건너뛰어 겹침·호출 폭주를 막는다(성능·청감)
		# 콤보 상승음은 동전 수집에만 — 피격/사망/발사음이 음이 올라가면 어색하다.
		if sound == "gold":
			# 상승 폭을 +40%(10단계×4%)에서 +15%(6단계×2.5%)로 줄였다 — 젬을 쓸어 담는 구간에서
			# 음이 계속 치솟아 귀가 아팠다. 콤보의 상승감은 남기되, 젬 기준 피치(0.8)로 최고조에
			# 올라도 원음(1.0)을 넘지 않는 선(0.8×1.15=0.92)에서 멈춘다.
			_combo[sound] = (_combo.get(sound, 0) + 1) if (now - last < _COMBO_WINDOW) else 0
			base_pitch *= 1.0 + mini(_combo[sound], 6) * 0.025
		_last_play[sound] = now

	# 정지 페이드가 걸려 있던 플레이어를 다시 쓰는 경우를 여기서 정리한다.
	# 이 두 줄이 없으면 stop_sfx() 직후(페이드 0.3초 안)에 난 소리가 **줄어든 볼륨으로
	# 재생되다가 그 페이드의 콜백에 의해 끊긴다.** 볼륨을 항상 설정값으로 되돌려 두면
	# "재생 시점의 volume_db 는 언제나 옳다"가 무조건 성립해 이 종류의 상태 누출이 사라진다.
	_cancel_stop_fade(sound)
	p.volume_db = _VOLUMES.get(sound, 0.0)

	p.pitch_scale = max(0.05, base_pitch * (1.0 + randf_range(-pitch_vary, pitch_vary)))
	p.play()


## 씬을 떠날 때 효과음을 **페이드해서** 끈다 — 배경음악은 건드리지 않는다.
##
## 왜 필요한가
## -----------
## 효과음 플레이어는 오토로드(SoundManager)의 자식이고 `process_mode = ALWAYS` 다.
## 즉 **씬이 바뀌어도 재생이 그대로 이어진다.** 게임오버 스팅어가 2.6초짜리 지속음이었고
## 패널은 0.35초 만에 뜨므로, 플레이어가 곧바로 메뉴로 나가면 그 소리가 최대 음량인 채로
## 메인 메뉴까지 따라 들어왔다(P2-23 — 사용자 보고).
##
## ⚠️ **그냥 stop() 하면 안 된다.** 이 스팅어는 감쇠하지 않고 최대 음량을 유지하다가
## 끝에서만 떨어진다. 진행 중간에 끊으면 파형이 0 이 아닌 지점에서 잘려 딸깍임이 난다.
## 그래서 화면 페이드와 **같은 시간에 걸쳐** 소리도 함께 빼면, 그림과 소리가 같이 사라진다.
##
## ⚠️ 볼륨을 낮췄다가 되돌리는 구조라, 되돌리기를 빠뜨리면 **그 소리가 영영 작아진 채로
## 남는다.** 복구는 두 겹으로 둔다 — 이 트윈의 마지막 콜백, 그리고 위 play() 의 재설정.
func stop_sfx(fade: float = 0.15) -> void:
	for key in _players:
		var p: AudioStreamPlayer = _players[key]
		if p == null or not p.playing:
			continue
		var base: float = _VOLUMES.get(key, 0.0)
		_cancel_stop_fade(key)
		if fade <= 0.0:
			p.stop()
			p.volume_db = base
			continue
		var tw := create_tween()
		_stop_tweens[key] = tw
		tw.tween_property(p, "volume_db", base - 40.0, fade)
		tw.tween_callback(func() -> void:
			p.stop()
			p.volume_db = base
			_stop_tweens.erase(key))


## 진행 중인 정지 페이드를 취소한다. 볼륨 복구는 호출부가 맡는다(중간에 죽이면
## 낮아진 값이 남으므로, 부르는 쪽이 반드시 base 로 되돌리거나 새 페이드를 건다).
func _cancel_stop_fade(key: String) -> void:
	var tw: Tween = _stop_tweens.get(key)
	if tw != null and tw.is_valid():
		tw.kill()
	_stop_tweens.erase(key)


# ───────────────────────── 배경음악 ─────────────────────────

## 트랙 재생/전환. 같은 트랙이면 볼륨만 원상 복구(덕킹 해제·씬 전환 시 이어 재생).
## 음소거 중에는 트랙 이름만 기억해 뒀다가 사운드를 켜면 이어서 시작한다.
func play_music(track: String) -> void:
	if _music_player == null or not is_instance_valid(_music_player):
		return   # 초기화 전/해체 중 호출 가드
	var target: float = _MUSIC_VOL.get(track, -9.0)
	if track == _music_current:
		_music_ducked = false   # 다시하기 등 재진입 — 사망 덕킹이 남아있으면 복구
		if not muted and not music_muted:
			if _music_player.playing:
				_fade_music_to(target, _MUSIC_FADE * 0.5)
			else:
				_start_music(track, target)
		return
	_music_current = track
	_music_ducked = false
	if muted or music_muted:
		return   # 트랙 이름만 기억해 두면 켤 때 이어서 시작한다(set_enabled/set_music_enabled)
	if _music_player.playing:
		# 페이드 아웃 → 트랙 교체 → 페이드 인 (단일 플레이어 크로스페이드)
		_kill_music_tween()
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", -40.0, _MUSIC_FADE * 0.5)
		_music_tween.tween_callback(_start_music.bind(track, target))
	else:
		_start_music(track, target)


func stop_music(fade: float = 0.6) -> void:
	if _music_player == null or not is_instance_valid(_music_player):
		return
	_music_current = ""
	if not _music_player.playing:
		return
	_kill_music_tween()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -40.0, fade)
	_music_tween.tween_callback(_music_player.stop)


func _start_music(track: String, target_db: float) -> void:
	if _music_player == null or not is_instance_valid(_music_player):
		return   # 씬 트리 해체 중(종료) 콜백 경합 가드
	if track != _music_current:
		return   # 페이드 중 다른 트랙으로 다시 전환된 경우
	var variants: Array = _MUSIC.get(track, [])
	if variants.is_empty():
		return
	var stream = load(_pick_variant(track, variants))
	if stream == null:
		return
	if stream is AudioStreamMP3:
		stream.loop = true   # 시작 시 결정된 곡을 심리스 루프(중간 로테이션 없음)
	_music_player.stream = stream
	_music_player.volume_db = -40.0
	_music_player.play()
	_fade_music_to(target_db, _MUSIC_FADE)


## 트랙의 재생 곡 결정 — 게임 BGM 은 선택 테마 인덱스로 고정되어 같은 테마는 항상 같은 곡.
func _pick_variant(track: String, variants: Array) -> String:
	if variants.size() <= 1 or track != "game":
		return variants[0]
	var idx := 0
	var t: ThemeData = ThemeManager.selected()
	if t != null:
		idx = maxi(0, GameData.themes.find(t))
	return variants[idx % variants.size()]


## 사망 시 음악을 낮추고(true) 부활 시 되돌린다(false). 다시하기는 play_music 이 복구.
func _duck_music(down: bool) -> void:
	if _music_player == null or not is_instance_valid(_music_player):
		return
	_music_ducked = down
	if muted or music_muted or not _music_player.playing or _music_current == "":
		return
	var base: float = _MUSIC_VOL.get(_music_current, -9.0)
	_fade_music_to(base + (_DUCK_DB if down else 0.0), 0.8)


func _fade_music_to(db: float, dur: float) -> void:
	if _music_player == null or not is_instance_valid(_music_player):
		return
	_kill_music_tween()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", db, dur)


func _kill_music_tween() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()


# ───────────────────────── 설정 ─────────────────────────

func is_enabled() -> bool:
	return not muted


## 사운드 On/Off 설정(옵션 메뉴). 즉시 적용하고 디스크에 보존한다.
## 끄면 배경음악도 함께 멈추고, 켜면 현재 씬의 트랙을 이어서 재생한다.
func set_enabled(on: bool) -> void:
	muted = not on
	var f := FileAccess.open(SETTING_PATH, FileAccess.WRITE)
	if f:
		f.store_string("1" if on else "0")
		f.close()
	if muted:
		_kill_music_tween()
		_music_player.stop()
	elif _music_current != "" and not music_muted:
		_start_music(_music_current, _MUSIC_VOL.get(_music_current, -9.0))


func is_music_enabled() -> bool:
	return not music_muted


## 음악만 켜고 끈다. 효과음(muted)과 독립이다 — 둘 다 켜져야 음악이 난다.
func set_music_enabled(on: bool) -> void:
	music_muted = not on
	var f := FileAccess.open(MUSIC_SETTING_PATH, FileAccess.WRITE)
	if f:
		f.store_string("1" if on else "0")
		f.close()
	if music_muted:
		_kill_music_tween()
		_music_player.stop()
	elif not muted and _music_current != "":
		_start_music(_music_current, _MUSIC_VOL.get(_music_current, -9.0))


func _read_setting() -> bool:
	return _read_flag_off(SETTING_PATH)


## "0" 이 적혀 있으면 true(=꺼짐). 파일이 없으면 false(=켜짐이 기본).
func _read_flag_off(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return false
	var txt := f.get_as_text().strip_edges()
	f.close()
	return txt == "0"
