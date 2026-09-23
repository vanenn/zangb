extends RefCounted

var sim
var fx = []
var pending = []
var states = {}
var chain_hits = null

func setup(combat):
	sim = combat

func reset():
	fx.clear()
	pending.clear()
	states.clear()

func target(origin: Vector2, weapon: Dictionary) -> int:
	var best = -1
	var score = INF
	for index in sim.grid.query(origin,weapon.range):
		var e = sim.enemies[index]
		if not e.active or origin.distance_to(e.pos) > weapon.range or not sim.city.attack_clear(origin,e.pos,weapon.lob): continue
		var value = origin.distance_to(e.pos)
		if weapon.targeting == "elite" and (e.elite or e.boss): value -= 1000
		if weapon.targeting == "wet" and e.get("wet",0) > 0: value -= 500
		if weapon.targeting == "cluster":
			# Spatial cell population estimates density without an all-pairs scan.
			var bucket = Vector2i(floori(e.pos.x/112.0),floori(e.pos.y/112.0))
			value -= mini(sim.grid.buckets.get(bucket,[]).size(),12)*22
		if value < score:
			score = value
			best = index
	return best

func state(source: String) -> Dictionary:
	if not states.has(source): states[source] = {"heat":0.0,"overheat":0.0,"combo":0,"last_hit":-10.0}
	return states[source]

func update(delta: float):
	for s in states.values():
		s.overheat = maxf(0,s.overheat-delta)
		s.heat = maxf(0,s.heat-delta*0.22)
	for effect in fx: effect.life -= delta
	fx = fx.filter(func(f): return f.life > 0)
	var ready = []
	for event in pending:
		event.delay -= delta
		if event.delay <= 0: ready.append(event)
	pending = pending.filter(func(p): return p.delay > 0)
	for event in ready:
		if event.kind == "pulse":
			pulse(event.origin,event.radius,event.damage,event.origin,0.2,event.id,event.source,true)
			continue
		var origin = source_position(event.source,event.origin)
		if event.kind == "reverse":
			swing(origin,event.weapon,event.direction,event.source,true)
			continue
		var selected = target(origin,event.weapon)
		if selected < 0: continue
		if event.kind == "heavy": melee(origin,event.weapon,selected,event.source)
		elif event.kind == "crossbow": shoot(origin,event.weapon,selected,event.source)
		elif event.kind in ["pistol","bolt_extra"]: shoot(origin,event.weapon,selected,event.source,true)
		elif event.kind == "echo": fire(origin,event.weapon,selected,event.source,true)
		elif event.kind == "cleaver": melee(origin,event.weapon,selected,event.source,true)

func source_position(source: String, fallback: Vector2) -> Vector2:
	if source == "captain": return sim.captain
	if source.begins_with("ally"):
		var index = int(source.trim_prefix("ally"))
		if index < sim.formation.members.size(): return sim.formation.members[index].pos
	return fallback

func effect(kind: String, pos: Vector2, end: Vector2, radius: float, color: Color, life: float = 0.22):
	if fx.size() < 900: fx.append({"kind":kind,"pos":pos,"end":end,"radius":radius,"color":color,"life":life,"max":life})

func fire(origin: Vector2, weapon: Dictionary, index: int, source: String, secondary: bool = false):
	if index < 0 or not sim.enemies[index].active: return
	if secondary:
		weapon = weapon.duplicate(true)
		if weapon.id in ["chain","acid","water"]: weapon.damage *= 0.5
		weapon.secondary = true
	else: sim.build.before_attack(origin,weapon,index,source)
	var s = state(source)
	s.shots = int(s.get("shots",0))+1
	match weapon.id:
		"wrench", "crossbow":
			sim.feedback.shot(origin,origin.direction_to(sim.enemies[index].pos),weapon.id,source,true)
			var delay = 0.42 if weapon.id == "wrench" else 0.65
			pending.append({"kind":"heavy" if weapon.id == "wrench" else "crossbow","delay":delay,"origin":origin,"source":source,"weapon":weapon})
			effect("charge",origin,sim.enemies[index].pos,weapon.range,Color(weapon.color),delay)
			sim.spatial_sound_requested.emit("charge",origin,0.7)
		"baton", "cleaver": melee(origin,weapon,index,source)
		"chain":
			sim.feedback.shot(origin,origin.direction_to(sim.enemies[index].pos),weapon.id,source)
			chain(origin,weapon,index,source,secondary)
		"acid": acid(origin,weapon,index,source,secondary)
		"chainsaw":
			if s.overheat > 0: return
			s.heat += weapon.cooldown*1.22
			melee(origin,weapon,index,source)
			if s.heat >= weapon.duration:
				s.overheat = 1.8
				s.heat = 0
				effect("overheat",origin,origin,28,Color("bb6b48"),1.5)
				if not secondary: sim.build.overheat(origin,weapon,index,source)
		"water": water(origin,weapon,index,source)
		_:
			shoot(origin,weapon,index,source)
			if weapon.id == "pistol" and sim.run.has_mod("pistol_1") and not secondary:
				pending.append({"kind":"pistol","delay":0.16,"origin":origin,"source":source,"weapon":weapon})

