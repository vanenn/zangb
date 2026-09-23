extends Node2D

signal wave_finished
signal defeated
signal level_requested
signal equipment_requested
signal message(text)
signal sound_requested(kind)
signal spatial_sound_requested(kind,at,intensity)

const Feedback = preload("res://scripts/combat_feedback.gd")
var feedback = Feedback.new()
var build = preload("res://scripts/build_runtime.gd").new()
var scavenging = preload("res://scripts/scavenge.gd").new()
var elite_serial = 0
var support_serial = 0
var boss_started = -1.0
var boss_duration = 0.0

const WeaponRuntime = preload("res://scripts/weapons_runtime.gd")
var weapons = WeaponRuntime.new()

const Formation = preload("res://scripts/formation.gd")
const Grid = preload("res://scripts/spatial_grid.gd")

var content
var run
var progress
var city
var formation = Formation.new()
var grid = Grid.new()
var enemies = []
var projectiles = []
var drops = []
var hazards = []
var effects = []
var stains = []
var captain = Vector2(1200,900)
var captain_facing = 1.0
var captain_move = 0.0
var captain_attack = 0.0
var captain_cooldown = 0.0
var elapsed = 0.0
var clock = 0.0
var spawn_clock = 0.0
var navigation_clock = 0.0
var grid_clock = 0.0
var invulnerability = 0.0
var shake_amount = 0.0
var rescue = {}
var rescue_progress = 0.0
var rescue_done = false
var boss_spawned = false
var elite_spawned = false
var active_count = 0
var wave_reward = 0
var manual_tick = false
var test_direction = Vector2.INF
var test_interact = false
var test_invulnerable = false
var uid_serial = 0
var width_limit = 220
var profile_enabled = false
var profile_totals = {}
var profile_counts = {}
var clear_started = false

func setup(book, state, storage, map_node):
	content = book
	run = state
	progress = storage
	city = map_node
	city.restore(run.map_state)
	weapons.setup(self)
	feedback.setup(self)
	build.setup(self)
	scavenging.setup(self)
	captain = Vector2(run.checkpoint_position[0],run.checkpoint_position[1])
	formation.sync(run,captain)

func begin_wave():
	captain = Vector2(run.checkpoint_position[0],run.checkpoint_position[1])
	if not city.point_free(captain):
		captain = Vector2(1200,900)
	city.reset_wave()
	weapons.reset()
	feedback.reset()
	build.reset()
	elite_serial=0
	support_serial=0
	boss_started=-1
	boss_duration=0
	shake_amount = 0
	run.wave += 1
	run.mode = "combat"
	elapsed = 0
	spawn_clock = 0
	navigation_clock = 0
	captain_cooldown = 0
	boss_spawned = false
	elite_spawned = false
	clear_started = false
	rescue_done = false
	rescue_progress = 0
	enemies.clear()
	projectiles.clear()
	drops.clear()
	hazards.clear()
	effects.clear()
	stains.clear()
	active_count = 0
	grid.rebuild(enemies)
	city.update_flow(captain)
	var pool = content.survivor_pool(progress.meta.unlocked)
	var zones = content.maps[run.map_id].get("rescue_zones",[])
	var rescue_origin = captain
	if not zones.is_empty():
		var zone = zones[(run.wave-1)%zones.size()]
		rescue_origin = Vector2(zone[0],zone[1])
	rescue = {"id":pool[run.rng.randi_range(0,pool.size()-1)],"pos":city.nearby_open(rescue_origin,65 if not zones.is_empty() else 430,run.rng)}
	scavenging.begin()
	formation.sync(run,captain)
	for person in formation.members:
		person.pos = captain
	queue_redraw()

func _process(delta: float):
	if not manual_tick:
		tick(minf(delta,0.05))

