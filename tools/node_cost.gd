extends SceneTree
## 노드 방식 vs 비(非)노드(SoA) 방식의 실제 부하 차이 (P1-22).
##
## 왜 있나 — "개체가 수백 개면 노드를 버리고 SoA + MultiMesh 로 가야 하나"는 이 프로젝트에서
## 주기적으로 다시 올라오는 질문이다. 매번 감으로 답하지 말고 여기서 재라. 값은
## `OPTIMIZATION_PLAN.md` §5-M 에 정리돼 있다.
##
##   godot --headless --path . --script res://tools/node_cost.gd -- mode=node_move n=600
##   # 렌더 비교는 실렌더가 필요하다(헤드리스는 드로우 콜이 0 이다)
##   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 720x1280x24" \
##     godot --path . --rendering-driver opengl3 --script res://tools/node_cost.gd -- mode=sprite n=600
##
## mode=
##   bare              기준선(아무것도 안 만든다)
##   node_idle         Node2D N개 — 스크립트 없음. "존재" 비용
##   node_empty        Node2D N개 + 빈 _physics_process. **콜백 호출 자체의 값**
##   node_move         Node2D N개가 각자 이동. 노드 방식의 실제 모습
##   node_move_overlap 위와 같되 촘촘히 겹쳐 놓는다(Area2D 와 짝을 맞추기 위한 대조군)
##   soa               노드 1개 + PackedVector2Array N개를 루프 1번으로 이동. 비노드 방식
##   area_idle         Area2D + 도형 N개, 정지
##   body_idle         CharacterBody2D + 도형 N개, 정지
##   area_move         Area2D + 도형 N개가 각자 이동. 브로드페이즈가 실제로 도는 경우
##   area_overlap      위와 같되 심하게 겹친다(충돌쌍 폭증)
##   sprite            Sprite2D N개(같은 텍스처) — 드로우 콜 배칭 확인용
##   multimesh         MultiMeshInstance2D 1개에 N 인스턴스
##
## ⚠️ 이 환경에는 GPU 가 없다(소프트웨어 GL). 그래서 렌더 모드의 `frame_med` 는 CPU 래스터화
## 비용이 지배해서 **캔버스 아이템 순회 비용을 가르지 못한다.** 렌더 쪽에서 믿을 것은
## `draws_med`(드로우 콜)뿐이고, 그건 기기와 무관한 값이다.
##
## 물리 틱 1회의 비용은 우선순위 센티넬 두 개로 직접 잰다(Performance 모니터는 최근 1초의
## **최댓값**이라 평상시 비용이 아니다 — §5-L 결함 ③).

class TickProbe extends Node:
	var t_usec: int = 0
	var sink = null
	var start_probe: TickProbe = null
	func _physics_process(_d: float) -> void:
		t_usec = Time.get_ticks_usec()
		if sink != null and start_probe != null:
			sink.append(float(t_usec - start_probe.t_usec) / 1000.0)


## 노드 1개 = 콜백 1번. 엔진이 개체마다 _physics_process 를 부른다.
class MoverNode extends Node2D:
	var vel: Vector2 = Vector2.ZERO
	func _physics_process(d: float) -> void:
		position += vel * d


## 스크립트는 붙었지만 아무것도 안 한다 — 콜백 호출 자체의 값.
class EmptyNode extends Node2D:
	func _physics_process(_d: float) -> void:
		pass


## 움직이는 Area2D — 물리 서버 브로드페이즈가 매 틱 갱신된다(가만히 있으면 비용이 안 난다).
class MoverArea extends Area2D:
	var vel: Vector2 = Vector2.ZERO
	func _physics_process(d: float) -> void:
		position += vel * d


## 개체 600개를 평면 배열에 담고 콜백 1번으로 전부 처리한다(SoA).
class SoaHost extends Node:
	var pos: PackedVector2Array = PackedVector2Array()
	var vel: PackedVector2Array = PackedVector2Array()
	func _physics_process(d: float) -> void:
		for i in pos.size():
			pos[i] = pos[i] + vel[i] * d


var _tick_ms: Array = []
var _frames: int = 0
var _limit: int = 400
var _warm: int = 60
var _mode: String = "bare"
var _n: int = 600
var _tail: TickProbe = null
var _frame_ms: Array = []
var _draws: Array = []
var _prev_us: int = 0


## 렌더 비교용 텍스처 — 프로젝트 에셋에 의존하지 않게 런타임에 만든다.
func _make_tex() -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 0.4, 0.2, 1.0))
	return ImageTexture.create_from_image(img)


