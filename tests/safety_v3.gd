extends SceneTree

const Content = preload("res://scripts/content.gd")
const State = preload("res://scripts/run_state.gd")
const Store = preload("res://scripts/progress.gd")
const Shop = preload("res://scripts/shop.gd")
const City = preload("res://scripts/city_map.gd")
const Combat = preload("res://scripts/combat.gd")
var book
var storage
var city
var sim
var state
var checks = 0
var failures = []

func _initialize(): call_deferred("execute")
func check(ok: bool,label: String):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func arena(rect: Rect2 = Rect2(1000,650,18,600),kind: String = "wall"):
	city.geometry.clear()
	city.fixtures.clear()
	if rect.size != Vector2.ZERO: city.geometry.append({"rect":rect,"kind":kind})
	city._rebuild_geometry()
	sim.enemies.clear()
	sim.projectiles.clear()
	sim.hazards.clear()
	sim.weapons.reset()
	sim.grid.rebuild(sim.enemies)
	sim.active_count = 0
	sim.clock = 0

func enemy(at: Vector2,id: String = "shambler") -> int:
	var index = sim.spawn_enemy(id,at)
	sim.enemies[index].hp = 10000.0
	sim.enemies[index].max_hp = 10000.0
	sim.grid.rebuild(sim.enemies)
	return index

func advance(seconds: float):
	for i in range(ceili(seconds*60)):
		sim.clock += 1.0/60
		sim.weapons.update(1.0/60)
		sim._update_projectiles(1.0/60)
		sim._update_hazards(1.0/60)

