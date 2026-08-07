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
	{"key": "common",    "title": "COMMON",        "col": Color(0.80, 0.84, 0.90), "flash": 0.0,  "shake": 0.0, "spark": 14, "hold": 1.6},
	{"key": "rare",      "title": "RARE !",        "col": Color(0.35, 0.65, 1.00), "flash": 0.25, "shake": 3.0, "spark": 26, "hold": 2.0},
	{"key": "epic",      "title": "EPIC !!",       "col": Color(0.75, 0.45, 1.00), "flash": 0.5,  "shake": 6.0, "spark": 44, "hold": 2.4},
	{"key": "legendary", "title": "LEGENDARY !!!", "col": Color(1.00, 0.82, 0.25), "flash": 0.85, "shake": 10.0, "spark": 70, "hold": 3.0},
]

static var _open_now: bool = false   # 동시 개봉 가드 — 이미 열려 있으면 연출 없이 즉시 지급

var _did_pause: bool = false
var _closed: bool = false
var _apply: Callable            # 닫힐 때 실행할 보상 적용
var _panel: PanelContainer
var _auto_left: float = 0.0


## 진입점 — 등급/보상을 추첨하고 리빌 패널을 띄운다.
static func open(parent: Node) -> void:
	var reward := _roll()
	if _open_now:
		reward["apply"].call()   # 겹침(연속 개봉) — 연출 생략하고 보상만 지급
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
	match rarity:
		3: return _roll_legendary(gscale)
		2: return _roll_epic(gscale)
		1: return _roll_rare(gscale)
		_: return _roll_common(gscale)


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
func _setup(reward: Dictionary) -> void:
	_apply = reward["apply"]
	set_meta("rarity", reward["rarity"])
	set_meta("text", reward["text"])


func _ready() -> void:
	_open_now = true
	layer = 60   # LevelUpPanel(기본)보다 위
	process_mode = Node.PROCESS_MODE_ALWAYS
	_did_pause = not get_tree().paused
	get_tree().paused = true

	var rar: Dictionary = _RARITY[int(get_meta("rarity"))]
	var col: Color = rar["col"]
	_auto_left = float(rar["hold"])

	# 어둠 + 입력 캐쳐(탭 = 닫기)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.72, 0.15)

	# 등급 섬광(희귀 이상) — 화면 전체가 등급색으로 번쩍였다 사라진다.
	var flash_a: float = rar["flash"]
	if flash_a > 0.0:
		var flash := ColorRect.new()
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.color = Color(col.r, col.g, col.b, flash_a)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flash)
		create_tween().tween_property(flash, "color:a", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 반짝이 입자 — 등급이 높을수록 많고 화려하게(정지 중에도 동작: ALWAYS 상속).
	var spark := CPUParticles2D.new()
	spark.position = Vector2(360, 560)
	spark.amount = int(rar["spark"])
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
	title.text = rar["title"]
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

	# 팝 등장 + (희귀 이상) 흔들림 연출. 정지 중에도 트윈이 돌도록 ALWAYS 노드에 바인딩된다.
	_panel.pivot_offset = Vector2(195, 90)
	_panel.scale = Vector2(0.4, 0.4)
	_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.18)
	var shake_amt: float = rar["shake"]
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


func _on_dim_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		_close()


func _process(delta: float) -> void:
	if _closed:
		return
	_auto_left -= delta
	if _auto_left <= 0.0:
		_close()


## 닫기: 게임 재개 → 보상 적용(레벨업 패널 등이 이어서 뜰 수 있게 재개 후 적용) → 해제.
func _close() -> void:
	if _closed:
		return
	_closed = true
	_open_now = false
	if _did_pause:
		get_tree().paused = false
	if _apply.is_valid():
		_apply.call()
	queue_free()
