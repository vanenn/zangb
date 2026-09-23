extends SceneTree

var game
var results = []

func _initialize(): call_deferred("execute")

func execute():
	DisplayServer.window_set_size(Vector2i(1920,1080))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game = load("res://main.tscn").instantiate()
	game.test_storage_path = "res://tests/user/performance-%s" % Time.get_ticks_msec()
	root.add_child(game)
	for i in range(10): await process_frame
	for class_id in game.content.classes:
		game.start_run(class_id,40017)
		game.run.wave = 7
		for i in range(30): game.run.recruit(game.content.survivors.keys()[i%12])
		game._begin_wave()
		game.sim.test_invulnerable = true
		game.sim.profile_enabled = true
		game.sim.width_limit = 200
		game.sim.elapsed = 61.0
		for i in range(200):
			var id = game.content.maps[game.run.map_id].enemies[i%3]
			var point = game.city.nearby_open(game.sim.captain,game.run.rng.randf_range(180,730),game.run.rng)
			var index = game.sim.spawn_enemy(id,point)
			game.sim.enemies[index].hp = 1.0e9
			game.sim.enemies[index].max_hp = 1.0e9
		for i in range(150):
			game.sim.test_direction = Vector2.from_angle(i*0.007)
			await process_frame
		var times = []
		var cpu_times = []
		var last = Time.get_ticks_usec()
		for i in range(600):
			game.sim.test_direction = Vector2.from_angle(i*0.007)
			await process_frame
			var now = Time.get_ticks_usec()
			times.append(float(now-last)/1000.0)
			cpu_times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
			last = now
		var total = times.reduce(func(a,b): return a+b,0.0)
		times.sort()
		cpu_times.sort()
		var entry = {"map":game.run.map_id,"companions":30,"captains":1,"enemies":game.sim.active_count,"resolution":"1920x1080","rendering":"OpenGL compatibility","gpu":RenderingServer.get_video_adapter_name(),"frames":times.size(),"average_fps":snappedf(1000.0/(total/times.size()),0.1),"frame_ms_p50":snappedf(times[300],0.01),"frame_ms_p95":snappedf(times[570],0.01),"frame_ms_p99":snappedf(times[594],0.01),"cpu_ms_p95":snappedf(cpu_times[570],0.01),"memory_mb":snappedf(Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,0.1),"controlled_benchmark":"normal movement, targeting, attacks and rendering; invulnerable captain and high-health enemies keep the population fixed"}
		var averages = {}
		for key in game.sim.profile_totals: averages[key] = snappedf(game.sim.profile_totals[key]/game.sim.profile_counts[key],0.001)
		entry.profile_ms_mean = averages
		results.append(entry)
		print("PERFORMANCE ",entry)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/stress-%s.png" % game.run.map_id)
	var file = FileAccess.open("res://tests/performance-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit()

