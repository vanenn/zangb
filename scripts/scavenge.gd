extends RefCounted
var sim
var sites = []
var opened = false
var progress = 0.0
var selected = -1

func setup(combat): sim = combat

func begin():
	sites.clear()
	opened=false
	progress=0
	selected=-1
	var zones=sim.content.maps[sim.run.map_id].rescue_zones
	var labels={"school":["配电室","医务室"],"street":["维修间","补给车"],"mall":["音响店","急救站"]}[sim.run.map_id]
	var biases={"school":["electric","healing"],"street":["melee","pickup"],"mall":["sonic","fire"]}[sim.run.map_id]
	for i in range(2):
		var zone=zones[(sim.run.wave+i*2)%zones.size()]
		var at=sim.city.nearby_open(Vector2(zone[0],zone[1]),90,sim.run.rng)
		if i==1 and at.distance_to(sites[0].pos)<350: at=sim.city.nearby_open(sim.captain,650,sim.run.rng)
		sites.append({"pos":at,"label":labels[i],"bias":biases[i],"kind":"equipment" if sim.run.wave%2==1 else "supplies" if i==0 else "medical"})

func nearby() -> int:
	if opened: return -1
	for i in range(sites.size()):
		if sim.captain.distance_to(sites[i].pos)<78 and sim.city.attack_clear(sim.captain,sites[i].pos): return i
	return -1

func tick(delta: float,held: bool,rescue_priority: bool):
	var index=nearby()
	if index!=selected:
		progress=0
		selected=index
	if rescue_priority or index<0 or not held:
		progress=maxf(0,progress-delta)
		return
	progress += delta
	if progress<2: return
	opened=true
	var site=sites[index]
	if site.kind=="equipment":
		sim.run.make_equipment_choices(site.bias)
		if sim.run.equipment_choices.is_empty():
			sim.run.supplies+=20
			sim.message.emit("已回收备用物资 +20")
		else:
			sim.run.equipment_return="combat"
			sim.run.mode="equipment"
			sim.equipment_requested.emit()
	elif site.kind=="supplies":
		sim.run.supplies+=30
		sim.build.pickup(30)
		sim.message.emit("回收补给 +30物资")
	else:
		sim.build.heal(35,true)
		sim.run.supplies+=10
		sim.build.pickup(10)
		sim.message.emit("急救补给 +35生命 / +10物资")

func draw():
	if opened: return
	for i in range(sites.size()):
		var site=sites[i]
		sim.draw_texture_rect(sim.content.prop_textures[12],Rect2(site.pos-Vector2(31,45),Vector2(62,62)),false)
		var reward="核心装备" if site.kind=="equipment" else "30物资" if site.kind=="supplies" else "急救 / 物资"
		sim.draw_string(sim.content.font,site.pos+Vector2(-72,-52),site.label+" · "+reward,0,-1,17,Color("ded1a6"))
		if i==selected:
			sim.draw_string(sim.content.font,site.pos+Vector2(-74,45),"按住 E 搜刮 · 本波二选一",0,-1,15,Color("ded1a6"))
			sim.draw_rect(Rect2(site.pos+Vector2(-45,51),Vector2(90*progress/2,4)),Color("c0b27e"))
