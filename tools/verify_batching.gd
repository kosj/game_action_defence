extends SceneTree
## 캔버스 배칭 회귀 검사 (CI 스텝).
##
## 배경: Godot 의 2D 배처는 연속해서 그리는 아이템이 **같은 텍스처 · 같은 머티리얼 ·
## 같은 modulate** 일 때만 하나로 묶는다. 아틀라스로 텍스처는 통일했지만, 한 유닛 안에서
## 그림자와 몸통의 modulate 가 다르면 그것만으로 아이템마다 배치가 끊긴다.
##
## 실제로 그랬다 — Zombie.tscn 의 Shadow 에 modulate = Color(1,1,1,0.5) 가 걸려 있어
## 좀비마다 그림자(a0.5) -> 몸통(흰색)이 번갈아 나왔다. 좀비 320마리 실측에서
## **드로우 콜 152 -> 39** (아이템 수는 188 로 동일). 알파를 shadow_soft.png 에 구워
## modulate 를 없애 고쳤다.
##
## 같은 계열의 두 번째 결함은 **한 CanvasItem 안**에 있었다. 같은 아이템 안에서는 명령별
## 색이 배칭을 깨지 않지만(색은 정점 데이터다) **프리미티브 종류가 다르면 끊긴다** —
## draw_circle / draw_line / draw_arc / draw_polygon 은 텍스처 쿼드와 섞이지 않는다.
## Ground._draw_decals 가 draw_circle 42 + draw_line 45 를 발행해 Ground 격리 드로우 콜이
## 93이었다. 같은 그림을 쿼드로만 바꾸니 43 이 됐다(외형은 최대 21/255 차이 = 테두리 AA).
##
## 이 검사가 막는 것:
##  1. 개체가 수백인 씬(좀비)에서 스프라이트끼리 modulate 나 텍스처가 어긋나는 것
##  2. 매 프레임 그려지는 _draw() 에서 프리미티브를 **루프로** 발행하는 것
## 둘 다 눈으로는 안 보이고 프레임만 깎이는 종류라 안전망이 필요하다.
##
##   godot --headless --script res://tools/verify_batching.gd
##
## 프레임 부하를 실제로 재려면 tools/profile_frame.gd (실렌더 프로파일러)를 쓴다.

## 개체가 수백 단위로 뜨는 씬 — 여기서 배칭이 깨지면 드로우 콜이 개체 수에 비례해 늘어난다.
const HOT_SCENES := ["res://scenes/Zombie.tscn"]

## 매 프레임 그려지는 _draw() 를 가진 스크립트 — 여기서 프리미티브를 루프로 발행하면
## 화면에 보이는 개수만큼 드로우 콜이 늘어난다.
## 매 프레임 그려지는 _draw() 를 가진 스크립트. 무기 비주얼은 실측에서 가장 컸다 —
## 오브 +121 · 테슬라 +112 · 마늘 +91(OPTIMIZATION_PLAN.md 5-H). 전부 프리미티브를
## 루프로 발행하던 것이고 QuadDraw(텍스처 쿼드)로 바꿨다.
## **여기 있는 파일만 검사한다.** 아직 프리미티브로 그리는 곳이 남아 있어(아래 목록)
## 전부 넣으면 CI 가 빨개진다 — 고친 파일을 하나씩 옮겨 오는 방식으로 조인다.
const HOT_DRAW := [
	"res://scripts/Ground.gd", "res://scripts/PropField.gd",
	"res://scripts/Orb.gd", "res://scripts/Tesla.gd", "res://scripts/GarlicAura.gd",
	"res://scripts/FXBurst.gd",
]
## 아직 안 고친 것 — 고칠 때마다 위로 옮긴다(OPTIMIZATION_PLAN.md 5-H).
##   FXLightning.gd · Ultimate.gd · TeslaCoil.gd · FlySwarm.gd · BossArena.gd
## 전부 QuadDraw 로 바꾸면 되고, 바꾼 뒤 HOT_DRAW 에 넣으면 회귀가 막힌다.
## 쿼드와 배칭되지 않는 그리기 명령.
const PRIMITIVES := ["draw_circle", "draw_line", "draw_arc", "draw_polygon",
	"draw_colored_polygon", "draw_multiline", "draw_rect"]
const EXEMPT := "batching-exempt:"

var _fails: Array = []


