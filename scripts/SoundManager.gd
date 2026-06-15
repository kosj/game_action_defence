extends Node
## 효과음 싱글톤 (Autoload "SoundManager")
## SoundManager.play("이름") 으로 어디서든 호출. 피치 랜덤으로 반복 효과 방지.

const _SOUNDS: Dictionary = {
	"shoot":       "res://assets/audio/sfx_shoot.ogg",
	"zombie_hit":  "res://assets/audio/sfx_zombie_hit.ogg",
	"zombie_die":  "res://assets/audio/sfx_zombie_die.ogg",
	"gold":        "res://assets/audio/sfx_gold.ogg",
	"player_hurt": "res://assets/audio/sfx_player_hurt.ogg",
}

const _VOLUMES: Dictionary = {
	"shoot":       -8.0,
	"zombie_hit":  -6.0,
	"zombie_die":  -3.0,
	"gold":        -5.0,
	"player_hurt":  0.0,
}

var _players: Dictionary = {}


func _ready() -> void:
	for key in _SOUNDS:
		var p := AudioStreamPlayer.new()
		var stream = load(_SOUNDS[key])
		if stream:
			p.stream = stream
			p.volume_db = _VOLUMES.get(key, 0.0)
		add_child(p)
		_players[key] = p


func play(sound: String, pitch_vary: float = 0.1) -> void:
	var p: AudioStreamPlayer = _players.get(sound)
	if p and p.stream:
		p.pitch_scale = 1.0 + randf_range(-pitch_vary, pitch_vary)
		p.play()
