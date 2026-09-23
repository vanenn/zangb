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
	elif not sim.scavenging.opened and sim.elapsed<65:
		target=sim.scavenging.sites[0].pos
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

func pick_core(state, priorities):
	if state.equipment_choices.is_empty(): return
	var choice=state.equipment_choices[0]
	for id in priorities:
		if id in state.equipment_choices:
			choice=id
			break
	if state.equipment.size()<4: state.choose_equipment(choice)
	else:
		var worst=0
		var score=-1
		for i in range(4):
			var rank=priorities.find(state.equipment[i])
			if rank<0: rank=99
			if rank>score:
				score=rank
				worst=i
		var new_rank=priorities.find(choice)
		if new_rank>=0 and new_rank<score: state.choose_equipment(choice,worst)
		else: state.equipment_choices.clear()
	state.first_core=true

func execute():
	InputMap.add_action("interact")
	var book=Content.new()
	var shop=Shop.new(book)
	var args=OS.get_cmdline_user_args()
	var class_id=args[0] if args.size()>0 else "teacher"
	var difficulty=args[1] if args.size()>1 else "challenge"
	var seed_value=int(args[2]) if args.size()>2 else 4471
	var strategy=args[3] if args.size()>3 else "build"
	var policy_rng=RandomNumberGenerator.new()
	policy_rng.seed=seed_value+80211
	var build_id=args[4] if args.size()>4 else {"teacher":"fire","mechanic":"acid","guard":"electric"}[class_id]
	var favourites={"fire":["chemist","sound_tech","nurse","officer"],"acid":["firefighter","chemical_worker","nurse","sanitation"],"electric":["electrician","sanitation","nurse","hunter"],"scavenge":["courier","nurse","hunter","officer"]}[build_id]
	var gear={"fire":["oil","resonator","fuse","thermos","flywheel","battery","magnet"],"acid":["valve","filter","coolant","thermos","flywheel","battery"],"electric":["battery","coil","coolant","thermos","flywheel","magnet"],"scavenge":["magnet","flywheel","medbox","battery","thermos"]}[build_id]
	var tags={"fire":["fire","sonic"],"acid":["acid","melee"],"electric":["electric","wet"],"scavenge":["pickup","movement"]}[build_id]
	var storage=Store.new("res://tests/user/campaign-v3-%s-%s-%s-%s-%s" % [class_id,difficulty,seed_value,strategy,Time.get_ticks_msec()])
	var state=State.new(book)
	state.start(class_id,seed_value,difficulty)
	var city=City.new()
	city.setup(book,state.map_id)
	root.add_child(city)
	navigator=city.astar
	var sim=Combat.new()
	sim.manual_tick=true
	sim.setup(book,state,storage,city)
	root.add_child(sim)
	var waves=[]
	var started=Time.get_ticks_msec()
	var completed=false
	var healed=0
	for wave in range(1,11):
		state.mode="camp"
		if wave==2 and not state.first_core:
			state.make_equipment_choices()
			pick_core(state,gear)
		shop.stock(state,storage.meta.unlocked)
		while state.health<state.stats.max_health*0.85 and state.supplies>=20:
			shop.heal(state)
			healed+=1
		var hired=0
		var candidates=state.offers.filter(func(o): return o.kind=="person")
		if strategy=="build" and wave>1 and state.supplies>90 and not candidates.any(func(o): return o.id in favourites):
			shop.refresh(state,storage.meta.unlocked)
			candidates=state.offers.filter(func(o): return o.kind=="person")
		if strategy=="build": candidates.sort_custom(func(a,b): return (favourites.find(a.id) if a.id in favourites else 99)<(favourites.find(b.id) if b.id in favourites else 99))
		for offer in candidates:
			if hired<(1 if wave==1 else 2) and shop.buy(state,offer.uid): hired+=1
		if strategy=="build":
			var ranks=state.weapon_levels.keys()
			ranks.sort_custom(func(a,b): return state.roster.filter(func(p): return book.survivors[p].weapon==a).size()>state.roster.filter(func(p): return book.survivors[p].weapon==b).size())
			for id in ranks:
				while state.supplies-state.upgrade_price(id)>=45 and shop.upgrade(state,id): pass
		elif state.supplies>100: shop.upgrade(state,book.classes[class_id].weapon)
		sim.begin_wave()
		var steps=0
		var minimum_hp=state.health
		var peak=0
		while state.mode in ["combat","upgrade","equipment"] and steps<9000:
			if state.mode=="equipment":
				if strategy!="build" and not state.equipment_choices.is_empty():
					var pick=state.equipment_choices[policy_rng.randi_range(0,state.equipment_choices.size()-1)]
					state.choose_equipment(pick,policy_rng.randi_range(0,3) if state.equipment.size()==4 else -1)
				pick_core(state,gear if strategy=="build" else [])
				state.mode="combat"
			if state.mode=="upgrade":
				var choice=state.choices[0]
				if strategy!="build": choice=state.choices[policy_rng.randi_range(0,state.choices.size()-1)]
				if strategy=="build":
					var score=-INF
					for id in state.choices:
						var item=book.mods.get(id,{"tags":[],"weapon":""})
						var rank=0.0
						for tag in item.tags:
							if tag in tags: rank+=3
						if id in ["auto_aid","pistol_2"]: rank+=5
						if id==book.classes[class_id].weapon+"_1": rank+=2
						if rank>score:
							score=rank
							choice=id
				state.choose_perk(choice)
				state.mode="combat"
			if steps%5==0: sim.test_direction=steer(sim)
			sim.test_interact=(not sim.rescue_done and sim.captain.distance_to(sim.rescue.pos)<75) or sim.scavenging.nearby()>=0
			sim.tick(1.0/30)
			minimum_hp=minf(minimum_hp,state.health)
			peak=maxi(peak,sim.active_count)
			steps+=1
			if steps%900==0: await process_frame
		var record={"wave":wave,"seconds":snappedf(sim.elapsed,0.1),"health":snappedf(state.health,0.1),"team":state.roster.size()+1,"rescued":state.rescued,"kills":state.kills,"level":state.level,"supplies":state.supplies,"remaining":sim.active_count,"damage_taken":snappedf(sim.build.damage_taken,0.1),"boss_seconds":sim.boss_duration,"scavenged":sim.scavenging.opened}
		record.minimum_hp=snappedf(minimum_hp,0.1)
		record.peak_enemies=peak
		record.spent=state.spent
		waves.append(record)
		print("WAVE ",class_id," ",difficulty," ",seed_value," ",strategy," ",record)
		if state.health<=0 or steps>=9000: break
		if wave==10: completed=true
	var result={"class":class_id,"difficulty":difficulty,"seed":seed_value,"strategy":strategy,"build":build_id,"completed":completed,"god_mode":false,"roster":state.counts,"weapon_levels":state.weapon_levels,"mods":state.mods,"equipment":state.equipment,"supplies_spent":state.spent,"heals_bought":healed,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"waves":waves}
	var filename="res://tests/campaign-v3-%s-%s-%s-%s.json" % [class_id,difficulty,seed_value,strategy]
	var file=FileAccess.open(filename,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("CAMPAIGN RESULT ",filename," completed=",completed)
	sim.queue_free()
	city.queue_free()
	await process_frame
	quit()
