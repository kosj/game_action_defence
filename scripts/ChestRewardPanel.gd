extends CanvasLayer
## 보물상자 보상 리빌 — 상자를 열면 게임을 멈추고 등급(일반/고급/희귀/전설)별 연출과 함께
## 무엇을 받았는지 보여준다. 탭(또는 자동)으로 닫히면 그때 보상을 실제 적용하고 게임을 재개한다.
## 보상을 "닫힌 뒤" 적용하는 이유: 무료 레벨업 등은 LevelUpPanel(자체 일시정지)을 띄우므로
## 두 패널의 일시정지가 겹치지 않게 순서를 보장한다.
##
## 사용:  ChestRewardPanel.open(get_tree().current_scene)  ← ItemPickup 이 호출
## 폰트 주의: 서브셋 폰트에 장식 글리프(★ 등)가 없으므로 표시는 전부 ASCII 로 구성한다.

const _UIStyle := preload("res://scripts/UIStyle.gd")

## 등급 정의 — 확률 가중치(행운 패시브가 상위 등급을 끌어올린다)와 연출 파라미터.
const _RARITY := [
	{"key": "common",    "title": "COMMON",        "col": Color(0.80, 0.84, 0.90), "flash": 0.0,  "shake": 0.0, "spark": 14, "hold": 1.6, "build": 0.7, "count": 1},
	{"key": "rare",      "title": "RARE !",        "col": Color(0.35, 0.65, 1.00), "flash": 0.25, "shake": 3.0, "spark": 26, "hold": 2.0, "build": 1.0, "count": 2},
	{"key": "epic",      "title": "EPIC !!",       "col": Color(0.75, 0.45, 1.00), "flash": 0.5,  "shake": 6.0, "spark": 44, "hold": 2.4, "build": 1.4, "count": 3},
	{"key": "legendary", "title": "LEGENDARY !!!", "col": Color(1.00, 0.82, 0.25), "flash": 0.85, "shake": 10.0, "spark": 70, "hold": 3.0, "build": 1.9, "count": 4},
]

static var _open_now: bool = false   # 동시 개봉 가드 — 이미 열려 있으면 연출 없이 즉시 지급

var _did_pause: bool = false
var _closed: bool = false
var _applies: Array = []        # 닫힐 때 실행할 보상 적용(등급이 높을수록 여러 개)
var _panel: PanelContainer
var _auto_left: float = 0.0


## 진입점 — 등급/보상을 추첨하고 리빌 패널을 띄운다.
static func open(parent: Node) -> void:
	var reward := _roll()
	if _open_now:
		for a in reward["applies"]:   # 겹침(연속 개봉) — 연출 생략하고 보상만 지급
			a.call()
		return
	var p = (load("res://scripts/ChestRewardPanel.gd") as GDScript).new()
	p._setup(reward)
	parent.add_child(p)


## ── 추첨 ──────────────────────────────────────────────────────────────
## 등급 → 등급 내 보상 종류 → 수치(경과 시간 스케일). 반환: {rarity(int), text, apply(Callable)}.
static func _roll() -> Dictionary:
	# 행운(rabbits_foot) 레벨이 상위 등급 확률을 키운다.
	var luck := int(Events.passives.get("rabbits_foot", 0))
	var w_leg := 2.0 + 1.0 * luck
	var w_epic := 11.0 + 2.0 * luck
	var w_rare := 27.0 + 3.0 * luck
	var w_common := maxf(10.0, 100.0 - w_leg - w_epic - w_rare)
	var roll := randf() * (w_leg + w_epic + w_rare + w_common)
	var rarity := 0
	if roll < w_leg: rarity = 3
	elif roll < w_leg + w_epic: rarity = 2
	elif roll < w_leg + w_epic + w_rare: rarity = 1

	# 골드는 경과 시간에 따라 증가(후반 상자가 더 달다).
	var gscale := 1.0 + (Events.elapsed_time / 60.0) * 0.10
	# 등급이 높을수록 보상 개수가 많다(1/2/3/4). 첫 보상은 해당 등급 풀에서,
	# 나머지 보너스는 하위 등급(일반 60%/고급 40%) 풀에서 추가로 뽑는다.
	var count := int(_RARITY[rarity]["count"])
	var texts: Array = []
	var applies: Array = []
	var main := _roll_tier(rarity, gscale)
	texts.append(main["text"])
	applies.append(main["apply"])
	for i in range(count - 1):
		var extra := _roll_tier(1 if randf() < 0.4 else 0, gscale)
		texts.append(extra["text"])
		applies.append(extra["apply"])
	return {"rarity": rarity, "texts": texts, "applies": applies}


