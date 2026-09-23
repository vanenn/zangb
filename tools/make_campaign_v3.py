from pathlib import Path
R=Path(__file__).resolve().parents[1]
s=(R/'tests/campaign.gd').read_text(encoding='utf-8')
s=s[:s.index('func execute():')]
s=s.replace('\telse:\n\t\tvar best = 10000000.0','\telif not sim.scavenging.opened and sim.elapsed<65:\n\t\ttarget=sim.scavenging.sites[0].pos\n\telse:\n\t\tvar best = 10000000.0',1)
s += '''func pick_core(state, priorities):
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
		if strategy=="build": candidates.sort_custom(func(a,b): return (favourites.find(a.id) if a.id in favourites else 99)<(favourites.find(b.id) if b.id in favourites else 99))
		for offer in candidates:
			if hired<(1 if wave==1 else 2) and shop.buy(state,offer.uid): hired+=1
		if strategy=="build":
			for id in state.weapon_levels:
				if state.supplies>100: shop.upgrade(state,id)
		elif state.supplies>100: shop.upgrade(state,book.classes[class_id].weapon)
		sim.begin_wave()
		var steps=0
		while state.mode in ["combat","upgrade","equipment"] and steps<9000:
			if state.mode=="equipment":
				pick_core(state,gear if strategy=="build" else [])
				state.mode="combat"
			if state.mode=="upgrade":
				var choice=state.choices[0]
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
			steps+=1
			if steps%900==0: await process_frame
		var record={"wave":wave,"seconds":snappedf(sim.elapsed,0.1),"health":snappedf(state.health,0.1),"team":state.roster.size()+1,"rescued":state.rescued,"kills":state.kills,"level":state.level,"supplies":state.supplies,"remaining":sim.active_count,"damage_taken":snappedf(sim.build.damage_taken,0.1),"boss_seconds":sim.boss_duration,"scavenged":sim.scavenging.opened}
		waves.append(record)
		print("WAVE ",class_id," ",difficulty," ",seed_value," ",strategy," ",record)
		if state.health<=0 or steps>=9000: break
		if wave==10: completed=true
	var result={"class":class_id,"difficulty":difficulty,"seed":seed_value,"strategy":strategy,"build":build_id,"completed":completed,"god_mode":false,"roster":state.counts,"weapon_levels":state.weapon_levels,"mods":state.mods,"equipment":state.equipment,"supplies_spent":state.spent,"heals_bought":healed,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"waves":waves}
	var filename="res://tests/campaign-v3-%s-%s-%s-%s.json" % [class_id,difficulty,seed_value,strategy]
	var file=FileAccess.open(filename,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\\t"))
	file.close()
	print("CAMPAIGN RESULT ",filename," completed=",completed)
	sim.queue_free()
	city.queue_free()
	await process_frame
	quit()
'''
(R/'tests/campaign_v3.gd').write_text(s,encoding='utf-8')
