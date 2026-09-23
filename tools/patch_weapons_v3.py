from pathlib import Path
p=Path(__file__).resolve().parents[1]/'scripts/weapons_runtime.gd'
s=p.read_text(encoding='utf-8')
s=s.replace('for event in ready:\n\t\tvar origin', '''for event in ready:
		if event.kind == "pulse":
			pulse(event.origin,event.radius,event.damage,event.origin,0.2,event.id,event.source,true)
			continue
		var origin''')
s=s.replace('\t\tvar selected = target(origin,event.weapon)','''		if event.kind == "reverse":
			swing(origin,event.weapon,event.direction,event.source,true)
			continue
		var selected = target(origin,event.weapon)''')
s=s.replace('elif event.kind == "crossbow": shoot(origin,event.weapon,selected,event.source)','elif event.kind == "crossbow": shoot(origin,event.weapon,selected,event.source)')
s=s.replace('elif event.kind == "pistol": shoot(origin,event.weapon,selected,event.source)','elif event.kind in ["pistol","bolt_extra"]: shoot(origin,event.weapon,selected,event.source,true)\n\t\telif event.kind == "echo": fire(origin,event.weapon,selected,event.source,true)')
s=s.replace('func fire(origin: Vector2, weapon: Dictionary, index: int, source: String):','func fire(origin: Vector2, weapon: Dictionary, index: int, source: String, secondary: bool = false):')
s=s.replace('\tvar s = state(source)\n\tmatch weapon.id:', '''	if secondary:
		weapon = weapon.duplicate(true)
		weapon.damage *= 0.5
		weapon.secondary = true
	else: sim.build.before_attack(origin,weapon,index,source)
	var s = state(source)
	s.shots = int(s.get("shots",0))+1
	match weapon.id:''')