static func _roll_tier(t: int, gs: float) -> Dictionary:
	match t:
		3: return _roll_legendary(gs)
		2: return _roll_epic(gs)
		1: return _roll_rare(gs)
		_: return _roll_common(gs)


static func _roll_common(gs: float) -> Dictionary:
	if randf() < 0.6:
		var g := int(randi_range(15, 35) * gs)
		return {"rarity": 0, "text": "+%d Gold" % g, "apply": func(): Events.add_gold(g)}
	var xp := maxi(5, int(Events.xp_to_next * 0.3))
	return {"rarity": 0, "text": "+%d XP" % xp, "apply": func(): Events.add_xp(xp)}


static func _roll_rare(gs: float) -> Dictionary:
	var r := randi() % 3
	if r == 0:
		var g := int(randi_range(50, 90) * gs)
		return {"rarity": 1, "text": "+%d Gold" % g, "apply": func(): Events.add_gold(g)}
	if r == 1:
		var pick := _random_grantable_item()
		if not pick.is_empty():
			var id: String = pick["id"]
			var owned := int(Events.weapons.get(id, Events.passives.get(id, 0)))
			var label: String = ("New item!  %s" % pick["name"]) if owned == 0 else ("%s  Lv +1" % pick["name"])
			return {"rarity": 1, "text": label, "apply": func(): Events.grant_item(id)}
		# 지급 가능한 아이템이 없으면 자석으로 폴백
	var magnet := func():
		var pl := _player()
		if pl != null and pl.has_method("activate_gold_magnet"):
			pl.activate_gold_magnet(8.0)
	return {"rarity": 1, "text": "Gold Magnet  8s", "apply": magnet}


static func _roll_epic(gs: float) -> Dictionary:
	var r := randi() % 3
	if r == 0:
		return {"rarity": 2, "text": "FREE LEVEL UP", "apply": func(): Events.bonus_level()}
	if r == 1:
		var do_heal := func():
			var pl := _player()
			if pl != null and pl.has_method("heal"):
				pl.heal(999)
		return {"rarity": 2, "text": "Full Heal", "apply": do_heal}
	var g := int(randi_range(130, 200) * gs)
	return {"rarity": 2, "text": "+%d Gold" % g, "apply": func(): Events.add_gold(g)}


static func _roll_legendary(gs: float) -> Dictionary:
	var r := randi() % 3
	if r == 0:
		return {"rarity": 3, "text": "+1 REVIVE", "apply": func(): Events.revives_left += 1}
	if r == 1:
		var mg := randi_range(40, 80)
		return {"rarity": 3, "text": "+%d Meta Gold (permanent)" % mg, "apply": func(): MetaManager.reward_gold(mg)}
	var g := int(randi_range(280, 420) * gs)
	return {"rarity": 3, "text": "JACKPOT  +%d Gold" % g, "apply": func(): Events.add_gold(g)}


## 새 슬롯 여유/만렙 규칙을 지켜 지급 가능한 아이템 하나를 무작위로 고른다(없으면 {}).
static func _random_grantable_item() -> Dictionary:
	var out: Array = []
	var w_free: bool = Events.weapons.size() < ItemDB.MAX_WEAPON_SLOTS
	var p_free: bool = Events.passives.size() < ItemDB.MAX_PASSIVE_SLOTS
	for item in ItemDB.weapons():
		var lv := int(Events.weapons.get(item["id"], 0))
		if item.get("evolved", false):
			continue   # 진화 무기는 상자에서 안 나온다(진화 전용)
		if (lv > 0 and lv < int(item["max"])) or (lv == 0 and w_free):
			out.append(item)
	for item in ItemDB.passives():
		var lv := int(Events.passives.get(item["id"], 0))
		if (lv > 0 and lv < int(item["max"])) or (lv == 0 and p_free):
			out.append(item)
	return out[randi() % out.size()] if not out.is_empty() else {}


static func _player() -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).get_first_node_in_group("player")
	return null


