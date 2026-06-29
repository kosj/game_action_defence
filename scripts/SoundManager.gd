extends Node
## 효과음 싱글톤 (Autoload "SoundManager")
## SoundManager.play("이름") 으로 어디서든 호출. 피치 랜덤으로 반복 효과 방지.

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

const SETTING_PATH := "user://sound.save"

var _players: Dictionary = {}
var muted: bool = false   # 옵션에서 끄면 모든 효과음을 음소거


func _ready() -> void:
	muted = _read_setting()
	for key in _SOUNDS:
		var p := AudioStreamPlayer.new()
		var stream = load(_SOUNDS[key])
		if stream:
			p.stream = stream
			p.volume_db = _VOLUMES.get(key, 0.0)
		add_child(p)
		_players[key] = p


## base_pitch: 무기 특성별 기준 음높이(1.0=원음). pitch_vary: 매 발 랜덤 변주(반복 단조로움 방지).
func play(sound: String, pitch_vary: float = 0.1, base_pitch: float = 1.0) -> void:
	if muted:
		return
	var p: AudioStreamPlayer = _players.get(sound)
	if p and p.stream:
		p.pitch_scale = max(0.05, base_pitch * (1.0 + randf_range(-pitch_vary, pitch_vary)))
		p.play()


func is_enabled() -> bool:
	return not muted


## 사운드 On/Off 설정(옵션 메뉴). 즉시 적용하고 디스크에 보존한다.
func set_enabled(on: bool) -> void:
	muted = not on
	var f := FileAccess.open(SETTING_PATH, FileAccess.WRITE)
	if f:
		f.store_string("1" if on else "0")
		f.close()


func _read_setting() -> bool:
	if not FileAccess.file_exists(SETTING_PATH):
		return false   # 기본: 음소거 아님(사운드 On)
	var f := FileAccess.open(SETTING_PATH, FileAccess.READ)
	if not f:
		return false
	var txt := f.get_as_text().strip_edges()
	f.close()
	return txt == "0"   # "0" = Off → muted=true
