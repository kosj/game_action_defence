@tool
extends SceneTree
## 데미지 숫자용 비트맵 숫자(0~9)를 굽는다.
##
## 왜
##   `draw_string` 은 폰트 글리프 아틀라스를 쓰는데 이건 게임플레이 시트와 별개 텍스처라
##   숫자 하나마다 배치가 끊긴다. 동시 36개 × (아웃라인 + 본문) = 실측 드로우 콜 49개였다.
##   숫자를 게임플레이 아틀라스에 구워 두면 쿼드가 되어 좀비·이펙트와 한 배치로 묶인다.
##
## 어떻게
##   **검은 아웃라인 + 흰 글리프**를 한 장에 굽는다. 쓰는 쪽에서 색을 틴트로 곱하면
##   아웃라인은 검정 그대로(0 × c = 0), 글리프만 색이 된다 — 텍스처 한 장으로 둘 다 된다.
##   글리프 모양이 원본과 같아야 하므로 PIL 이 아니라 **Godot 이 직접 렌더**한다.
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 \
##       --script res://tools/gen_damage_digits.gd
##
##   ⚠️ `--headless` 로는 안 된다. 헤드리스는 더미 렌더러라 SubViewport 텍스처가 비어 있고
##   `get_image()` 가 null 을 돌려준다(조용히 실패하지 않고 아래에서 막는다).
##
## 굽는 크기는 화면 표시의 2배(고DPI 여유 — ASSET_PIPELINE.md). 아웃라인 두께는 원본이
## 크기와 무관하게 5px 고정이라 텍스처로는 완전 재현이 안 된다 — 기본 크기(24pt)에서
## 정확히 5px 가 되도록 굽고, 팝·크리티컬에서는 함께 두꺼워진다(의도된 근사).
##
## 자르기는 **10장 공통 사각형**으로 한다. 장마다 따로 자르면 글자마다 세로 위치가
## 어긋나 숫자열이 출렁인다. 폰트 전체 높이(ascent+descent)를 그대로 두면 아틀라스에서
## 세로 절반 이상이 빈칸이라(55x98 중 실제 30x43), 공통 사각형이 둘 다 해결한다.
## 이 스크립트가 출력하는 GLYPH_* 상수를 `scripts/DamageNumber.gd` 에 그대로 옮긴다.

const FONT_PATH := "res://assets/fonts/NotoSansCJK-Subset.otf"
const BASE := 24          # DamageNumber.BASE_FONT_SIZE
const SS := 3             # 고DPI 여유 — 크리티컬 팝 최대 배율(34×1.7 ÷ 24 = 2.41배)까지 확대 없이 커버
const SIZE := BASE * SS
const OUTLINE := 5 * SS
const PAD := 4            # 아틀라스 패딩과 별개로 글리프 주변 여백
const OUT_DIR := "res://assets/sprites/"


func _initialize() -> void:
	var font: Font = load(FONT_PATH)
	if font == null:
		print("[DIGIT] 폰트를 못 읽었습니다: ", FONT_PATH)
		quit(1)
		return
	var ascent := font.get_ascent(SIZE)
	var descent := font.get_descent(SIZE)
	var h := int(ceil(ascent + descent)) + (OUTLINE + PAD) * 2
	var origin := Vector2(OUTLINE + PAD, OUTLINE + PAD + ascent)

	var imgs: Array[Image] = []
	var advances := PackedFloat32Array()
	for d in 10:
		var s := str(d)
		var adv := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
		# 전진폭은 **표시 크기(BASE)에서 직접** 잰다. SIZE 에서 재고 SS 로 나누면 힌팅 반올림
		# 때문에 원본(`get_string_size(txt, .., 24)`)과 미세하게 어긋나 글자열 폭이 달라진다.
		advances.append(font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, BASE).x)
		var w := int(ceil(adv)) + (OUTLINE + PAD) * 2
		# Godot 은 Image 에 직접 문자열을 못 그리므로 CanvasItem 을 뷰포트에 그려 캡처한다.
		var vp := SubViewport.new()
		vp.size = Vector2i(w, h)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var node := _Glyph.new()
		node.font = font
		node.text = s
		node.origin = origin
		vp.add_child(node)
		root.add_child(vp)
		await process_frame
		await process_frame
		var cap := vp.get_texture().get_image()
		if cap == null:
			print("[DIGIT] 뷰포트 캡처 실패 — 실제 GL 컨텍스트가 필요합니다(--headless 불가).")
			quit(1)
			return
		imgs.append(cap)
		vp.queue_free()

	# 10장 공통 사각형 = 각 장 알파 bbox 의 합집합(1px 여유).
	var box := Rect2i()
	for img in imgs:
		var b := img.get_used_rect()
		box = b if box.size == Vector2i.ZERO else box.merge(b)
	box = box.grow(1)
	box = box.intersection(Rect2i(Vector2i.ZERO, imgs[0].get_size()))

	for d in 10:
		var cut := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
		cut.fill(Color(0, 0, 0, 0))
		cut.blit_rect(imgs[d], box, Vector2i.ZERO)
		var path := OUT_DIR + "dmg_%d.png" % d
		if cut.save_png(ProjectSettings.globalize_path(path)) != OK:
			cut.save_png(path)

	# 표시(1배) 좌표계 기준 — 펜 위치에서 쿼드 좌상단까지의 오프셋과 쿼드 크기.
	var off := (Vector2(box.position) - origin) / float(SS)
	var qsz := Vector2(box.size) / float(SS)
	print("[DIGIT] 잘라낸 공통 사각형 = ", box, "  (원본 %dx%d)" % [imgs[0].get_width(), h])
	print("[DIGIT] --- scripts/DamageNumber.gd 에 옮길 상수 ---")
	print("const GLYPH_ADVANCE := %.4f" % advances[0])
	print("const GLYPH_OFFSET := Vector2(%.4f, %.4f)" % [off.x, off.y])
	print("const GLYPH_SIZE := Vector2(%.4f, %.4f)" % [qsz.x, qsz.y])
	print("[DIGIT] 전진폭(표시 1배 기준) = ", advances)
	print("[DIGIT] 완료 — python3 tools/build_atlas.py 로 아틀라스에 반영하세요")
	quit(0)


class _Glyph extends Node2D:
	var font: Font
	var text: String
	var origin: Vector2

	func _draw() -> void:
		draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			SIZE, OUTLINE, Color(0, 0, 0, 1))
		draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			SIZE, Color(1, 1, 1, 1))