func _initialize() -> void:
	for path in HOT_SCENES:
		_check(path)
	for path in HOT_DRAW:
		_check_primitives(path)
	if _fails.is_empty():
		print("[BATCH] 검사 통과 (핫 씬의 스프라이트 modulate·아틀라스 일치)")
		quit(0)
		return
	for f in _fails:
		print("[BATCH] 실패: " + f)
	print("[BATCH] 알파는 modulate 대신 텍스처에, 반복 그리기는 텍스처 쿼드로 —")
	print("[BATCH] 자세한 근거는 tools/verify_batching.gd 주석과 ASSET_PIPELINE.md 1절 참고.")
	quit(1)


func _check(path: String) -> void:
	var ps: PackedScene = load(path)
	if ps == null:
		_fails.append("%s 로드 실패" % path)
		return
	var inst := ps.instantiate()
	var sprites: Array = []
	_collect(inst, sprites)
	if sprites.size() < 2:
		inst.free()
		return

	var atlases := {}
	for s in sprites:
		# ① modulate 가 스프라이트마다 다르면 그 경계에서 배치가 끊긴다.
		if s.modulate != Color.WHITE:
			_fails.append("%s: %s 의 modulate 가 %s — 알파는 텍스처에 구울 것"
				% [path, s.name, str(s.modulate)])
		if s.self_modulate != Color.WHITE:
			_fails.append("%s: %s 의 self_modulate 가 %s — 알파는 텍스처에 구울 것"
				% [path, s.name, str(s.self_modulate)])
		# ② 같은 아틀라스여야 텍스처 교체가 안 생긴다.
		if s.texture is AtlasTexture:
			atlases[(s.texture as AtlasTexture).atlas.resource_path] = true
		elif s.texture != null:
			_fails.append("%s: %s 가 아틀라스 밖 텍스처(%s)"
				% [path, s.name, s.texture.resource_path])
	if atlases.size() > 1:
		_fails.append("%s: 스프라이트가 서로 다른 아틀라스를 씀 %s"
			% [path, str(atlases.keys())])
	inst.free()


## _draw() 안에서 프리미티브를 **루프 안에서** 발행하는지 본다. 루프 밖의 한두 개 고정
## 발행은 드로우 콜이 늘지 않으니 통과시킨다 — 개수에 비례해 늘어나는 것만 잡는다.
##
## 예외: `# batching-exempt: <이유>` 를 함수 선언 위 주석이나 해당 줄에 두면 넘어간다.
## 도달 불가한 폴백처럼 핫패스가 아닌 것을 위한 장치다 — **파일 통째 예외는 두지 않는다.**
## 이유를 코드 옆에 남기게 해야 새로 들어오는 위반이 계속 잡힌다.
func _check_primitives(path: String) -> void:
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		_fails.append("%s 를 열 수 없음" % path)
		return
	var lines := fa.get_as_text().split("\n")
	var loop_indent := -1
	var func_exempt := false
	var pending_exempt := false      # 직전 주석 줄에 표시가 있었나
	for i in lines.size():
		var raw: String = lines[i]
		var s := raw.strip_edges()
		if s.begins_with("#"):
			if s.contains(EXEMPT):
				pending_exempt = true
			continue
		if s == "":
			continue
		if s.begins_with("func "):
			# 함수 단위 예외: 선언 줄 자체나 바로 위 주석 블록에 표시가 있으면 그 함수 전체를 넘긴다.
			func_exempt = pending_exempt or s.contains(EXEMPT)
			loop_indent = -1
			pending_exempt = false
			continue
		var line_exempt: bool = pending_exempt or s.contains(EXEMPT)
		pending_exempt = false
		var indent := raw.length() - raw.lstrip("\t").length()
		if loop_indent >= 0 and indent <= loop_indent:
			loop_indent = -1                       # 루프를 빠져나왔다
		if s.begins_with("for ") or s.begins_with("while "):
			if loop_indent < 0:
				loop_indent = indent
			continue
		if loop_indent < 0 or func_exempt or line_exempt:
			continue
		for prim in PRIMITIVES:
			if s.contains(prim + "("):
				_fails.append("%s:%d 루프 안에서 %s() — 텍스처 쿼드(draw_texture_rect)로 바꿀 것"
					% [path, i + 1, prim])
				break


func _collect(n: Node, out: Array) -> void:
	if n is Sprite2D:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)
