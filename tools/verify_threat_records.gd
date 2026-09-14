extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	var menu: Node = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await create_timer(0.3).timeout
	var threat: Node = root.get_node("ThreatManager")
	var ranking: Node = root.get_node("RankingManager")
	var locale: Node = root.get_node("Locale")
	threat._max_rank = 2
	threat._selected = 2
	threat._best = {"1":125.0,"2":0.0}
	ranking._backend.set_best(ranking.mode_id_for_threat(1),4321)
	ranking._backend.set_best(ranking.mode_id_for_threat(2),987)
	check(ranking.current_mode_id()=="threat_2","Score mode is not selected threat")
	locale.current = "ko"
	var korean: String = menu._records_text()
	check(korean.contains("위협 1 — 4321 / 02:05"),"Threat 1 score/time missing")
	check(korean.contains("위협 2 — 987 / --:--"),"Empty survival placeholder missing")
	check(not korean.contains("쉬움") and not korean.contains("보통") and not korean.contains("어려움"),"Legacy difficulty remains")
	menu._on_records_pressed()
	await create_timer(0.4).timeout
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://output/validation/threat-records-menu.png")
	locale.current = "en"
	check(menu._records_text().contains("Threat 1 — 4321 / 02:05"),"English threat record missing")
	locale.current = "ja"
	check(menu._records_text().contains("スレット 1 — 4321 / 02:05"),"Japanese threat record missing")
	print("THREAT RECORDS failures=",failures)
	quit(failures)