func _init() -> void:
	var a: Dictionary = {}
	for s in OS.get_cmdline_user_args():
		var kv := String(s).split("=")
		if kv.size() == 2:
			a[kv[0]] = kv[1]
	_mode = String(a.get("mode", "bare"))
	_n = int(a.get("n", "600"))
	_limit = int(a.get("frames", "400"))
	await process_frame
	# vsync 가 켜져 있으면 프레임이 16.67ms 로 고정돼 CPU 몫이 안 보인다.
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_build()
	var head := TickProbe.new()
	head.process_physics_priority = -10000
	root.add_child(head)
	var tail := TickProbe.new()
	tail.process_physics_priority = 10000
	tail.start_probe = head
	tail.sink = _tick_ms
	root.add_child(tail)
	_tail = tail
	_prev_us = Time.get_ticks_usec()
	while _frames < _warm + _limit:
		await process_frame
		var now := Time.get_ticks_usec()
		if _frames >= _warm:
			_frame_ms.append(float(now - _prev_us) / 1000.0)
			_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_prev_us = now
		_frames += 1
		if _frames == _warm:
			_tick_ms.clear()
	_report()


func _build() -> void:
	var host := Node2D.new()
	root.add_child(host)
	match _mode:
		"bare":
			pass
		"node_idle":
			for i in _n:
				var z := Node2D.new()
				z.position = Vector2(float(i % 40) * 20.0, float(i / 40) * 20.0)
				host.add_child(z)
		"node_empty":
			for i in _n:
				var z := EmptyNode.new()
				z.position = Vector2(float(i % 40) * 20.0, float(i / 40) * 20.0)
				host.add_child(z)
		"node_move":
			for i in _n:
				var z := MoverNode.new()
				z.position = Vector2(float(i % 40) * 20.0, float(i / 40) * 20.0)
				z.vel = Vector2(cos(float(i)), sin(float(i))) * 30.0
				host.add_child(z)
		"soa":
			var h := SoaHost.new()
			for i in _n:
				h.pos.append(Vector2(float(i % 40) * 20.0, float(i / 40) * 20.0))
				h.vel.append(Vector2(cos(float(i)), sin(float(i))) * 30.0)
			host.add_child(h)
		"area_move", "area_overlap":
			var gap: float = 20.0 if _mode == "area_move" else 4.0
			for i in _n:
				var ar3 := MoverArea.new()
				ar3.position = Vector2(float(i % 40) * gap, float(i / 40) * gap)
				ar3.vel = Vector2(cos(float(i)), sin(float(i))) * 30.0
				var cs3 := CollisionShape2D.new()
				var ci3 := CircleShape2D.new()
				ci3.radius = 8.0
				cs3.shape = ci3
				ar3.add_child(cs3)
				host.add_child(ar3)
		"node_move_overlap":
			for i in _n:
				var z4 := MoverNode.new()
				z4.position = Vector2(float(i % 40) * 4.0, float(i / 40) * 4.0)
				z4.vel = Vector2(cos(float(i)), sin(float(i))) * 30.0
				host.add_child(z4)
		"sprite":
			var tex := _make_tex()
			for i in _n:
				var sp := Sprite2D.new()
				sp.texture = tex
				sp.position = Vector2(60.0 + float(i % 30) * 22.0, 60.0 + float(i / 30) * 22.0)
				host.add_child(sp)
		"multimesh":
			var tex2 := _make_tex()
			var qm := QuadMesh.new()
			qm.size = Vector2(16, 16)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_2D
			mm.mesh = qm
			mm.instance_count = _n
			for i in _n:
				mm.set_instance_transform_2d(i, Transform2D(0.0,
					Vector2(60.0 + float(i % 30) * 22.0, 60.0 + float(i / 30) * 22.0)))
			var mmi := MultiMeshInstance2D.new()
			mmi.multimesh = mm
			mmi.texture = tex2
			host.add_child(mmi)
		"area_idle":
			for i in _n:
				var ar := Area2D.new()
				ar.position = Vector2(float(i % 40) * 20.0, float(i / 40) * 20.0)
				var cs := CollisionShape2D.new()
				var ci := CircleShape2D.new()
				ci.radius = 8.0
				cs.shape = ci
				ar.add_child(cs)
				host.add_child(ar)
		"body_idle":
			for i in _n:
				var b := CharacterBody2D.new()
				b.position = Vector2(float(i % 40) * 20.0, float(i / 40) * 20.0)
				var cs2 := CollisionShape2D.new()
				var ci2 := CircleShape2D.new()
				ci2.radius = 8.0
				cs2.shape = ci2
				b.add_child(cs2)
				host.add_child(b)


func _stat(v: Array) -> Dictionary:
	if v.is_empty():
		return {"med": 0.0, "p95": 0.0}
	var s := v.duplicate()
	s.sort()
	return {"med": s[s.size() / 2], "p95": s[int(float(s.size()) * 0.95)]}


func _report() -> void:
	var t := _stat(_tick_ms)
	var f := _stat(_frame_ms)
	var dr := _stat(_draws)
	print("NODECOST mode=%s n=%d tick_med=%.4f tick_p95=%.4f frame_med=%.4f draws_med=%d pairs=%d nodes=%d samples=%d" % [
		_mode, _n, t["med"], t["p95"], f["med"], int(dr["med"]),
		int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), _tick_ms.size()])
	quit(0)
