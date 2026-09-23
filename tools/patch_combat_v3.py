from pathlib import Path
p=Path(__file__).resolve().parents[1]/'scripts/combat.gd';s=p.read_text(encoding='utf-8')
s=s.replace('signal level_requested','signal level_requested\nsignal equipment_requested')
s=s.replace('var feedback = Feedback.new()','var feedback = Feedback.new()\nvar build = preload("res://scripts/build_runtime.gd").new()\nvar scavenging = preload("res://scripts/scavenge.gd").new()\nvar elite_serial = 0\nvar support_serial = 0\nvar boss_started = -1.0\nvar boss_duration = 0.0')
s=s.replace('var width_limit = 310','var width_limit = 220')
s=s.replace('\tfeedback.setup(self)','\tfeedback.setup(self)\n\tbuild.setup(self)\n\tscavenging.setup(self)')
s=s.replace('\tfeedback.reset()','\tfeedback.reset()\n\tbuild.reset()\n\telite_serial=0\n\tsupport_serial=0\n\tboss_started=-1\n\tboss_duration=0')
a=s.index('\tfor i in range(5):\n\t\t_drop');b=s.index('\tformation.sync',a);s=s[:a]+'\tscavenging.begin()\n'+s[b:]
s=s.replace('\tfeedback.update(delta)','\tfeedback.update(delta)\n\tbuild.update(delta)')
s=s.replace('run.health = minf(run.stats.max_health,run.health+run.stats.regen*delta)','build.heal(minf(run.stats.regen,run.stats.max_health*0.03)*delta)')
s=s.replace('movement*run.stats.move_speed*delta','movement*run.stats.move_speed*(1.25 if build.stride>0 else 1.0)*delta')
s=s.replace('\t_update_tactics(delta)','\t_update_tactics(delta)\n\tif run.mode != "combat": return')
a=s.index('func _update_spawn(');b=s.index('func spawn_enemy(',a)
s=s[:a]+'''func spawn_point() -> Vector2:
	var phase=int(elapsed/20)%4
	for attempt in range(60):
		var angle=run.rng.randf()*TAU if run.wave<7 else phase*PI/2+run.rng.randf_range(-0.65,0.65)
		var at=captain+Vector2.from_angle(angle)*run.rng.randf_range(620,900)
		if city.point_free(at,28) and at.distance_to(captain)>600: return at
	return city.nearby_open(captain,850,run.rng)

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
				spawn_enemy(kinds[index],spawn_point())
		if elite_serial<data.elite_times.size() and elapsed>=data.elite_times[elite_serial] and active_count<width_limit:
			elite_serial+=1
			spawn_enemy(content.maps[run.map_id].enemies[2],spawn_point(),true)
			message.emit("精英接近 · 留意预警")
		if data.boss and elapsed>3 and not boss_spawned and active_count<width_limit:
			boss_spawned=true
			boss_started=elapsed
			spawn_enemy(content.maps[run.map_id].boss,spawn_point())
			sound_requested.emit("boss")
		if data.boss and support_serial<2 and elapsed>25+support_serial*20:
			support_serial+=1
			for i in range(6):
				if active_count<width_limit: spawn_enemy(content.maps[run.map_id].enemies[1+i%2],spawn_point())
	elif not clear_started:
		clear_started=true
		message.emit("尸潮暂歇 · 清理剩余感染者后整备")

''' +s[b:]
s=s.replace('var hp = float(data.hp) * (1.0 if boss else float(content.wave(run.wave).hp)) * (5.0 if elite else 1.0)','var scaling=run.wave_data()\n\tvar hp = float(data.hp) * ((1.4 if run.difficulty=="easy" else 2.0) if boss else float(scaling.hp)) * (5.0 if elite else 1.0)')
s=s.replace('float(data.speed)*(1.2 if elite else 1.0)','float(data.speed)*scaling.speed*(1.2 if elite else 1.0)').replace('float(data.damage)*(1.5 if elite else 1.0)','float(data.damage)*scaling.damage*(1.5 if elite else 1.0)')
s=s.replace('["wet","stun","corrode","resolve"]','["wet","stun","corrode","resolve","burning","resonance"]')
s=s.replace('hazards.append({"pos":at,"radius":radius,"life":life,"damage":damage,','hazards.append({"pos":at,"radius":radius,"life":life,"damage":damage*run.wave_data().damage,')
s=s.replace('\tcity.tick_tactics(delta,captain,held,rescue_priority,actors)','\tscavenging.tick(delta,held,rescue_priority)\n\tcity.tick_tactics(delta,captain,held,rescue_priority or scavenging.nearby()>=0 or run.mode!="combat",actors)')
a=s.index('func _damage(');b=s.index('func _hurt(',a)
s=s[:a]+'''func _damage(index: int,amount: float,origin: Vector2,weapon_id: String="",source: String="world",secondary: bool=false):
	var enemy=enemies[index]
	if not enemy.active: return
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

''' +s[b:]
s=s.replace('run.health -= maxf(1,amount-run.stats.armor)','run.health -= build.absorb(maxf(1,amount-run.stats.armor))')
s=s.replace('func _drop(at: Vector2, experience: float, gold: int, crate: bool = false):','func _drop(at: Vector2, experience: float, gold: int, crate: bool = false):\n\tif run.level>=17: experience=0\n\tif experience<=0 and gold<=0 and not crate: return')
s=s.replace('if item.active and not item.crate and item.pos.distance_squared_to(at) < 900:','if item.active and not item.crate and not item.has("heal") and item.pos.distance_squared_to(at) < 900:')
s=s.replace('if distance < run.stats.pickup:','if distance < run.stats.pickup or item.get("magnet",false):')
s=s.replace('\t\t\trun.supplies += int(item.gold)\n\t\t\trun.add_xp(item.xp)','\t\t\trun.supplies += int(item.gold)\n\t\t\trun.add_xp(item.xp)\n\t\t\tbuild.pickup(int(item.gold))\n\t\t\tif item.has("heal"): build.heal(item.heal,true)',1)
s=s.replace('\t\t\trun.recruit(rescue.id,true)','\t\t\trun.recruit(rescue.id,true)\n\t\t\tbuild.rescued()')
s=s.replace('\tweapons.draw_fields()','\tweapons.draw_fields()\n\tscavenging.draw()')
s=s.replace('\t\tif drop.crate:\n','\t\tif drop.has("heal"):\n\t\t\tweapons.sprite("water_loop",fposmod(clock*1.8,1.0),drop.pos,Vector2(32,32))\n\t\t\tdraw_string(content.font,drop.pos+Vector2(-6,4),"+",0,-1,17,Color("e1edd5"))\n\t\telif drop.crate:\n')
s=s.replace('\tfeedback.draw()','\tfeedback.draw()\n\tif build.shield>0: weapons.sprite("armor_hit",0.22,captain-Vector2(0,25),Vector2(92,92),0,0.26)')
p.write_text(s,encoding='utf-8')
