extends SceneTree

const Content = preload("res://scripts/content.gd")
const State = preload("res://scripts/run_state.gd")
const Store = preload("res://scripts/progress.gd")
const City = preload("res://scripts/city_map.gd")
const Combat = preload("res://scripts/combat.gd")
var book
var results = []
var failures = []

func _initialize(): call_deferred("execute")

func trial(id: String,enabled: bool) -> Dictionary:
	var state = State.new(book)
	state.start(id,781)
	var city = City.new()
	city.setup(book,state.map_id)
	root.add_child(city)
	var storage = Store.new("res://tests/user/tactics-%s-%s" % [id,enabled])
	var sim = Combat.new()
	sim.manual_tick = true
	sim.setup(book,state,storage,city)
	root.add_child(sim)
	sim.begin_wave()
	state.health = 10000
	sim.enemies.clear()
	sim.active_count = 0
	for f in city.fixtures:
		if f.kind == "alarm": f.active = false
	var fixture = city.fixtures[0] if id != "guard" else city.fixtures[4]
	var enemy_positions = []
	if id == "teacher":
		sim.captain = Vector2(770,450)
		if enabled: city.tick_tactics(0.81,sim.captain,true,false,[sim.captain])
		for i in range(20): enemy_positions.append(Vector2(970+i%4*18,420+i/4*15))
	elif id == "mechanic":
		sim.captain = fixture.pos+Vector2(-120,0)
		for i in range(20): enemy_positions.append(fixture.pos+Vector2(-100-i%4*12,-75+i/4*32))
	else:
		sim.captain = Vector2(1280,960)
		for i in range(20): enemy_positions.append(Vector2(1160+i%4*18,810+i/4*15))
	city.update_flow(sim.captain)
	for at in enemy_positions: sim.spawn_enemy("shambler",at)
	sim.grid.rebuild(sim.enemies)
	if enabled and id == "mechanic":
		city.tick_tactics(0.81,sim.captain,true,false,[sim.captain])
		for event in city.events:
			if event.kind == "explosion": sim.weapons.pulse(event.pos,event.radius,event.damage,event.pos)
		city.events.clear()
	if enabled and id == "guard":
		city.tick_tactics(0.81,fixture.pos+Vector2(35,0),true,false,[])
	var kills = sim.run.kills
	var first_contact = -1.0
	var close_enemy_seconds = 0.0
	var start_hp = state.health
	for step in range(360):
		city.tick_tactics(1.0/30,sim.captain,false,false,[sim.captain])
		sim.clock += 1.0/30.0
		sim.invulnerability = maxf(0,sim.invulnerability-1.0/30)
		sim._update_enemies(1.0/30)
		for e in sim.enemies:
			if not e.active: continue
			if e.pos.distance_to(sim.captain) < 90 and city.attack_clear(e.pos,sim.captain): close_enemy_seconds += 1.0/30
			if e.pos.distance_to(sim.captain) < 26 and first_contact < 0: first_contact = step/30.0
	var entry = {"map":state.map_id,"mechanism_enabled":enabled,"first_contact_seconds":first_contact,"enemy_seconds_within_90px":snappedf(close_enemy_seconds,0.01),"initial_explosion_kills":kills,"fixture_destroyed":fixture.destroyed,"health_lost":start_hp-state.health,"fixed_population":20,"duration_seconds":12,"friendly_attacks":false}
	sim.queue_free()
	city.queue_free()
	return entry

func execute():
	book = Content.new()
	for id in ["teacher","mechanic","guard"]:
		var baseline = trial(id,false)
		var tactical = trial(id,true)
		results.append(baseline)
		results.append(tactical)
		if id == "teacher" and tactical.first_contact_seconds >= 0 and tactical.first_contact_seconds <= baseline.first_contact_seconds: failures.append("door did not delay contact")
		if id == "mechanic" and tactical.initial_explosion_kills <= baseline.initial_explosion_kills: failures.append("car did not clear enemies")
		if id == "guard" and tactical.enemy_seconds_within_90px >= baseline.enemy_seconds_within_90px: failures.append("broadcast did not divert pressure")
		await process_frame
	var file = FileAccess.open("res://tests/tactics-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"trials":results,"failures":failures},"\t"))
	file.close()
	print("TACTICS ",results," FAILURES ",failures)
	quit(0 if failures.is_empty() else 1)