func tick(delta: float):
	if run == null or run.mode != "combat":
		return
	clock += delta
	var time_feedback_update = Time.get_ticks_usec() if profile_enabled else 0
	feedback.update(delta)
	build.update(delta)
	profile_end("feedback_update",time_feedback_update)
	elapsed += delta
	run.elapsed_total += delta
	invulnerability = maxf(0,invulnerability-delta)
	shake_amount = maxf(0,shake_amount-delta*22)
	captain_attack = maxf(0,captain_attack-delta)
	build.heal(minf(run.stats.regen,run.stats.max_health*0.03)*delta)
	var movement = Input.get_vector("move_left","move_right","move_up","move_down") if test_direction == Vector2.INF else test_direction.limit_length()
	captain_move = movement.length()
	if absf(movement.x) > 0.1:
		captain_facing = signf(movement.x)
	captain = city.move_actor(captain,movement*run.stats.move_speed*(1.25 if build.stride>0 else 1.0)*delta,13)
	navigation_clock -= delta
	if navigation_clock <= 0:
		city.update_flow(captain)
		navigation_clock = 0.28
	var time_formation_update = Time.get_ticks_usec() if profile_enabled else 0
	formation.update(delta,captain,city,run.stats.move_speed)
	profile_end("formation_update",time_formation_update)
	var time_update_tactics = Time.get_ticks_usec() if profile_enabled else 0
	_update_tactics(delta)
	if run.mode != "combat": return
	profile_end("update_tactics",time_update_tactics)
	_update_spawn(delta)
	var time_grid = Time.get_ticks_usec() if profile_enabled else 0
	grid.rebuild(enemies)
	profile_end("grid",time_grid)
	var time_update_enemies = Time.get_ticks_usec() if profile_enabled else 0
	_update_enemies(delta)
	profile_end("update_enemies",time_update_enemies)
	var time_weapons_update = Time.get_ticks_usec() if profile_enabled else 0
	weapons.update(delta)
	profile_end("weapons_update",time_weapons_update)
	var time_update_attacks = Time.get_ticks_usec() if profile_enabled else 0
	_update_attacks(delta)
	profile_end("update_attacks",time_update_attacks)
	var time_update_projectiles = Time.get_ticks_usec() if profile_enabled else 0
	_update_projectiles(delta)
	profile_end("update_projectiles",time_update_projectiles)
	var time_update_hazards = Time.get_ticks_usec() if profile_enabled else 0
	_update_hazards(delta)
	profile_end("update_hazards",time_update_hazards)
	_update_drops(delta)
	_update_rescue(delta)
	for fx in effects:
		fx.life -= delta
	effects = effects.filter(func(fx): return fx.life > 0)
	if run.health <= 0:
		run.health = 0
		run.mode = "result"
		defeated.emit()
	elif run.pending_levels > 0:
		run.mode = "upgrade"
		run.make_choices()
		level_requested.emit()
	elif elapsed >= content.wave(run.wave).duration and active_count == 0:
		_complete_wave()
	queue_redraw()

func spawn_point() -> Vector2:
	var phase=int(elapsed/20)%4
	var camera=Vector2(clampf(captain.x,800,1600),clampf(captain.y,440,1360))
	var visible=Rect2(camera-Vector2(830,485),Vector2(1660,970))
	var fallback=Vector2.INF
	for attempt in range(120):
		var side=phase if run.wave>=7 and attempt<60 else run.rng.randi_range(0,3)
		var at=[Vector2(2320,run.rng.randf_range(100,1700)),Vector2(run.rng.randf_range(100,2300),1720),Vector2(80,run.rng.randf_range(100,1700)),Vector2(run.rng.randf_range(100,2300),80)][side]
		var cell=city.to_cell(at)
		if not city.point_free(at,28) or city.flow[cell.y*city.grid_size.x+cell.x]<0 or at.distance_to(captain)<420: continue
		if fallback==Vector2.INF: fallback=at
		if not visible.has_point(at): return at
	if fallback!=Vector2.INF: return fallback
	return city.nearby_open(captain,850,run.rng)

func arrival(id: String, elite: bool=false):
	var at=spawn_point()
	var index=spawn_enemy(id,at,elite)
	enemies[index].arrival=0.9
	feedback.add_animation(at,"sonic",Vector2(100,100),0.9)

func _update_spawn(delta: float):
	var data=run.wave_data()
	if elapsed<data.duration:
		spawn_clock-=delta
		if spawn_clock<=0:
			spawn_clock=1.0/float(data.rate)
			if active_count<width_limit:
				var roll=run.rng.randf()
				var kinds=content.maps[run.map_id].enemies
				var index=0 if roll<data.weights[0] else 1 if roll<data.weights[0]+data.weights[1] else 2
				arrival(kinds[index])
		if elite_serial<data.elite_times.size() and elapsed>=data.elite_times[elite_serial] and active_count<width_limit:
			elite_serial+=1
			arrival(content.maps[run.map_id].enemies[2],true)
			message.emit("精英接近 · 留意预警")
		if data.boss and elapsed>3 and not boss_spawned and active_count<width_limit:
			boss_spawned=true
			boss_started=elapsed
			arrival(content.maps[run.map_id].boss)
			sound_requested.emit("boss")
		if data.boss and support_serial<2 and elapsed>25+support_serial*20:
			support_serial+=1
			for i in range(6):
				if active_count<width_limit: arrival(content.maps[run.map_id].enemies[1+i%2])
	elif not clear_started:
		clear_started=true
		message.emit("尸潮暂歇 · 清理剩余感染者后整备")

