extends SceneTree

const Content = preload("res://scripts/content.gd")
const State = preload("res://scripts/run_state.gd")
const Store = preload("res://scripts/progress.gd")
const Shop = preload("res://scripts/shop.gd")
const City = preload("res://scripts/city_map.gd")
const Combat = preload("res://scripts/combat.gd")
var checks = 0
var failures = []

func _initialize():
	call_deferred("execute")

func check(condition: bool, label: String):
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: "+label)

func execute():
	var book = Content.new()
	var shop = Shop.new(book)
	var root_path = "res://tests/user/rules-%s" % Time.get_ticks_msec()
	var storage = Store.new(root_path)
	for id in book.classes:
		var state = State.new(book)
		state.start(id,91)
		check(state.map_id == book.classes[id].map,"class map binding "+id)
		check(is_equal_approx(state.health,120.0 if id == "guard" else 100.0),"class health "+id)
		check(state.upgrade_price(book.classes[id].weapon) == (26 if id == "mechanic" else 30),"upgrade discount "+id)
		state.add_xp(10)
		check(is_equal_approx(state.xp,11.5 if id == "teacher" else 10.0),"class experience "+id)
	var state = State.new(book)
	state.start("teacher",197)
	for unused in range(6): state.recruit("repairer")
	check(state.synergy_tier("repairer") == 3,"six-person synergy")
	var bonus = state.stats.attack_speed
	for unused in range(5): state.recruit("repairer")
	check(state.roster.size() == 11 and state.synergy_tier("repairer") == 3 and state.stats.attack_speed == bonus,"unlimited bodies with capped synergy")
	state.weapon_levels.nailgun = 5
	var damage = state.weapon("nailgun").damage
	state.recruit("repairer")
	check(state.weapon("nailgun").damage == damage and state.weapon_levels.nailgun == 5,"new recruits inherit upgrades")
	state.supplies = 1000
	shop.stock(state,storage.meta.unlocked)
	var uid = state.offers[0].uid
	var cost = state.offers[0].cost
	var count = state.roster.size()
	check(shop.buy(state,uid),"can purchase")
	check(not shop.buy(state,uid) and state.roster.size() == count+1 and state.supplies == 1000-cost,"duplicate purchase prevented")
	check(not shop.upgrade(state,"nailgun"),"cannot exceed weapon rank five")
	check(shop.refresh(state,storage.meta.unlocked) and not shop.buy(state,uid),"stale offer rejected after refresh")
	state.supplies = 0
	check(not shop.buy(state,state.offers[0].uid) and not shop.heal(state),"insufficient funds rejected")
	state.mode = "combat"
	state.supplies = 1000
	check(not shop.buy(state,state.offers[0].uid),"cannot shop during combat")
	state.mode = "camp"
	check(storage.save_run(state),"checkpoint saved")
	var restored = State.new(book)
	check(restored.restore(storage.load_run()),"checkpoint loaded")
	check(restored.roster == state.roster and JSON.stringify(restored.offers) == JSON.stringify(state.offers),"roster and offers round trip")
	check(restored.rng.randi() == state.rng.randi(),"64-bit random state round trip")
	var malformed = state.snapshot()
	malformed.perks.erase("damage")
	check(not State.new(book).restore(malformed),"malformed stat dictionary rejected")
	malformed = state.snapshot()
	malformed.offers[0].cost = "free"
	check(not State.new(book).restore(malformed),"malformed shop price rejected")
	state.checkpoint_position = [1530.0,905.0]
	check(storage.save_run(state),"checkpoint backup created")
	check(restored.restore(storage.load_run()) and restored.checkpoint_position == state.checkpoint_position,"wave-start position restored")
	var corrupt = FileAccess.open(root_path.path_join("run.json"),FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	check(not storage.load_run().is_empty(),"corrupt primary falls back to backup")
	check(storage.unlock_for_wave(3) == ["chef"],"third wave unlock")
	check(storage.unlock_for_wave(5) == ["chemist"],"fifth wave unlock")
	check(storage.unlock_for_wave(5).is_empty(),"unlock idempotence")
	check(storage.finish(state,false),"result committed")
	var runs_before = storage.meta.runs
	check(storage.finish(state,false) and storage.meta.runs == runs_before and storage.load_run().is_empty(),"result idempotence and no dead run continuation")
	for map_id in book.maps:
		var city = City.new()
		city.setup(book,map_id)
		root.add_child(city)
		check(city.point_free(Vector2(1200,900)),"captain safe spawn "+map_id)
		var open_cells = 0
		var reached_cells = 0
		for i in range(city.solids.size()):
			if city.solids[i] == 0:
				open_cells += 1
				if city.flow[i] >= 0: reached_cells += 1
		check(float(reached_cells)/open_cells > 0.98,"map rooms are connected "+map_id)
		for rect in city.obstacles:
			check(not city.point_free(rect.get_center()),"solid obstacle "+map_id)
		var moved = city.move_actor(Vector2(1200,900),Vector2(-5000,0))
		check(city.point_free(moved),"movement cannot tunnel through walls "+map_id)
		if map_id == "mall":
			var stuck = Vector2(1611.853,1175.613)
			var target = Vector2(1554.319,1073.788)
			city.update_flow(target)
			for step in range(900):
				stuck = city.move_actor(stuck,city.steer(stuck,target,12.6)*40.0/30.0,12.6)
			check(stuck.distance_to(target) < 40,"cart escapes shop wall edge and reaches captain")
		city.queue_free()
	var combat_state = State.new(book)
	combat_state.start("teacher",1972)
	var city = City.new()
	city.setup(book,"school")
	root.add_child(city)
	var sim = Combat.new()
	sim.manual_tick = true
	sim.setup(book,combat_state,storage,city)
	root.add_child(sim)
	sim.begin_wave()
	sim.rescue.pos = sim.captain
	sim.test_interact = true
	sim.test_direction = Vector2.ZERO
	for i in range(60): sim.tick(1.0/30.0)
	check(combat_state.rescued == 1 and combat_state.roster.size() == 1,"rescue requires hold and recruits exactly once")
	for i in range(90): sim.tick(1.0/30.0)
	check(combat_state.rescued == 1,"held key cannot repeat rescue")
	var hp = combat_state.health
	sim._hurt(10)
	sim._hurt(10)
	check(is_equal_approx(combat_state.health,hp-10),"shared damage invulnerability window")
	combat_state.mode = "paused"
	var elapsed_before = sim.elapsed
	sim.tick(1)
	check(sim.elapsed == elapsed_before,"pause freezes simulation")
	combat_state.mode = "combat"
	var index = sim.spawn_enemy("shambler",sim.captain+Vector2(80,0))
	sim._damage(index,999,sim.captain)
	var new_index = sim.spawn_enemy("shambler",sim.captain+Vector2(100,0))
	check(new_index == index,"enemy pool reuses inactive slot")
	sim.invulnerability = 0
	combat_state.health = 2
	sim._hurt(50)
	sim.tick(1.0/30.0)
	check(combat_state.mode == "result" and combat_state.health == 0,"zero health ends the run")
	sim.queue_free()
	city.queue_free()
	await process_frame
	var result = {"checks":checks,"failures":failures}
	var output = FileAccess.open("res://tests/rules-result.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(result,"\t"))
	output.close()
	print("RULES: ",checks," checks; failures=",failures)
	quit(0 if failures.is_empty() else 1)
