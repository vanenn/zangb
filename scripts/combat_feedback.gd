extends RefCounted

# Presentation has its own random stream; it never changes combat rolls or saves.
const LIMIT = 128
var sim
var rng = RandomNumberGenerator.new()
var particles = []
var corpses = []
var cursor = 0
var shake_gate = 0.0
var continuous_gate = {}
var sound_gate = {}
var poses = {}
var camera_kick = Vector2.ZERO
var animation_time = 0.0
var foot_clock = 0.0

const STYLES = {
	"book":{"clip":"paper_hit","color":"ded0a3","kind":"paper","count":6,"force":3.0,"shake":0.7,"sound":"paper_hit"},
	"wrench":{"clip":"wrench","color":"dfbd7c","kind":"chip","count":17,"force":11.0,"shake":4.6,"sound":"heavy_hit"},
	"baton":{"clip":"baton","color":"c7d3bd","kind":"spark","count":8,"force":5.0,"shake":1.6,"sound":"baton_hit"},
	"molotov":{"clip":"fire_burst","color":"d99a53","kind":"ember","count":7,"force":1.0,"shake":0.4,"sound":"fire_hit"},
	"nailgun":{"clip":"nail_hit","color":"d8ccb0","kind":"spark","count":5,"force":3.0,"shake":0.8,"sound":"nail_hit"},
	"shotgun":{"clip":"shotgun_hit","color":"e7ba79","kind":"chip","count":11,"force":8.0,"shake":3.2,"sound":"shotgun_hit"},
	"pistol":{"clip":"pistol_hit","color":"e6cfad","kind":"spark","count":5,"force":3.0,"shake":1.1,"sound":"pistol_hit"},
	"cleaver":{"clip":"cleaver","color":"c9b5a0","kind":"slash","count":9,"force":7.0,"shake":2.1,"sound":"slice_hit"},
	"brick":{"clip":"brick_hit","color":"b99c7c","kind":"chip","count":14,"force":8.0,"shake":3.2,"sound":"stone_hit"},
	"chain":{"clip":"lightning","color":"a6dce0","kind":"electric","count":8,"force":3.5,"shake":1.0,"sound":"electric_hit"},
	"acid":{"clip":"acid_spray","color":"b8ce78","kind":"droplet","count":7,"force":1.0,"shake":0.3,"sound":"acid_hit"},
	"chainsaw":{"clip":"chainsaw","color":"efc080","kind":"spark","count":9,"force":2.5,"shake":1.2,"sound":"saw_hit"},
	"sweeper":{"clip":"water_jet","color":"a4cbd0","kind":"mist","count":8,"force":2.0,"shake":0.5,"sound":"water_hit"},
	"breach":{"clip":"explosion","color":"e0a15e","kind":"ember","count":20,"force":12.0,"shake":6.5,"sound":"explosion"},
	"crossbow":{"clip":"bolt_hit","color":"d9c9a1","kind":"chip","count":10,"force":9.0,"shake":2.6,"sound":"bolt_hit"},
	"decoy":{"clip":"sonic","color":"c5abcd","kind":"pulse","count":9,"force":5.0,"shake":2.5,"sound":"pulse_hit"},
	"water":{"clip":"water_loop","color":"a4cbd0","kind":"mist","count":6,"force":1.0,"shake":0.4,"sound":"water_hit"},
	"explosion":{"clip":"explosion","color":"e0a15e","kind":"ember","count":24,"force":13.0,"shake":7.5,"sound":"explosion"}
}

func setup(combat):
	sim = combat
	rng.seed = 180731

func reset():
	particles.clear()
	corpses.clear()
	poses.clear()
	continuous_gate.clear()
	sound_gate.clear()
	camera_kick = Vector2.ZERO
	shake_gate = 0

func update(delta: float):
	animation_time += delta
	foot_clock -= delta
	if sim.captain_move > 0.2 and foot_clock <= 0:
		foot_clock = 0.32
		var wet = sim.city.is_wet(sim.captain)
		sim.spatial_sound_requested.emit("splash_step" if wet else "step",sim.captain,0.48)
		burst(sim.captain,Vector2.UP,{"clip":"water_loop" if wet else "dust","count":3,"kind":"mist" if wet else "smoke","color":"9bbabd" if wet else "aaa28d"})
	shake_gate = maxf(0,shake_gate-delta)
	camera_kick = camera_kick.move_toward(Vector2.ZERO,delta*65)
	for p in particles:
		if p.life <= 0: continue
		p.life -= delta
	for corpse in corpses: corpse.life -= delta
	corpses = corpses.filter(func(c): return c.life > 0)
	for pose in poses.values():
		pose.life = maxf(0,pose.life-delta)