s=s.replace('chain(origin,weapon,index)','chain(origin,weapon,index,source,secondary)').replace('acid(origin,weapon,index,source)','acid(origin,weapon,index,source,secondary)')
s=s.replace('\t\t\t\teffect("overheat",origin,origin,28,Color("bb6b48"),1.5)','\t\t\t\teffect("overheat",origin,origin,28,Color("bb6b48"),1.5)\n\t\t\t\tif not secondary: sim.build.overheat(origin,weapon,index,source)')
s=s.replace('weapon.id == "pistol" and weapon.rank >= 3','weapon.id == "pistol" and sim.run.has_mod("pistol_1") and not secondary').replace('0.16 if weapon.rank < 5 else 0.10','0.16')
a=s.index('func melee(');b=s.index('func shoot(',a)
s=s[:a]+'''func melee(origin: Vector2,w: Dictionary,selected: int,source: String,follow: bool = false):
	swing(origin,w,origin.direction_to(sim.enemies[selected].pos),source,follow or w.get("secondary",false))

func swing(origin: Vector2,w: Dictionary,direction: Vector2,source: String,secondary: bool = false):
	sim.feedback.shot(origin,direction,w.id,source)
	var reach = w.range
	var cosine = {"wrench":0.15,"baton":0.45,"cleaver":-0.15,"chainsaw":0.80}.get(w.id,0.4)
	var count = 0
	for index in sim.grid.query(origin,reach+35):
		var e = sim.enemies[index]
		if not e.active or origin.distance_to(e.pos)>reach+e.radius or direction.dot(origin.direction_to(e.pos))<cosine or not sim.city.attack_clear(origin,e.pos): continue
		sim._damage(index,w.damage*(0.5 if secondary else 1.4 if w.id == "wrench" else 1.0),origin,w.id,source,secondary)
		count += 1
		if w.id == "baton": status(e,"stun",0.22)
		if w.id == "wrench": push(e,direction,24)
	var state_data = state(source)
	if count>0 and not secondary:
		if sim.clock-state_data.last_hit>2: state_data.combo=0
		state_data.combo += 1
		state_data.last_hit = sim.clock
		if w.id == "cleaver" and sim.run.has_mod("cleaver_1") and state_data.combo%2 == 0:
			pending.append({"kind":"cleaver","delay":0.18,"origin":origin,"source":source,"weapon":w})
		if w.id == "wrench":
			if sim.run.has_mod("wrench_1"): cone(origin,direction,reach*1.6,0.55,w.damage*0.5,"wrench",source)
			if sim.run.has_mod("wrench_2") and sim.build.gate("wrench_shield",4): sim.build.add_shield()
	if not secondary and w.id == "baton":
		if sim.run.has_mod("baton_1") and state_data.combo>0 and state_data.combo%3==0: pulse(origin,100,w.damage*0.5,origin,0.45,"baton",source,true)
		if sim.run.has_mod("baton_2"): pending.append({"kind":"reverse","delay":0.12,"origin":origin,"source":source,"weapon":w,"direction":-direction})
	var kind = {"wrench":"hammer","baton":"baton","cleaver":"cleaver","chainsaw":"saw"}.get(w.id,"cleaver")
	effect(kind,origin,origin+direction*reach,reach,Color(w.color),0.22)
	sim.spatial_sound_requested.emit(kind,origin,0.72 if w.id == "chainsaw" else 1.0)

func cone(origin: Vector2,direction: Vector2,reach: float,cosine: float,damage: float,id: String,source: String):
	for index in sim.grid.query(origin,reach+30):
		var e=sim.enemies[index]
		if e.active and origin.distance_to(e.pos)<=reach and direction.dot(origin.direction_to(e.pos))>=cosine and sim.city.attack_clear(origin,e.pos):
			sim._damage(index,damage,origin,id,source,true)
			push(e,direction,20)
	effect("water" if id=="water" else "hammer",origin,origin+direction*reach,reach,Color.WHITE,0.38)

''' +s[b:]
s=s.replace('func shoot(origin: Vector2, w: Dictionary, selected: int, source: String):','func shoot(origin: Vector2, w: Dictionary, selected: int, source: String, secondary: bool = false):\n\tsecondary = secondary or w.get("secondary",false)')
s=s.replace('if w.id == "shotgun": amount = 5 + int(w.rank >= 3)*2 + int(w.rank >= 5)*2','if w.id == "shotgun": amount = 1 if sim.run.has_mod("shotgun_1") else 5').replace('if w.id == "book" and w.rank >= 5: amount = 2','if w.id == "book" and sim.run.has_mod("book_2") and not secondary: amount = 2').replace('(0.85 if w.rank >= 5 else 0.62)','0.62')
a=s.index('\t\tvar speed = maxf(1,w.speed)',s.index('func shoot'));b=s.index('\n\tsim.spatial_sound_requested',a)
s=s[:a]+'''		projectile(origin,destination,w,source,angle,secondary)
	if secondary: return
	if w.id == "shotgun" and sim.run.has_mod("shotgun_2"):
		for offset in [-0.25,0,0.25]: projectile(origin,origin-direction*w.range,w,source,direction.angle()+PI+offset,true)
	if w.id == "molotov" and sim.run.has_mod("molotov_2") and state(source).get("shots",0)%2==0:
		var end=destination+direction.orthogonal()*65
		var t=sim.city.wall_hit(origin,end,true)
		if t!=INF: end=origin.lerp(end,t).move_toward(origin,3)
		projectile(origin,end,w,source,origin.direction_to(end).angle(),true)
	if w.id == "pistol" and sim.run.has_mod("pistol_2") and state(source).get("shots",0)%4==0: sim.build.aid_drop(source,origin)
	if w.id == "crossbow" and sim.run.has_mod("crossbow_2"):
		for delay in [0.14,0.28]: pending.append({"kind":"bolt_extra","delay":delay,"origin":origin,"source":source,"weapon":w})
''' +s[b:]
where=s.index('func circle_fraction')
s=s[:where]+'''func projectile(origin: Vector2,destination: Vector2,w: Dictionary,source: String,angle: float,secondary: bool = false,excluded: Dictionary = {}):
	var speed=maxf(1,w.speed)
	var damage=w.damage*(0.5 if secondary else 1.0)
	var penetration=maxi(1,int(w.penetration))
	if w.id=="shotgun" and sim.run.has_mod("shotgun_1") and not secondary:
		damage *= 3.5
		penetration=3
	var entry={"active":true,"pos":origin,"velocity":Vector2.from_angle(angle)*speed,"damage":damage,"life":w.range/speed+0.2,"origin":origin,"color":Color(w.color),"mode":w.mode,"id":w.id,"splash":w.splash,"destination":destination,"radius":4.0,"weapon":w,"source":source,"hits":excluded.duplicate(),"remaining":penetration,"age":0.0,"returning":false,"distance":0.0,"secondary":secondary,"first_hit":false}
	if w.lob: entry.life=maxf(0.08,origin.distance_to(destination)/speed)
	entry.total_life=entry.life
	sim._projectile(entry)

func other_target(at: Vector2,reach: float,excluded: Dictionary,wet_only: bool = false) -> int:
	var best=-1
	var distance=INF
	for index in sim.grid.query(at,reach):
		var e=sim.enemies[index]
		if not e.active or excluded.has(e.uid) or (wet_only and e.get("wet",0)<=0) or not sim.city.attack_clear(at,e.pos): continue
		var d=at.distance_to(e.pos)
		if d<=reach and d<distance:
			best=index
			distance=d
	return best

''' +s[where:]
s=s.replace('for b in sim.projectiles:\n\t\tif not b.active:', 'for projectile_index in range(sim.projectiles.size()):\n\t\tvar b=sim.projectiles[projectile_index]\n\t\tif not b.active:',1)
s=s.replace('sim._damage(hit.index,damage,b.origin,b.id)','''sim._damage(hit.index,damage,b.origin,b.id,b.source,b.get("secondary",false))
			if not b.get("secondary",false):
				if b.id=="nailgun" and not b.first_hit and sim.run.has_mod("nailgun_1"):
					var other=other_target(e.pos,170,b.hits)
					if other>=0: projectile(e.pos,sim.enemies[other].pos,w,b.source,e.pos.direction_to(sim.enemies[other].pos).angle(),true,b.hits)
				if b.id=="crossbow" and (e.elite or e.boss) and sim.run.has_mod("crossbow_1") and not b.first_hit:
					for offset in [-0.3,0.3]: projectile(e.pos,e.pos+Vector2.from_angle(b.velocity.angle()+offset)*200,w,b.source,b.velocity.angle()+offset,true,b.hits)
			b.first_hit=true''')
