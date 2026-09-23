extends RefCounted

var content

func _init(book):
	content = book

func stock(run, unlocked: Array):
	run.shop_serial += 1
	run.offers.clear()
	var pool = content.survivor_pool(unlocked)
	for index in range(3):
		var candidates = pool.duplicate()
		var label = "随机人选"
		if index == 0:
			label = "已有职业补员"
			if not run.roster.is_empty(): candidates = run.counts.keys()
			if run.shop_serial == 1:
				candidates = ["electrician","chemical_worker","firefighter","hunter","sound_tech","sanitation"]
				label = "新面孔 · 首次保证"
		if index == 1:
			label = "地图倾向人选"
			candidates = content.maps[run.map_id].affinity.filter(func(id): return id in unlocked)
		if candidates.is_empty(): candidates = pool
		var id = candidates[run.rng.randi_range(0, candidates.size()-1)]
		run.offers.append({"uid":"%s-%s" % [run.shop_serial,index],"kind":"person","label":label,"id":id,"cost":int(content.survivors[id].cost) + run.wave * 2,"sold":false})
	var weapons = run.weapon_levels.keys()
	var selected = weapons[run.rng.randi_range(0, weapons.size()-1)]
	run.offers.append({"uid":"%s-3" % run.shop_serial,"kind":"weapon","id":selected,"cost":run.upgrade_price(selected),"sold":int(run.weapon_levels[selected]) >= 5})

func buy(run, uid: String) -> bool:
	if run.mode != "camp":
		return false
	for offer in run.offers:
		if offer.uid != uid:
			continue
		if offer.sold or run.supplies < offer.cost:
			return false
		if offer.kind == "weapon" and int(run.weapon_levels.get(offer.id,1)) >= 5:
			return false
		run.supplies -= int(offer.cost)
		run.spent += int(offer.cost)
		offer.sold = true
		if offer.kind == "person":
			run.recruit(offer.id)
		else:
			run.weapon_levels[offer.id] += 1
		return true
	return false

func heal(run) -> bool:
	if run.mode != "camp" or run.supplies < 20 or run.health >= run.stats.max_health:
		return false
	run.supplies -= 20
	run.spent += 20
	run.health = minf(run.health + (40 if run.difficulty == "easy" else 25), run.stats.max_health)
	return true

func upgrade(run, id: String) -> bool:
	if run.mode != "camp" or not run.weapon_levels.has(id) or int(run.weapon_levels[id]) >= 5:
		return false
	var cost = run.upgrade_price(id)
	if run.supplies < cost:
		return false
	run.supplies -= cost
	run.spent += cost
	run.weapon_levels[id] += 1
	for offer in run.offers:
		if offer.kind == "weapon" and offer.id == id:
			offer.cost = run.upgrade_price(id)
			if run.weapon_levels[id] >= 5:
				offer.sold = true
	return true

func refresh(run, unlocked: Array) -> bool:
	var price = 8 + run.refreshes * 4
	if run.mode != "camp" or run.supplies < price:
		return false
	run.supplies -= price
	run.spent += price
	run.refreshes += 1
	stock(run, unlocked)
	return true
