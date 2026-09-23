extends SceneTree
const Content=preload("res://scripts/content.gd")
const State=preload("res://scripts/run_state.gd")
const Store=preload("res://scripts/progress.gd")
const City=preload("res://scripts/city_map.gd")
const Combat=preload("res://scripts/combat.gd")
var failures=[]
var checks=0
var sim
var city
var run
var book
func _initialize(): call_deferred("execute")
func check(ok: bool,label: String):
	checks+=1
	if not ok:
		failures.append(label)
		push_error(label)
func reset():
	sim.enemies.clear()
	sim.active_count=0
	sim.projectiles.clear()
	sim.hazards.clear()
	sim.drops.clear()
	sim.weapons.reset()
	sim.build.reset()
	run.mods.clear()
	run.equipment.clear()
	sim.captain=Vector2(1200,900)
	sim.clock=0
func enemy(offset: Vector2=Vector2(70,0),hp: float=10000) -> int:
	var index=sim.spawn_enemy("shambler",sim.captain+offset)
	sim.enemies[index].hp=hp
	sim.enemies[index].max_hp=hp
	sim.grid.rebuild(sim.enemies)
	return index
func advance(seconds: float):
	for i in range(ceili(seconds*60)):
		sim.clock+=1.0/60
		sim.weapons.update(1.0/60)
		sim.weapons.projectiles_tick(1.0/60)
		sim.weapons.fields_tick(1.0/60)
		sim.hazards=sim.hazards.filter(func(h): return h.life>0)
