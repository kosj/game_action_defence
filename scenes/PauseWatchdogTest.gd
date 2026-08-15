extends Node
## 일시정지 워치독 회귀 테스트 — "화면엔 아무것도 없는데 게임만 멈춘" 프리즈 재발 방지용.
##
## 실행:
##   godot --headless --path . res://scenes/PauseWatchdogTest.tscn
## 마지막 줄에 "RESULT ok=<통과>/<전체>" 가 찍힌다. 통과 수가 전체와 다르면 회귀다.
##
## 검사 항목
##   T1 소유자 없는 정지(외부 코드가 직접 paused=true) → 유예 후 자동 해제
##   T2 정지를 건 채 해제된 소유자 → 자동 해제
##   T3 계속 숨겨져 있는 소유자 → 유예 시간 동안은 유지, 이후 자동 해제
##   T4 복구되지 않은 히트스톱 배속 → 1.0 으로 자동 복구
##   T5 레벨업 패널이 떠 있는 동안 들어온 진화 제안 → 버려지지 않고 대기 후 처리
##   T6 자동플레이 장시간 구동 중 2초 이상 지속되는 정지가 없음

const MAIN := preload("res://scenes/Main.tscn")

## T6 자동플레이 감시 길이(초, 실시간). Engine.time_scale 로 게임 시간은 이보다 훨씬 길게 흐른다.
const SOAK_SECONDS := 60.0
const SOAK_TIME_SCALE := 6.0

var _ok: int = 0
var _total: int = 0


func _ready() -> void:
	add_child(MAIN.instantiate())
	_run()


## 실시간(벽시계) 대기 — 워치독이 Time.get_ticks_msec() 기준이라 프레임 델타에 흔들리면 안 된다.
func _wait(sec: float) -> void:
	var until := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _check(name: String, cond: bool) -> void:
	_total += 1
	if cond:
		_ok += 1
	print("%s %s" % ["PASS" if cond else "FAIL", name])


func _run() -> void:
	Cheats.autoplay = true
	Events.reset()
	await get_tree().process_frame

	# T1 — 레지스트리를 거치지 않은 정지(레거시 코드/서드파티)도 워치독이 걷어내야 한다.
	get_tree().paused = true
	await _wait(2.0)
	_check("T1 소유자 없는 정지 자동 해제", not get_tree().paused)

	# T2 — 정지를 걸어놓고 소유권 반납 없이 사라지는 패널.
	var ghost := CanvasLayer.new()
	add_child(ghost)
	Events.pause_push(ghost, "ghost")
	_check("T2 push 로 정지됨", get_tree().paused)
	ghost.queue_free()
	await _wait(1.0)
	_check("T2 해제된 소유자 자동 정리", not get_tree().paused and Events.pause_owner_tags().is_empty())

	# T3 — 연출 대기 등으로 잠깐 숨어 있는 소유자는 유예 시간 동안 정지를 유지해야 한다.
	var hidden := CanvasLayer.new()
	add_child(hidden)
	hidden.visible = false
	Events.pause_push(hidden, "hidden")
	await _wait(1.2)
	var held := get_tree().paused
	await _wait(4.0)
	_check("T3 숨은 소유자 유예 유지", held)
	_check("T3 계속 숨은 소유자 자동 해제", not get_tree().paused)
	hidden.queue_free()

	# T4 — 히트스톱 배속이 남으면 게임이 멈춘 것처럼 보인다.
	Engine.time_scale = 0.05
	await _wait(2.0)
	_check("T4 잔류 히트스톱 배속 복구", is_equal_approx(Engine.time_scale, 1.0))

	# T5 — 패널이 떠 있는 동안 들어온 진화 제안이 증발하지 않아야 한다.
	var lp := _find_levelup_panel()
	if lp == null:
		_check("T5 LevelUpPanel 발견", false)
	else:
		Cheats.autoplay = false          # 자동 선택을 잠시 꺼 패널을 유지
		Events.bonus_level()
		await get_tree().process_frame
		var showing: bool = lp._showing
		Events.evolution_offer.emit()
		await get_tree().process_frame
		_check("T5 패널 중 진화 제안 대기열 적재", showing and int(lp._evo_queued) == 1)
		Cheats.autoplay = true
		await _wait(4.0)
		_check("T5 대기열 소진 후 정지 해제",
			not bool(lp._showing) and int(lp._evo_queued) == 0 and not get_tree().paused)

	# T6 — 장시간 자동플레이. 2초 이상 지속되는 정지는 곧 프리즈다.
	Engine.time_scale = SOAK_TIME_SCALE
	var stalls := 0
	var stall_t := 0.0
	var t := 0.0
	while t < SOAK_SECONDS:
		await _wait(0.25)
		t += 0.25
		var pl := get_tree().get_first_node_in_group("player")
		if pl != null:
			pl.health = 999   # 사망으로 인한 게임오버 정지는 이 테스트의 대상이 아니다
		if get_tree().paused:
			stall_t += 0.25
			if stall_t >= 2.0:
				stalls += 1
				stall_t = 0.0
				print("  STALL owners=%s level=%d elapsed=%.0f"
					% [str(Events.pause_owner_tags()), Events.level, Events.elapsed_time])
		else:
			stall_t = 0.0
	Engine.time_scale = 1.0
	_check("T6 자동플레이 %.0fs 중 정지 정체 없음 (level=%d elapsed=%.0f)"
		% [SOAK_SECONDS, Events.level, Events.elapsed_time], stalls == 0)

	print("RESULT ok=%d/%d" % [_ok, _total])
	await get_tree().process_frame
	get_tree().quit(0 if _ok == _total else 1)


func _find_levelup_panel() -> Node:
	for n in get_tree().root.get_children():
		var f: Node = _search(n)
		if f != null:
			return f
	return null


func _search(n: Node) -> Node:
	var sc: Variant = n.get_script()
	if sc != null and String(sc.resource_path).ends_with("LevelUpPanel.gd"):
		return n
	for c in n.get_children():
		var f: Node = _search(c)
		if f != null:
			return f
	return null