func spawn_enemy(id: String, at: Vector2, elite: bool = false) -> int:
	var data = content.enemies[id]
	var boss = bool(data.get("boss",false))
	var scaling=run.wave_data()
	var hp = float(data.hp) * ((1.4 if run.difficulty=="easy" else 2.0) if boss else float(scaling.hp)) * (5.0 if elite else 1.0)
	uid_serial += 1
	var entry = {"active":true,"uid":uid_serial,"id":id,"pos":at,"hp":hp,"max_hp":hp,"speed":float(data.speed)*scaling.speed*(1.2 if elite else 1.0),"damage":float(data.damage)*scaling.damage*(1.5 if elite else 1.0),"radius":float(data.radius)*(1.35 if elite else 1.0),"sprite":int(data.sprite),"behavior":data.behavior,"boss":boss,"elite":elite,"ability":run.rng.randf_range(2.0,4.0),"windup":0.0,"aim":captain,"dash":0.0,"dash_dir":Vector2.ZERO,"direction":Vector2.ZERO,"nav":0.0,"facing":0.0,"hit":0.0,"phase":run.rng.randf()*TAU,"slow":0.0,"wet":0.0,"stun":0.0,"corrode":0.0,"resolve":0.0,"stuck":0.0,"stuck_pos":at,"stuck_time":0.0,"target_pos":captain}
	for index in range(enemies.size()):
		if not enemies[index].active:
			enemies[index] = entry
			active_count += 1
			progress.observe(id)
			return index
	enemies.append(entry)
	active_count += 1
	progress.observe(id)
	return enemies.size()-1

func _update_enemies(delta: float):
	var initial_size = enemies.size()
	for index in range(initial_size):
		var enemy = enemies[index]
		if not enemy.active:
			continue
		if enemy.get("arrival",0)>0:
			enemy.arrival-=delta
			continue
		enemy.hit = maxf(0,enemy.hit-delta)
		enemy.recoil = enemy.get("recoil",Vector2.ZERO).move_toward(Vector2.ZERO,delta*70)
		enemy.anim_stop = maxf(0,enemy.get("anim_stop",0)-delta)
		if enemy.anim_stop <= 0: enemy.anim_clock = enemy.get("anim_clock",clock)+delta
		enemy.slow = maxf(0,enemy.slow-delta)
		for status in ["wet","stun","corrode","resolve","burning","resonance"]: enemy[status] = maxf(0,enemy.get(status,0)-delta)
		if city.is_wet(enemy.pos): enemy.wet = 2.0
		enemy.nav -= delta
		var pursuit = captain
		if not enemy.boss and not enemy.elite:
			if enemy.nav <= 0:
				var noise = city.noise_target(enemy.pos)
				var lure = weapons.lure_target(enemy)
				enemy.distraction = lure if lure != Vector2.INF else noise
			if enemy.get("distraction",Vector2.INF) != Vector2.INF: pursuit = enemy.distraction
		enemy.target_pos = pursuit
		enemy.stuck_time += delta
		if enemy.stuck_time >= 0.65:
			enemy.stuck = enemy.stuck+0.65 if enemy.pos.distance_to(enemy.stuck_pos) < 5 else 0.0
			enemy.stuck_time = 0.0
			enemy.stuck_pos = enemy.pos
			if enemy.pos.distance_to(pursuit) < 50: enemy.stuck = 0
			if enemy.stuck > 0.6: enemy.nav = 0
		if enemy.stun > 0:
			enemy.windup = 0.0
			enemy.dash = 0.0
			continue
		if enemy.windup > 0 and not city.attack_clear(enemy.pos,enemy.aim):
			enemy.windup = 0
			enemy.ability = 0.4
		enemy.ability -= delta
		var difference = pursuit-enemy.pos
		var target_angle = difference.angle()
		if enemy.behavior == "warden":
			enemy.facing = rotate_toward(enemy.facing,target_angle,delta*0.55)
		else:
			enemy.facing = target_angle
		if enemy.windup > 0:
			enemy.windup -= delta
			if enemy.windup <= 0:
				_execute_ability(enemy)
		elif enemy.dash > 0:
			enemy.dash -= delta
			var old = enemy.pos
			enemy.pos = city.move_actor(enemy.pos,enemy.dash_dir*340*delta,enemy.radius*0.65)
			if enemy.pos.distance_to(old) < delta*50:
				enemy.dash = 0
			if enemy.behavior == "roadboss" and int(clock*12)%3 == 0:
				_add_hazard(enemy.pos,47,6,12,0)
		else:
			if enemy.nav <= 0:
				enemy.direction = city.recovery_steer(enemy.pos,pursuit,enemy.radius*0.6) if enemy.stuck > 0.6 else city.steer(enemy.pos,pursuit,enemy.radius*0.6)
				enemy.nav = 0.18 + float(index%7)*0.013
			var speed = enemy.speed * (0.70 if enemy.slow > 0 else 1.0)
			if enemy.behavior == "spit" and difference.length() < 330 and city.attack_clear(enemy.pos,pursuit):
				speed *= 0.28
			var direction = enemy.direction
			if enemy.behavior == "warden" and city.attack_clear(enemy.pos,pursuit):
				direction = Vector2.from_angle(enemy.facing)
			enemy.pos = city.move_actor(enemy.pos,direction*minf(speed*delta,difference.length()),enemy.radius*0.6)
			if enemy.ability <= 0 and difference.length() < 580 and enemy.behavior not in ["chase","armor"] and pursuit == captain and city.attack_clear(enemy.pos,captain):
				enemy.aim = captain
				enemy.windup = 1.15 if enemy.boss else 0.9
				enemy.ability = 5.4 if enemy.boss else 6.5
		var block = city.blocker(enemy.pos,pursuit,75)
		if not block.is_empty() and enemy.pos.distance_to(enemy.pos.clamp(block.rect.position,block.rect.end)) < enemy.radius+28:
			city.damage_fixture(block,enemy.damage*delta*1.8)
		if enemy.pos.distance_to(captain) < enemy.radius+12 and city.attack_clear(enemy.pos,captain):
			_hurt(enemy.damage)

