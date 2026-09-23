extends SceneTree

var game
var issues = []
var screenshot_names = []

func _initialize(): call_deferred("execute")

func settle(frames: int = 5):
	for i in range(frames): await process_frame

func capture(name: String):
	await settle(4)
	await RenderingServer.frame_post_draw
	var path = "res://tests/%s.png" % name
	root.get_texture().get_image().save_png(path)
	screenshot_names.append(path)
	print("CAPTURE ",name)

func click(name: String):
	var button = game.find_child(name,true,false)
	if button == null:
		issues.append("Missing button "+name)
		return
	var at = button.get_global_rect().get_center()
	var event = InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event,true)
	event = InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	root.push_input(event,true)
	await settle(4)

func execute():
	game = load("res://main.tscn").instantiate()
	game.test_storage_path = "res://tests/user/visual-%s" % Time.get_ticks_msec()
	root.add_child(game)
	await settle(8)
	await capture("01-title")
	await click("NewRun")
	if game.screen != "classes": issues.append("Title mouse click did not open classes")
	await capture("02-classes")
	await click("Class_guard")
	if game.selected_class != "guard": issues.append("Class selection click failed")
	await click("StartRun")
	if game.screen != "camp": issues.append("Start button did not enter camp")
	await capture("03-camp")
	game.run.supplies = 120
	game.show_camp(true)
	await settle()
	var before = game.run.roster.size()
	await click("Buy_0")
	if game.run.roster.size() != before+1: issues.append("Recruit click failed")
	var saved_count = game.run.roster.size()
	var saved_supplies = game.run.supplies
	game._camp_to_menu()
	await settle()
	await click("ContinueRun")
	if game.run.roster.size() != saved_count or game.run.supplies != saved_supplies or not game.run.offers[0].sold:
		issues.append("Continue did not retain purchases")
	await click("NextWave")
	if game.screen != "combat": issues.append("Next wave click failed")
	game.sim.manual_tick = true
	var start = game.sim.captain
	var key = InputEventKey.new()
	key.physical_keycode = KEY_D
	key.keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await process_frame
	for i in range(30): game.sim.tick(1.0/30.0)
	key = InputEventKey.new()
	key.physical_keycode = KEY_D
	key.keycode = KEY_D
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	if game.sim.captain.x <= start.x: issues.append("Movement failed")
	await click("Pause")
	if game.run.mode != "paused": issues.append("Pause failed")
	var elapsed = game.sim.elapsed
	game.sim.tick(1)
	if game.sim.elapsed != elapsed: issues.append("Pause did not freeze combat")
	await click("Resume")
	if game.run.mode != "combat": issues.append("Resume failed")
	for class_id in game.content.classes:
		game.start_run(class_id,391)
		game.run.wave = 6
		game.run.supplies = 177
		for i in range(29): game.run.recruit(game.content.survivors.keys()[i%12])
		game._begin_wave()
		game.sim.manual_tick = true
		game.sim.test_invulnerable = true
		game.sim.test_direction = Vector2.RIGHT
		for i in range(60): game.sim.tick(1.0/30.0)
		game.sim.test_direction = Vector2.ZERO
		for i in range(75):
			var position = game.city.nearby_open(game.sim.captain,game.run.rng.randf_range(180,680),game.run.rng)
			game.sim.spawn_enemy(game.content.maps[game.run.map_id].enemies[i%3],position)
		game.sim.grid.rebuild(game.sim.enemies)
		for i in range(12): game.sim.tick(1.0/30.0)
		game.sim.elapsed = 36
		await capture("04-battle-"+class_id)
	game.run.pending_levels = 1
	game.run.make_choices()
	game.run.mode = "upgrade"
	game.show_level()
	await capture("05-upgrade")
	game._choose_level(game.run.choices[0])
	game.show_roster()
	await capture("06-roster")
	for node in game.modal.get_children():
		if node is ScrollContainer:
			node.scroll_vertical = 2000
			await settle()
			if node.scroll_vertical <= 0: issues.append("Twelve profession roster does not scroll")
	await capture("11-roster-new")
	game._resume()
	for node in game.ui.get_children():
		if node is ScrollContainer: node.scroll_horizontal = 3000
	await capture("10-team-new")
	var boss = game.sim.spawn_enemy("warden",game.city.nearby_open(game.sim.captain,200,game.run.rng))
	game.sim.enemies[boss].windup = 1.0
	game.sim.enemies[boss].aim = game.sim.captain+Vector2(100,0)
	await capture("13-boss-telegraph")
	game.show_pause()
	game.show_settings("pause")
	await capture("07-settings")
	game._close_settings()
	game.run.wave = 10
	game.run.kills = 1842
	game.run.rescued = 10
	game._finish(true)
	await capture("08-result")
	game.show_codex()
	await capture("09-codex")
	for node in game.ui.get_children():
		if node is ScrollContainer:
			node.scroll_vertical = 2000
			await settle()
			if node.scroll_vertical <= 0: issues.append("Twelve profession codex does not scroll")
	await capture("12-codex-new")
	game.start_run("teacher",1198)
	game._begin_wave()
	game.run.health = 0
	game.run.stats.regen = 0
	game.sim.tick(0.01)
	if game.screen != "result" or game.last_win: issues.append("Defeat screen failed")
	game.start_run("mechanic",1199)
	if game.run.wave != 0 or not game.run.roster.is_empty() or game.run.health <= 0: issues.append("Restart after defeat did not reset run")
	var file = FileAccess.open("res://tests/visual-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"issues":issues,"screenshots":screenshot_names},"\t"))
	file.close()
	print("VISUAL ISSUES ",issues)
	game.queue_free()
	await settle()
	quit(0 if issues.is_empty() else 1)