func melee(origin: Vector2,w: Dictionary,selected: int,source: String,follow: bool = false):
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

func shoot(origin: Vector2, w: Dictionary, selected: int, source: String, secondary: bool = false):
	secondary = secondary or w.get("secondary",false)
	var destination = sim.enemies[selected].pos
	var direction = origin.direction_to(destination)
	sim.feedback.shot(origin,direction,w.id,source)
	var amount = 1
	if w.id == "shotgun": amount = 1 if sim.run.has_mod("shotgun_1") else 5
	if w.id == "book" and sim.run.has_mod("book_2") and not secondary: amount = 2
	for i in range(amount):
		var angle = direction.angle()
		if amount > 1: angle += (float(i)/float(amount-1)-0.5)*0.62
		if w.id == "book": angle = direction.angle()+i*0.23
		projectile(origin,destination,w,source,angle,secondary or (w.id=="book" and i>0))
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

	sim.spatial_sound_requested.emit({"book":"book","molotov":"fire","nailgun":"nail","shotgun":"shotgun","pistol":"pistol","brick":"brick","crossbow":"bow","decoy":"decoy"}.get(w.id,"shot"),origin,1.0)

func projectile(origin: Vector2,destination: Vector2,w: Dictionary,source: String,angle: float,secondary: bool = false,excluded: Dictionary = {}):
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

func other_target(at: Vector2,reach: float,excluded: Dictionary,wet_only: bool = false,prefer_wet: bool = false) -> int:
	var best=-1
	var distance=INF
	for index in sim.grid.query(at,reach):
		var e=sim.enemies[index]
		if not e.active or excluded.has(e.uid) or (wet_only and e.get("wet",0)<=0) or not sim.city.attack_clear(at,e.pos): continue
		var d=at.distance_to(e.pos)
		var score=d-(180 if prefer_wet and (e.get("wet",0)>0 or sim.city.is_wet(e.pos)) else 0)
		if d<=reach and score<distance:
			best=index
			distance=score
	return best

func circle_fraction(a: Vector2,b: Vector2,center: Vector2,radius: float) -> float:
	var d = b-a
	var f = a-center
	var aa = d.dot(d)
	if f.length_squared() <= radius*radius: return 0
	if aa < 0.00001: return INF
	var bb = 2*f.dot(d)
	var cc = f.dot(f)-radius*radius
	var disc = bb*bb-4*aa*cc
	if disc < 0: return INF
	var t = (-bb-sqrt(disc))/(2*aa)
	return t if t >= 0 and t <= 1 else INF

