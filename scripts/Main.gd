extends Node2D
## 메인: 풀 프리워밍(첫 웨이브 끊김 방지).
## Events 의 새 게임/이어하기 상태는 MainMenu 에서 씬 전환 전에 이미 준비된다.

const ZOMBIE := preload("res://scenes/Zombie.tscn")
const BULLET := preload("res://scenes/Bullet.tscn")
const ENEMY_BULLET := preload("res://scenes/EnemyBullet.tscn")
const GOLD := preload("res://scenes/Gold.tscn")
const ITEM_PICKUP := preload("res://scenes/ItemPickup.tscn")


func _ready() -> void:
	Telemetry.begin_run()       # 이 판의 기록 시작(기기 안에만 남는다 — Telemetry.gd 참고)
	CodexManager.on_run_start(ThemeManager.selected_id())   # 도감: 이 아레나를 플레이함 + 시작 인벤토리
	Events.pause_release_all()  # 게임 씬 진입 시 이전 판의 정지 소유권이 남아있지 않도록 보장
	Engine.time_scale = 1.0     # 이전 판의 히트스톱 배속이 남아 새 판이 느리게/멈춘 듯 시작하지 않도록
	_clean_slate()              # 이전 판의 잔존 엔티티/풀/정적 상태 정리(새 판·이어하기·다시하기 공통)
	# 인게임 BGM 으로 크로스페이드(다시하기 재진입 시에는 끊김 없이 이어 재생 + 덕킹 복구).
	SoundManager.play_music("game")
	# 첫 프레임을 먼저 렌더한 뒤 풀을 채워 WebGL 초기 프리즈 방지
	call_deferred("_do_prewarm")
	call_deferred("_spawn_ambient")


## 테마별 앰비언트 입자 — 화면 전반에 은은히 떠다니는 티끌(교외/도심/연구소 색조). 플레이어를 따라다녀
## 이동해도 시야가 채워진다. 입자는 월드 좌표에 남아 자연스럽게 흐른다.
## 새 게임 씬 진입마다 이전 판의 잔재를 확실히 청소한다. 씬 전환(change_scene)이 대부분 정리하지만
## SceneFade 페이드(0.3s) 동안 옛 스포너가 좀비를 풀에 반납하거나, 웹에서 해제 타이밍이 밀려
## 좀비가 남아 보이는 경우를 방지 — 그룹에 남은 적을 즉시 해제하고 오브젝트 풀·정적 상태를 비운다.
func _clean_slate() -> void:
	for g in ["zombies", "boss"]:
		for n in get_tree().get_nodes_in_group(g):
			if is_instance_valid(n):
				n.queue_free()
	Pool.clear()
	# 정적 풀/추적 목록 초기화 — 이전 씬에서 해제된 노드를 재사용해 에러가 나거나 활성 카운터가
	# 남아 이펙트가 영구히 안 나오는 것을 방지한다.
	preload("res://scripts/Gold.gd").reset_live()
	preload("res://scripts/SpriteFX.gd").reset_pool()
	preload("res://scripts/FXBurst.gd").reset_pool()
	preload("res://scripts/DamageNumber.gd").reset_pool()
	preload("res://scripts/BossShell.gd").reset_pool()
	preload("res://scripts/FXLightning.gd").reset_pool()


func _spawn_ambient() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var tint := Color(0.7, 0.75, 0.8)
	var td: ThemeData = ThemeManager.selected()
	if td != null:
		tint = td.mark
	var vp := get_viewport().get_visible_rect().size
	var p := CPUParticles2D.new()
	p.z_index = -1                      # 지면 위, 유닛 아래
	p.local_coords = false              # 방출된 입자는 월드에 남아 흐른다
	p.amount = 22
	p.lifetime = 7.0
	p.preprocess = 4.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(vp.x * 0.62, vp.y * 0.62)
	p.direction = Vector2(0, -1)
	p.spread = 60.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 16.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.4
	p.color = Color(tint.r, tint.g, tint.b, 0.28)
	p.add_to_group("ambient_fx")   # DayNightCycle 이 밤에 반딧불 톤으로 옮긴다
	player.add_child(p)


func _do_prewarm() -> void:
	Pool.prewarm(ZOMBIE, 60)
	Pool.prewarm(BULLET, 50)
	Pool.prewarm(ENEMY_BULLET, 10)
	Pool.prewarm(GOLD, 60)
	Pool.prewarm(ITEM_PICKUP, 2)
