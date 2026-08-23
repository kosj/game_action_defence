extends SceneTree
## 유도탄 명중률 회귀 검사 (P1-32).
##
## 왜 별도 하네스인가
## -----------------
## 조준 주기(`Bullet.STEER_EVERY`)를 늘리면 물리 틱은 확실히 내려간다. 문제는 그 대가를
## 재는 쪽이다 — **전체 판(`bench_lategame.gd`)에서는 명중률을 판정할 수 없다.**
##
## 실측으로 확인한 것:
##   · `kills_per_s` 는 전체 무기가 섞여 있고 런간 산포가 ±6 이라 유도탄 몫이 묻힌다.
##   · 유도탄만 세는 계측을 넣어도(`Bullet.stat_homing_*`) 같은 코드로 3번 재면
##     86.8 ~ 92.3% 로 5.5pp 흔들린다. 3pp 짜리 변화는 그 산포 안에서 판정이 안 된다.
##   · `seed=` 로 전역 RNG 를 고정해도 재현되지 않았다(87.7 vs 85.8%).
##     `--fixed-fps 60` 을 같이 줘도 마찬가지였다(87.8 vs 84.0%) — 전체 판에는
##     RNG 말고도 비결정 요소가 있다.
##
## 그래서 판 전체가 아니라 **조준 로직만 격리**해 잰다. 스포너·오토플레이·디렉터가 없으므로
## 남는 비결정 요소는 `on_spawn()` 의 `randi() % STEER_EVERY` 하나뿐이고, 그건 시드로 잠근다.
##
## 실행 (⚠️ `--fixed-fps 60` 필수):
##   godot --headless --path . --fixed-fps 60 --script res://tools/verify_homing_accuracy.gd
##
## 없이 돌리면 실시간 60Hz 로 물리 프레임을 기다려 **80초**가 걸린다(결과는 같다).
## 주면 언스로틀로 **1.2초**다 — 고정 delta 라 결정론도 그대로다.
##
## 종료 코드 0 = 통과. 명중률 절대값은 시나리오에 종속되므로 **바닥선만** 잠그고,
## 정확한 값은 출력으로 남긴다(조준을 건드릴 때 이 값을 전후로 대조할 것).
##
## 이 검사가 실제로 변별하는가 — 조준 주기를 쓸어 확인했다(2026-08-23):
##
##   STEER_EVERY  1     2     3     4     6     8     12    30    999
##   명중률       94.25 94.25 94.05 93.55 93.25 94.50 92.15 73.25 56.50  (%)
##
## 조준을 사실상 끄면(999) 56.5% 로 무너지므로 검사는 살아 있다. 반대로 1~12 구간은
## 평평하고 **8 이 3 보다 높다** — 즉 이 시나리오 자체의 구조적 흔들림이 약 ±1pp 다.
## 그 안의 차이(3→6 은 -0.8pp)는 "같다"로 읽어야 하며, 유의미한 회귀는 30 쯤부터다.

## ⚠️ 최상위 `preload` 를 쓰면 안 된다 — 이 스크립트는 **오토로드 등록 전에** 컴파일되므로
## Bullet.gd 안의 `Events` 참조가 미해결로 죽는다(`CLAUDE.md` §3 이 경고하는 함정).
## 씬도 오토로드도 전부 실행 시점에 `load()`/`get_node()` 로 늦게 가져온다.
var _bullet_scene: PackedScene = null
var _pool: Node = null

