extends RefCounted

var difficulty = "challenge"
var mods = []
var equipment = []
var rerolls = 2
var equipment_choices = []
var equipment_return = "combat"
var first_core = false
var content
var rng = RandomNumberGenerator.new()
var class_id = "teacher"
var map_id = "school"
var wave = 0
var supplies = 28
var health = 100.0
var level = 1
var xp = 0.0
var kills = 0
var rescued = 0
var spent = 0
var roster = []
var weapon_levels = {}
var perks = {"damage":0, "speed":0, "range":0, "pickup":0, "vitality":0, "stride":0}
var stats = {}
var counts = {}
var offers = []
var shop_serial = 0
var refreshes = 0
var mode = "camp"
var choices = []
var pending_levels = 0
var elapsed_total = 0.0
var run_id = ""
var map_state = {}
var checkpoint_position = [1200.0,900.0]

func _init(book):
	content = book

func start(id: String, seed_value: int = 0, difficulty_id: String = "challenge"):
	difficulty = difficulty_id
	class_id = id
	map_id = content.classes[id].map
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	run_id = "%s-%s-%s" % [id, Time.get_unix_time_from_system(), rng.randi()]
	weapon_levels[content.classes[id].weapon] = 1
	recalculate()
	health = stats.max_health

func recalculate():
	counts = {}
	for person in roster:
		counts[person] = int(counts.get(person, 0)) + 1
	stats = {
		"max_health":100.0 * content.classes[class_id].health_mult,
		"damage":1.0,
		"attack_speed":1.0,
		"range":1.0,
		"pickup":110.0,
		"move_speed":185.0,
		"regen":float(counts.get("nurse", 0)) * 0.18,
		"armor":0.0,
		"fire_radius":1.0
	}
	for id in counts:
		var tier = synergy_tier(id)
		var data = content.survivors[id]
		var value = tier * float(data.step)
		if data.effect == "pickup":
			stats.pickup *= 1.0 + value
		else:
			stats[data.effect] = stats.get(data.effect,0.0) + value

func synergy_tier(id: String) -> int:
	return mini(int(counts.get(id, 0)) / 2, 3)

func recruit(id: String, from_rescue: bool = false):
	assert(content.survivors.has(id))
	roster.append(id)
	var weapon = content.survivors[id].weapon
	if not weapon_levels.has(weapon):
		weapon_levels[weapon] = 1
	if from_rescue:
		rescued += 1
	recalculate()

func has_mod(id: String) -> bool:
	return id in mods

func tags() -> Array:
	var result = ["pickup","movement","rescue"]
	for id in weapon_levels:
		if id not in result: result.append(id)
		for item in content.mods.values():
			if item.weapon == id:
				for tag in item.tags:
					if tag == "healing" and id == "pistol" and not (counts.get("nurse",0)>0 or has_mod("pistol_2")): continue
					if tag not in result: result.append(tag)
	if "valve" in equipment and "acid" not in result: result.append("acid")
	if "battery" in equipment and "electric" not in result: result.append("electric")
	for id in mods:
		for tag in content.mods[id].tags:
			if tag not in result: result.append(tag)
	return result

func xp_target() -> float:
	return 30.0+(level-1)*23.0

func add_xp(amount: float):
	if level >= 17: return
	xp += amount*float(content.classes[class_id].xp_mult)
	while level < 17 and xp >= xp_target():
		xp -= xp_target()
		level += 1
		pending_levels += 1
	if level >= 17: xp = 0

func make_choices():
	if not choices.is_empty(): return
	var draw_rng=RandomNumberGenerator.new()
	draw_rng.seed=hash(str(rng.seed)+"mods"+str(level-pending_levels)+str(rerolls))
	var pool = []
	for id in content.mods:
		var item = content.mods[id]
		if id not in mods and (item.weapon.is_empty() or weapon_levels.has(item.weapon)): pool.append(id)
	var selected_tags = []
	for id in equipment:
		for tag in content.equipment[id].tags:
			if tag not in selected_tags: selected_tags.append(tag)
	# One synergy, one utility, one broader option; all are unique and usable.
	for slot in range(3):
		var preferred = pool.filter(func(id): return content.mods[id].tags.any(func(t): return t in selected_tags)) if slot == 0 else pool.filter(func(id): return content.mods[id].weapon.is_empty()) if slot == 1 else pool
		if preferred.is_empty(): preferred = pool
		if preferred.is_empty():
			choices.append(["supply","aid","refresh"][slot])
		else:
			var id = preferred[draw_rng.randi_range(0,preferred.size()-1)]
			choices.append(id)
			pool.erase(id)

