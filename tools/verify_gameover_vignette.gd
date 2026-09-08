extends SceneTree
## 게임오버 배경 비네트 검증 (P2-25).
##   godot --headless --path . --script res://tools/verify_gameover_vignette.gd
## 종료 코드 = 실패 개수.
##
## 무엇을 지키는가: 비네트는 `gameover_blur.gdshader` 의 유니폼 두 개(`tint`·`tint_amount`)로
## 켜고, HUD 가 게임오버 때 값을 넣는다. 여기서 못박는 것은 **꺼진 상태가 기본**이라는 점이다 —
## 블러 재질은 한 번 만들어 계속 재사용하므로(부활 → 재사망), `_set_blur(false)` 가
## `tint_amount` 를 0 으로 되돌리지 않으면 **두 번째 게임오버가 이미 물든 화면에서 시작한다.**
## 그 증상은 부활을 한 번 거쳐야만 나와서 눈으로는 잘 안 걸린다.
##
## 색이 실제로 어떻게 보이는지는 헤드리스로 알 수 없다 — `tools/shot_hud_layers.gd` 로 픽셀을
## 본다(CLAUDE.md §3).

const _SHADER := "res://assets/shaders/gameover_blur.gdshader"
const _HUD := "res://scripts/HUD.gd"

var _fails := 0
var _done := false


func _ok(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("  FAIL %s%s" % [label, ("  — " + detail) if detail != "" else ""])


## 함수 하나의 본문을 줄 배열로 돌려준다(주석 줄은 뺀다). 다음 함수 정의에서 끊는다.
func _func_body(path: String, fname: String) -> Array:
	var out: Array = []
	var inside := false
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var t := String(line).strip_edges()
		var head := "func " + fname
		if t.begins_with(head):
			# 여는 괄호가 뒤따라야 정의 줄이다(_set_blur 가 _set_blurred 를 잡지 않게).
			# 40 = 여는 괄호의 코드포인트 — 짝 없는 괄호를 문자열에 넣으면
			# check_gdscript.py 의 괄호 짝 검사가 이 파일을 오탐한다.
			var rest := t.substr(head.length())
			if rest.length() > 0 and rest.unicode_at(0) == 40:
				inside = true
				continue
		if inside:
			if t.begins_with("func ") or t.begins_with("static func "):
				break
			if t == "" or t.begins_with("#"):
				continue
			out.append(t)
	return out


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	print("── 셰이더 ──────────────────────────────────────")
	# 리소스로 읽히면 파싱은 통과한 것이다(문법이 깨지면 여기서 null 이 된다).
	var sh: Shader = load(_SHADER)
	_ok("셰이더를 읽는다", sh != null)

	# 유니폼 목록은 **소스에서** 본다. 헤드리스는 더미 렌더러라
	# get_shader_uniform_list 가 빈 배열을 돌려줄 수 있어, 엔진에 물으면 이 검사가
	# 코드와 무관하게 깨지거나(거짓 실패) 늘 비어서 통과하거나(무의미) 둘 중 하나가 된다.
	var src := FileAccess.get_file_as_string(_SHADER)
	_ok("유니폼 tint", src.contains("uniform vec3 tint"))
	_ok("유니폼 tint_inner", src.contains("uniform float tint_inner"))
	_ok("유니폼 tint_outer", src.contains("uniform float tint_outer"))

	print("── 기본값은 '꺼짐' ──────────────────────────────")
	# 값을 넣지 않은 재질은 셰이더의 기본값을 쓴다. 여기가 0 이 아니면 블러가 보이는
	# 모든 순간(= 게임오버 패널이 떠 있는 내내) 화면이 물든 채로 시작한다.
	_ok("tint_amount 기본값이 0", src.contains("uniform float tint_amount = 0.0;"),
		"셰이더 소스에서 그 줄을 못 찾았다")

	print("── HUD 가 되돌리는가 ───────────────────────────")
	var set_blur := _func_body(_HUD, "_set_blur")
	_ok("_set_blur 를 찾았다", not set_blur.is_empty())
	var resets := false
	for t in set_blur:
		if String(t).contains("tint_amount"):
			resets = true
	_ok("_set_blur 가 tint_amount 를 되돌린다", resets,
		"부활 뒤 재사망이 이미 물든 화면에서 시작한다")

	var show_panel := _func_body(_HUD, "_show_end_panel")
	var plays := false
	for t in show_panel:
		if String(t).contains("_play_vignette"):
			plays = true
	_ok("_show_end_panel 이 _play_vignette 를 부른다", plays)

	print("── 승패 색이 실제로 다른가 ──────────────────────")
	var hud: GDScript = load(_HUD)
	var consts: Dictionary = hud.get_script_constant_map()
	for k in ["_VIGNETTE_DEFEAT", "_VIGNETTE_VICTORY", "_VIGNETTE_AMOUNT_DEFEAT",
			"_VIGNETTE_AMOUNT_VICTORY", "_VIGNETTE_INNER", "_VIGNETTE_OUTER"]:
		_ok("HUD 에 %s 가 있다" % k, consts.has(k))
	if consts.has("_VIGNETTE_DEFEAT") and consts.has("_VIGNETTE_VICTORY"):
		var d: Color = consts["_VIGNETTE_DEFEAT"]
		var v: Color = consts["_VIGNETTE_VICTORY"]
		# 색맹 여부와 무관하게 구분되도록 요구하지는 않는다(제목 글자·메달이 따로 말한다).
		# 다만 둘이 같아지면 이 기능 자체가 무의미해진다.
		_ok("패배/승리 색이 다르다", not d.is_equal_approx(v), "%s vs %s" % [d, v])
		_ok("패배는 붉은 쪽이 우세하다", d.r > d.g and d.r > d.b, str(d))
		_ok("승리는 초록이 파랑보다 우세하다(금색)", v.g > v.b, str(v))
	if consts.has("_VIGNETTE_INNER") and consts.has("_VIGNETTE_OUTER"):
		# 안쪽 경계가 바깥보다 크면 smoothstep 이 뒤집혀 화면 **가운데**가 물든다.
		_ok("inner < outer", float(consts["_VIGNETTE_INNER"]) < float(consts["_VIGNETTE_OUTER"]))
		# 게임오버 패널의 좌우 변은 중심에서 d=0.64 다. 안쪽 경계가 그보다 한참 안쪽이면
		# 패널 바로 옆까지 물들어 비네트가 아니라 "화면 전체가 붉다"가 된다.
		_ok("안쪽 경계가 패널 근처 바깥", float(consts["_VIGNETTE_INNER"]) >= 0.5,
			str(consts["_VIGNETTE_INNER"]))

	print("\n실패 %d건" % _fails)
	quit(_fails)
	return true