## ── 연출 ──────────────────────────────────────────────────────────────
## 2단계 리빌: (1) 기대(암시) — 등급색 글로우가 두근거리며 커지고 틱 사운드가 점점 높아진다.
##            (2) 공개(짜잔) — 섬광 + 파티클 분출 + 패널 팝으로 보상을 드러낸다.
## 탭: 기대 단계에서는 즉시 공개로 건너뛰고, 공개 후에는 닫는다.
func _setup(reward: Dictionary) -> void:
	_applies = reward["applies"]
	set_meta("rarity", reward["rarity"])
	set_meta("text", "\n".join(reward["texts"]))
	set_meta("count", reward["texts"].size())


var _phase: int = 0            # 0=기대(암시) 1=공개
var _phase0_t: float = 0.0     # 기대 단계 경과(초) — 트윈이 죽어도 _process 가 공개를 보장(데드맨 스위치)
var _antic: Control = null     # 기대 단계 노드 묶음(공개 시 일괄 제거)
var _antic_tws: Array = []     # 기대 단계 트윈들 — 공개 시 전부 kill(해제된 노드 참조 에러 방지)
var _buildup_tw: Tween = null
var _rar: Dictionary = {}
var _col := Color.WHITE


func _ready() -> void:
	_open_now = true
	layer = 60   # LevelUpPanel(기본)보다 위
	process_mode = Node.PROCESS_MODE_ALWAYS
	_did_pause = not get_tree().paused
	get_tree().paused = true
	_rar = _RARITY[int(get_meta("rarity"))]
	_col = _rar["col"]

	# 어둠 + 입력 캐쳐(탭 = 스킵/닫기)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.72, 0.15)

	_build_anticipation()