func projectiles_tick(delta: float):
	for projectile_index in range(sim.projectiles.size()):
		var b=sim.projectiles[projectile_index]
		if not b.active: continue
		b.life -= delta
		b.age += delta
		var before = b.pos
		var destination = b.pos+b.velocity*delta
		var w = b.weapon
		if w.lob:
			destination = b.origin.lerp(b.destination,minf(1,b.age/maxf(0.01,b.total_life)))
		var wall_t = sim.city.wall_hit(before,destination,w.lob)
		if w.lob:
			b.pos = destination
			if wall_t != INF:
				b.pos = before.lerp(destination,wall_t).move_toward(before,2)
				land(b)
				b.active = false
			elif b.life <= 0:
				land(b)
				b.active = false
			continue
		var hits = []
		for index in sim.grid.query((before+destination)*0.5,before.distance_to(destination)*0.5+55):
			var e = sim.enemies[index]
			if not e.active or b.hits.has(e.uid): continue
			var t = circle_fraction(before,destination,e.pos,e.radius+b.radius)
			if t < wall_t and t != INF and sim.city.attack_clear(before,e.pos): hits.append({"index":index,"t":t})
		hits.sort_custom(func(a,c): return a.t < c.t)
		for hit in hits:
			var e = sim.enemies[hit.index]
			b.hits[e.uid] = true
			var damage = b.damage
			if b.id == "shotgun": damage *= clampf(1.25-b.origin.distance_to(e.pos)/w.range,0.30,1.25)
			sim._damage(hit.index,damage,b.origin,b.id,b.source,b.get("secondary",false))
			if not b.get("secondary",false):
				if b.id=="nailgun" and not b.first_hit and sim.run.has_mod("nailgun_1"):
					var other=other_target(e.pos,170,b.hits)
					if other>=0: projectile(e.pos,sim.enemies[other].pos,w,b.source,e.pos.direction_to(sim.enemies[other].pos).angle(),true,b.hits)
				if b.id=="crossbow" and (e.elite or e.boss) and sim.run.has_mod("crossbow_1") and not b.first_hit:
					for offset in [-0.3,0.3]: projectile(e.pos,e.pos+Vector2.from_angle(b.velocity.angle()+offset)*200,w,b.source,b.velocity.angle()+offset,true,b.hits)
			b.first_hit=true
			if b.id == "shotgun": push(e,b.velocity.normalized(),19)
			b.remaining -= 1
			if b.remaining <= 0:
				if b.id=="nailgun" and not b.get("secondary",false) and sim.run.has_mod("nailgun_2"):
					for offset in [-0.45,0,0.45]:
						var short=w.duplicate()
						short.range=180.0
						short.penetration=1
						projectile(e.pos,e.pos+b.velocity.normalized()*180,short,b.source,b.velocity.angle()+offset,true,b.hits)
				b.active = false
				b.pos = before.lerp(destination,hit.t)
				break
		if not b.active and b.id=="book" and not b.returning and b.remaining<=0:
			b.returning=true
			b.active=true
			b.remaining=4
			destination=b.pos
			if sim.run.has_mod("book_1") and not b.get("secondary",false): b.hits.clear()
		if not b.active: continue
		b.pos = destination
		b.distance += before.distance_to(destination)
		if wall_t != INF:
			b.pos = before.lerp(destination,wall_t).move_toward(before,1)
			var block = sim.city.blocker(before,destination)
			if not block.is_empty(): sim.city.damage_fixture(block,b.damage*0.7)
			b.active = false
		if b.id == "book":
			if not b.returning and (b.life <= b.total_life*0.5 or not b.active):
				b.returning = true
				b.active = sim.city.attack_clear(b.pos,source_position(b.source,b.origin))
				b.remaining = 4
				if sim.run.has_mod("book_1") and not b.get("secondary",false): b.hits.clear()
			if b.returning:
				var home = source_position(b.source,b.origin)
				b.velocity = b.pos.direction_to(home)*w.speed
				if b.pos.distance_to(home) < 15: b.active = false
		if b.life <= 0: b.active = false

func land(b: Dictionary):
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

func status(e: Dictionary, kind: String, duration: float):
	if duration <= 0: return
	if kind == "stun":
		if e.get("resolve",0) > 0: return
		duration = minf(duration,0.7)*(0.18 if e.boss else 1.0)
		e.resolve = duration+(2.5 if e.boss else 0.9)
	if kind == "corrode": duration = minf(duration,4.0)
	if kind == "wet": duration = minf(duration,4.0)
	e[kind] = maxf(e.get(kind,0),duration)

func push(e: Dictionary, direction: Vector2, force: float):
	if sim.clock>=e.get("push_reset",-1):
		e.push_reset=sim.clock+0.5
		e.push_budget=10.0
	var applied=minf(force,e.get("push_budget",10.0))
	e.push_budget=maxf(0,e.get("push_budget",10.0)-applied)
	e.pos = sim.city.move_actor(e.pos,direction*applied*(0.12 if e.boss else 1.0),e.radius*0.6)

