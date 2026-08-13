extends WeaponModule
## 못 박은 배트(근접 원호): 주기적으로 조준 방향으로 넓은 부채꼴을 휘둘러 그 안의 좀비를
## 한 번에 강타(강한 넉백). _data: fire_interval=휘두르기 주기, spread=원호 반각(rad),
## area_radius=사거리, proj_damage/dmg_per_level=피해, knockback=넉백 세기.

const SWING_DUR := 0.18   # 휘두르기 애니메이션(스윕) 지속

var _t: float = 0.0
var _swing_t: float = -1.0   # >=0 이면 스윙 연출 진행 중
var _aim: Vector2 = Vector2.RIGHT
var _slash: Sprite2D


func _ready() -> void:
	# 휘두르기 궤적 이미지(초승달 슬래시). 조준 방향으로 회전·스윕하며 옅어진다.
	_slash = Sprite2D.new()
	_slash.texture = preload("res://assets/sprites/fx/slash.png")
	_slash.z_index = 1
	_slash.visible = false
	add_child(_slash)


func _reach() -> float:
	return _data.area_radius * (1.0 + 0.04 * float(_level() - 1))


func _physics_process(delta: float) -> void:
	if _data == null:
		return
	if _swing_t >= 0.0:
		_swing_t += delta
		if _swing_t >= SWING_DUR:
			_swing_t = -1.0
	_t += delta
	var interval: float = maxf(_data.fire_interval * 0.6, _data.fire_interval * pow(0.95, float(_level() - 1)))
	if _t >= interval:
		_t = 0.0
		_aim = _aim_dir(_reach())
		_swing()
		_swing_t = 0.0
	rotation = _aim.angle()
	_update_slash()


func _swing() -> void:
	SoundManager.play("swing", 0.12, 1.0)   # 휘두르는 휙 소리(파일 있을 때만 — 스로틀 적용)
	var lvl := _level()
	var dmg: int = _data.proj_damage + _data.dmg_per_level * (lvl - 1)
	var reach := _reach()
	var reach_sq := reach * reach
	var half := _data.spread
	for z in Events.live_zombies():
		if not is_instance_valid(z) or not z.is_in_group("zombies"):
			continue
		var to: Vector2 = z.global_position - global_position
		if to.length_squared() > reach_sq:
			continue
		if absf(to.angle_to(_aim)) <= half:
			z.take_damage(dmg)
			if z.has_method("apply_knockback"):
				z.apply_knockback(to.normalized(), _data.knockback)
	_FXBurst.spawn(get_tree().current_scene, global_position + _aim * reach * 0.6, _data.color, reach * 0.4, 0.14)


## 스윙 연출: 초승달 슬래시 이미지가 조준 방향(로컬 +X) 앞에서 원호를 따라 쓸고 지나가며 옅어진다.
## 스프라이트의 호 반경(92px)을 사거리에 맞춰 스케일, 회전으로 -spread→+spread 스윕.
func _update_slash() -> void:
	if _slash == null:
		return
	if _swing_t < 0.0:
		_slash.visible = false
		return
	var p := clampf(_swing_t / SWING_DUR, 0.0, 1.0)
	var sc: float = (_reach() / 92.0) * (0.8 + 0.3 * p)
	_slash.visible = true
	_slash.scale = Vector2(sc, sc)
	_slash.rotation = -_data.spread * 0.6 + (_data.spread * 1.2) * p
	var c: Color = _data.color
	_slash.modulate = Color(minf(c.r * 1.25, 1.0), minf(c.g * 1.25, 1.0), minf(c.b * 1.25, 1.0), 1.0 - p * 0.85)