## 기대 단계 — 등급색만으로 "뭔가 좋은 게 나올 것 같다"를 암시한다(등급이 높을수록 길고 강하게).
func _build_anticipation() -> void:
	_antic = Control.new()
	_antic.set_anchors_preset(Control.PRESET_FULL_RECT)
	_antic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_antic)

	var build := float(_rar["build"])

	# 등급색 방사형 글로우 — 두근거리며 점점 커진다.
	var grad := Gradient.new()
	grad.set_color(0, Color(_col.r, _col.g, _col.b, 0.55))
	grad.set_color(1, Color(_col.r, _col.g, _col.b, 0.0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	gtex.width = 256
	gtex.height = 256
	var glow := TextureRect.new()
	glow.texture = gtex
	glow.size = Vector2(430, 430)
	glow.position = Vector2(360 - 215, 560 - 215)
	glow.pivot_offset = Vector2(215, 215)
	glow.scale = Vector2(0.45, 0.45)
	glow.modulate.a = 0.0
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_antic.add_child(glow)
	var gt := create_tween()
	_antic_tws.append(gt)
	gt.set_parallel(true)
	gt.tween_property(glow, "modulate:a", 1.0, 0.25)
	gt.tween_property(glow, "scale", Vector2(1.15, 1.15), build).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 두근거리는 "?" — 개수가 곧 이번 상자의 보상 개수(등급 암시와 함께 이중 힌트).
	var qn := int(get_meta("count", 1))
	var qcol := Color(minf(_col.r * 1.2 + 0.1, 1.0), minf(_col.g * 1.2 + 0.1, 1.0), minf(_col.b * 1.2 + 0.1, 1.0))
	var spacing := 96.0
	var start_x := 360.0 - spacing * float(qn - 1) * 0.5
	for qi in qn:
		var q := Label.new()
		q.text = "?"
		q.add_theme_font_size_override("font_size", 74 if qn >= 3 else 88)
		q.add_theme_color_override("font_color", qcol)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.size = Vector2(96, 140)
		q.position = Vector2(start_x + spacing * float(qi) - 48.0, 560 - 70)
		q.pivot_offset = Vector2(48, 70)
		UITheme.heading(q)
		_antic.add_child(q)
		# 개체마다 주기를 살짝 달리해 자연스럽게 어긋나며 두근거린다.
		var pulse := create_tween().set_loops()
		_antic_tws.append(pulse)
		var dur := 0.15 + 0.025 * float(qi)
		pulse.tween_property(q, "scale", Vector2(1.14, 1.14), dur).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(q, "scale", Vector2(0.95, 0.95), dur).set_trans(Tween.TRANS_SINE)

	# 은은한 상승 입자 — 등급이 높을수록 짙게.
	var drift := CPUParticles2D.new()
	drift.position = Vector2(360, 640)
	drift.amount = 10 + 7 * int(get_meta("rarity"))
	drift.lifetime = 1.3
	drift.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	drift.emission_rect_extents = Vector2(170.0, 6.0)
	drift.direction = Vector2(0, -1)
	drift.spread = 14.0
	drift.gravity = Vector2(0, -30)
	drift.initial_velocity_min = 40.0
	drift.initial_velocity_max = 110.0
	drift.scale_amount_min = 1.2
	drift.scale_amount_max = 2.6
	drift.color = Color(_col.r, _col.g, _col.b, 0.7)
	drift.emitting = true
	_antic.add_child(drift)

	# 틱 사운드 — 점점 높아지며 기대감을 조인다.
	var ticks := 3 + int(get_meta("rarity"))
	var tick_tw := create_tween()
	_antic_tws.append(tick_tw)
	for i in ticks:
		tick_tw.tween_interval(build / float(ticks))
		var pitch := 0.85 + 0.16 * float(i)
		tick_tw.tween_callback(func(): SoundManager.play("gold", 0.02, pitch))

	# 빌드업이 끝나면 공개.
	_buildup_tw = create_tween()
	_buildup_tw.tween_interval(build + 0.05)
	_buildup_tw.tween_callback(_reveal)


## 공개(짜잔) — 기대 단계를 걷어내고 섬광·파티클·패널 팝으로 보상을 드러낸다.
func _reveal() -> void:
	if _phase == 1 or _closed:
		return
	_phase = 1
	if _buildup_tw and _buildup_tw.is_valid():
		_buildup_tw.kill()
	for tw0 in _antic_tws:
		if tw0 and tw0.is_valid():
			tw0.kill()
	_antic_tws.clear()
	if _antic != null:
		_antic.queue_free()
		_antic = null
	_auto_left = float(_rar["hold"])
	var col := _col

	# 등급 섬광(희귀 이상) — 화면 전체가 등급색으로 번쩍였다 사라진다.
	var flash_a: float = _rar["flash"]
	if flash_a > 0.0:
		var flash := ColorRect.new()
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.color = Color(col.r, col.g, col.b, flash_a)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flash)
		create_tween().tween_property(flash, "color:a", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 반짝이 입자 분출 — 등급이 높을수록 많고 화려하게.
	var spark := CPUParticles2D.new()
	spark.position = Vector2(360, 560)
	spark.amount = int(_rar["spark"])
	spark.lifetime = 1.1
	spark.one_shot = false
	spark.explosiveness = 0.7
	spark.spread = 180.0
	spark.gravity = Vector2(0, 60)
	spark.initial_velocity_min = 90.0
	spark.initial_velocity_max = 260.0
	spark.scale_amount_min = 1.5
	spark.scale_amount_max = 3.5
	spark.color = Color(col.r, col.g, col.b, 0.9)
	spark.emitting = true
	add_child(spark)

	# 폭죽 홀더 — 보상 패널보다 먼저 추가해, 늦게 터지는 폭죽도 항상 UI "뒤"에 그려진다.
	var fw_holder := Control.new()
	fw_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	fw_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fw_holder)
	_launch_fireworks(fw_holder)

	# 중앙 패널 — 등급색 테두리, 스케일 팝.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _UIStyle.panel(Color(0.07, 0.08, 0.11, 0.97), col, 22, 4))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + m, 30)
	_panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.custom_minimum_size = Vector2(330, 0)
	margin.add_child(vb)

	var head := Label.new()
	head.text = "- TREASURE -"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	vb.add_child(head)

	var title := Label.new()
	title.text = _rar["title"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", col)
	UITheme.heading(title)
	vb.add_child(title)

	var what := Label.new()
	what.text = String(get_meta("text"))
	what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	what.add_theme_font_size_override("font_size", 26)
	what.add_theme_color_override("font_color", Color(0.94, 0.95, 0.98))
	vb.add_child(what)

	var hint := Label.new()
	hint.text = "tap to continue"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.55, 0.58, 0.66))
	vb.add_child(hint)

	# 팝 등장 + (희귀 이상) 흔들림 연출.
	_panel.pivot_offset = Vector2(195, 90)
	_panel.scale = Vector2(0.4, 0.4)
	_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.18)
	var shake_amt: float = _rar["shake"]
	if shake_amt > 0.0:
		var st := create_tween()
		for i in 6:
			var off := Vector2(randf_range(-shake_amt, shake_amt), randf_range(-shake_amt, shake_amt))
			st.tween_property(center, "position", off, 0.04)
		st.tween_property(center, "position", Vector2.ZERO, 0.05)

	# 등급별 사운드 — 전설은 겹쳐서 임팩트.
	match int(get_meta("rarity")):
		0: SoundManager.play("gold", 0.05, 1.1)
		1: SoundManager.play("gold", 0.05, 1.25)
		2:
			SoundManager.play("gold", 0.05, 0.9)
			SoundManager.play("laser", 0.05, 1.4)
		3:
			SoundManager.play("boom", 0.05, 1.2)
			SoundManager.play("gold", 0.05, 0.7)