func _execute_ability(enemy: Dictionary):
	if not city.attack_clear(enemy.pos,enemy.aim): return
	match enemy.behavior:
		"charge", "roadboss":
			enemy.dash_dir = enemy.pos.direction_to(enemy.aim)
			enemy.dash = minf(1.8,enemy.pos.distance_to(enemy.aim)/340.0+0.25)
			if enemy.behavior == "roadboss":
				_add_hazard(enemy.aim,95,7,18,0.5)
		"spit":
			_add_hazard(enemy.aim,64,6,12,0.45)
		"scream", "bell":
			_add_hazard(enemy.pos,160 if enemy.boss else 105,0.3,18,0.15)
			if elapsed < content.wave(run.wave).duration:
				for count in range(7 if enemy.boss else 3):
					if active_count < width_limit:
						spawn_enemy("runner" if enemy.boss else "shambler",city.nearby_open(enemy.pos,110,run.rng))
			sound_requested.emit("bell")
		"warden":
			_add_hazard(enemy.aim,145,0.45,28,0.55)
			sound_requested.emit("boss")

func _add_hazard(at: Vector2, radius: float, life: float, damage: float, delay: float):
	if hazards.size() >= 90:
		return
	hazards.append({"pos":at,"radius":radius,"life":life,"damage":damage*run.wave_data().damage,"delay":delay,"tick":0.0})

func _nearest(pos: Vector2, reach: float) -> int:
	var best = -1
	var best_distance = reach*reach
	for index in grid.query(pos,reach):
		var enemy = enemies[index]
		if not enemy.active:
			continue
		var distance = pos.distance_squared_to(enemy.pos)
		if distance < best_distance and city.attack_clear(pos,enemy.pos):
			best = index
			best_distance = distance
	return best

func _update_attacks(delta: float):
	captain_cooldown -= delta
	if captain_cooldown <= 0:
		var weapon = run.weapon(content.classes[run.class_id].weapon)
		var target = weapons.target(captain,weapon)
		if target >= 0:
			weapons.fire(captain,weapon,target,"captain")
			captain_cooldown = weapon.cooldown
			captain_attack = 0.18
		else: captain_cooldown = 0.1
	for i in range(formation.members.size()):
		var person = formation.members[i]
		person.cooldown -= delta
		if person.cooldown > 0: continue
		var weapon = run.weapon(content.survivors[person.id].weapon)
		var target = weapons.target(person.pos,weapon)
		if target >= 0:
			weapons.fire(person.pos,weapon,target,"ally"+str(i))
			person.cooldown = weapon.cooldown
			person.attack = 0.17
			person.facing = 1.0 if enemies[target].pos.x >= person.pos.x else -1.0
			if weapon.id in ["cleaver","chainsaw"]: person.engage_time = 0.45
		else:
			person.cooldown = 0.14
			if weapon.id in ["cleaver","chainsaw"]:
				var seek = weapon.duplicate()
				seek.range = 245.0
				var close = weapons.target(person.pos,seek)
				if close >= 0 and enemies[close].pos.distance_to(captain) < 265:
					person.engage = enemies[close].pos.move_toward(person.pos,weapon.range*0.65)
					person.engage_time = 0.65

func _attack(origin: Vector2, weapon: Dictionary, target: int):
	weapons.fire(origin,weapon,target,"test")