func chain(origin: Vector2,w: Dictionary,selected: int,source: String="chain",secondary: bool=false):
	var hit={}
	var previous_hits=chain_hits
	chain_hits=hit
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
		var next=other_target(at,165,hit,false,true)
		if branch.left>1 and next>=0:
			queue.append({"at":at,"index":next,"damage":branch.damage*0.78,"left":branch.left-1,"step":branch.step+1,"secondary":branch.secondary})
		elif sim.run.has_mod("chain_2") and not branch.secondary: pulse(at,65,w.damage*0.5,at,0,"chain",source,true)
		if branch.step==1 and not branch.secondary and sim.run.has_mod("chain_1"):
			var excluded=hit.duplicate()
			if next>=0: excluded[sim.enemies[next].uid]=true
			var side=other_target(at,165,excluded,false,true)
			if side>=0: queue.append({"at":at,"index":side,"damage":w.damage*0.5,"left":2,"step":0,"secondary":true})
	chain_hits=previous_hits
	sim.spatial_sound_requested.emit("arc",origin,0.75)

func acid(origin: Vector2,w: Dictionary,index: int,source: String,secondary: bool=false):
	var direction = origin.direction_to(sim.enemies[index].pos)
	sim.feedback.shot(origin,direction,"acid",source)
	for i in range(3):
		var angle = direction.angle()+(i%3-1)*0.35
		var end = origin+Vector2.from_angle(angle)*minf(w.range,origin.distance_to(sim.enemies[index].pos))*(0.60 if i >= 3 else 1.0)
		var t = sim.city.wall_hit(origin,end)
		if t != INF: end = origin.lerp(end,t).move_toward(origin,3)
		field(end,w,source,"acid",w.splash,w.duration,secondary)
		if sim.run.has_mod("acid_2") and not secondary:
			for fraction in [0.35,0.65]: field(origin.lerp(end,fraction),w,source,"acid",65,3,secondary)
		effect("acid",origin,end,w.splash,Color(w.color),0.45)
	sim.spatial_sound_requested.emit("acid",origin,0.75)

func water(origin: Vector2,w: Dictionary,index: int,source: String = "water"):
	sim.feedback.shot(origin,origin.direction_to(sim.enemies[index].pos),w.id,source)
	var direction = origin.direction_to(sim.enemies[index].pos)
	var directions=[direction.rotated(-0.22),direction.rotated(0.22)] if sim.run.has_mod("water_1") else [direction]
	for other in sim.grid.query(origin,w.range+25):
		var e = sim.enemies[other]
		if not e.active or origin.distance_to(e.pos) > w.range or not directions.any(func(d): return origin.direction_to(e.pos).dot(d)>=0.94) or not sim.city.attack_clear(origin,e.pos): continue
		status(e,"wet",3.5)
		status(e,"slow",0.35)
		sim._damage(other,w.damage,origin,"water",source,w.get("secondary",false))
		push(e,direction,7*(1+sim.run.synergy_tier("sanitation")*0.15))
	for d in directions: effect("water",origin,origin+d*w.range,w.range,Color(w.color),0.18)
	var s=state(source)
	if sim.clock-s.get("last_water",-10)>0.5: s.water_time=0.0
	s.last_water=sim.clock
	s.water_time=s.get("water_time",0.0)+w.cooldown
	if s.water_time>=2 and sim.run.has_mod("water_2") and not w.get("secondary",false):
		s.water_time=0
		cone(origin,direction,w.range*1.2,0.65,w.damage*0.5,"water",source)
	sim.spatial_sound_requested.emit("water",origin,0.75)

func field(at: Vector2,w: Dictionary,source: String,kind: String,radius: float,duration: float,secondary: bool=false):
	for h in sim.hazards:
		if h.get("source","") == source and h.get("kind","") == kind and h.pos.distance_to(at) < radius*0.55:
			h.life = duration
			return
	sim.hazards.append({"pos":at,"radius":radius,"life":duration,"damage":w.damage,"delay":0.0,"tick":0.0,"friendly":true,"source":source,"kind":kind,"color":Color(w.color),"secondary":secondary})

func fields_tick(delta: float):
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

func lure_target(e: Dictionary) -> Vector2:
	if e.boss or e.elite: return Vector2.INF
	var nearest = Vector2.INF
	var distance = 390.0*(1+sim.run.synergy_tier("sound_tech")*0.15)
	for h in sim.hazards:
		if h.get("kind","") == "decoy" and h.life > 0 and e.pos.distance_to(h.pos) < distance:
			distance = e.pos.distance_to(h.pos)
			nearest = h.pos
	return nearest

