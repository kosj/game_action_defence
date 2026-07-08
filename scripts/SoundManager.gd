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
}

const _VOLUMES: Dictionary = {
	"shoot":       -8.0,
	"laser":       -9.0,
	"boom":        -4.0,
	"zombie_hit":  -6.0,
	"zombie_die":  -3.0,
	"gold":        -4.0,
	"player_hurt":  0.0,
}

## 배경음악 트랙 — 둘 다 프로시저럴 합성 루프(assets/audio, 심리스 루프 검증됨).
const _MUSIC: Dictionary = {
	"title": "res://assets/audio/bgm_title.wav",   # 다크 앰비언트(타이틀·메뉴)
	"game":  "res://assets/audio/bgm_game.wav",    # 긴장감 있는 액션 루프(인게임)
}
const _MUSIC_VOL: Dictionary = {"title": -8.0, "game": -10.0}
const _MUSIC_FADE := 0.9        # 트랙 전환 크로스페이드(초)
const _DUCK_DB := -14.0         # 사망 시 음악을 낮추는 상대량(dB)

const SETTING_PATH := "user://sound.save"

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
}
const _COMBO_WINDOW := 380   # ms — 이 안에 연속되면 콤보로 보고 음을 살짝 올린다(마리오 동전 느낌)

var _players: Dictionary = {}
var _last_play: Dictionary = {}   # sound -> 마지막 재생 시각(ms)
var _combo: Dictionary = {}       # sound -> 콤보 단계
var muted: bool = false   # 옵션에서 끄면 효과음·배경음악 모두 음소거

# ── 배경음악 상태 ──
var _music_player: AudioStreamPlayer
var _music_current: String = ""      # 재생 중(또는 음소거 해제 시 재생할) 트랙 이름
var _music_tween: Tween
var _music_ducked: bool = false      # 사망 연출로 볼륨을 낮춘 상태


func _ready() -> void:
	# 상점/게임오버에서 트리를 일시정지해도 음악(과 그 페이드 트윈)은 계속 흘러야 한다.
	process_mode = Node.PROCESS_MODE_ALWAYS
	muted = _read_setting()
	for key in _SOUNDS:
		var p := AudioStreamPlayer.new()
		var stream = load(_SOUNDS[key])
		if stream:
			p.stream = stream
			p.volume_db = _VOLUMES.get(key, 0.0)
		add_child(p)
		_players[key] = p

	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	# 루프 설정이 실패하는 환경(웹 등)을 위한 폴백 — 끝나면 즉시 재시작.
	_music_player.finished.connect(_on_music_finished)

	# 사망 시 음악을 낮춰 게임오버 연출을 살리고, 부활하면 복구한다.
	Events.player_died.connect(_duck_music.bind(true))
	Events.player_revived.connect(_duck_music.bind(false))


func _on_music_finished() -> void:
	if not muted and _music_current != "":
		_music_player.play()


## 앱이 백그라운드로 가면(모바일 홈 버튼 / 웹 탭 전환 / 창 포커스 아웃) 소리를 전부 끄고,
## 돌아오면 복구한다. 마스터 버스 음소거라 효과음·배경음악이 한 번에 조용해지고,
## 옵션의 사운드 On/Off 설정(muted)과는 독립적으로 동작한다.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			AudioServer.set_bus_mute(0, true)
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			AudioServer.set_bus_mute(0, false)


## base_pitch: 무기 특성별 기준 음높이(1.0=원음). pitch_vary: 매 발 랜덤 변주(반복 단조로움 방지).
func play(sound: String, pitch_vary: float = 0.1, base_pitch: float = 1.0) -> void:
	if muted:
		return
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
			_combo[sound] = (_combo.get(sound, 0) + 1) if (now - last < _COMBO_WINDOW) else 0
			base_pitch *= 1.0 + mini(_combo[sound], 10) * 0.04
		_last_play[sound] = now

	p.pitch_scale = max(0.05, base_pitch * (1.0 + randf_range(-pitch_vary, pitch_vary)))
	p.play()


# ───────────────────────── 배경음악 ─────────────────────────

## 트랙 재생/전환. 같은 트랙이면 볼륨만 원상 복구(덕킹 해제·씬 전환 시 이어 재생).
## 음소거 중에는 트랙 이름만 기억해 뒀다가 사운드를 켜면 이어서 시작한다.
func play_music(track: String) -> void:
	var target: float = _MUSIC_VOL.get(track, -9.0)
	if track == _music_current:
		_music_ducked = false   # 다시하기 등 재진입 — 사망 덕킹이 남아있으면 복구
		if not muted:
			if _music_player.playing:
				_fade_music_to(target, _MUSIC_FADE * 0.5)
			else:
				_start_music(track, target)
		return
	_music_current = track
	_music_ducked = false
	if muted:
		return
	if _music_player.playing:
		# 페이드 아웃 → 트랙 교체 → 페이드 인 (단일 플레이어 크로스페이드)
		_kill_music_tween()
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", -40.0, _MUSIC_FADE * 0.5)
		_music_tween.tween_callback(_start_music.bind(track, target))
	else:
		_start_music(track, target)


func stop_music(fade: float = 0.6) -> void:
	_music_current = ""
	if not _music_player.playing:
		return
	_kill_music_tween()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -40.0, fade)
	_music_tween.tween_callback(_music_player.stop)


func _start_music(track: String, target_db: float) -> void:
	if track != _music_current:
		return   # 페이드 중 다른 트랙으로 다시 전환된 경우
	var stream = load(_MUSIC.get(track, ""))
	if stream == null:
		return
	if stream is AudioStreamWAV:
		# 임포트 기본값은 루프 꺼짐 — 런타임에 루프를 켠다(16-bit mono: 프레임 = 바이트/2).
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2
	_music_player.stream = stream
	_music_player.volume_db = -40.0
	_music_player.play()
	_fade_music_to(target_db, _MUSIC_FADE)


## 사망 시 음악을 낮추고(true) 부활 시 되돌린다(false). 다시하기는 play_music 이 복구.
func _duck_music(down: bool) -> void:
	_music_ducked = down
	if muted or not _music_player.playing or _music_current == "":
		return
	var base: float = _MUSIC_VOL.get(_music_current, -9.0)
	_fade_music_to(base + (_DUCK_DB if down else 0.0), 0.8)


func _fade_music_to(db: float, dur: float) -> void:
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
	elif _music_current != "":
		_start_music(_music_current, _MUSIC_VOL.get(_music_current, -9.0))


func _read_setting() -> bool:
	if not FileAccess.file_exists(SETTING_PATH):
		return false   # 기본: 음소거 아님(사운드 On)
	var f := FileAccess.open(SETTING_PATH, FileAccess.READ)
	if not f:
		return false
	var txt := f.get_as_text().strip_edges()
	f.close()
	return txt == "0"   # "0" = Off → muted=true