func _projectile(entry: Dictionary):
	for i in range(projectiles.size()):
		if not projectiles[i].active:
			projectiles[i] = entry
			return
	projectiles.append(entry)

func _update_projectiles(delta: float):
	weapons.projectiles_tick(delta)

func _fire_pool(bullet: Dictionary):
	weapons.field(bullet.destination,run.weapon("molotov"),bullet.get("source","legacy"),"fire",bullet.splash,3)

func _update_hazards(delta: float):
	weapons.fields_tick(delta)
	for hazard in hazards:
		if hazard.get("friendly",false): continue
		if hazard.delay > 0:
			hazard.delay -= delta
			continue
		hazard.life -= delta
		if captain.distance_to(hazard.pos) < hazard.radius+8 and city.attack_clear(hazard.pos,captain): _hurt(hazard.damage)
	hazards = hazards.filter(func(h): return h.life > 0)

func _update_tactics(delta: float):
	var held = test_interact or Input.is_action_pressed("interact")
	var rescue_priority = not rescue_done and not rescue.is_empty() and captain.distance_to(rescue.pos) < 75 and city.attack_clear(captain,rescue.pos)
	var actors = [captain]
	for p in formation.members: actors.append(p.pos)
	for e in enemies:
		if e.active: actors.append(e.pos)
	scavenging.tick(delta,held,rescue_priority)
	city.tick_tactics(delta,captain,held,rescue_priority or scavenging.nearby()>=0 or run.mode!="combat",actors)
	for event in city.events:
		if event.kind == "message": message.emit(event.text)
		elif event.kind == "explosion":
			weapons.pulse(event.pos,event.radius,event.damage,event.pos,0.6,"explosion")
			weapons.effect("landing",event.pos,event.pos,event.radius,Color("dfa870"),0.7)
			sound_requested.emit("explosion")
	city.events.clear()

func _damage(index: int,amount: float,origin: Vector2,weapon_id: String="",source: String="world",secondary: bool=false):
	var enemy=enemies[index]
	if not enemy.active: return
	if weapon_id=="chain" and weapons.chain_hits is Dictionary:
		if not weapons.chain_hits.has(enemy.uid) and weapons.chain_hits.size()>=12: return
		weapons.chain_hits[enemy.uid]=true
	var base=amount
	if weapon_id in ["acid","molotov"] and enemy.get("resonance",0)>0: amount*=1.3
	if enemy.behavior in ["armor","warden"]:
		if enemy.pos.direction_to(origin).dot(Vector2.from_angle(enemy.facing))>0.35:
			amount *= (0.70 if enemy.boss else 0.85) if enemy.get("corrode",0)>0 else (0.30 if enemy.boss else 0.55)
	enemy.hp-=amount
	enemy.hit=0.10
	var dead=enemy.hp<=0
	if dead:
		enemy.active=false
		active_count-=1
		run.kills+=1
		var gold=int(content.enemies[enemy.id].reward)
		if not enemy.boss and not enemy.elite: gold=gold if run.rng.randf()<0.30 else 0
		if enemy.elite: gold+=20
		_drop(enemy.pos,2.0 if not enemy.boss else 20.0,gold)
		feedback.death(enemy,origin)
		if progress.settings.blood and stains.size()<180: stains.append({"pos":enemy.pos,"radius":run.rng.randf_range(6,15)})
		if enemy.boss:
			boss_duration=elapsed-boss_started
			message.emit("首领倒下了 · 清理剩余尸群")
			sound_requested.emit("victory")
	feedback.impact(enemy,origin,weapon_id,amount)
	build.hit(enemy,origin,weapon_id,source,base,secondary)
	if dead: build.killed(enemy,origin,weapon_id,source,base,secondary)

func _hurt(amount: float):
	if invulnerability > 0 or test_invulnerable:
		return
	run.health -= build.absorb(maxf(1,amount-run.stats.armor))
	invulnerability = 0.70
	shake_amount = 6 if progress.settings.shake else 0
	sound_requested.emit("hurt")

func _drop(at: Vector2, experience: float, gold: int, crate: bool = false):
	if run.level>=17: experience=0
	if experience<=0 and gold<=0 and not crate: return
	if not crate:
		for item in drops:
			if item.active and not item.crate and not item.has("heal") and item.pos.distance_squared_to(at) < 900:
				item.xp += experience
				item.gold += gold
				return
	var entry = {"active":true,"pos":at,"xp":experience,"gold":gold,"crate":crate}
	for index in range(drops.size()):
		if not drops[index].active:
			drops[index] = entry
			return
	drops.append(entry)

