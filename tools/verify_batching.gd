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
## 이 검사가 막는 것: 개체가 수백인 씬(좀비)에서 스프라이트끼리 modulate 나 텍스처가
## 어긋나는 것. 눈으로는 안 보이고 프레임만 깎이는 종류라 안전망이 필요하다.
##
##   godot --headless --script res://tools/verify_batching.gd
##
## 프레임 부하를 실제로 재려면 tools/profile_frame.gd (실렌더 프로파일러)를 쓴다.

## 개체가 수백 단위로 뜨는 씬 — 여기서 배칭이 깨지면 드로우 콜이 개체 수에 비례해 늘어난다.
const HOT_SCENES := ["res://scenes/Zombie.tscn"]

var _fails: Array = []


func _initialize() -> void:
	for path in HOT_SCENES:
		_check(path)
	if _fails.is_empty():
		print("[BATCH] 검사 통과 (핫 씬의 스프라이트 modulate·아틀라스 일치)")
		quit(0)
		return
	for f in _fails:
		print("[BATCH] 실패: " + f)
	print("[BATCH] 알파는 modulate 대신 텍스처에 구울 것 — tools/verify_batching.gd 주석 참고.")
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


func _collect(n: Node, out: Array) -> void:
	if n is Sprite2D:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)