func refresh_choices() -> bool:
	if mode != "upgrade" or rerolls <= 0 or pending_levels <= 0: return false
	rerolls -= 1
	choices.clear()
	make_choices()
	return true

func choose_perk(id: String) -> bool:
	if pending_levels <= 0 or id not in choices: return false
	if content.mods.has(id):
		if id in mods: return false
		mods.append(id)
	elif id == "aid": health = minf(stats.max_health,health+25)
	elif id == "supply": supplies += 20
	elif id == "refresh": rerolls += 1
	else: return false
	pending_levels -= 1
	choices.clear()
	return true

func make_equipment_choices(bias: String = ""):
	if not equipment_choices.is_empty(): return
	var draw_rng=RandomNumberGenerator.new()
	draw_rng.seed=hash(str(rng.seed)+"equipment"+str(wave)+bias)
	var available = tags()
	var pool = content.equipment.keys().filter(func(id): return id not in equipment and content.equipment[id].requires.all(func(t): return t in available))
	for slot in range(mini(3,pool.size())):
		var preferred = pool.filter(func(id): return bias in content.equipment[id].tags) if slot == 0 else pool
		if preferred.is_empty(): preferred = pool
		var id = preferred[draw_rng.randi_range(0,preferred.size()-1)]
		equipment_choices.append(id)
		pool.erase(id)

func choose_equipment(id: String, replacement: int = -1) -> bool:
	if id not in equipment_choices or id in equipment: return false
	if equipment.size() >= 4:
		if replacement < 0 or replacement >= 4: return false
		equipment[replacement] = id
	else: equipment.append(id)
	equipment_choices.clear()
	first_core = true
	return true

func wave_data() -> Dictionary:
	var data = content.wave(wave).duplicate(true)
	if difficulty == "easy":
		data.hp *= 0.7
		data.damage *= 0.7
		data.rate *= 0.75
	return data

func weapon(id: String) -> Dictionary:
	var result = content.weapons[id].duplicate(true)
	var rank = int(weapon_levels.get(id, 1))
	result.damage *= (1.0+(rank-1)*0.12)*stats.damage
	result.cooldown /= stats.attack_speed
	result.range *= stats.range
	result.splash *= stats.range
	result.rank = rank
	result.jumps += synergy_tier("electrician")
	if id == "molotov": result.splash *= stats.fire_radius
	if id == "acid": result.duration += synergy_tier("chemical_worker")*0.5
	if id == "chainsaw": result.duration += synergy_tier("firefighter")*0.4
	if id == "crossbow": result.penetration += synergy_tier("hunter")

	return result

func upgrade_price(id: String) -> int:
	return int(ceil((18 + int(weapon_levels.get(id, 1)) * 12) * content.classes[class_id].upgrade_mult))

func snapshot() -> Dictionary:
	return {"version":3,"difficulty":difficulty,"mods":mods.duplicate(),"equipment":equipment.duplicate(),"rerolls":rerolls,"choices":choices.duplicate(),"pending_levels":pending_levels,"equipment_choices":equipment_choices.duplicate(),"equipment_return":equipment_return,"first_core":first_core,"map_state":map_state.duplicate(true),"class_id":class_id,"map_id":map_id,"wave":wave,"supplies":supplies,"health":health,"level":level,"xp":xp,"kills":kills,"rescued":rescued,"spent":spent,"roster":roster.duplicate(),"weapon_levels":weapon_levels.duplicate(),"perks":perks.duplicate(),"offers":offers.duplicate(true),"shop_serial":shop_serial,"refreshes":refreshes,"elapsed_total":elapsed_total,"rng_state":str(rng.state),"rng_seed":str(rng.seed),"run_id":run_id,"checkpoint_position":checkpoint_position.duplicate()}