s=s.replace('19 if w.rank < 5 else 29','19')
s=s.replace('\t\t\tif b.remaining <= 0:\n\t\t\t\tb.active', '''			if b.remaining <= 0:
				if b.id=="nailgun" and not b.get("secondary",false) and sim.run.has_mod("nailgun_2"):
					for offset in [-0.45,0,0.45]:
						var short=w.duplicate()
						short.range=180.0
						short.penetration=1
						projectile(e.pos,e.pos+b.velocity.normalized()*180,short,b.source,b.velocity.angle()+offset,true,b.hits)
				b.active''')
s=s.replace('if w.rank >= 3: b.hits.clear()','if sim.run.has_mod("book_1"): b.hits.clear()')
a=s.index('func land(');b=s.index('func status(',a)
s=s[:a]+'''func land(b: Dictionary):
	var secondary=b.get("secondary",false)
	var w=b.weapon.duplicate(true)
	w.damage=b.damage
	match b.id:
		"molotov":
			field(b.pos,w,b.source,"fire",b.splash,w.duration,secondary)
			if not secondary and sim.run.has_mod("molotov_1"):
				for offset in [-65,65]:
					var at=b.pos+b.velocity.normalized()*offset
					if sim.city.attack_clear(b.pos,at) and sim.city.point_free(at,0): field(at,w,b.source,"fire",65,3,secondary)
		"brick":
			pulse(b.pos,b.splash,b.damage,b.origin,0.3,"brick",b.source,secondary)
			if not secondary:
				if sim.run.has_mod("brick_2"): sim.build.magnet()
				if sim.run.has_mod("brick_1"):
					var excluded={}
					for i in sim.grid.query(b.pos,b.splash): excluded[sim.enemies[i].uid]=true
					var other=other_target(b.pos,220,excluded)
					if other>=0: projectile(b.pos,sim.enemies[other].pos,w,b.source,b.pos.direction_to(sim.enemies[other].pos).angle(),true)
		"decoy": field(b.pos,w,b.source,"decoy",b.splash,w.duration,secondary)
	effect("fire_burst" if b.id=="molotov" else "sonic" if b.id=="decoy" else "brick_hit",b.pos,b.pos,b.splash,b.color,0.42)
	sim.spatial_sound_requested.emit("brick" if b.id=="brick" else "decoy" if b.id=="decoy" else "fire",b.pos,1.0)

func pulse(origin: Vector2,radius: float,damage: float,source: Vector2,stun: float=0.0,kind: String="brick",owner: String="world",secondary: bool=false):
	if sim.feedback.STYLES.has(kind):
		sim.feedback.burst(origin,Vector2.UP,sim.feedback.STYLES[kind],18)
		sim.feedback.shake(origin,sim.feedback.STYLES[kind].shake,Vector2.UP)
	for index in sim.grid.query(origin,radius+40):
		var e=sim.enemies[index]
		if e.active and origin.distance_to(e.pos)<=radius+e.radius and sim.city.attack_clear(origin,e.pos):
			sim._damage(index,damage,source,kind,owner,secondary)
			status(e,"stun",stun)
			push(e,origin.direction_to(e.pos),18)

''' +s[b:]
a=s.index('func chain(');b=s.index('func acid(',a)
s=s[:a]+'''func chain(origin: Vector2,w: Dictionary,selected: int,source: String="chain",secondary: bool=false):
	var hit={}
	var queue=[{"at":origin,"index":selected,"damage":w.damage,"left":int(w.jumps),"step":0,"secondary":secondary}]
	while not queue.is_empty() and hit.size()<12:
		var branch=queue.pop_front()
		var index=int(branch.index)
		if index<0: continue
		var e=sim.enemies[index]
		if not e.active or hit.has(e.uid) or not sim.city.attack_clear(branch.at,e.pos): continue
		hit[e.uid]=true
		var at=e.pos
		var wet=e.get("wet",0)>0 or sim.city.is_wet(at)
		sim._damage(index,branch.damage*(1.5 if wet else 1.0),branch.at,"chain",source,branch.secondary)
		status(e,"stun",0.16)
		effect("arc",branch.at,at,0,Color(w.color),0.24)
		var next=other_target(at,165,hit)
		if branch.left>1 and next>=0:
			queue.append({"at":at,"index":next,"damage":branch.damage*0.78,"left":branch.left-1,"step":branch.step+1,"secondary":branch.secondary})
		elif sim.run.has_mod("chain_2") and not branch.secondary: pulse(at,65,w.damage*0.5,at,0,"chain",source,true)
		if branch.step==1 and not branch.secondary and sim.run.has_mod("chain_1"):
			var excluded=hit.duplicate()
			if next>=0: excluded[sim.enemies[next].uid]=true
			var side=other_target(at,165,excluded)
			if side>=0: queue.append({"at":at,"index":side,"damage":w.damage*0.5,"left":2,"step":0,"secondary":true})
	sim.spatial_sound_requested.emit("arc",origin,0.75)

''' +s[b:]
s=s.replace('func acid(origin: Vector2,w: Dictionary,index: int,source: String):','func acid(origin: Vector2,w: Dictionary,index: int,source: String,secondary: bool=false):').replace('range(3 if w.rank < 5 else 5)','range(3)').replace('(0.35 if w.rank < 3 else 0.48)','0.35')
s=s.replace('field(end,w,source,"acid",w.splash,w.duration)','''field(end,w,source,"acid",w.splash,w.duration,secondary)
		if sim.run.has_mod("acid_2") and not secondary:
			for fraction in [0.35,0.65]: field(origin.lerp(end,fraction),w,source,"acid",65,3,secondary)''')