func execute():
	book=Content.new()
	check(book.mods.size()==36 and book.equipment.size()==12,"complete construction data")
	var shop=load("res://scripts/shop.gd").new(book)
	var store=Store.new("res://tests/user/v3-%s" % Time.get_ticks_msec())
	check(store.meta.unlocked.size()==12,"all professions unlocked")
	for seed_value in range(1000):
		var trial=State.new(book)
		trial.start(["teacher","mechanic","guard"][seed_value%3],seed_value+1)
		if seed_value%2==0:
			for id in book.survivors: trial.recruit(id)
		trial.pending_levels=1
		trial.mode="upgrade"
		trial.make_choices()
		check(trial.choices.size()==3 and trial.choices[0]!=trial.choices[1] and trial.choices[1]!=trial.choices[2] and trial.choices[0]!=trial.choices[2],"unique choices %s" % seed_value)
		check(trial.choices.all(func(id): return book.mods.has(id) and (book.mods[id].weapon.is_empty() or trial.weapon_levels.has(book.mods[id].weapon))),"eligible choices %s" % seed_value)
		trial.make_equipment_choices("electric")
		check(trial.equipment_choices.size()==3 and trial.equipment_choices.all(func(id): return book.equipment[id].requires.all(func(t): return t in trial.tags())),"equipment prerequisites %s" % seed_value)
		shop.stock(trial,store.meta.unlocked)
		var restored=State.new(book)
		check(restored.restore(JSON.parse_string(JSON.stringify(trial.snapshot()))),"restore v3 %s" % seed_value)
		restored.mode="upgrade"
		for i in range(seed_value%9): restored.rng.randi()
		trial.refresh_choices()
		restored.refresh_choices()
		check(trial.choices==restored.choices and trial.rerolls==restored.rerolls,"reroll replay %s" % seed_value)
	run=State.new(book)
	run.start("teacher",47)
	city=City.new()
	city.setup(book,"school")
	root.add_child(city)
	sim=Combat.new()
	sim.manual_tick=true
	sim.setup(book,run,store,city)
	root.add_child(sim)
	sim.begin_wave()
	for id in book.weapons:
		reset()
		var index=enemy()
		run.mods=[id+"_1",id+"_2"]
		var w=run.weapon(id)
		for shot in range(4):
			sim.weapons.fire(sim.captain,w,index,"captain")
			advance(0.8)
		check(sim.enemies[index].hp<10000,"modified weapon hits "+id)
		check(sim.projectiles.size()<100 and sim.hazards.size()<80,"bounded additional attacks "+id)
	reset()
	var index=enemy()
	run.mods=["book_2"]
	sim.weapons.fire(sim.captain,run.weapon("book"),index,"captain")
	check(sim.projectiles.size()==2,"second rotating book")
	reset()
	index=enemy()
	run.mods=["pistol_1","pistol_2"]
	for shot in range(4):
		sim.weapons.fire(sim.captain,run.weapon("pistol"),index,"captain")
		advance(0.2)
	check(sim.projectiles.size()>=2 and sim.drops.any(func(d): return d.has("heal")),"double tap and actual aid pickup")
	reset()
	index=enemy()
	run.mods=["wrench_2"]
	sim.weapons.fire(sim.captain,run.weapon("wrench"),index,"captain")
	advance(0.5)
	check(sim.build.shield==8,"wrench hit shields")
	for i in range(10): sim.build.add_shield()
	check(sim.build.shield<=run.stats.max_health*0.3,"shield cap")
	sim.build.update(3.1)
	check(sim.build.shield==0,"shield expiration")
	reset()
	index=enemy(Vector2(60,0),1)
	run.mods=["cleaver_2"]
	sim.weapons.fire(sim.captain,run.weapon("cleaver"),index,"captain")
	check(sim.weapons.pending.any(func(e): return e.kind=="reverse"),"kill generates reverse slash")
	var kills=run.kills
	sim._damage(index,100,sim.captain,"cleaver")
	check(run.kills==kills,"dead enemy cannot award twice")
	reset()
	index=enemy()
	run.mods=["chainsaw_1"]
	run.equipment=["valve"]
	for shot in range(25): sim.weapons.fire(sim.captain,run.weapon("chainsaw"),index,"captain")
	check(sim.weapons.state("captain").overheat>0 and sim.hazards.any(func(h): return h.kind=="acid" and h.secondary),"overheat acid and cooldown")
	reset()
	index=enemy()
	run.equipment=["battery","magnet","flywheel","medbox"]
	sim.build.pickup(8)
	sim.build.update(0.01)
	check(sim.enemies[index].hp<10000 and sim.build.battery_charge==0,"merged eight supplies trigger battery")
	run.equipment_choices=["coil"]
	check(not run.choose_equipment("coil") and run.choose_equipment("coil",2) and run.equipment.size()==4,"full slots require explicit replacement")
	check(not run.choose_equipment("coil",1),"equipment reward idempotent")
	reset()
	index=enemy()
	var other=enemy(Vector2(130,0))
	sim.enemies[index].wet=3
	sim.enemies[other].wet=3
	run.equipment=["coil"]
	sim._damage(index,20,sim.captain,"chain","captain",false)
	check(sim.enemies[other].hp<10000,"wet chain triggers coil")
	var before=sim.enemies[other].hp
	sim._damage(index,20,sim.captain,"chain","captain",true)
	check(sim.enemies[other].hp==before,"secondary cannot recurse")
	reset()
	index=enemy()
	run.equipment=["filter","resonator","thermos","oil"]
	sim.enemies[index].corrode=3
	sim._damage(index,10,sim.captain,"cleaver")
	check(sim.build.shield==8,"corrosion melee shield")
	sim._damage(index,10,sim.captain,"decoy")
	check(sim.enemies[index].resonance==3,"sonic applies vulnerability")
	sim.build.shield=0
	run.health=run.stats.max_health
	sim.build.heal(20,true)
	check(sim.build.shield==10,"overflow healing becomes shield")
	sim.enemies[index].burning=1
	sim._damage(index,20000,sim.captain,"book")
	check(sim.hazards.any(func(h): return h.source=="oil" and h.secondary),"burning death leaves secondary fire")
	reset()
	index=enemy()
	run.equipment=["coolant","fuse"]
	sim.weapons.state("captain").heat=2
	sim._damage(index,4,sim.captain,"water","captain")
	check(sim.weapons.state("captain").heat==1,"water cools saw state")
	sim.enemies[index].burning=1
	var near=enemy(Vector2(85,0))
	sim._damage(index,5,sim.captain,"brick")
	check(sim.enemies[near].hp<10000,"brick ignites burning group")
	reset()
	sim.scavenging.begin()
	sim.captain=sim.scavenging.sites[0].pos
	sim.scavenging.tick(2.1,true,false)
	check(sim.scavenging.opened and run.mode=="equipment" and not run.equipment_choices.is_empty(),"search opens equipment choice")
	var offers=run.equipment_choices.duplicate()
	sim.scavenging.tick(2.1,true,false)
	check(run.equipment_choices==offers,"search cannot settle twice")
	run.add_xp(100000)
	check(run.level==17 and run.pending_levels==16 and run.xp==0,"16 upgrade cap")
	var file=FileAccess.open("res://tests/v3-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	file.close()
	print("V3 ",checks," FAILURES ",failures)
	sim.queue_free()
	city.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
