extends Node

var game
var destination = ""
var issues = []

func frames(count: int = 4):
	for i in range(count): await get_tree().process_frame

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
		get_tree().root.push_input(event,true)
	await frames()

func execute(owner_game,output: String):
	game = owner_game
	destination = output
	DirAccess.make_dir_recursive_absolute(destination)
	await frames(10)
	if game.content.vfx_frames.size() != 28: issues.append("animation atlas missing from release")
	for clip in game.content.vfx_frames.values():
		if clip.size() != 6 or clip[0].get_width() != 256: issues.append("invalid release animation frames")
	await click("NewRun")
	await click("DifficultyEasy")
	if game.selected_difficulty!="easy": issues.append("easy selection failed")
	await click("DifficultyChallenge")
	await click("Class_mechanic")
	await click("StartRun")
	if game.run == null or game.run.class_id != "mechanic": issues.append("class selection failed")
	if game.run.difficulty!="challenge": issues.append("difficulty selection failed")
	await click("Buy_0")
	if game.run.roster.is_empty(): issues.append("initial new profession recruit failed")
	await click("NextWave")
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
	if game.sim.captain.x < start.x+20: issues.append("keyboard movement failed")
	var index = game.sim.spawn_enemy("shambler",game.sim.captain+Vector2(70,0))
	game.sim.enemies[index].hp = 1000
	game.sim.enemies[index].max_hp = 1000
	game.sim.grid.rebuild(game.sim.enemies)
	for i in range(100): game.sim.tick(1.0/60.0)
	if game.sim.enemies[index].hp >= 1000: issues.append("automatic attacks failed")
	var attack_hp=game.sim.enemies[index].hp
	var movement_pixels=game.sim.captain.x-start.x
	await click("Pause")
	var elapsed = game.sim.elapsed
	game.sim.tick(1)
	if game.run.mode != "paused" or game.sim.elapsed != elapsed: issues.append("pause failed")
	await click("Resume")
	if game.run.mode != "combat": issues.append("resume failed")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(destination.path_join("release-battle.png"))
	game.run.add_xp(30)
	game.sim.tick(0.01)
	if game.screen!="upgrade": issues.append("upgrade selection missing")
	await click("Reroll")
	if game.run.rerolls!=1: issues.append("upgrade reroll failed")
	await click("Perk_"+game.run.choices[0])
	if game.run.mods.size()!=1 or game.run.mode!="combat": issues.append("mod selection failed")
	game.sim.rescue_done=true
	game.sim.captain=game.sim.scavenging.sites[0].pos
	key.physical_keycode=KEY_E
	key.keycode=KEY_E
	key.pressed=true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	for i in range(125): game.sim.tick(1.0/60)
	key=key.duplicate()
	key.pressed=false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	if game.screen!="equipment": issues.append("E scavenging interaction failed")
	if not game.run.equipment_choices.is_empty(): await click("Equip_"+game.run.equipment_choices[0])
	if game.run.equipment.size()!=1: issues.append("equipment selection failed")
	game.run.equipment=["battery","magnet","flywheel","medbox"]
	game.run.equipment_choices=["thermos"]
	game.show_equipment()
	await click("Equip_thermos")
	await click("Replace_1")
	if game.run.equipment[1]!="thermos": issues.append("four slot replacement failed")
	game.run.mode="camp"
	game.run.map_state=game.city.snapshot()
	game.progress.save_run(game.run)
	var build=game.run.mods.duplicate()
	var gear=game.run.equipment.duplicate()
	game._continue_run()
	if game.run.mods!=build or game.run.equipment!=gear or game.run.rerolls!=1 or game.run.difficulty!="challenge": issues.append("build checkpoint restore failed")
	game._begin_wave()
	game.sim.manual_tick=true
	game.run.health=0
	game.run.stats.regen=0
	game.sim.tick(0.01)
	if game.screen!="result" or game.last_win: issues.append("defeat failed")
	game.start_run("teacher",9011)
	if game.run.wave!=0 or not game.run.mods.is_empty() or not game.run.equipment.is_empty(): issues.append("restart retained old build")
	var file = FileAccess.open(destination.path_join("release-result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"issues":issues,"executable":OS.get_executable_path(),"renderer":DisplayServer.get_name(),"classes":game.content.classes.size(),"survivors":game.content.survivors.size(),"weapons":game.content.weapons.size(),"mods":game.content.mods.size(),"equipment":game.content.equipment.size(),"movement_pixels":movement_pixels,"automatic_attack_hp":attack_hp,"checks":["difficulty","recruit","move","attack","pause","reroll","mod","E scavenge","gear replacement","save/load","defeat","restart"]},"\t"))
	file.close()
	print("RELEASE VALIDATION ",issues)
	await frames(8)
	get_tree().quit(0 if issues.is_empty() else 1)
