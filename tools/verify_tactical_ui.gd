extends SceneTree
## Integration checks for the opt-in redesign, using disposable user data.
var failures := 0

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 8: await process_frame

func inside(ctrl: Control, message: String) -> void:
	check(Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1).encloses(ctrl.get_global_rect()), message + " " + str(ctrl.get_global_rect()))

func card_text_inside(card: Control, message: String) -> void:
	for node_name in ["Badge", "Title", "Description"]:
		var label: Label = card.find_child(node_name, true, false)
		check(label != null, message + " missing " + node_name)
		if label == null: continue
		check(label.size.y > 0.0, message + " missing " + node_name)
		check(card.get_global_rect().grow(1).encloses(label.get_global_rect()),
			message + " overflow " + node_name + " " + str(label.get_global_rect()))
	var description: Label = card.find_child("Description", true, false)
	if description != null:
		check(description.get_line_count() <= 2, message + " description exceeds two rows")

func _run() -> void:
	# Save-presence fixture is restored even when an assertion fails.
	var save_path := "user://save.json"
	var existed := FileAccess.file_exists(save_path)
	var original := FileAccess.get_file_as_bytes(save_path) if existed else PackedByteArray()
	var ev := root.get_node("Events")
	var loc := root.get_node("Locale")
	var item_db = load("res://scripts/ItemDB.gd")
	for screen in [Vector2i(720,1280), Vector2i(360,640), Vector2i(1280,720)]:
		root.size = screen
		root.content_scale_size = Vector2i(720,1280) if screen.y>screen.x else Vector2i(2272,1278)
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		await settle()
		for language in ["ko", "en", "ja"]:
			loc.current = language
			for saved in [false,true]:
				if saved:
					var f := FileAccess.open(save_path,FileAccess.WRITE)
					f.store_string("{}")
					f.close()
				else: DirAccess.remove_absolute(save_path)
				var menu = load("res://scenes/MainMenu.tscn").instantiate()
				root.add_child(menu)
				await settle()
				# Skip entrance transforms while measuring the steady-state layout.
				for child in menu.get_children():
					if child is CenterContainer:
						for box in child.get_children():
							for node in box.get_children():
								if node is Control: node.scale = Vector2.ONE
				check(menu._continue_btn.visible == saved, "Continue presence")
				if saved:
					check(menu._continue_btn.get_index()<menu._new_game_btn.get_index(), "Continue is first")
				inside(menu._new_game_btn,"New game fits "+language)
				inside(menu._records_btn,"Records fits "+language)
				for btn in [menu._power_btn,menu._quest_btn,menu._records_btn,menu._rewards_btn]:
					check(btn.size.y>=88,"Menu touch height")
					var style: StyleBox = btn.get_theme_stylebox("normal")
					var font: Font = btn.get_theme_font("font")
					check(font.get_string_size(btn.text,HORIZONTAL_ALIGNMENT_LEFT,-1,28).x <= btn.size.x-style.get_content_margin(SIDE_LEFT)-style.get_content_margin(SIDE_RIGHT),"Menu text fits: "+btn.text)
				check(menu._power_panel.get_theme_stylebox("panel") is StyleBoxTexture,"Legacy popup style retained")
				menu._on_records_pressed()
				check(menu._records_panel.visible,"Records opens")
				menu._records_dim.hide()
				menu._records_panel.hide()
				menu._on_new_game_pressed()
				check(menu._newgame_flow and menu._char_panel.visible,"New game opens character selection")
				menu.queue_free()
				await settle()
			print("PASS lobby ",screen," ",language)
		ev.reset()
		var hud = load("res://scenes/HUD.tscn").instantiate()
		root.add_child(hud)
		ev.weapons = {}
		var count := 0
		for item in item_db.weapons():
			if count>=7: break
			ev.weapons[item.id] = 3
			count += 1
		ev.passives = {}
		count = 0
		for item in item_db.passives():
			if count>=6: break
			ev.passives[item.id] = 2
			count += 1
		ev.inventory_changed.emit()
		await settle()
		check(hud._weapon_row.get_child_count()==7,"Seventh character weapon retained")
		inside(hud.get_node("TacticalLoadout"),"Loadout fits")
		for row in [hud._weapon_row,hud._passive_row]:
			for slot in row.get_children(): inside(slot,"Slot fits")
		check(hud.top_bg.size.y<=root.get_visible_rect().size.y*0.15,"HUD <=15% height")
		check(not hud.hp_bar.get_global_rect().intersects(hud.time_label.get_global_rect()),"Health/time separated")
		check(not hud.time_label.get_global_rect().intersects(hud._pause_btn.get_global_rect()),"Time/pause separated")
		hud._on_player_health_changed(1,5)
		hud._on_boss_spawned(100)
		check(not hud.boss_bar.get_global_rect().intersects(hud._alert.get_global_rect()),"Boss/alert separated")
		hud._toasts.push("FIRST",Color.WHITE,504,"first")
		hud._toasts.push("SECOND",Color.WHITE,504,"second")
		check(hud._toasts._active.size()==1 and hud._toasts._queue.size()==1,"General notices queued")
		var joystick = hud.get_node("Joystick")
		joystick._try_activate(Vector2(root.get_visible_rect().size.x*0.5,root.get_visible_rect().size.y-20),0)
		check(not joystick._active,"Inventory region does not start movement")
		joystick._try_activate(Vector2(150,root.get_visible_rect().size.y-240),0)
		check(joystick._origin.y+joystick.base_radius<=root.get_visible_rect().size.y-220,"Joystick stays above inventory")
		joystick._reset()
		var panel = load("res://scripts/LevelUpPanel.gd").new()
		root.add_child(panel)
		ev.bonus_level()
		await settle()
		inside(panel._panel,"Level-up fits")
		check(paused and panel._showing,"Level-up owns pause")
		var cards: Array = panel._card_box.get_children()
		check(not cards.is_empty(),"Level-up has choices")
		if not cards.is_empty():
			var id: String = cards[0].get_meta("pick_id")
			var before: int = ev.weapons.get(id,ev.passives.get(id,0))
			cards[0].pressed.emit()
			cards[0].pressed.emit()
			await create_timer(0.4,true,false,true).timeout
			var after: int = ev.weapons.get(id,ev.passives.get(id,0))
			check(after==before+1,"Double press grants exactly once")
			check(not paused,"Selection releases pause")
		# Use the longest actual catalog strings, not a short hand-picked fixture.
		var catalog: Array = item_db.weapons()+item_db.passives()
		catalog.sort_custom(func(a,b): return (a.name+a.desc).length()>(b.name+b.desc).length())
		for language in ["ko","en","ja"]:
			loc.current = language
			ev.bonus_level()
			for child in panel._card_box.get_children():
				panel._card_box.remove_child(child)
				child.queue_free()
			for i in 3:
				panel._card_box.add_child(panel._make_item_card({"item":catalog[i],"lv":7,"is_new":false}))
			await settle()
			inside(panel._panel,"Long cards fit "+language)
			for card in panel._card_box.get_children():
				inside(card,"Long card fits")
				card_text_inside(card,"Long card text fits "+language)
			panel._pending = 0
			panel._advance_or_close()
		# An evolution followed by a queued level must keep pause until both finish.
		panel._evo_mode = true
		panel._evo_rules = [{"base":"gun","into":"railgun"}]
		panel._present()
		ev.bonus_level()
		await settle()
		panel._card_box.get_child(0).pressed.emit()
		await create_timer(0.4,true,false,true).timeout
		check(ev.weapons.has("railgun") and not ev.weapons.has("gun"),"Evolution replaces base weapon")
		check(paused and panel._showing and not panel._evo_mode,"Queued upgrade retains pause after evolution")
		panel._card_box.get_child(0).pressed.emit()
		await create_timer(0.4,true,false,true).timeout
		check(not paused and not panel._showing,"Queued selection resumes play")
		panel.queue_free()
		hud.queue_free()
		await settle()
		print("PASS HUD and selection ",screen)
	if existed:
		var f := FileAccess.open(save_path,FileAccess.WRITE)
		f.store_buffer(original)
		f.close()
	else: DirAccess.remove_absolute(save_path)
	print("TACTICAL UI failures: ",failures)
	quit(failures)