func restore(data: Dictionary) -> bool:
	if int(data.get("version",0)) != 3 or not content.classes.has(data.get("class_id", "")):
		return false
	if not _valid_checkpoint(data):
		return false
	for id in data.get("roster", []):
		if not content.survivors.has(id):
			return false
	for key in ["class_id","map_id","wave","supplies","health","level","xp","kills","rescued","spent","roster","weapon_levels","perks","offers","shop_serial","refreshes","elapsed_total","run_id","difficulty","mods","equipment","rerolls","choices","pending_levels","equipment_choices","equipment_return","first_core"]:
		if not data.has(key):
			return false
		set(key, data[key])
	if wave < 0 or wave > 9 or map_id != content.classes[class_id].map:
		return false
	for key in ["wave","supplies","level","kills","rescued","spent","shop_serial","refreshes"]:
		set(key,int(get(key)))
	for key in weapon_levels:
		weapon_levels[key] = int(weapon_levels[key])
	for key in perks:
		perks[key] = int(perks[key])
	for offer in offers:
		offer.cost = int(offer.cost)
	map_state = data.get("map_state",{}).duplicate(true)
	checkpoint_position = data.get("checkpoint_position",[1200.0,900.0]).duplicate()
	rng.seed = int(data.get("rng_seed","0"))
	rng.state = int(data.get("rng_state","0"))
	mode = "camp"
	pending_levels = int(pending_levels)
	rerolls = int(rerolls)
	recalculate()
	health = clampf(health, 1, stats.max_health)
	return true

func _valid_checkpoint(data: Dictionary) -> bool:
	if not data.get("map_state",{}) is Dictionary: return false
	if data.get("difficulty","") not in ["easy","challenge"]: return false
	for key in ["mods","equipment","choices","equipment_choices"]:
		if not data.get(key) is Array: return false
		var unique = {}
		for id in data[key]:
			if not id is String or unique.has(id): return false
			unique[id] = true
			if key in ["mods","choices"] and not content.mods.has(id) and (key == "mods" or id not in ["aid","supply","refresh"]): return false
			if key in ["equipment","equipment_choices"] and not content.equipment.has(id): return false
	if data.equipment.size()>4 or data.mods.size()>16 or int(data.get("rerolls",-1))<0: return false
	if data.choices.size()>3 or data.equipment_choices.size()>3: return false
	if not data.get("first_core") is bool or data.get("equipment_return") not in ["camp","combat"]: return false
	for key in ["pending_levels","rerolls"]:
		if not (data.get(key) is int or data.get(key) is float): return false
		if not is_finite(float(data[key])) or data[key]<0 or data[key]>16: return false
	if not (data.get("level") is int or data.get("level") is float) or data.level<1 or data.level>17: return false
	for key in ["wave","supplies","health","level","xp","kills","rescued","spent","shop_serial","refreshes","elapsed_total"]:
		if not data.get(key) is float and not data.get(key) is int:
			return false
		if not is_finite(float(data[key])) or float(data[key]) < 0:
			return false
	if not data.get("roster") is Array or not data.get("offers") is Array or data.offers.size() < 3:
		return false
	if not data.get("perks") is Dictionary or not data.get("weapon_levels") is Dictionary:
		return false
	for key in perks:
		if not data.perks.has(key) or not (data.perks[key] is float or data.perks[key] is int) or data.perks[key] < 0:
			return false
	if not data.weapon_levels.has(content.classes[data.class_id].weapon):
		return false
	for id in data.weapon_levels:
		if not content.weapons.has(id) or not (data.weapon_levels[id] is float or data.weapon_levels[id] is int):
			return false
		if data.weapon_levels[id] < 1 or data.weapon_levels[id] > 5:
			return false
	for offer in data.offers:
		if not offer is Dictionary or not offer.get("uid") is String or not offer.get("sold") is bool:
			return false
		if not (offer.get("cost") is float or offer.get("cost") is int) or offer.cost < 0:
			return false
		if offer.get("kind") == "person":
			if not content.survivors.has(offer.get("id")): return false
		elif offer.get("kind") == "weapon":
			if not content.weapons.has(offer.get("id")): return false
		else:
			return false
	var position = data.get("checkpoint_position",[1200.0,900.0])
	if not position is Array or position.size() != 2:
		return false
	for value in position:
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
	return true