func execute():
	book = Content.new()
	storage = Store.new("res://tests/user/v2-%s" % Time.get_ticks_msec())
	state = State.new(book)
	state.start("teacher",1107)
	city = City.new()
	city.setup(book,"school")
	root.add_child(city)
	sim = Combat.new()
	sim.manual_tick = true
	sim.setup(book,state,storage,city)
	root.add_child(sim)
	sim.begin_wave()
	check(book.survivors.size() == 12 and book.weapons.size() == 15,"twelve professions and fifteen weapons")
	for id in ["electrician","chemical_worker","firefighter","hunter","sound_tech","sanitation"]:
		check(id in storage.meta.unlocked,"new profession initially unlocked "+id)
	var shop = Shop.new(book)
	state.mode = "camp"
	shop.stock(state,storage.meta.unlocked)
	check(book.survivors[state.offers[0].id].sprite >= 16,"guaranteed new profession first camp")
	state.recruit("electrician")
	shop.stock(state,storage.meta.unlocked)
	check(state.offers[0].id == "electrician","reinforcement offer matches roster")
	for i in range(6): state.recruit("electrician")
	check(state.synergy_tier("electrician") == 3 and state.weapon("chain").jumps == 6,"synergy caps at six while seven members remain")
	state.weapon_levels.chain = 5
	check(state.weapon("chain").jumps == 6,"weapon ranks no longer grant automatic mechanics")
	state.roster.clear()
	state.weapon_levels.clear()
	state.weapon_levels.book = 1
	state.recalculate()
	state.mode = "combat"
	# Four wall faces, plus a doorway frame and a corner. Logical actors are 14px away.
	var wall_cases = [
		[Rect2(1000,650,18,600),Vector2(986,900),Vector2(0,60)],
		[Rect2(1000,650,18,600),Vector2(1032,900),Vector2(0,60)],
		[Rect2(650,1000,600,18),Vector2(900,986),Vector2(60,0)],
		[Rect2(650,1000,600,18),Vector2(900,1032),Vector2(60,0)],
		[Rect2(1000,650,18,160),Vector2(986,816),Vector2(0,60)],
		[Rect2(1000,650,18,600),Vector2(986,636),Vector2(-60,0)]]
	for w_id in book.weapons:
		for ci in range(wall_cases.size()):
			var c = wall_cases[ci]
			arena(c[0])
			sim.captain = c[1]
			var index = enemy(c[1]+c[2])
			var w = state.weapon(w_id)
			check(sim.weapons.target(c[1],w) == index,"wall-side acquisition "+w_id+str(ci))
			sim.weapons.fire(c[1],w,index,"test")
			advance(6.0)
			check(sim.enemies[index].hp < 10000,"wall-side damage "+w_id+str(ci))
	# All weapons must reject targets across an unbroken solid wall.
	for w_id in book.weapons:
		arena()
		var index = enemy(Vector2(1045,900))
		check(sim.weapons.target(Vector2(975,900),state.weapon(w_id)) == -1,"solid wall blocks targeting "+w_id)
	# Swept hit order: an enemy before the wall is hit; one beyond it is protected.
	arena()
	var near = enemy(Vector2(930,900))
	var far = enemy(Vector2(1045,900))
	sim.weapons.shoot(Vector2(880,900),state.weapon("crossbow"),far,"test")
	sim._update_projectiles(0.25)
	check(sim.enemies[near].hp < 10000 and sim.enemies[far].hp == 10000,"swept projectile chooses enemy before wall; no tunneling")
	arena(Rect2(1000,650,18,600),"low")
	var low_target = enemy(Vector2(1060,900))
	check(sim.weapons.target(Vector2(950,900),state.weapon("brick")) == low_target,"brick can aim over low cover")
	check(sim.weapons.target(Vector2(950,900),state.weapon("nailgun")) == -1,"nail blocked by low cover")
	sim.weapons.fire(Vector2(950,900),state.weapon("brick"),low_target,"test")
	advance(1.0)
	check(sim.enemies[low_target].hp < 10000,"lob lands beyond low cover")
	arena()
	near = enemy(Vector2(980,900))
	far = enemy(Vector2(1045,900))
	var chain_w = state.weapon("chain")
	chain_w.jumps = 5
	sim.weapons.chain(Vector2(940,900),chain_w,near)
	check(sim.enemies[near].hp < 10000 and sim.enemies[far].hp == 10000,"chain checks every hop against walls")
	sim.weapons.pulse(Vector2(980,900),120,100,Vector2(980,900))
	check(sim.enemies[far].hp == 10000,"area impact cannot cross solid wall")
	arena(Rect2())
	near = enemy(Vector2(1150,900))
	far = enemy(Vector2(1230,900))
	var wet_target = enemy(Vector2(1200,990))
	sim.enemies[wet_target].wet = 3.0
	chain_w.jumps = 2
	sim.weapons.chain(Vector2(1100,900),chain_w,near)
	check(sim.enemies[wet_target].hp < 10000 and sim.enemies[far].hp == 10000,"chain prefers wet target over nearer dry target")
	check(10000-sim.enemies[wet_target].hp > (10000-sim.enemies[near].hp)*0.78,"wet grants extra electric damage")
	arena(Rect2())
	var armored = enemy(Vector2(1150,900),"armored")
	sim.enemies[armored].facing = PI
	sim._damage(armored,100,Vector2(1100,900))
	var protected_damage = 10000-sim.enemies[armored].hp
	sim.enemies[armored].hp = 10000
	sim.weapons.status(sim.enemies[armored],"corrode",3)
	sim._damage(armored,100,Vector2(1100,900))
	check(10000-sim.enemies[armored].hp > protected_damage,"corrosion weakens frontal armor")
	var water_w = state.weapon("water")
	sim.weapons.water(Vector2(1100,900),water_w,armored)
	check(sim.enemies[armored].wet > 0 and sim.enemies[armored].pos.x > 1150,"water wets and pushes")
	# Same source overlapping DOT zones cannot double tick, different people still add damage.
	arena(Rect2())
	near = enemy(Vector2(1100,900))
	var acid_w = state.weapon("acid")
	sim.weapons.field(Vector2(1100,900),acid_w,"ally0","acid",90,3)
	sim.weapons.field(Vector2(1160,900),acid_w,"ally0","acid",90,3)
	sim.weapons.fields_tick(0.1)
	var one_source = 10000-sim.enemies[near].hp
	sim.weapons.field(Vector2(1100,900),acid_w,"ally1","acid",90,3)
	sim.weapons.fields_tick(0.1)
	check(is_equal_approx(10000-sim.enemies[near].hp,one_source*2),"DOT source refresh vs independent contributors")
	check(sim.enemies[near].corrode > 0,"acid field applies corrosion")
	arena(Rect2())
	near = enemy(Vector2(1100,900))
	var saw = state.weapon("chainsaw")
	for i in range(30): sim.weapons.fire(Vector2(1050,900),saw,near,"sawtest")
	check(sim.weapons.state("sawtest").overheat > 0,"chainsaw overheats and stops")
	var stopped_hp = sim.enemies[near].hp
	sim.weapons.fire(Vector2(1050,900),saw,near,"sawtest")
	check(sim.enemies[near].hp == stopped_hp,"overheated chainsaw deals no damage")
	sim.weapons.update(2)
	sim.weapons.fire(Vector2(1050,900),saw,near,"sawtest")
	check(sim.enemies[near].hp < stopped_hp,"chainsaw resumes after cooling")
	var boss = enemy(Vector2(1150,900),"warden")
	sim.weapons.status(sim.enemies[boss],"stun",1)
	check(sim.enemies[boss].stun <= 0.13,"boss stun resistance")
	sim.weapons.field(Vector2(1250,900),state.weapon("decoy"),"lure","decoy",125,4)
	check(sim.weapons.lure_target(sim.enemies[near]) == Vector2(1250,900),"decoy attracts normal enemies")
	check(sim.weapons.lure_target(sim.enemies[boss]) == Vector2.INF,"boss immune to decoy")
	arena(Rect2())
	near = enemy(Vector2(1160,900))
	far = enemy(Vector2(1040,900))
	sim.weapons.melee(Vector2(1100,900),state.weapon("cleaver"),near,"cone")
	check(sim.enemies[near].hp < 10000 and sim.enemies[far].hp == 10000,"cleaver is directional rather than circular")
	arena(Rect2())
	near = enemy(Vector2(1170,900))
	far = enemy(Vector2(1240,900))
	var third = enemy(Vector2(1310,900))
	sim.weapons.shoot(Vector2(1100,900),state.weapon("nailgun"),third,"nails")
	advance(0.6)
	check(sim.enemies[near].hp < 10000 and sim.enemies[far].hp < 10000 and sim.enemies[third].hp == 10000,"level one nail stops after two targets")
	arena(Rect2())
	near = enemy(Vector2(1170,900))
	var heavy = state.weapon("wrench")
	sim.weapons.fire(Vector2(1100,900),heavy,near,"heavy")
	advance(0.3)
	check(sim.enemies[near].hp == 10000,"wrench charge precedes damage")
	advance(0.3)
	check(sim.enemies[near].hp < 10000,"wrench charge completes with heavy hit")
	arena(Rect2())
	near = enemy(Vector2(1170,900))
	boss = enemy(Vector2(1410,900),"warden")
	check(sim.weapons.target(Vector2(1100,900),state.weapon("crossbow")) == boss,"hunter prioritizes boss over nearby normal enemy")
	arena(Rect2())
	near = enemy(Vector2(1170,900))
	state.weapon_levels.book = 3
	state.mods.append("book_1")
	sim.weapons.fire(Vector2(1100,900),state.weapon("book"),near,"returning")
	advance(1.3)
	check(10000-sim.enemies[near].hp >= state.weapon("book").damage*1.99,"level three book damages on outward and return journey")
	state.weapon_levels.book = 1
	# Formation stuck recovery must make progress through the real narrow shop route.
	city.setup(book,"mall")
	var trapped = Vector2(1611.853,1175.613)
	var goal = Vector2(1554.319,1073.788)
	city.update_flow(goal)
	for step in range(450): trapped = city.move_actor(trapped,city.recovery_steer(trapped,goal,9)*185/30.0,9)
	check(trapped.distance_to(goal) < 40,"follower recovery navigates a shop corner")
	arena()
	sim.captain = Vector2(986,900)
	near = enemy(Vector2(1032,900),"charger")
	sim.enemies[near].ability = 0
	var hp = state.health
	for i in range(20): sim._update_enemies(0.03)
	check(sim.enemies[near].windup == 0 and state.health == hp,"enemy does not charge or hurt across wall")
	# Tactical mechanisms, persistence, reset and rescue priority.
	for map_id in book.maps:
		city.setup(book,map_id)
		var first = city.fixtures[0]
		var at = first.rect.position+Vector2(-40,first.rect.size.y/2)
		if first.kind in ["door","shutter"]:
			var rev = city.revision
			city.tick_tactics(0.81,at,true,false,[at])
			check(first.closed and not city.point_free(first.pos) and city.revision > rev,"door closure updates navigation "+map_id)
			if first.kind == "door":
				city.damage_fixture(first,500)
				check(first.destroyed and city.point_free(first.pos),"wood door destruction opens route")
			else:
				city.tick_tactics(8.1,at,false,false,[at])
				check(not first.closed and first.cooldown > 0,"shutter automatically opens with remaining cooldown")
		elif first.kind == "car":
			city.tick_tactics(0.81,at,true,false,[at])
			check(first.destroyed and city.point_free(first.pos) and not city.events.is_empty(),"oil car explosion opens route")
		var saved = city.snapshot()
		city.setup(book,map_id)
		city.restore(saved)
		check(city.fixtures[0].destroyed == saved[city.fixtures[0].id].destroyed,"scene damage checkpoint restored "+map_id)
		city.reset_wave()
		check(city.fixtures[0].destroyed == saved[city.fixtures[0].id].destroyed and city.fixtures[0].cooldown == 0,"wave preserves damage and resets cooldown "+map_id)
	city.setup(book,"school")
	var alarm = city.fixtures[4]
	check(city.noise_target(alarm.pos+Vector2(100,0)) == alarm.pos,"alarm redirects existing enemies")
	city.tick_tactics(0.81,alarm.pos+Vector2(55,0),true,true,[])
	check(alarm.active,"rescue priority prevents simultaneous switch activation")
	city.tick_tactics(0.81,alarm.pos+Vector2(55,0),true,false,[])
	check(not alarm.active,"E silences alarm")
	# Cached distraction must refresh on the same tick navigation expires.
	sim.enemies.clear()
	sim.active_count = 0
	sim.hazards.clear()
	for fixture in city.fixtures:
		if fixture.kind == "alarm": fixture.active = false
	sim.captain = Vector2(1200,900)
	var distracted_index = sim.spawn_enemy("shambler",Vector2(1230,900))
	var distracted = sim.enemies[distracted_index]
	distracted.distraction = Vector2(1500,900)
	distracted.nav = 0.01
	sim._update_enemies(0.02)
	check(distracted.target_pos == sim.captain,"expired lure releases cached target on navigation refresh")
	state.mode="camp"
	shop.stock(state,storage.meta.unlocked)
	var legacy=state.snapshot()
	legacy.version=2
	var restored=State.new(book)
	check(not restored.restore(legacy),"v2 checkpoints rejected after deliberate reset")
	check(restored.restore(JSON.parse_string(JSON.stringify(state.snapshot()))),"v3 checkpoint restores")
	var file = FileAccess.open("res://tests/safety-v3-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	file.close()
	print("SAFETY V3 ",checks," FAILURES ",failures)
	sim.queue_free()
	city.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
