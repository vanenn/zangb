extends SceneTree

const Content = preload("res://scripts/content.gd")
const State = preload("res://scripts/run_state.gd")
const Store = preload("res://scripts/progress.gd")
const Shop = preload("res://scripts/shop.gd")
const City = preload("res://scripts/city_map.gd")
const Combat = preload("res://scripts/combat.gd")
var results = []
var navigator: AStarGrid2D

func _initialize(): call_deferred("execute")

func steer(sim) -> Vector2:
	var target = sim.captain
	if not sim.rescue_done:
		target = sim.rescue.pos
	else:
		var best = 10000000.0
		for drop in sim.drops:
			if drop.active and sim.elapsed < 60:
				var dist = sim.captain.distance_squared_to(drop.pos)
				if dist < best:
					best = dist
					target = drop.pos
		if best == 10000000.0:
			for enemy in sim.enemies:
				if enemy.active:
					var distance = sim.captain.distance_squared_to(enemy.pos)
					if distance < best:
						best = distance
						target = enemy.pos
	var preferred = sim.captain.direction_to(target)
	if not sim.city.clear_line(sim.captain,target,13):
		var start = sim.city.to_cell(sim.captain)
		var goal = sim.city.to_cell(target)
		var start_solid = navigator.is_point_solid(start)
		var goal_solid = navigator.is_point_solid(goal)
		navigator.set_point_solid(start,false)
		navigator.set_point_solid(goal,false)
		var path = navigator.get_point_path(start,goal)
		navigator.set_point_solid(start,start_solid)
		navigator.set_point_solid(goal,goal_solid)
		if path.size() > 1: preferred = sim.city.recovery_steer(sim.captain,target,13)
	if sim.captain.distance_to(target) < 30: preferred = Vector2.ZERO
	var best_score = -INF
	var best_direction = Vector2.ZERO
	var near_enemies = sim.grid.query(sim.captain,220)
	for index in range(17):
		var direction = Vector2.from_angle(float(index)/16*TAU) if index < 16 else Vector2.ZERO
		var point = sim.city.move_actor(sim.captain,direction*45,13)
		var score = preferred.dot(direction)*2.0
		if not sim.rescue_done and point.distance_to(sim.rescue.pos) < 60: score += 2.2
		if point.distance_to(sim.captain) < 15 and direction != Vector2.ZERO: score -= 9
		for enemy_index in near_enemies:
			var enemy = sim.enemies[enemy_index]
			if not enemy.active: continue
			var distance = point.distance_to(enemy.pos)-enemy.radius
			if distance < 130: score -= pow(maxf(0,130-distance)/65.0,2)*1.6
			if enemy.windup > 0 and point.distance_to(enemy.aim) < 100: score -= 8
		for hazard in sim.hazards:
			if not hazard.get("friendly",false) and point.distance_to(hazard.pos) < hazard.radius+45:
				score -= 28.0*(1.0-point.distance_to(hazard.pos)/(hazard.radius+45))
		if score > best_score:
			best_score = score
			best_direction = direction
	return best_direction

func execute():
	InputMap.add_action("interact")
	var book = Content.new()
	var shop = Shop.new(book)
	var requested = OS.get_cmdline_user_args()
	var classes = book.classes.keys() if requested.is_empty() else [requested[0]]
	for class_id in classes:
		var storage = Store.new("res://tests/user/campaign-%s-%s" % [class_id,Time.get_ticks_msec()])
		var state = State.new(book)
		state.start(class_id,4471)
		var city = City.new()
		city.setup(book,state.map_id)
		root.add_child(city)
		navigator = AStarGrid2D.new()
		navigator.region = Rect2i(Vector2i.ZERO,city.grid_size)
		navigator.cell_size = Vector2(48,48)
		navigator.offset = Vector2(24,24)
		navigator.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		navigator.update()
		for y in range(city.grid_size.y):
			for x in range(city.grid_size.x):
				navigator.set_point_solid(Vector2i(x,y),city.solids[y*city.grid_size.x+x] != 0)
		var sim = Combat.new()
		sim.manual_tick = true
		sim.setup(book,state,storage,city)
		root.add_child(sim)
		sim.test_interact = false
		var wave_records = []
		var done = false
		var start_time = Time.get_ticks_msec()
		for wave in range(1,11):
			state.mode = "camp"
			shop.stock(state,storage.meta.unlocked)
			if state.health < state.stats.max_health*0.75: shop.heal(state)
			var hired = 0
			for offer in state.offers:
				if offer.kind == "person" and hired < (1 if wave == 1 else 2):
					if shop.buy(state,offer.uid): hired += 1
			var leader_weapon = book.classes[class_id].weapon
			if wave % 2 == 0: shop.upgrade(state,leader_weapon)
			for weapon_id in state.weapon_levels:
				if state.supplies > 110: shop.upgrade(state,weapon_id)
			while state.health < state.stats.max_health*0.8 and state.supplies >= 16: shop.heal(state)
			sim.begin_wave()
			var steps = 0
			while state.mode in ["combat","upgrade"] and steps < 7200:
				if state.mode == "upgrade":
					var choice = state.choices[0]
					var preference = ["vitality","damage","speed","range","pickup","stride"] if state.health < state.stats.max_health*0.65 else ["damage","speed","vitality","range","pickup","stride"]
					for perk in preference:
						if perk in state.choices:
							choice = perk
							break
					state.choose_perk(choice)
					state.mode = "combat"
				if steps % 5 == 0: sim.test_direction = steer(sim)
				sim.test_interact = not sim.rescue_done and sim.captain.distance_to(sim.rescue.pos) < 75
				sim.tick(1.0/30.0)
				steps += 1
				if steps % 900 == 0: await process_frame
			var record = {"wave":wave,"seconds":snappedf(sim.elapsed,0.1),"health":snappedf(state.health,0.1),"team":state.roster.size()+1,"rescued":state.rescued,"kills":state.kills,"level":state.level,"supplies":state.supplies,"remaining":sim.active_count}
			wave_records.append(record)
			print(class_id," ",record)
			if state.health <= 0 or steps >= 7200:
				print("STOP captain=",sim.captain," rescue=",sim.rescue)
				for enemy in sim.enemies:
					if enemy.active: print("REMAINING ",enemy.id," at ",enemy.pos," goal ",enemy.target_pos)
				break
			storage.unlock_for_wave(wave)
			if wave == 10: done = true
		results.append({"class":class_id,"completed":done,"god_mode":false,"roster":state.counts.duplicate(),"weapon_levels":state.weapon_levels.duplicate(),"fixed_step":1.0/30.0,"elapsed_wall_seconds":(Time.get_ticks_msec()-start_time)/1000.0,"waves":wave_records})
		sim.queue_free()
		city.queue_free()
		await process_frame
	var filename = "res://tests/campaign-%s.json" % ("all" if requested.is_empty() else requested[0])
	var file = FileAccess.open(filename,FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	print("CAMPAIGNS FINISHED: ",filename)
	quit(0 if results.all(func(r): return r.completed) else 1)