s=s.replace('var direction = origin.direction_to(sim.enemies[index].pos)\n\tfor other in sim.grid.query', '''var direction = origin.direction_to(sim.enemies[index].pos)
	var directions=[direction.rotated(-0.22),direction.rotated(0.22)] if sim.run.has_mod("water_1") else [direction]
	for other in sim.grid.query''')
s=s.replace('origin.direction_to(e.pos).dot(direction) < (0.84 if w.rank >= 3 else 0.94)','not directions.any(func(d): return origin.direction_to(e.pos).dot(d)>=0.94)')
s=s.replace('sim._damage(other,w.damage,origin,"water")','sim._damage(other,w.damage,origin,"water",source,w.get("secondary",false))')
s=s.replace('effect("water",origin,origin+direction*w.range,w.range,Color(w.color),0.18)','''for d in directions: effect("water",origin,origin+d*w.range,w.range,Color(w.color),0.18)
	var s=state(source)
	if sim.clock-s.get("last_water",-10)>0.5: s.water_time=0.0
	s.last_water=sim.clock
	s.water_time=s.get("water_time",0.0)+w.cooldown
	if s.water_time>=2 and sim.run.has_mod("water_2") and not w.get("secondary",false):
		s.water_time=0
		cone(origin,direction,w.range*1.2,0.65,w.damage*0.5,"water",source)''')
