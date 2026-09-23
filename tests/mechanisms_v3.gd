extends "res://tests/v3.gd"

var coverage={}

func sample(id: String,enabled: bool) -> Dictionary:
	reset()
	sim.feedback.reset()
	var weapon_id=book.mods[id].weapon
	if enabled: run.mods=[id]
	var primary=enemy(Vector2(60,0))
	for offset in [Vector2(105,0),Vector2(150,0),Vector2(205,0),Vector2(265,0),Vector2(90,65),Vector2(-55,0),Vector2(225,85)]: enemy(offset)
	sim.enemies[primary].elite=true
	var w=run.weapon(weapon_id)
	if id in ["cleaver_2","chainsaw_2"]:
		sim.enemies[primary].hp=1
		sim.weapons.state("captain").heat=2
	sim.drops=[{"active":true,"pos":sim.captain+Vector2(180,0),"xp":2,"gold":1,"crate":false}]
	var result={"projectiles":0,"fields":0,"effects":0,"pending":0,"shield":0,"damage":0.0,"magnet":false,"heat":0.0,"aid":0}
	var shots=16 if weapon_id in ["water","chainsaw"] else 4
	for shot in range(shots):
		var target=primary if sim.enemies[primary].active else sim.weapons.target(sim.captain,w)
		if target>=0: sim.weapons.fire(sim.captain,w,target,"captain")
		result.projectiles+=sim.projectiles.filter(func(p): return p.active).size()
		result.pending+=sim.weapons.pending.size()
		result.effects+=sim.weapons.fx.size()
		result.heat+=sim.weapons.state("captain").heat
		for tick in range(11 if weapon_id in ["water","chainsaw"] else 45):
			advance(1.0/60)
			result.projectiles+=sim.projectiles.filter(func(p): return p.active).size()
		result.fields+=sim.hazards.size()
		result.shield=maxf(result.shield,sim.build.shield)
	advance(7)
	for e in sim.enemies: result.damage+=e.max_hp-maxf(0,e.hp)
	result.damage=snappedf(result.damage,0.001)
	result.magnet=sim.drops.any(func(d): return d.get("magnet",false))
	result.aid=sim.drops.filter(func(d): return d.has("heal")).size()
	return result