func _update_drops(delta: float):
	for item in drops:
		if not item.active:
			continue
		var distance = item.pos.distance_to(captain)
		if (distance < run.stats.pickup or item.get("magnet",false)) and city.attack_clear(item.pos,captain):
			item.pos = item.pos.move_toward(captain,delta*440)
		if distance < 24:
			item.active = false
			run.supplies += int(item.gold)
			run.add_xp(item.xp)
			build.pickup(int(item.gold))
			if item.has("heal"): build.heal(item.heal,true)
			if item.crate:
				message.emit("找到物资箱  +%s物资" % item.gold)
				sound_requested.emit("pickup")

func _update_rescue(delta: float):
	if rescue_done or rescue.is_empty():
		return
	if captain.distance_to(rescue.pos) < 75 and city.attack_clear(captain,rescue.pos) and (test_interact or Input.is_action_pressed("interact")):
		rescue_progress += delta
		if rescue_progress >= 1.6:
			rescue_done = true
			run.recruit(rescue.id,true)
			build.rescued()
			formation.sync(run,captain)
			message.emit("有人回应了呼救 · %s加入队伍" % content.survivors[rescue.id].name)
			sound_requested.emit("rescue")
	else:
		rescue_progress = maxf(0,rescue_progress-delta*0.6)

func _complete_wave():
	for item in drops:
		if item.active:
			run.supplies += int(item.gold)
			run.add_xp(item.xp)
			item.active = false
	if run.pending_levels > 0:
		run.mode = "upgrade"
		run.make_choices()
		level_requested.emit()
		return
	wave_reward = int(content.wave(run.wave).reward)
	run.supplies += wave_reward
	run.map_state = city.snapshot()
	run.checkpoint_position = [captain.x,captain.y]
	run.mode = "camp" if run.wave < 10 else "result"
	wave_finished.emit()

func boss_status() -> Dictionary:
	for enemy in enemies:
		if enemy.active and enemy.boss:
			return enemy
	return {}

func _draw_actor(at: Vector2, sprite_index: int, facing: float, moving: float, phase: float, attack: float, size_value: float = 76.0, tint: Color = Color.WHITE, visual: Dictionary = {}, source: String = ""):
	var enemy_actor = visual.has("behavior")
	var time = float(visual.get("anim_clock",clock))
	if enemy_actor and at.distance_squared_to(captain) > 250000:
		var far_stride = sin(time*7+phase)*moving
		draw_set_transform(at+visual.get("recoil",Vector2.ZERO)+Vector2(0,-absf(far_stride)*2),far_stride*0.045,Vector2(facing,1))
		draw_texture_rect(content.character_textures[sprite_index],Rect2(-size_value*0.5,-size_value*0.91,size_value,size_value),false,tint)
		draw_set_transform(Vector2.ZERO)
		return
	var fast = visual.get("id","") in ["runner","charger"] or visual.get("dash",0) > 0
	var rate = 12.0 if fast else (5.6 if enemy_actor else 9.0)
	var stride = sin(time*rate+phase)
	var opposite = sin(time*rate+phase+PI)
	var limp = (0.65+0.35*sin(time*rate*0.5+phase)) if enemy_actor else 1.0
	var gait = clampf(moving,0,1.3)*limp
	var bob = -absf(stride)*(3.4 if fast else 2.4)*gait
	var lean = (0.055 if enemy_actor else 0.028)*stride*gait
	var squeeze = 1.0+sin(time*2.3+phase)*0.009
	var recoil = visual.get("recoil",Vector2.ZERO)
	var body_shift = Vector2.ZERO
	var pose = feedback.poses.get(source,{})
	if not pose.is_empty() and pose.life > 0:
		var progress_value = 1.0-pose.life/pose.max
		var direction = pose.direction
		if pose.charge:
			lean -= facing*0.17*progress_value
			body_shift -= direction*progress_value*4
			squeeze -= progress_value*0.045
		else:
			var snap = sin(progress_value*PI)*exp(-progress_value*1.5)
			var heavy = pose.id in ["wrench","cleaver","baton","chainsaw"]
			lean += facing*snap*(0.24 if heavy else -0.11)
			body_shift += direction*snap*(7 if heavy else -4)
	elif attack > 0: lean += sin(attack/0.18*PI)*0.10*facing
	if enemy_actor:
		if visual.get("windup",0) > 0:
			var anticipation = 1.0-clampf(visual.windup/1.15,0,1)
			lean -= facing*(0.10+anticipation*0.12)
			squeeze -= anticipation*0.08
			bob += sin(time*32)*0.6
		if visual.get("dash",0) > 0:
			lean += facing*0.28
			body_shift += Vector2.from_angle(visual.facing)*7
		if visual.get("stun",0) > 0:
			lean += sin(time*18+phase)*0.085
			gait = 0
		lean += recoil.x*0.012
	var tex = content.character_textures[sprite_index]
	var dimensions = tex.get_size()
	draw_set_transform(at)
	draw_set_transform(at,0,Vector2(1,0.3))
	draw_circle(Vector2.ZERO,size_value*0.22,Color(0.03,0.04,0.035,0.26))
	# Cutout legs step independently; the upper section breathes and anticipates attacks.
	for leg in range(2):
		var step = stride if leg == 0 else opposite
		var foot = Vector2(step*1.1*gait,-maxf(0,step)*3.5*gait)
		draw_set_transform(at+foot+recoil*0.3,0,Vector2(facing,1))
		var target_rect = Rect2(-size_value*0.5+leg*size_value*0.5,-size_value*0.27,size_value*0.5,size_value*0.36)
		var source_rect = Rect2(leg*dimensions.x*0.5,dimensions.y*0.64,dimensions.x*0.5,dimensions.y*0.36)
		draw_texture_rect_region(tex,target_rect,source_rect,tint)
	var hip = Vector2(0,-size_value*0.27)
	draw_set_transform(at+hip+Vector2(0,bob)+body_shift+recoil,lean,Vector2(facing,squeeze))
	draw_texture_rect_region(tex,Rect2(-size_value*0.5,-size_value*0.64,size_value,size_value*0.66),Rect2(0,0,dimensions.x,dimensions.y*0.66),tint)
	draw_set_transform(Vector2.ZERO)

