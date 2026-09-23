extends SceneTree

var game
var output_dir = ""
var issues = []

func _initialize(): call_deferred("execute")

func frames(count: int = 4):
	for i in range(count): await process_frame

func click(name: String):
	var button = game.find_child(name,true,false)
	if button == null:
		issues.append("Missing button "+name)
		return
	for down in [true,false]:
		var event = InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
	await frames()

func execute():
	output_dir = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output_dir)
	var marker = FileAccess.open(output_dir.path_join("started.txt"),FileAccess.WRITE)
	marker.store_string("Release test entered SceneTree.\n"+OS.get_executable_path())
	marker.close()
	game = load("res://main.tscn").instantiate()
	game.test_storage_path = output_dir.path_join("user")
	root.add_child(game)
	await frames(10)
	await click("NewRun")
	await click("Class_mechanic")
	await click("StartRun")
	if game.run == null or game.run.class_id != "mechanic": issues.append("Exported class selection failed")
	await click("NextWave")
	if game.screen != "combat": issues.append("Exported battle start failed")
	game.sim.manual_tick = true
	var start = game.sim.captain
	var key = InputEventKey.new()
	key.physical_keycode = KEY_D
	key.keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await frames(2)
	for i in range(30): game.sim.tick(1.0/30.0)
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	if game.sim.captain.x <= start.x+10: issues.append("Exported keyboard movement failed")
	await click("Pause")
	if game.run.mode != "paused": issues.append("Exported pause failed")
	await click("Resume")
	await frames(50)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output_dir.path_join("release-battle.png"))
	var file = FileAccess.open(output_dir.path_join("release-result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"issues":issues,"embedded_resources":true,"class":game.run.class_id,"map":game.run.map_id,"enemies":game.sim.active_count,"scene":game.screen,"executable":OS.get_executable_path()},"\t"))
	file.close()
	print("RELEASE SMOKE: ",issues)
	game.queue_free()
	await frames()
	quit(0 if issues.is_empty() else 1)