# Texture UVs clip authored animation to the same physical walls as damage.
func draw_field(h: Dictionary, clip: String, tint: Color):
	if h.get("draw_revision",-1) != sim.city.revision:
		var boundary = PackedVector2Array()
		for i in range(32):
			var point = h.pos+Vector2.from_angle(i*TAU/32)*h.radius
			var t = sim.city.wall_hit(h.pos,point)
			boundary.append(h.pos.lerp(point,t) if t != INF else point)
		h.polygon = boundary
		h.draw_revision = sim.city.revision
	var frame = sim.content.effect_frame(clip,fposmod(sim.clock*1.6+h.pos.x*0.01,1.0))
	var uv = PackedVector2Array()
	for point in h.polygon:
		var local = (point-h.pos)/(h.radius*2)+Vector2(0.5,0.5)
		uv.append((frame.region.position+local*frame.region.size)/frame.atlas.get_size())
	sim.draw_polygon(h.polygon,PackedColorArray([tint]),uv,frame.atlas)

func sprite(clip: String, phase: float, at: Vector2, size: Vector2, angle: float = 0, alpha: float = 0.85):
	sim.draw_set_transform(at,angle)
	sim.draw_texture_rect(sim.content.effect_frame(clip,phase),Rect2(-size*0.5,size),false,Color(1,1,1,alpha))
	sim.draw_set_transform(Vector2.ZERO)

func draw_fields():
	for h in sim.hazards:
		if not h.get("friendly",false): continue
		var kind = h.get("kind","fire")
		var phase = fposmod(sim.clock*1.7,1.0)
		if kind == "decoy":
			sprite("sonic",phase,h.pos,Vector2.ONE*minf(h.radius*2,190),0,0.35)
			sprite("speaker",phase,h.pos-Vector2(0,12),Vector2.ONE*58)
		else:
			draw_field(h,"acid_loop" if kind == "acid" else "fire_loop",Color(1,1,1,0.68*minf(1,h.life*3)))

func draw():
	for b in sim.projectiles:
		if not b.active: continue
		var at = b.pos-Vector2(0,15)
		if b.weapon.lob: at.y -= sin(clampf(b.age/maxf(0.01,b.total_life),0,1)*PI)*65
		var clip = {"book":"book_flight","brick":"brick_flight","molotov":"fire_burst","decoy":"speaker","crossbow":"bolt_flight","nailgun":"nail_flight","shotgun":"shotgun_hit","pistol":"pistol_hit"}.get(b.id,"nail_flight")
		var size = {"book":Vector2(48,48),"brick":Vector2(37,37),"molotov":Vector2(40,40),"decoy":Vector2(43,43),"crossbow":Vector2(68,40),"nailgun":Vector2(44,24),"shotgun":Vector2(18,13),"pistol":Vector2(24,15)}.get(b.id,Vector2(32,32))
		var phase = fposmod(b.age*2.4,1.0) if b.id not in ["shotgun","pistol"] else 0.2
		sprite(clip,phase,at,size,b.velocity.angle())
	for f in fx:
		var phase = 1-f.life/f.max
		var angle = f.pos.direction_to(f.end).angle()
		if f.kind == "charge": continue # Character anticipation conveys charge.
		if f.kind == "overheat":
			sprite("dust",phase,f.pos-Vector2(0,40),Vector2(55,65),0,0.55)
			sim.draw_string(sim.content.font,f.pos+Vector2(-25,-75),"冷却",0,-1,15,Color("dcb282"))
			continue
		var clip = {"arc":"lightning","water":"water_jet","acid":"acid_spray","saw":"chainsaw","hammer":"wrench"}.get(f.kind,f.kind)
		if not sim.content.vfx_frames.has(clip): continue
		var end = f.end
		if f.kind in ["water","acid"]:
			var t = sim.city.wall_hit(f.pos,end)
			if t != INF: end = f.pos.lerp(end,t)
		var distance = f.pos.distance_to(end)
		var size = Vector2.ONE*maxf(58,f.radius*1.7)
		var at = f.pos-Vector2(0,18)
		if f.kind in ["arc","water","acid","saw","hammer","baton","cleaver"]:
			at = f.pos.lerp(end,0.5)-Vector2(0,18)
			size = Vector2(maxf(45,distance*1.4),40 if f.kind == "arc" else maxf(65,distance*0.85))
		else: angle = 0
		sprite(clip,phase,at,size,angle,0.72 if sim.progress.settings.flash else 0.48)