## 등급에 비례해 화면 곳곳에 폭죽을 연달아 터뜨린다(보상 UI 뒤). 전설은 중앙 피날레 대형 폭죽까지.
func _launch_fireworks(holder: Control) -> void:
	var rarity := int(get_meta("rarity"))
	var bursts: int = [3, 5, 8, 13][rarity]
	var fw_tw := create_tween()
	for i in bursts:
		fw_tw.tween_interval(0.05 if i == 0 else randf_range(0.10, 0.22))
		fw_tw.tween_callback(_pop_firework.bind(holder, 1.0))
	if rarity == 3:
		fw_tw.tween_interval(0.25)
		fw_tw.tween_callback(_pop_firework.bind(holder, 1.9))


## 폭죽 1발 — 원샷 방사 폭발 + 중력 낙하 + 페이드. size_mul 로 피날레 대형화.
func _pop_firework(holder: Control, size_mul: float) -> void:
	if _closed or not is_instance_valid(holder):
		return
	var rarity := int(get_meta("rarity"))
	var pos := Vector2(randf_range(90, 630), randf_range(220, 920))
	if size_mul > 1.5:
		pos = Vector2(360, 470)   # 피날레는 중앙 상단
	# 색 변주 — 등급색·밝은 등급색·흰 불꽃을 섞고, 전설은 금/주황/백금 혼합.
	var cols: Array = [_col, _col.lightened(0.35), Color(1, 1, 1)]
	if rarity == 3:
		cols = [Color(1.0, 0.82, 0.25), Color(1.0, 0.55, 0.2), Color(1.0, 1.0, 0.9)]
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = int((22 + rarity * 6) * size_mul)
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2(0, 260)
	p.initial_velocity_min = 150.0 * size_mul
	p.initial_velocity_max = 340.0 * size_mul
	p.damping_min = 40.0
	p.damping_max = 110.0
	p.scale_amount_min = 1.4
	p.scale_amount_max = 3.2 * size_mul
	p.color = cols[randi() % cols.size()]
	var ramp := Gradient.new()   # 수명 끝에서 자연스럽게 사그라들도록 알파 페이드
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	p.emitting = true
	holder.add_child(p)
	# 원샷 방출이 끝나면 스스로 정리 — 외부 타이머·람다 캡처가 없어 조기 닫힘에도 안전하다.
	p.finished.connect(p.queue_free)
	if size_mul > 1.5:
		SoundManager.play("boom", 0.05, 1.5)   # 피날레는 낮게 쿵
	else:
		SoundManager.play("gold", 0.08, 1.35 + randf() * 0.3)


func _on_dim_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if _phase == 0:
			_reveal()   # 기대 단계 탭 = 바로 공개로 스킵
		else:
			_close()


func _process(delta: float) -> void:
	if _closed:
		return
	if _phase == 0:
		# 안전장치 — 빌드업 트윈이 어떤 이유로든 죽어도 시간이 되면 반드시 공개한다.
		_phase0_t += delta
		if _phase0_t >= float(_rar["build"]) + 1.0:
			_reveal()
		return
	_auto_left -= delta
	if _auto_left <= 0.0:
		_close()


## 씬 전환 등으로 패널이 닫히지 못한 채 제거될 때 — 일시정지·정적 가드가 영구히 남지 않게 복구.
func _exit_tree() -> void:
	_open_now = false
	if not _closed and _did_pause and get_tree() != null:
		get_tree().paused = false


## 닫기: 게임 재개 → 보상 적용(레벨업 패널 등이 이어서 뜰 수 있게 재개 후 적용) → 해제.
func _close() -> void:
	if _closed:
		return
	_closed = true
	_open_now = false
	if _did_pause:
		get_tree().paused = false
	for a in _applies:
		if a is Callable and a.is_valid():
			a.call()
	queue_free()
