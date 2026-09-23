extends RefCounted

var sim
var gates = {}
var shield = 0.0
var shield_life = 0.0
var move_charge = 0.0
var pickup_charge = 0
var battery_charge = 0
var magnet_charge = 0
var stride = 0.0
var med_ready = false
var aid_times = {}
var damage_taken = 0.0
var proc_count = 0
var overflow_bank = 0.0

func setup(combat): sim = combat

func reset():
	gates.clear()
	shield = 0
	shield_life = 0
	move_charge = 0
	pickup_charge = 0
	battery_charge = 0
	magnet_charge = 0
	stride = 0
	med_ready = false
	aid_times.clear()
	overflow_bank = 0

func mod(id: String) -> bool: return sim.run.has_mod(id)
func equipped(id: String) -> bool: return id in sim.run.equipment

func gate(id: String, delay: float) -> bool:
	if gates.get(id,-1.0)>sim.clock: return false
	gates[id] = sim.clock+delay
	return true

func update(delta: float):
	stride = maxf(0,stride-delta)
	shield_life -= delta
	if shield_life <= 0: shield = 0
	if sim.captain_move > 0.1: move_charge = minf(4,move_charge+delta)
	if mod("auto_aid") and sim.run.health < sim.run.stats.max_health*0.3 and gate("auto_aid",30): heal(20,true)
	if battery_charge >= 8 and equipped("battery"):
		var target = sim._nearest(sim.captain,320)
		if target >= 0 and gate("battery",1):
			battery_charge -= 8
			var w = sim.run.weapon("chain")
			w.damage = 24.0
			w.jumps = 3
			sim.weapons.chain(sim.captain,w,target,"equipment",true)

func add_shield(amount: float = 8.0):
	shield = minf(sim.run.stats.max_health*0.3,shield+amount)
	shield_life = 3
	sim.feedback.add_animation(sim.captain-Vector2(0,20),"armor_hit",Vector2(92,92),0.4)

func heal(amount: float, pack: bool = false):
	var overflow = maxf(0,sim.run.health+amount-sim.run.stats.max_health)
	sim.run.health = minf(sim.run.stats.max_health,sim.run.health+amount)
	if equipped("thermos"):
		overflow_bank=minf(sim.run.stats.max_health*0.6,overflow_bank+overflow)
		if overflow_bank>=1 and gate("thermos",4):
			add_shield(overflow_bank*0.5)
			overflow_bank=0
	if pack:
		if mod("heal_magnet"): magnet()
		if equipped("medbox"): med_ready = true
		sim.feedback.add_animation(sim.captain-Vector2(0,25),"water_loop",Vector2(78,78),0.45)

func absorb(amount: float) -> float:
	var used = minf(shield,amount)
	shield -= used
	damage_taken += amount-used
	return amount-used

func magnet():
	for item in sim.drops:
		if item.active and item.pos.distance_to(sim.captain)<330 and sim.city.attack_clear(sim.captain,item.pos): item.magnet = true
	sim.feedback.add_animation(sim.captain,"sonic",Vector2(185,185),0.5)

func pickup(gold: int):
	if gold <= 0: return
	if mod("pickup_stride"): stride = 2
	if mod("pickup_echo"): pickup_charge = mini(10,pickup_charge+gold)
	if equipped("battery"): battery_charge = mini(16,battery_charge+gold)
	if equipped("magnet"):
		magnet_charge += gold
		if magnet_charge >= 10 and gate("magnet",1):
			magnet_charge %= 10
			magnet()

func aid_drop(source: String, at: Vector2):
	if aid_times.get(source,-1)>sim.clock: return
	aid_times[source] = sim.clock+4
	sim.drops.append({"active":true,"pos":at,"xp":0.0,"gold":0,"crate":false,"heal":4.0})

func before_attack(origin: Vector2,w: Dictionary,index: int,source: String):
	if source != "captain": return
	if pickup_charge >= 10 and mod("pickup_echo"):
		pickup_charge = 0
		sim.weapons.pending.append({"kind":"echo","delay":0.12,"origin":origin,"source":source,"weapon":w.duplicate(true)})
	if move_charge>=4 and (mod("move_charge") or equipped("flywheel")):
		move_charge = 0
		if mod("move_charge"): w.damage *= 1.5
		if equipped("flywheel"): sim.weapons.pulse(sim.enemies[index].pos,65,w.damage*0.5,origin,0.15,"wrench",source,true)
	if med_ready:
		med_ready = false
		sim.weapons.pulse(origin,100,12,origin,0.2,"decoy",source,true)

func hit(enemy: Dictionary,origin: Vector2,id: String,source: String,base: float,secondary: bool):
	if secondary: return
	if id == "decoy" and equipped("resonator"): enemy.resonance = 3.0
	if id == "water" and equipped("coolant") and gate("coolant",4):
		for key in sim.weapons.states:
			if sim.weapons.source_position(key,origin).distance_to(origin) <= 240:
				sim.weapons.states[key].heat = maxf(0,sim.weapons.states[key].heat-1.0)
				sim.weapons.states[key].overheat = maxf(0,sim.weapons.states[key].overheat-0.5)
	if id in ["wrench","baton","cleaver","chainsaw"] and enemy.get("corrode",0)>0 and equipped("filter") and gate("filter",4): add_shield()
	if id == "chain" and enemy.get("wet",0)>0 and equipped("coil") and gate("coil",1):
		var excluded=sim.weapons.chain_hits.duplicate() if sim.weapons.chain_hits is Dictionary else {enemy.uid:true}
		var index = sim.weapons.other_target(enemy.pos,165,excluded,true)
		if index >= 0:
			var next = sim.enemies[index]
			sim.weapons.effect("arc",enemy.pos,next.pos,0,Color("97cdd5"),0.28)
			sim._damage(index,base*0.5,enemy.pos,"chain",source,true)
	if id == "brick" and enemy.get("burning",0)>0 and equipped("fuse") and gate("fuse",1): sim.weapons.pulse(enemy.pos,65,base*0.5,origin,0,"molotov",source,true)

func killed(enemy: Dictionary,origin: Vector2,id: String,source: String,base: float,secondary: bool):
	if secondary: return
	if enemy.get("burning",0)>0 and equipped("oil") and gate("oil",1):
		var w = sim.run.weapon("molotov")
		w.damage = base*0.25
		sim.weapons.field(enemy.pos,w,"oil","fire",65,3,true)
	if id == "chainsaw" and mod("chainsaw_2") and gate("saw_kill_"+source,1):
		var state = sim.weapons.state(source)
		state.heat = maxf(0,state.heat-0.7)
	if id == "cleaver" and mod("cleaver_2") and gate("cleaver_kill_"+source,1):
		sim.weapons.pending.append({"kind":"reverse","delay":0.08,"origin":origin,"source":source,"weapon":sim.run.weapon("cleaver"),"direction":enemy.pos.direction_to(origin)})

func overheat(origin: Vector2,w: Dictionary,index: int,source: String):
	if mod("chainsaw_1"): sim.weapons.pulse(origin,110,w.damage*0.5,origin,0.35,"water",source,true)
	if equipped("valve") and gate("valve",1):
		var acid = sim.run.weapon("acid")
		acid.damage = w.damage*0.25
		acid.range = 150.0
		acid.duration = 3.0
		sim.weapons.acid(origin,acid,index,source+"_valve",true)

func rescued():
	if mod("rescue_shield"): add_shield()