## 시나리오 설계 — **변별력이 있어야 한다.**
##
## 처음에는 실제 판처럼 60마리를 촘촘히 깔았는데 명중률이 100% 로 나왔다. 무리가 빽빽하면
## 유도가 없어도 맞기 때문이다 — 조준을 통째로 꺼도 통과하는 검사는 안전망이 아니다.
##
## 그래서 **유도탄이 실제로 빗나가는 기제**를 재현한다: 표적이 죽어 재탐색이 필요한 순간이다.
## 조준 주기가 길수록 그 공백 동안 탄이 직진하고, 그만큼 빗나간다. 후반 판은 초당 38킬이라
## 이 일이 끊임없이 일어난다 — 유도 성능의 실질은 "얼마나 빨리 다시 잡는가"다.
const TARGETS := 12           # 성기게 — 빽빽하면 유도 없이도 맞아 변별력이 사라진다
const WAVES := 40             # 표본 = WAVES × BULLETS_PER_WAVE
const BULLETS_PER_WAVE := 50
const FRAMES_PER_WAVE := 120  # 2초 — 탄 수명(1.5초)보다 길어 전부 소멸한다
const TARGET_SPEED := 90.0    # 좀비 이동 속도대(측면 이동 — 조준 지연이 가장 드러나는 축)
const BULLET_SPEED := 700.0
const KILL_EVERY := 7         # 이 프레임마다 표적 하나가 죽는다(재탐색 강제)
const REVIVE_AFTER := 14      # 죽은 표적이 다른 자리에서 되살아나기까지
const SEED := 20260823

## 실제 무기의 선회 속도(rad/s) — `data/item_catalog.tres` 에서 가져온 값이다.
## 느린 쪽(산탄총 1.6)이 조준 주기에 가장 민감하므로 반드시 섞는다.
const HOMING_RATES := [1.6, 3.0, 3.2, 3.4, 4.5, 5.0]

var _host: Node2D = null
var _targets: Array = []
var _dead_until: Array = []   # 표적별 부활 프레임(-1=살아 있음)
var _fail := 0


func _initialize() -> void:
	seed(SEED)
	_host = Node2D.new()
	root.add_child(_host)
	# `_resolve_hit` 이 피격 스파크를 `current_scene` 아래에 붙인다 — null 이면 죽는다.
	current_scene = _host
	for i in TARGETS:
		var t := Node2D.new()
		_host.add_child(t)
		t.add_to_group("zombies")
		_targets.append(t)
		_dead_until.append(-1)


## `_run()` 은 `await physics_frame` 으로 스스로를 굴리며 끝에서 `quit()` 한다.
## 여기서 true 를 돌려주면 그 전에 트리가 닫혀 아무 일도 일어나지 않는다 — false 로 둘 것.
var _started := false


func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	_bullet_scene = load("res://scenes/Bullet.tscn")
	_pool = root.get_node("Pool")
	var bs := load("res://scripts/Bullet.gd")
	var every: int = int(bs.STEER_EVERY)
	var gone0: int = int(bs.stat_homing_gone)
	var hit0: int = int(bs.stat_homing_hit)

	for w in WAVES:
		_place_targets(w)
		_fire_wave(w)
		for f in FRAMES_PER_WAVE:
			_step_targets(w * FRAMES_PER_WAVE + f)
			await physics_frame

	var gone: int = int(bs.stat_homing_gone) - gone0
	var hit: int = int(bs.stat_homing_hit) - hit0
	var rate := float(hit) / maxf(float(gone), 1.0)

	print("")
	print("── 유도탄 명중률 (STEER_EVERY=%d · 시드 고정) ──────────" % every)
	print("  표적 %d · 발사 %d발 · 소멸 %d발 · 명중 %d발" % [TARGETS, WAVES * BULLETS_PER_WAVE, gone, hit])
	print("  명중률 %.2f%%" % (rate * 100.0))
	print("")
	print("HOMING %s" % JSON.stringify({
		"steer_every": every, "gone": gone, "hit": hit,
		"rate": snappedf(rate, 0.0001),
	}))

	# 소멸 수가 발사 수와 크게 다르면 시나리오가 깨진 것이다(수명 안에 안 끝났거나 풀이 샜다).
	_check("발사한 탄이 전부 회수됐다", gone >= WAVES * BULLETS_PER_WAVE - 2,
		"소멸 %d < 발사 %d — 시나리오가 짧거나 탄이 남았다" % [gone, WAVES * BULLETS_PER_WAVE])
	# 바닥선만 잠근다. 절대값은 시나리오에 종속돼 의미가 없고, 조준이 통째로 깨지면 여기서 걸린다.
	_check("명중률이 바닥선(50%) 위다", rate >= 0.50,
		"명중률 %.2f%% — 유도 조준이 사실상 동작하지 않는다" % (rate * 100.0))

	if _fail > 0:
		print("❌ 유도탄 명중률 검사 실패 %d건" % _fail)
		quit(1)
	else:
		print("유도탄 명중률 검사 통과")
		quit(0)


