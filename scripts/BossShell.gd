extends Node2D
## 보스 포격 탄착 표식: 지정 위치에 경고 링을 warn_time 동안 표시한 뒤 폭발한다.
## 폭발 순간 반경 안의 플레이어에게 피해 — 표식이 곧 텔레그래프이므로 이동으로 피할 수 있다.
## FXBurst 와 동일한 정적 풀(free-list)로 인스턴스를 재사용해 할당 비용을 없앤다.

const _FXBurst := preload("res://scripts/FXBurst.gd")

static var _pool: Array = []

var warn_time: float = 1.0
var blast_radius: float = 90.0
var damage: int = 2
var color: Color = Color(1.0, 0.5, 0.15)
var _t: float = 0.0
var _active: bool = false
var _exploded: bool = false


## 풀에서 탄착 표식 하나를 꺼내(없으면 생성) parent 에 붙이고 즉시 재생. 폭발 후 자동 반납.
static func spawn(parent: Node, pos: Vector2, p_warn: float, p_radius: float, p_damage: int, p_color: Color = Color(1.0, 0.5, 0.15)) -> void:
	var s = _pool.pop_back() if _pool.size() > 0 else (load("res://scripts/BossShell.gd") as GDScript).new()
	s.warn_time = p_warn
	s.blast_radius = p_radius
	s.damage = p_damage
	s.color = p_color
	s._t = 0.0
	s._active = true
	s._exploded = false
	s.visible = true
	if s.get_parent() != parent:
		if s.get_parent() != null:
			s.get_parent().remove_child(s)
		parent.add_child(s)
	s.global_position = pos
	s.queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	if _t >= warn_time and not _exploded:
		_explode()
		return
	queue_redraw()


func _explode() -> void:
	_exploded = true
	_FXBurst.spawn(get_tree().current_scene, global_position, color, blast_radius, 0.4)
	SoundManager.play("zombie_die")
	Events.shake(4.0)   # 포격 착탄 타격감
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("take_hit"):
		if global_position.distance_squared_to(player.global_position) <= blast_radius * blast_radius:
			player.take_hit(damage)
	_recycle()


## 트리에서 떼어내 풀에 보관(재사용 대기).
func _recycle() -> void:
	_active = false
	visible = false
	if get_parent() != null:
		get_parent().remove_child(self)
	_pool.append(self)


## 씬 전환 시 보관 중인 오르팬 노드 정리(메모리·오르팬 경고 방지).
static func clear_pool() -> void:
	for s in _pool:
		if is_instance_valid(s):
			s.queue_free()
	_pool.clear()


func _draw() -> void:
	if not _active:
		return
	var t := clampf(_t / warn_time, 0.0, 1.0)
	# 고정 경고 테두리 링
	draw_arc(Vector2.ZERO, blast_radius, 0.0, TAU, 48, Color(color.r, color.g, color.b, 0.9), 3.0, true)
	# 임박할수록 채워지는 내부(폭발 직전 가장 진하게 — "지금 벗어나라" 신호)
	draw_circle(Vector2.ZERO, blast_radius * t, Color(color.r, color.g, color.b, 0.12 + 0.28 * t))
	# 조준 십자
	draw_line(Vector2(-blast_radius, 0), Vector2(blast_radius, 0), Color(color.r, color.g, color.b, 0.5), 1.5)
	draw_line(Vector2(0, -blast_radius), Vector2(0, blast_radius), Color(color.r, color.g, color.b, 0.5), 1.5)
