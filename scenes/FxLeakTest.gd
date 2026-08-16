extends Node
## 레벨업 연출(축하 폭죽) 누수 회귀 테스트.
##
## 실행:
##   godot --headless --path . res://scenes/FxLeakTest.tscn
##
## 배경: FireworksFX 는 CPUParticles2D 를 원샷으로 띄우고 finished 시그널로 해제했다.
## 그런데 CPUParticles2D 는 화면에서 숨겨지면(레벨업 패널이 닫히면) 시뮬레이션을 멈추고
## finished 를 영영 emit 하지 않는다. 카드를 폭죽이 끝나기 전에 고르면 매번 수십 개가
## 홀더에 남았고, 고레벨(100+)에서는 수천 개가 쌓였다가 패널이 열리는 순간 전부 되살아나
## 프레임이 무너졌다 — 웹에서 보고된 하드 프리즈의 직접 원인이다.
##
## 검사 항목
##   T1 레벨업을 반복해도 폭죽 홀더가 매번 비워진다
##   T2 레벨업 반복 후 전체 노드 수가 유의미하게 늘지 않는다

const MAIN := preload("res://scenes/Main.tscn")

const LEVELS := 20            # 반복할 레벨업 횟수
const PICK_WAIT := 0.9        # 자동플레이가 카드를 고르는 데 필요한 시간(초, 실시간)
const NODE_SLACK := 400       # 좀비/젬/총알 등 정상 변동 허용치

var _ok: int = 0
var _total: int = 0


func _ready() -> void:
	add_child(MAIN.instantiate())
	_run()


func _wait(sec: float) -> void:
	var until := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _check(name: String, cond: bool) -> void:
	_total += 1
	if cond:
		_ok += 1
	print("%s %s" % ["PASS" if cond else "FAIL", name])


func _particles() -> int:
	var n := 0
	for c in get_tree().root.get_children():
		n += _count(c)
	return n


func _count(n: Node) -> int:
	var c := 1 if n is CPUParticles2D else 0
	for ch in n.get_children():
		c += _count(ch)
	return c


func _run() -> void:
	Cheats.autoplay = true
	Events.reset()
	await _wait(1.0)

	var base_particles := _particles()          # 화염방사기/앰비언트 등 상시 파티클
	var base_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var worst_particles := base_particles

	for i in LEVELS:
		Events.bonus_level()
		await _wait(0.25)
		worst_particles = maxi(worst_particles, _particles())   # 폭죽이 실제로 터지는 시점
		await _wait(PICK_WAIT - 0.25)

	await _wait(2.0)   # 마지막 폭죽의 수명 타이머까지 소진
	var end_particles := _particles()
	var end_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	print("  base_particles=%d worst=%d end=%d | base_nodes=%d end_nodes=%d level=%d"
		% [base_particles, worst_particles, end_particles, base_nodes, end_nodes, Events.level])

	# 레벨업 %d 회를 돌고 나면 상시 파티클 수로 되돌아와야 한다(누수면 수백 개가 남는다).
	_check("사전조건: 폭죽이 실제로 발사됨", worst_particles > base_particles + 3)
	_check("T1 레벨업 %d 회 후 폭죽이 남지 않음" % LEVELS, end_particles <= base_particles + 8)
	_check("T2 노드 수가 정상 범위 유지 (%d → %d)" % [base_nodes, end_nodes],
		end_nodes <= base_nodes + NODE_SLACK)

	print("RESULT ok=%d/%d" % [_ok, _total])
	await get_tree().process_frame
	get_tree().quit(0 if _ok == _total else 1)
