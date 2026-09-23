exec((__import__('pathlib').Path(__file__).parent/'update_v2.py').read_text(encoding='utf-8').split('new = [')[0])
p=read('scripts/combat.gd')
p=p.replace('const Formation =','const WeaponRuntime = preload("res://scripts/weapons_runtime.gd")\nvar weapons = WeaponRuntime.new()\n\nconst Formation =',1)
p=p.replace('\tcity = map_node','\tcity = map_node\n\tcity.restore(run.map_state)\n\tweapons.setup(self)',1)
p=p.replace('\trun.wave += 1','\tcity.reset_wave()\n\tweapons.reset()\n\trun.wave += 1',1)
p=p.replace('\t_update_spawn(delta)','\t_update_tactics(delta)\n\t_update_spawn(delta)',1)
p=p.replace('\t_update_attacks(delta)','\tweapons.update(delta)\n\t_update_attacks(delta)',1)
p=p.replace('"slow":0.0}', '"slow":0.0,"wet":0.0,"stun":0.0,"corrode":0.0,"resolve":0.0,"stuck":0.0,"stuck_pos":at,"stuck_time":0.0,"target_pos":captain}',1)
p=p.replace('\t\tenemy.ability -= delta', '''\t\tfor status in ["wet","stun","corrode","resolve"]: enemy[status] = maxf(0,enemy.get(status,0)-delta)
\t\tif city.is_wet(enemy.pos): enemy.wet = 2.0
\t\tvar pursuit = captain
\t\tif not enemy.boss and not enemy.elite:
\t\t\tvar noise = city.noise_target(enemy.pos)
\t\t\tvar lure = weapons.lure_target(enemy)
\t\t\tif noise != Vector2.INF: pursuit = noise
\t\t\tif lure != Vector2.INF: pursuit = lure
\t\tenemy.target_pos = pursuit
\t\tenemy.stuck_time += delta
\t\tif enemy.stuck_time >= 0.65:
\t\t\tenemy.stuck = enemy.stuck+0.65 if enemy.pos.distance_to(enemy.stuck_pos) < 5 else 0.0
\t\t\tenemy.stuck_time = 0.0
\t\t\tenemy.stuck_pos = enemy.pos
\t\t\tif enemy.stuck > 0.6: enemy.nav = 0
\t\tif enemy.stun > 0:
\t\t\tenemy.windup = 0.0
\t\t\tenemy.dash = 0.0
\t\t\tcontinue
\t\tif enemy.windup > 0 and not city.attack_clear(enemy.pos,enemy.aim):
\t\t\tenemy.windup = 0
\t\t\tenemy.ability = 0.4
\t\tenemy.ability -= delta''',1)
p=p.replace('var difference = captain-enemy.pos','var difference = pursuit-enemy.pos',1)
p=p.replace('enemy.direction = city.steer(enemy.pos,captain,enemy.radius*0.6)','enemy.direction = city.recovery_steer(enemy.pos,pursuit,enemy.radius*0.6) if enemy.stuck > 0.6 else city.steer(enemy.pos,pursuit,enemy.radius*0.6)')
p=p.replace('enemy.behavior == "spit" and difference.length() < 330','enemy.behavior == "spit" and difference.length() < 330 and city.attack_clear(enemy.pos,pursuit)')
p=p.replace('enemy.behavior == "warden" and city.clear_line(enemy.pos,captain)','enemy.behavior == "warden" and city.attack_clear(enemy.pos,pursuit)')
p=p.replace('and enemy.behavior not in ["chase","armor"]:', 'and enemy.behavior not in ["chase","armor"] and pursuit == captain and city.attack_clear(enemy.pos,captain):',1)
p=p.replace('\t\tif enemy.pos.distance_to(captain) < enemy.radius+12:', '''\t\tvar block = city.blocker(enemy.pos,pursuit)
\t\tif not block.is_empty() and enemy.pos.distance_to(enemy.pos.clamp(block.rect.position,block.rect.end)) < enemy.radius+28:
\t\t\tcity.damage_fixture(block,enemy.damage*delta*1.8)
\t\tif enemy.pos.distance_to(captain) < enemy.radius+12 and city.attack_clear(enemy.pos,captain):''',1)
p=p.replace('func _execute_ability(enemy: Dictionary):\n\tmatch', 'func _execute_ability(enemy: Dictionary):\n\tif not city.attack_clear(enemy.pos,enemy.aim): return\n\tmatch',1)
p=p.replace('city.clear_line(pos,enemy.pos)','city.attack_clear(pos,enemy.pos)')
start=p.index('func _update_attacks('); end=p.index('func _projectile(',start)
p=p[:start]+'''func _update_attacks(delta: float):
\tcaptain_cooldown -= delta
\tif captain_cooldown <= 0:
\t\tvar weapon = run.weapon(content.classes[run.class_id].weapon)
\t\tvar target = weapons.target(captain,weapon)
\t\tif target >= 0:
\t\t\tweapons.fire(captain,weapon,target,"captain")
\t\t\tcaptain_cooldown = weapon.cooldown
\t\t\tcaptain_attack = 0.18
\t\telse: captain_cooldown = 0.1
\tfor i in range(formation.members.size()):
\t\tvar person = formation.members[i]
\t\tperson.cooldown -= delta
\t\tif person.cooldown > 0: continue
\t\tvar weapon = run.weapon(content.survivors[person.id].weapon)
\t\tvar target = weapons.target(person.pos,weapon)
\t\tif target >= 0:
\t\t\tweapons.fire(person.pos,weapon,target,"ally"+str(i))
\t\t\tperson.cooldown = weapon.cooldown
\t\t\tperson.attack = 0.17
\t\t\tperson.facing = 1.0 if enemies[target].pos.x >= person.pos.x else -1.0
\t\t\tif weapon.id in ["cleaver","chainsaw"]: person.engage_time = 0.45
\t\telse:
\t\t\tperson.cooldown = 0.14
\t\t\tif weapon.id in ["cleaver","chainsaw"]:
\t\t\t\tvar seek = weapon.duplicate()
\t\t\t\tseek.range = 245.0
\t\t\t\tvar close = weapons.target(person.pos,seek)
\t\t\t\tif close >= 0 and enemies[close].pos.distance_to(captain) < 265:
\t\t\t\t\tperson.engage = enemies[close].pos.move_toward(person.pos,weapon.range*0.65)
\t\t\t\t\tperson.engage_time = 0.65

func _attack(origin: Vector2, weapon: Dictionary, target: int):
\tweapons.fire(origin,weapon,target,"test")

''' +p[end:]
start=p.index('func _update_projectiles(');end=p.index('func _damage(',start)
p=p[:start]+'''func _update_projectiles(delta: float):
\tweapons.projectiles_tick(delta)

func _fire_pool(bullet: Dictionary):
\tweapons.field(bullet.destination,run.weapon("molotov"),bullet.get("source","legacy"),"fire",bullet.splash,3)

func _update_hazards(delta: float):
\tweapons.fields_tick(delta)
\tfor hazard in hazards:
\t\tif hazard.get("friendly",false): continue
\t\tif hazard.delay > 0:
\t\t\thazard.delay -= delta
\t\t\tcontinue
\t\thazard.life -= delta
\t\tif captain.distance_to(hazard.pos) < hazard.radius+8 and city.attack_clear(hazard.pos,captain): _hurt(hazard.damage)
\thazards = hazards.filter(func(h): return h.life > 0)

func _update_tactics(delta: float):
\tvar held = test_interact or Input.is_action_pressed("interact")
\tvar rescue_priority = not rescue_done and not rescue.is_empty() and captain.distance_to(rescue.pos) < 75 and city.attack_clear(captain,rescue.pos)
\tvar actors = [captain]
\tfor p in formation.members: actors.append(p.pos)
\tfor e in enemies:
\t\tif e.active: actors.append(e.pos)
\tcity.tick_tactics(delta,captain,held,rescue_priority,actors)
\tfor event in city.events:
\t\tif event.kind == "message": message.emit(event.text)
\t\telif event.kind == "explosion":
\t\t\tweapons.pulse(event.pos,event.radius,event.damage,event.pos,0.6)
\t\t\tweapons.effect("landing",event.pos,event.pos,event.radius,Color("dfa870"),0.7)
\t\t\tsound_requested.emit("explosion")
\tcity.events.clear()

''' +p[end:]
p=p.replace('amount *= 0.30 if enemy.boss else 0.55','amount *= (0.70 if enemy.boss else 0.85) if enemy.get("corrode",0) > 0 else (0.30 if enemy.boss else 0.55)')
p=p.replace('captain.distance_to(rescue.pos) < 75 and (test_interact', 'captain.distance_to(rescue.pos) < 75 and city.attack_clear(captain,rescue.pos) and (test_interact')
p=p.replace('\trun.checkpoint_position = [captain.x,captain.y]','\trun.map_state = city.snapshot()\n\trun.checkpoint_position = [captain.x,captain.y]')
p=p.replace('\t\tvar friendly = hazard.get("friendly",false)','\t\tif hazard.get("friendly",false): continue\n\t\tvar friendly = false',1)
start=p.index('\tfor bullet in projectiles:',p.index('func _draw():'))
p=p[:start]+'''\tweapons.draw()
\tfor enemy in enemies:
\t\tif not enemy.active: continue
\t\tif enemy.get("wet",0) > 0: draw_arc(enemy.pos,enemy.radius+3,0.2,PI-0.2,12,Color("8cc9cf"),2)
\t\tif enemy.get("corrode",0) > 0: draw_arc(enemy.pos,enemy.radius+5,PI,TAU,12,Color("bcce78"),2)
\t\tif enemy.get("stun",0) > 0: draw_string(content.font,enemy.pos+Vector2(-8,-65),"晕",0,-1,16,Color("ded4a0"))
\tif not city.interaction.is_empty() and (rescue_done or rescue.is_empty() or captain.distance_to(rescue.pos) >= 75):
\t\tvar at = captain+Vector2(-125,46)
\t\tdraw_string(content.font,at,"按住 E · "+city.fixture_label(city.interaction),0,-1,18,Color("eee0b6"))
\t\tdraw_rect(Rect2(at+Vector2(0,9),Vector2(220,5)),Color("28392e"))
\t\tdraw_rect(Rect2(at+Vector2(0,9),Vector2(220*city.interaction_progress/0.8,5)),Color("c5c08f"))
'''
write('scripts/combat.gd',p)
p=read('scripts/formation.gd').replace('"phase":index*2.4','"phase":index*2.4,"engage":captain,"engage_time":0.0,"stuck":0.0,"previous":captain,"stuck_time":0.0')
p=p.replace('\t\tvar distance = person.pos.distance_to(target)', '''\t\tperson.engage_time = maxf(0,person.engage_time-delta)
\t\tif person.engage_time > 0 and person.engage.distance_to(captain) < 265 and city.clear_line(person.pos,person.engage,9): target = person.engage
\t\tperson.stuck_time += delta
\t\tif person.stuck_time > 0.6:
\t\t\tperson.stuck = person.stuck+0.6 if person.pos.distance_to(person.previous) < 4 else 0.0
\t\t\tperson.previous = person.pos
\t\t\tperson.stuck_time = 0.0
\t\tvar distance = person.pos.distance_to(target)''')
p=p.replace('var direction = city.steer(person.pos,target,9)','var direction = city.recovery_steer(person.pos,target,9) if person.stuck > 0.6 else city.steer(person.pos,target,9)')
write('scripts/formation.gd',p)
p=read('scripts/city_map.gd')+'''
func recovery_steer(pos: Vector2, target: Vector2, clearance: float) -> Vector2:
\tif clear_line(pos,target,clearance): return pos.direction_to(target)
\tvar end = to_cell(target)
\tif astar.is_point_solid(end): return steer(pos,target,clearance)
\tvar start = to_cell(pos)
\tvar best = Vector2.ZERO
\tvar score = INF
\tfor dy in range(-2,3):
\t\tfor dx in range(-2,3):
\t\t\tvar cell = start+Vector2i(dx,dy)
\t\t\tif _index(cell) < 0 or astar.is_point_solid(cell): continue
\t\t\tvar at = (Vector2(cell)+Vector2.ONE*0.5)*cell_size
\t\t\tif not clear_line(pos,at,clearance): continue
\t\t\tvar path = astar.get_point_path(cell,end)
\t\t\tif path.is_empty(): continue
\t\t\tvar cost = path.size()*cell_size+pos.distance_to(at)
\t\t\tif cost < score:
\t\t\t\tscore = cost
\t\t\t\tbest = pos.direction_to(at)
\t\t\t\tif pos.distance_to(at) < 12 and path.size() > 1 and clear_line(pos,path[1],clearance): best = pos.direction_to(path[1])
\treturn best
'''
write('scripts/city_map.gd',p)
