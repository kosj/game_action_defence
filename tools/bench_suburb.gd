extends SceneTree
var frames: Array[float] = []
var _last := 0
var _elapsed := 0.0
var _running := false
var _player: Node2D
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	seed(42)
	var theme_id := "suburb"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--theme="):
			theme_id = arg.trim_prefix("--theme=")
	root.get_node("ThemeManager")._bought[theme_id] = true
	root.get_node("ThemeManager")._selected_id = theme_id
	root.get_node("Events").reset()
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(2).timeout
	var spawner := main.get_node("ZombieSpawner")
	spawner.set_process(false)
	_player = get_first_node_in_group("player")
	_player.set_physics_process(false)
	_player.set("_hurt_timer",100000.0)
	for z in get_nodes_in_group("zombies"):
		root.get_node("Pool").release(z)
	await process_frame
	var kinds: Array = spawner.get("ZOMBIE_TYPES")
	for i in 320:
		var pos := Vector2(940,940)+Vector2.from_angle(float(i)*2.39996)*(350+i%6*50)
		spawner.call("_spawn_at",kinds[0],pos)
	for z in get_nodes_in_group("zombies"):
		z.set("health",1000000000)
	_running = true
	_last = Time.get_ticks_usec()
func _process(delta: float) -> bool:
	if not _running:
		return false
	_elapsed += delta
	_player.global_position = Vector2(940,940)+Vector2.from_angle(_elapsed*0.25)*400
	var world := get_first_node_in_group("suburb_world")
	if world != null:
		_player.global_position = load("res://scripts/SuburbLayout.gd").safe(_player.global_position)
	var now := Time.get_ticks_usec()
	if _elapsed>5:
		frames.append(float(now-_last)/1000)
	_last = now
	if _elapsed>25:
		frames.sort()
		print("SUBURB BENCH ",JSON.stringify({"count":get_nodes_in_group("zombies").size(),"p95_ms":frames[int(frames.size()*0.95)],"median_ms":frames[frames.size()/2],"samples":frames.size()}))
		quit()
	return false