s=s.replace('func field(at: Vector2,w: Dictionary,source: String,kind: String,radius: float,duration: float):','func field(at: Vector2,w: Dictionary,source: String,kind: String,radius: float,duration: float,secondary: bool=false):')
s=s.replace('"color":Color(w.color)})','"color":Color(w.color),"secondary":secondary})')
a=s.index('func fields_tick(');b=s.index('func lure_target(',a)
s=s[:a]+'''func fields_tick(delta: float):
	for hazard_index in range(sim.hazards.size()):
		var h=sim.hazards[hazard_index]
		if not h.get("friendly",false): continue
		h.life -= delta
		h.tick -= delta
		var secondary=h.get("secondary",false)
		if h.kind=="decoy":
			if h.life<=0:
				pulse(h.pos,h.radius,h.damage,h.pos,0.35,"decoy",h.source,secondary)
				if sim.run.has_mod("decoy_1") and not secondary: pending.append({"kind":"pulse","delay":0.35,"origin":h.pos,"radius":h.radius,"damage":h.damage*0.5,"id":"decoy","source":h.source})
			elif h.tick<=0 and sim.run.has_mod("decoy_2") and not secondary:
				h.tick=1.0
				pulse(h.pos,h.radius,h.damage*0.25,h.pos,0,"decoy",h.source,false)
			continue
		if h.life<=0:
			if h.kind=="acid" and sim.run.has_mod("acid_1") and not secondary: pulse(h.pos,h.radius+30,h.damage*0.5,h.pos,0,"acid",h.source,true)
			continue
		if h.tick>0: continue
		h.tick=0.5
		for index in sim.grid.query(h.pos,h.radius+35):
			var e=sim.enemies[index]
			if not e.active or h.pos.distance_to(e.pos)>h.radius+e.radius or not sim.city.attack_clear(h.pos,e.pos): continue
			if not e.has("dot"): e.dot={}
			var key=h.source+h.kind
			if e.dot.get(key,-1)>sim.clock: continue
			e.dot[key]=sim.clock+0.49
			if h.kind=="acid": status(e,"corrode",3.0)
			else: e.burning=1.0
			sim._damage(index,h.damage*0.5,h.pos,"acid" if h.kind=="acid" else "molotov",h.source,secondary)

''' +s[b:]
p.write_text(s,encoding='utf-8')
