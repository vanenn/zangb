from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=root/'scripts/combat_feedback.gd'
s=p.read_text(encoding='utf-8').replace('const LIMIT = 360','const LIMIT = 128')
clips={'book':'paper_hit','wrench':'wrench','baton':'baton','molotov':'fire_burst','nailgun':'nail_hit','shotgun':'shotgun_hit','pistol':'pistol_hit','cleaver':'cleaver','brick':'brick_hit','chain':'lightning','acid':'acid_spray','chainsaw':'chainsaw','crossbow':'bolt_hit','decoy':'sonic','water':'water_loop','explosion':'explosion'}
for key,clip in clips.items(): s=s.replace('"'+key+'":{"color"','"'+key+'":{"clip":"'+clip+'","color"')
s=s.replace('"count":3,"kind":"mist" if wet else "smoke"','"clip":"water_loop" if wet else "dust","count":3,"kind":"mist" if wet else "smoke"')
a=s.index('func add_particle(');b=s.index('func shake(',a)
s=s[:a]+'''func add_animation(at: Vector2, clip: String, size: Vector2, life: float, angle: float = 0, kind: String = "impact", tint: Color = Color.WHITE):
	var entry = {"pos":at,"clip":clip,"size":size,"life":life,"max":life,"angle":angle,"kind":kind,"color":tint}
	if particles.size() < LIMIT:
		particles.append(entry)
	else:
		particles[cursor] = entry
		cursor = (cursor+1)%LIMIT

func burst(at: Vector2,direction: Vector2,style: Dictionary,count: int = -1):
	if at.distance_squared_to(sim.captain) > 1000000: return
	var clip = style.get("clip","dust")
	var size = 76.0
	if clip in ["wrench","shotgun_hit","brick_hit","sonic"]: size = 112.0
	if clip == "explosion": size = 310.0
	if clip == "dust": size = 52.0
	var angle = direction.angle() if clip in ["wrench","baton","cleaver","chainsaw","lightning","acid_spray"] else 0.0
	add_animation(at,clip,Vector2.ONE*size,0.42 if clip != "explosion" else 0.7,angle)

''' + s[b:]
s=s.replace('\n\t\tp.pos += p.velocity*delta\n\t\tp.velocity *= exp(-delta*p.drag)\n\t\tp.velocity.y += p.gravity*delta\n\t\tp.angle += p.spin*delta','')
a=s.index('\tif id in ["shotgun","pistol","nailgun","crossbow"]:');b=s.index('\tif id == "shotgun": shake',a)
s=s[:a]+'''	if id in ["shotgun","pistol","nailgun"] and sim.progress.settings.flash:
		add_animation(muzzle,"muzzle",Vector2(75,58) if id == "shotgun" else Vector2(48,38),0.18,direction.angle(),"muzzle")
''' + s[b:]
s=s.replace('{"count":7,"kind":"spark","color":"d3d5c0"}','{"clip":"armor_hit","count":7,"kind":"spark","color":"d3d5c0"}')
a=s.index('\t\tif sim.progress.settings.blood');b=s.index('\n\tenemy.recoil',a)
s=s[:a]+s[b:]
a=s.index('func draw():')
s=s[:a]+'''func draw():
	var camera = Vector2(clampf(sim.captain.x,800,1600),clampf(sim.captain.y,440,1360))
	var visible_world = Rect2(camera-Vector2(840,420),Vector2(1680,900))
	for p in particles:
		if p.life <= 0 or not visible_world.has_point(p.pos): continue
		var frame = sim.content.effect_frame(p.clip,1.0-p.life/p.max)
		var tint = p.color
		tint.a *= 0.8 if sim.progress.settings.flash else 0.5
		sim.draw_set_transform(p.pos,p.angle)
		sim.draw_texture_rect(frame,Rect2(-p.size*0.5,p.size),false,tint)
	sim.draw_set_transform(Vector2.ZERO)
'''
p.write_text(s,encoding='utf-8')
p=root/'scripts/weapons_runtime.gd';s=p.read_text(encoding='utf-8')
s=s.replace('effect("landing",b.pos,b.pos,b.splash,b.color,0.35)','effect("fire_burst" if b.id == "molotov" else ("sonic" if b.id == "decoy" else "brick_hit"),b.pos,b.pos,b.splash,b.color,0.42)')
s=s.replace('effect("landing",h.pos,h.pos,h.radius,h.color,0.5)','effect("sonic",h.pos,h.pos,h.radius,h.color,0.5)')
s=s.replace('\n\t\t\teffect("spark",e.pos,e.pos+b.velocity.normalized()*12,9,b.color,0.13)','')
s=s[:s.index('func draw():')]+'''# Texture UVs clip authored animation to the same physical walls as damage.
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
'''
p.write_text(s,encoding='utf-8')
p=root/'scripts/combat.gd';s=p.read_text(encoding='utf-8')
a=s.index('\t\tvar friendly = false',s.index('func _draw():'));b=s.index('\tfor drop in drops:',a)
s=s[:a]+'''		if hazard.delay > 0:
			draw_arc(hazard.pos,hazard.radius,0,TAU,48,Color("df8d71"),2.5,true)
			draw_line(hazard.pos-Vector2(10,0),hazard.pos+Vector2(10,0),Color("e2a187"),2)
		else:
			weapons.draw_field(hazard,"acid_loop",Color(1,0.52,0.32,0.65))
	weapons.draw_fields()
''' + s[b:]
p.write_text(s,encoding='utf-8')
