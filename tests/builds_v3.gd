extends "res://tests/v3.gd"

func execute():
	book=Content.new()
	var store=Store.new("res://tests/user/builds-%s" % Time.get_ticks_msec())
	var scenarios=[
		{"name":"water_electric","people":["sanitation","electrician"],"gear":["battery","coil"],"mods":["chain_1","chain_2","water_2"]},
		{"name":"corrosion_melee","people":["chemical_worker","firefighter","nurse"],"gear":["filter","valve","thermos"],"mods":["acid_2","chainsaw_1","chainsaw_2"]},
		{"name":"lure_fire","people":["chemist","sound_tech","courier"],"gear":["oil","resonator","fuse"],"mods":["molotov_1","decoy_2","brick_1"]},
		{"name":"recovery_movement","people":["courier","nurse"],"gear":["magnet","flywheel","medbox","battery"],"mods":["pickup_echo","move_charge","pistol_2","brick_2"]},
		{"name":"mixed_water_acid","people":["sanitation","electrician","chemical_worker","firefighter"],"gear":["coil","coolant","filter","valve"],"mods":["water_1","acid_2","chain_1","chainsaw_1"]},
		{"name":"mixed_fire_recovery","people":["chemist","sound_tech","courier","nurse"],"gear":["fuse","resonator","magnet","medbox"],"mods":["molotov_2","decoy_2","pistol_2","pickup_echo"]}
	]
	var results=[]
	for spec in scenarios:
		run=State.new(book)
		run.start("teacher",330)
		for id in spec.people: run.recruit(id)
		run.mods=spec.mods.duplicate()
		run.equipment=spec.gear.duplicate()
		check(run.equipment.all(func(id): return book.equipment[id].requires.all(func(t): return t in run.tags())),"available trigger sources: "+spec.name)
		city=City.new()
		city.setup(book,"school")
		root.add_child(city)
		sim=Combat.new()
		sim.manual_tick=true
		sim.setup(book,run,store,city)
		root.add_child(sim)
		sim.begin_wave()
		for i in range(36): enemy(Vector2(45+i%6*17,-45+i/6*18),600)
		for person in sim.formation.members: person.pos=sim.captain
		# Controlled firing range, not a survival or difficulty measurement.
		for frame in range(900):
			sim.clock+=1.0/30
			sim.captain_move=1
			if frame%150==0:
				sim.build.pickup(8)
				sim.build.heal(4,true)
			sim.build.update(1.0/30)
			sim.grid.rebuild(sim.enemies)
			sim.weapons.update(1.0/30)
			sim._update_attacks(1.0/30)
			sim._update_projectiles(1.0/30)
			sim._update_hazards(1.0/30)
		var damage=0.0
		for e in sim.enemies: damage+=e.max_hp-maxf(0,e.hp)
		check(run.kills>0 and damage>1000,"combined build operates: "+spec.name)
		results.append({"name":spec.name,"damage":damage,"kills":run.kills,"trigger_cooldowns":sim.build.gates.keys(),"bounded_pending":sim.weapons.pending.size(),"gear":run.equipment,"mods":run.mods})
		check(sim.weapons.pending.size()<80 and sim.hazards.size()<100,"no cascading explosion: "+spec.name)
		sim.queue_free()
		city.queue_free()
		await process_frame
	var file=FileAccess.open("res://tests/builds-v3-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"trials":results,"method":"30 second firing range; stationary targets, scheduled supplies and aid inputs; no claim about survival difficulty"},"\t"))
	file.close()
	print("BUILDS ",checks," FAILURES ",failures)
	quit(0 if failures.is_empty() else 1)