func execute():
	book=Content.new()
	var store=Store.new("res://tests/user/mechanisms-%s" % Time.get_ticks_msec())
	run=State.new(book)
	run.start("teacher",801)
	city=City.new()
	city.setup(book,"school")
	root.add_child(city)
	sim=Combat.new()
	sim.manual_tick=true
	sim.setup(book,run,store,city)
	root.add_child(sim)
	sim.begin_wave()
	for id in book.mods:
		if book.mods[id].weapon.is_empty(): continue
		var before=sample(id,false)
		var after=sample(id,true)
		coverage[id]={"before":before,"after":after}
		check(before!=after,"observable independent change: "+id)
	reset()
	var index=enemy()
	run.mods=["pickup_stride","heal_magnet","move_charge","rescue_shield","auto_aid","pickup_echo"]
	run.equipment=["magnet","flywheel","medbox","battery"]
	sim.drops=[{"active":true,"pos":sim.captain+Vector2(250,0),"xp":2,"gold":0,"crate":false}]
	sim.build.pickup(3)
	sim.build.pickup(7)
	check(sim.build.stride==2 and sim.build.pickup_charge==10 and sim.drops[0].get("magnet",false),"pickup stride, merged charge and magnet")
	sim.drops[0].magnet=false
	sim.build.heal(4,true)
	check(sim.drops[0].magnet and sim.build.med_ready,"aid magnet and emergency box ready")
	var w=run.weapon("book")
	sim.build.move_charge=4
	var hp=sim.enemies[index].hp
	sim.build.before_attack(sim.captain,w,index,"captain")
	check(is_equal_approx(w.damage,run.weapon("book").damage*1.5) and sim.build.move_charge==0,"movement strengthens next captain attack only")
	check(sim.enemies[index].hp<hp and not sim.build.med_ready,"flywheel and medical pulse hit")
	check(sim.weapons.pending.size()==1 and sim.build.pickup_charge==0,"pickup echo consumed once")
	sim.build.rescued()
	check(sim.build.shield==8,"rescue shield")
	run.health=10
	sim.build.update(0.01)
	check(run.health==30,"automatic emergency aid")
	run.health=10
	sim.build.update(0.01)
	check(run.health==10,"emergency aid cooldown")
	run.health=run.stats.max_health
	reset()
	for i in range(25):
		index=enemy(Vector2(40+i%5*27,i/5*25))
		sim.enemies[index].wet=3
	run.mods=["chain_1","chain_2"]
	run.equipment=["coil"]
	w=run.weapon("chain")
	w.jumps=20
	sim.weapons.chain(sim.captain,w,0,"captain")
	check(sim.enemies.filter(func(e): return e.hp<e.max_hp).size()<=12,"shared twelve target cap includes coil and endpoint pulse")
	check(sim.weapons.chain_hits==null,"chain context released")
	var elapsed=sim.elapsed
	var timer=sim.build.shield_life
	for mode in ["paused","upgrade","equipment"]:
		run.mode=mode
		sim.tick(2)
		check(sim.elapsed==elapsed and sim.build.shield_life==timer,"timers frozen: "+mode)
	run.mode="combat"
	reset()
	var charged=enemy()
	sim.build.pickup_charge=10
	sim.build.battery_charge=8
	sim.build.shield=20
	sim.begin_wave()
	check(sim.build.shield==0 and sim.build.battery_charge==0 and sim.build.pickup_charge==0,"camp resets temporary build state")
	for class_id in ["teacher","mechanic","guard"]:
		var easy=State.new(book)
		var hard=State.new(book)
		easy.start(class_id,99,"easy")
		hard.start(class_id,99,"challenge")
		for wave in range(1,11):
			easy.wave=wave
			hard.wave=wave
			check(is_equal_approx(easy.wave_data().hp,hard.wave_data().hp*0.7) and is_equal_approx(easy.wave_data().rate,hard.wave_data().rate*0.75),"fixed difficulty scaling %s %s" % [class_id,wave])
		var old=hard.wave_data()
		for i in range(50): hard.recruit("electrician")
		check(old==hard.wave_data(),"recruiting never scales enemies "+class_id)
		var rank1=hard.weapon(book.classes[class_id].weapon)
		hard.weapon_levels[rank1.id]=5
		var rank5=hard.weapon(rank1.id)
		check(is_equal_approx(rank5.damage,rank1.damage*1.48) and rank5.cooldown==rank1.cooldown,"weapon rank damage only "+class_id)
	# Save cleanup is exercised only in an isolated game test directory.
	var location="res://tests/user/reset-v3-%s" % Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(location)
	for file_name in ["run.json","progress.json","settings.json","run.pre-v2.json","run.json.bak","run.json.tmp","unrelated.txt"]:
		var old_file=FileAccess.open(location.path_join(file_name),FileAccess.WRITE)
		old_file.store_string("{\"version\":2}")
		old_file.close()
	var clean=Store.new(location)
	check(FileAccess.file_exists(location.path_join("unrelated.txt")) and not FileAccess.file_exists(location.path_join("run.pre-v2.json")),"reset exact allowlist preserves unrelated files")
	check(not FileAccess.file_exists(location.path_join("run.json")) and not FileAccess.file_exists(location.path_join("settings.json")),"old checkpoint and settings removed")
	var shop=load("res://scripts/shop.gd").new(book)
	run.wave=1
	run.mode="camp"
	shop.stock(run,clean.meta.unlocked)
	clean.save_run(run)
	var again=Store.new(location)
	check(again.load_run().version==3,"second launch never clears new checkpoint")
	DirAccess.remove_absolute(location.path_join("schema.json"))
	again=Store.new(location)
	check(again.load_run().version==3,"missing marker preserves version three progress")
	var file=FileAccess.open("res://tests/mechanisms-v3-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"weapon_comparisons":coverage},"\t"))
	file.close()
	print("MECHANISMS ",checks," FAILURES ",failures)
	sim.queue_free()
	city.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