func add_animation(at: Vector2, clip: String, size: Vector2, life: float, angle: float = 0, kind: String = "impact", tint: Color = Color.WHITE):
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

func shake(at: Vector2,strength: float,direction: Vector2):
	if not sim.progress.settings.shake or shake_gate > 0: return
	var attenuation = clampf(1.0-at.distance_to(sim.captain)/850.0,0,1)
	if attenuation <= 0: return
	shake_gate = 0.08 if strength >= 2.0 else 0.16
	sim.shake_amount = minf(8.0,maxf(sim.shake_amount,strength*attenuation))
	camera_kick = (camera_kick-direction*strength*attenuation*0.4).limit_length(4.0)

func shot(origin: Vector2,direction: Vector2,id: String,source: String,charge: bool = false):
	if not STYLES.has(id): return
	var duration = 0.42 if id == "wrench" else 0.65
	poses[source] = {"life":duration if charge else 0.22,"max":duration if charge else 0.22,"direction":direction,"id":id,"charge":charge}
	if charge: return
	if id in ["chainsaw","water","sweeper"]:
		var key = source+id
		if continuous_gate.get(key,-1) > animation_time: return
		continuous_gate[key] = animation_time+0.12
	var muzzle = origin+direction*22-Vector2(0,20)
	if id in ["shotgun","pistol","nailgun"] and sim.progress.settings.flash:
		add_animation(muzzle,"muzzle",Vector2(75,58) if id == "shotgun" else Vector2(48,38),0.18,direction.angle(),"muzzle")
	if id == "shotgun": shake(origin,1.5,direction)

func impact(enemy: Dictionary,origin: Vector2,id: String,amount: float):
	if not STYLES.has(id): return
	var style = STYLES[id]
	var direction = origin.direction_to(enemy.pos)
	var continuous = id in ["chainsaw","sweeper","acid","molotov"]
	var key = str(enemy.uid)+id
	if continuous and continuous_gate.get(key,-1) > animation_time: return
	continuous_gate[key] = animation_time+(0.14 if continuous else 0.0)
	var impact_point = enemy.pos-Vector2(0,26)+direction*rng.randf_range(-4,4)
	var armored = enemy.behavior in ["armor","warden"] and enemy.get("corrode",0) <= 0 and enemy.pos.direction_to(origin).dot(Vector2.from_angle(enemy.facing)) > 0.35
	if armored:
		burst(impact_point,-direction,{"clip":"armor_hit","count":7,"kind":"spark","color":"d3d5c0"})
	else:
		burst(impact_point,direction,style)

	enemy.recoil = (enemy.get("recoil",Vector2.ZERO)+direction*float(style.force)*(0.35 if enemy.boss else 1.0)).limit_length(12)
	enemy.anim_stop = maxf(enemy.get("anim_stop",0),0.018 if continuous else minf(0.055,amount*0.001))
	shake(enemy.pos,float(style.shake),direction)
	var sound = "armor_hit" if armored else style.sound
	if sound_gate.get(sound,-1) <= animation_time:
		sound_gate[sound] = animation_time+(0.14 if continuous else 0.075)
		sim.spatial_sound_requested.emit(sound,enemy.pos,0.72 if continuous else 1.0)

func death(enemy: Dictionary,origin: Vector2):
	if corpses.size() >= 22: corpses.pop_front()
	corpses.append({"pos":enemy.pos,"sprite":enemy.sprite,"facing":1.0 if cos(enemy.facing) >= 0 else -1.0,"direction":origin.direction_to(enemy.pos),"life":0.65,"max":0.65,"size":124.0 if enemy.boss else (91.0 if enemy.elite else 69.0)})
	burst(enemy.pos,origin.direction_to(enemy.pos),{"count":7,"kind":"smoke","color":"9c9b84"})
	if enemy.boss: shake(enemy.pos,7.5,origin.direction_to(enemy.pos))

func draw_corpses():
	for c in corpses:
		var progress = 1.0-c.life/c.max
		var fall = minf(1,progress*2.4)
		var alpha = minf(0.65,c.life*2)
		sim.draw_set_transform(c.pos+c.direction*fall*18,fall*0.85*c.facing,Vector2(c.facing,1-fall*0.55))
		sim.draw_texture_rect(sim.content.character_textures[c.sprite],Rect2(-c.size*0.5,-c.size*0.85,c.size,c.size),false,Color(0.60,0.63,0.54,alpha))
	sim.draw_set_transform(Vector2.ZERO)

func draw():
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