func _draw():
	var render_time = Time.get_ticks_usec() if profile_enabled else 0
	if content == null:
		return
	for stain in stains:
		if progress.settings.blood:
			draw_circle(stain.pos,stain.radius,Color(0.27,0.09,0.065,0.35))
	for hazard in hazards:
		if hazard.get("friendly",false): continue
		if hazard.delay > 0:
			draw_arc(hazard.pos,hazard.radius,0,TAU,48,Color("df8d71"),2.5,true)
			draw_line(hazard.pos-Vector2(10,0),hazard.pos+Vector2(10,0),Color("e2a187"),2)
		else:
			weapons.draw_field(hazard,"acid_loop",Color(1,0.52,0.32,0.65))
	weapons.draw_fields()
	scavenging.draw()
	for drop in drops:
		if not drop.active:
			continue
		if drop.has("heal"):
			weapons.sprite("water_loop",fposmod(clock*1.8,1.0),drop.pos,Vector2(32,32))
			draw_string(content.font,drop.pos+Vector2(-6,4),"+",0,-1,17,Color("e1edd5"))
		elif drop.crate:
			draw_texture_rect(content.prop_textures[12],Rect2(drop.pos-Vector2(24,32),Vector2(48,48)),false)
			draw_arc(drop.pos,28,0,TAU,24,Color(0.78,0.74,0.5,0.5),1.2,true)
		else:
			var color = Color("d3b66e") if drop.gold > 0 else Color("8db6aa")
			draw_circle(drop.pos,5.5,Color(color,0.14))
			draw_colored_polygon(PackedVector2Array([drop.pos+Vector2(0,-4),drop.pos+Vector2(3.5,0),drop.pos+Vector2(0,4),drop.pos+Vector2(-3.5,0)]),color)
	if not rescue_done and not rescue.is_empty():
		var at = rescue.pos
		draw_circle(at,37,Color(0.78,0.71,0.45,0.07))
		draw_arc(at,37+sin(clock*3)*2,0,TAU,36,Color("b8ca9a"),1.7,true)
		_draw_actor(at,content.survivors[rescue.id].sprite,1,0,0,0,70,Color(0.86,0.9,0.8))
		draw_string(content.font,at+Vector2(-44,-91),"有人求救",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("eee0b6"))
		if captain.distance_to(at) < 105:
			draw_string(content.font,at+Vector2(-65,43),"按住 E  救援",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("eee0b6"))
			draw_rect(Rect2(at+Vector2(-35,52),Vector2(70,5)),Color("28392e"))
			draw_rect(Rect2(at+Vector2(-35,52),Vector2(70*rescue_progress/1.6,5)),Color("b8ca9a"))
	feedback.draw_corpses()
	var sorted_actors = []
	var camera = Vector2(clampf(captain.x,800,1600),clampf(captain.y,440,1360))
	var visible_world = Rect2(camera-Vector2(860,390),Vector2(1720,910))
	for index in range(enemies.size()):
		if enemies[index].active and visible_world.has_point(enemies[index].pos):
			sorted_actors.append({"y":enemies[index].pos.y,"kind":0,"index":index})
	for index in range(formation.members.size()):
		sorted_actors.append({"y":formation.members[index].pos.y,"kind":1,"index":index})
	sorted_actors.append({"y":captain.y,"kind":2,"index":0})
	sorted_actors.sort_custom(func(a,b): return a.y < b.y)
	for actor in sorted_actors:
		if actor.kind == 0:
			var enemy = enemies[actor.index]
			var size_value = 124.0 if enemy.boss else (91.0 if enemy.elite else 69.0)
			var tint = Color(0.87,0.89,0.80)
			if enemy.hit > 0 and progress.settings.flash:
				tint = Color(1.35,1.18,1.0)
			_draw_actor(enemy.pos,enemy.sprite,1.0 if cos(enemy.facing) >= 0 else -1.0,0.0 if enemy.windup > 0 or enemy.pos.distance_to(enemy.target_pos) < 5 else (1.3 if enemy.dash > 0 else 1.0),enemy.phase,0,size_value,tint,enemy)
			if enemy.hp < enemy.max_hp and (enemy.elite or enemy.boss):
				draw_rect(Rect2(enemy.pos+Vector2(-28,-size_value-7),Vector2(56,4)),Color("302a25"))
				draw_rect(Rect2(enemy.pos+Vector2(-28,-size_value-7),Vector2(56*enemy.hp/enemy.max_hp,4)),Color("b0644f"))
			if enemy.windup > 0:
				var red = Color(0.9,0.45,0.32,0.75)
				if enemy.behavior in ["charge","roadboss"]:
					draw_line(enemy.pos,enemy.aim,Color(0.8,0.3,0.18,0.17),enemy.radius*1.3,true)
					draw_line(enemy.pos,enemy.aim,red,2,true)
				else:
					draw_arc(enemy.aim if enemy.behavior in ["spit","warden"] else enemy.pos,145 if enemy.boss else 65,0,TAU,40,red,2.0,true)
			if enemy.behavior in ["armor","warden"]:
				draw_arc(enemy.pos,enemy.radius+8,enemy.facing-0.95,enemy.facing+0.95,18,Color(0.68,0.72,0.7,0.75),3,true)
		elif actor.kind == 1:
			var person = formation.members[actor.index]
			_draw_actor(person.pos,content.survivors[person.id].sprite,person.facing,person.moving,person.phase,person.attack,70,Color.WHITE,{},"ally"+str(actor.index))
			draw_circle(person.pos+Vector2(0,7),2,Color(content.survivors[person.id].color))
		else:
			draw_arc(captain,23,0,TAU,36,Color("e3d9ab"),2.0,true)
			var tint = Color.WHITE
			if invulnerability > 0 and progress.settings.flash:
				tint.a = 0.6+0.4*absf(sin(clock*18))
			_draw_actor(captain,int(content.classes[run.class_id].sprite),captain_facing,captain_move,0,captain_attack,80,tint,{},"captain")
			draw_colored_polygon(PackedVector2Array([captain+Vector2(-5,-92),captain+Vector2(5,-92),captain+Vector2(0,-85)]),Color("eee1b3"))
	weapons.draw()
	feedback.draw()
	if build.shield>0: weapons.sprite("armor_hit",0.22,captain-Vector2(0,25),Vector2(92,92),0,0.26)
	for enemy in enemies:
		if not enemy.active or not visible_world.has_point(enemy.pos): continue
		if enemy.get("wet",0) > 0: draw_arc(enemy.pos,enemy.radius+3,0.2,PI-0.2,12,Color("8cc9cf"),2)
		if enemy.get("corrode",0) > 0: draw_arc(enemy.pos,enemy.radius+5,PI,TAU,12,Color("bcce78"),2)
		if enemy.get("stun",0) > 0: draw_string(content.font,enemy.pos+Vector2(-8,-65),"晕",0,-1,16,Color("ded4a0"))
	if not city.interaction.is_empty() and scavenging.nearby()<0 and (rescue_done or rescue.is_empty() or captain.distance_to(rescue.pos) >= 75):
		var at = captain+Vector2(-125,46)
		draw_string(content.font,at,"按住 E · "+city.fixture_label(city.interaction),0,-1,18,Color("eee0b6"))
		draw_rect(Rect2(at+Vector2(0,9),Vector2(220,5)),Color("28392e"))
		draw_rect(Rect2(at+Vector2(0,9),Vector2(220*city.interaction_progress/0.8,5)),Color("c5c08f"))

	profile_end("draw",render_time)

func profile_end(label: String,started: int):
	if not profile_enabled: return
	profile_totals[label] = profile_totals.get(label,0.0)+(Time.get_ticks_usec()-started)/1000.0
	profile_counts[label] = profile_counts.get(label,0)+1