## 표적 배치 — 원점 앞쪽 250~500px 에 성기게 깐다. 파도마다 결정론적으로 어긋나게 해
## 한 배치에만 맞는 값이 나오는 것을 막는다(RNG 를 쓰지 않는다 — 인덱스로만 만든다).
func _place_targets(wave: int) -> void:
	for i in _targets.size():
		var jitter := float((i * 37 + wave * 53) % 71) - 35.0
		var t: Node2D = _targets[i]
		t.global_position = Vector2(
			-260.0 + float(i) * 47.0 + jitter * 0.8,
			250.0 + float((i * 29 + wave * 17) % 250))
		if not t.is_in_group("zombies"):
			t.add_to_group("zombies")
		_dead_until[i] = -1


## 표적은 **측면으로** 걷는다. 원점 쪽으로만 오면 탄과 같은 축이라 조준 지연이 상쇄된다 —
## 각도가 변해야 조준을 다시 하는 것의 값어치가 드러난다.
## 동시에 주기적으로 하나씩 "죽여" 재탐색을 강제한다(후반 판은 초당 38킬이다).
func _step_targets(frame: int) -> void:
	var dt := 1.0 / 60.0
	var lateral := Vector2.RIGHT
	for i in _targets.size():
		var n: Node2D = _targets[i]
		if int(_dead_until[i]) >= 0:
			if frame >= int(_dead_until[i]):
				# 다른 자리에서 되살아난다 — 죽은 표적을 쫓던 탄은 새로 잡아야 한다.
				n.global_position = Vector2(
					-260.0 + float((i * 61 + frame * 13) % 520),
					250.0 + float((i * 43 + frame * 7) % 250))
				n.add_to_group("zombies")
				_dead_until[i] = -1
			continue
		var dir := lateral if (i % 2 == 0) else -lateral
		n.global_position += dir * TARGET_SPEED * dt

	if frame % KILL_EVERY == 0:
		var victim := (frame / KILL_EVERY) % _targets.size()
		var v: Node2D = _targets[victim]
		if v.is_in_group("zombies"):
			v.remove_from_group("zombies")   # 풀 반납된 좀비와 같은 상태(인스턴스는 유효)
			_dead_until[victim] = frame + REVIVE_AFTER


## 원점에서 표적 무리 쪽으로 부채꼴로 쏜다. 각도를 벌려 놔야 유도가 실제로 일을 한다 —
## 정면으로만 쏘면 유도 없이도 맞아서 조준 주기의 차이가 안 보인다.
func _fire_wave(wave: int) -> void:
	for i in BULLETS_PER_WAVE:
		var spread := deg_to_rad(-30.0 + 60.0 * float(i) / float(BULLETS_PER_WAVE - 1))
		var dir := Vector2.DOWN.rotated(spread)
		var b = _pool.acquire(_bullet_scene, _host)
		b.global_position = Vector2.ZERO
		b.direction = dir
		b.rotation = dir.angle() + PI / 2.0
		b.speed = BULLET_SPEED
		b.damage = 1
		b.lifetime = 1.5
		b.homing = HOMING_RATES[(i + wave) % HOMING_RATES.size()]
		b.homing_arc = PI / 4.0
		b.pierce = 0
		b.splash_radius = 0.0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fail += 1
		print("  FAIL %s%s" % [label, ("  — " + detail) if detail != "" else ""])
