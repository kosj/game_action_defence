extends Area2D
## 필드 픽업: 보물상자(먹으면 랜덤 골드) 또는 폭탄(화면 내 잡몹 일소). 방치 시 사라진다.
## 풀링되며 "item_pickups" 그룹으로 동시 등장 수를 제한한다.

const _FXBurst := preload("res://scripts/FXBurst.gd")
const _ChestReward := preload("res://scripts/ChestRewardPanel.gd")

@export var collect_radius: float = 34.0
@export var lifetime: float = 26.0
@export var fade_time: float = 3.0

const CHEST_COLOR := Color(1.0, 0.82, 0.2)
const EVOCHEST_COLOR := Color(0.75, 0.45, 1.0)   # 진화 상자 — 보라(엘리트/보스 드롭)
const BOMB_COLOR := Color(1.0, 0.45, 0.15)
const BOMB_DAMAGE := 40           # 폭탄: 화면 내 잡몹 일소(보스 제외)
const CHEST_GOLD_MIN := 12        # 보물상자 골드 획득 범위
const CHEST_GOLD_MAX := 55

# 상자 아트 — 있으면 스프라이트로, 없으면 아래 절차 드로잉으로 그린다.
# (Pool.acquire 가 kind 를 지정하기 "전에" on_spawn 을 부르므로 미리 정할 수 없어
#  그리는 시점에 kind 를 보고 한 번만 로드해 캐시한다.)
const CHEST_TEX_PATH := "res://assets/sprites/props/chest_treasure.png"
const EVOCHEST_TEX_PATH := "res://assets/sprites/props/chest_evolution.png"
const CHEST_DRAW_PX := 46.0   # 화면에 그릴 긴 변 크기

var kind: String = "chest"   # "chest" | "bomb" — 스포너가 스폰 시 지정
var player: Node2D = null
var _alive: bool = false
var _t: float = 0.0
var _tex: Texture2D = null
var _tex_kind: String = ""   # _tex 를 어느 kind 로 캐시했는지


func _icon_color() -> Color:
	match kind:
		"bomb": return BOMB_COLOR
		"evochest": return EVOCHEST_COLOR
		_: return CHEST_COLOR


func _label() -> String:
	match kind:
		"bomb": return "Bomb"
		"evochest": return "Evolution"
		_: return "Treasure"


func _ready() -> void:
	add_to_group("item_pickups")
	monitoring = false
	monitorable = false


func on_spawn() -> void:
	add_to_group("item_pickups")   # 재사용 시 멱등 재등록(안전)
	_alive = true
	_t = 0.0
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")


func on_despawn() -> void:
	_alive = false
	remove_from_group("item_pickups")


func _process(delta: float) -> void:
	if not _alive:
		return
	_t += delta
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		queue_redraw()
		return
	if global_position.distance_to(player.global_position) <= collect_radius:
		_collect()
		return
	if _t >= lifetime:
		_despawn()
		return
	queue_redraw()


func _collect() -> void:
	_alive = false
	match kind:
		"bomb": _collect_bomb()
		"evochest": _collect_evochest()
		_: _collect_chest()
	_despawn()


## 진화 보물상자: 진화 가능한 무기가 있으면 진화 선택지를 띄우고, 없으면 보상(무료 레벨업 + 골드).
func _collect_evochest() -> void:
	SoundManager.play("gold", 0.05, 0.9)
	_FXBurst.spawn(get_tree().current_scene, global_position, EVOCHEST_COLOR, 110.0, 0.55)
	Events.shake(5.0)
	if not Events.available_evolutions().is_empty():
		Events.evolution_offer.emit()          # LevelUpPanel 이 진화 선택 패널을 띄운다
	else:
		Events.bonus_level()                    # 진화 대상 없음 — 무료 레벨업으로 보상
		Events.add_gold(randi_range(25, 50))


func _collect_chest() -> void:
	# 보물상자: 등급(일반/고급/희귀/전설) 추첨 → 게임을 멈추는 리빌 연출 → 닫힐 때 보상 적용.
	_FXBurst.spawn(get_tree().current_scene, global_position, CHEST_COLOR, 90.0, 0.5)
	_ChestReward.open(get_tree().current_scene)


func _collect_bomb() -> void:
	# 화면 내 잡몹 일소(보스 제외). 큰 폭발 이펙트 + 강한 화면 흔들림.
	for z in Events.live_zombies():
		if is_instance_valid(z) and z.is_in_group("zombies") and not z.is_in_group("boss"):
			z.take_damage(BOMB_DAMAGE)
	SoundManager.play("boom", 0.06)
	_FXBurst.spawn(get_tree().current_scene, global_position, BOMB_COLOR, 420.0, 0.55)
	Events.shake(9.0)


