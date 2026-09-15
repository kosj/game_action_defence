extends SceneTree
## 최신 게임오버 헤더에서 등급 중앙 정렬과 최종 스탬프 상태를 실렌더로 검증한다.

func _initialize() -> void:
	call_deferred("_run")


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout
	await RenderingServer.frame_post_draw


func _run() -> void:
	root.content_scale_size = Vector2i(720, 1280)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(720, 1280)
	root.get_node("Locale").current = "ko"
	root.get_node("SoundManager").set_enabled(false)
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _wait(0.5)
	var events := root.get_node("Events")
	events.elapsed_time = 293.0
	events.total_kills = 566
	events.total_gold = 114
	events.level = 15
	Engine.time_scale = 1.0
	var hud := main.get_node("HUD")
	hud._revive_btn.visible = false
	hud._show_end_panel(false)
	assert(hud._go_grade_reveal.modulate.a == 0.0,
		"게임오버 시작부터 등급이 노출됨")
	await _wait(1.58)
	assert(hud._go_grade_reveal.modulate.a == 0.0,
		"통계 집계가 끝나기 전에 등급이 노출됨")
	root.get_texture().get_image().save_png(
		"res://output/validation/gameover_grade_before_impact.png")
	await _wait(7.0)
	var path := "res://output/validation/gameover_grade_latest.png"
	root.get_texture().get_image().save_png(path)
	var row: Control = hud._go_medal_row
	var reveal: Control = hud._go_grade_reveal
	var medal_center := row.global_position + Vector2(row.size.x * 0.849, row.size.y * 0.42)
	var reveal_center := reveal.global_position + reveal.size * 0.5
	var header_top_gap: float = row.global_position.y - hud.game_over_panel.global_position.y
	assert(header_top_gap < 42.0,
		"게임오버 헤더 위쪽에 불필요한 빈 공간이 남음")
	assert(medal_center.distance_to(reveal_center) < 2.0,
		"등급 묶음이 헤더 메달 중앙에서 벗어남")
	assert(reveal.modulate.a > 0.99 and reveal.scale.distance_to(Vector2.ONE) < 0.02,
		"등급 스탬프가 최종 상태에 도달하지 않음")
	print("PASS: latest game-over grade centered and final impact settled")
	print("CAPTURE ", ProjectSettings.globalize_path(path))
	events.pause_release_all()
	quit()