func _despawn() -> void:
	_alive = false
	Pool.release(self)


func _draw() -> void:
	if not _alive:
		return
	var bob := sin(_t * 2.4) * 5.0
	var center := Vector2(0.0, bob)
	var alpha := 1.0
	var remain := lifetime - _t
	if remain < fade_time:
		alpha = clampf(remain / fade_time, 0.0, 1.0)
	if kind == "bomb":
		_draw_bomb(center, alpha)
	else:
		_draw_chest(center, alpha)   # chest/evochest — 금속 밴드 색은 _icon_color()
	var font := ThemeDB.fallback_font
	draw_string(font, center + Vector2(-60.0, -34.0), _label(), HORIZONTAL_ALIGNMENT_CENTER, 120.0, 14, Color(1.0, 1.0, 1.0, alpha))


## 종류에 맞는 상자 텍스처(없으면 null). 파일이 없으면 절차 드로잉으로 폴백하므로
## 에셋이 아직 안 들어와도 게임은 그대로 돌아간다.
func _chest_texture() -> Texture2D:
	if _tex_kind == kind:
		return _tex
	_tex_kind = kind
	_tex = null
	var path := EVOCHEST_TEX_PATH if kind == "evochest" else CHEST_TEX_PATH
	if ResourceLoader.exists(path):
		var r = load(path)
		if r is Texture2D:
			_tex = r
	return _tex


func _draw_chest(center: Vector2, alpha: float) -> void:
	var pulse := 1.0 + sin(_t * 4.0) * 0.05
	var band := _icon_color()   # 보물=금색 / 진화=보라
	draw_circle(center, 20.0 * pulse, Color(band.r, band.g, band.b, 0.22 * alpha))   # 후광

	var tex := _chest_texture()
	if tex:
		# 비율을 유지한 채 긴 변을 CHEST_DRAW_PX 에 맞추고, 후광과 같은 맥동을 준다.
		var ts := Vector2(tex.get_size())
		var longest := maxf(ts.x, ts.y)
		if longest > 0.0:
			var dst := ts * (CHEST_DRAW_PX * pulse / longest)
			draw_texture_rect(tex, Rect2(center - dst * 0.5, dst), false, Color(1, 1, 1, alpha))
			return

	var gold := Color(band.r, band.g, band.b, alpha)
	var wood := Color(0.5, 0.32, 0.15, alpha)
	var wood_d := Color(0.38, 0.24, 0.11, alpha)
	var dark := Color(0.12, 0.08, 0.05, alpha)
	var w := 15.0
	draw_rect(Rect2(center + Vector2(-w, -2.0), Vector2(2.0 * w, 14.0)), wood)      # 몸통
	draw_rect(Rect2(center + Vector2(-w, -11.0), Vector2(2.0 * w, 10.0)), wood_d)   # 뚜껑
	draw_rect(Rect2(center + Vector2(-w, -2.0), Vector2(2.0 * w, 3.0)), gold)       # 중앙 금속 밴드
	draw_rect(Rect2(center + Vector2(-w, 10.0), Vector2(2.0 * w, 2.0)), gold)       # 하단 밴드
	draw_rect(Rect2(center + Vector2(-2.5, -11.0), Vector2(5.0, 23.0)), gold)       # 세로 밴드
	draw_circle(center + Vector2(0.0, 4.0), 3.0, gold)                              # 자물쇠
	draw_circle(center + Vector2(0.0, 4.0), 1.3, dark)
	draw_rect(Rect2(center + Vector2(-w, -11.0), Vector2(2.0 * w, 23.0)), dark, false, 1.5)


func _draw_bomb(center: Vector2, alpha: float) -> void:
	var col := BOMB_COLOR
	var pulse := 1.0 + sin(_t * 5.0) * 0.07
	var glow_r := 22.0 * pulse
	draw_circle(center, glow_r, Color(col.r, col.g, col.b, 0.30 * alpha))
	draw_arc(center, glow_r * 0.8, 0.0, TAU, 28, Color(col.r, col.g, col.b, 0.6 * alpha), 2.5, true)
	for i in 6:
		var a := _t * 2.0 + TAU * float(i) / 6.0
		var p := center + Vector2.from_angle(a) * (glow_r + 4.0)
		draw_circle(p, 2.2, Color(col.r, col.g, col.b, 0.7 * alpha))
	var r := 11.0 * pulse
	draw_circle(center, r, Color(col.r, col.g, col.b, 0.92 * alpha))
	draw_circle(center, r * 0.55, Color(1.0, 1.0, 1.0, 0.85 * alpha))
