exec((__import__('pathlib').Path(__file__).parent/'update_v2.py').read_text(encoding='utf-8').split('new = [')[0])
p=read('scripts/city_map.gd')
p=p.replace('var obstacles:','var geometry = []\nvar fixtures = []\nvar revision = 0\nvar astar = AStarGrid2D.new()\nvar interaction = {}\nvar interaction_progress = 0.0\nvar interaction_latched = false\nvar events = []\nvar obstacles:')
p=p.replace('\t_build_grid()\n\tupdate_flow', '\t_build_tactics()\n\t_rebuild_geometry()\n\tupdate_flow',1)
p=p.replace('\tobstacles.append(rect)','\tgeometry.append({"rect":rect,"kind":"wall"})\n\tobstacles.append(rect)',1)
p=p.replace('\t\tobstacles.append(solid_rect)','\t\tgeometry.append({"rect":solid_rect,"kind":"low"})\n\t\tobstacles.append(solid_rect)',1)
p=p.replace('\tobstacles.clear()','\tgeometry.clear()\n\tobstacles.clear()',1)
p=p.replace('\t\t\tprop(4 + index % 2,pos,Vector2(164,224),Rect2(pos+Vector2(-53,-130),Vector2(106,163)))','\t\t\t# The additional oil cars are interactive; outer wrecks remain low cover.\n\t\t\tprop(4 + index % 2,pos,Vector2(164,224),Rect2(pos+Vector2(-53,-130),Vector2(106,163)))')
p=p.replace('\tvar amount = grid_size.x * grid_size.y','''\tastar.region = Rect2i(Vector2i.ZERO,grid_size)
\tastar.cell_size = Vector2.ONE*cell_size
\tastar.offset = Vector2.ONE*cell_size*0.5
\tastar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
\tastar.update()
\tvar amount = grid_size.x * grid_size.y''')
p=p.replace('\t\t\tsolids[y*grid_size.x+x] = 0 if point_free(point,18) else 1','\t\t\tsolids[y*grid_size.x+x] = 0 if point_free(point,18) else 1\n\t\t\tastar.set_point_solid(Vector2i(x,y),solids[y*grid_size.x+x] == 1)')
p=p.replace('clearance: float = 16.0','clearance: float = 0.0')
p=p.replace('\tvar cell = to_cell(pos)\n\tvar best_point', '''\tvar start_cell = to_cell(pos)
\tvar end_cell = to_cell(target)
\tif end_cell != flow_target and not astar.is_point_solid(start_cell) and not astar.is_point_solid(end_cell):
\t\tvar path = astar.get_point_path(start_cell,end_cell)
\t\tfor i in range(mini(4,path.size()-1),0,-1):
\t\t\tif clear_line(pos,path[i],clearance): return pos.direction_to(path[i])
\tvar cell = to_cell(pos)
\tvar best_point''')
# Draw low cover footprints and fixtures at end, geometry thinwalls remains intact.
p += '''
func _build_tactics():
\tfixtures.clear()
\tfor data in definition.get("tactical",[]):
\t\tvar entry = data.duplicate(true)
\t\tentry.rect = Rect2(data.rect[0],data.rect[1],data.rect[2],data.rect[3])
\t\tentry.pos = entry.rect.get_center()
\t\tentry.max_hp = entry.hp
\t\tentry.destroyed = false
\t\tentry.cooldown = 0.0
\t\tentry.timer = 0.0
\t\tentry.active = entry.get("enabled",false)
\t\tfixtures.append(entry)

func _fixture_blocks(f: Dictionary) -> bool:
\treturn not f.destroyed and (f.kind == "car" or (f.kind in ["door","shutter"] and f.get("closed",false)))

func _rebuild_geometry():
\tobstacles.clear()
\tfor item in geometry: obstacles.append(item.rect)
\tfor f in fixtures:
\t\tif _fixture_blocks(f): obstacles.append(f.rect)
\trevision += 1
\tvar previous = (Vector2(flow_target)+Vector2.ONE*0.5)*cell_size
\t_build_grid()
\tflow_target = Vector2i(-100,-100)
\tupdate_flow(previous.clamp(Vector2(50,50),bounds.end-Vector2(50,50)))
\tqueue_redraw()

func segment_fraction(a: Vector2, b: Vector2, rect: Rect2) -> float:
\tvar direction = b-a
\tvar near = 0.0
\tvar far = 1.0
\tfor axis in range(2):
\t\tif absf(direction[axis]) < 0.00001:
\t\t\tif a[axis] < rect.position[axis] or a[axis] > rect.end[axis]: return INF
\t\telse:
\t\t\tvar first = (rect.position[axis]-a[axis])/direction[axis]
\t\t\tvar second = (rect.end[axis]-a[axis])/direction[axis]
\t\t\tnear = maxf(near,minf(first,second))
\t\t\tfar = minf(far,maxf(first,second))
\t\t\tif near > far: return INF
\treturn near

func wall_hit(a: Vector2, b: Vector2, lob: bool = false) -> float:
\tvar first = INF
\tfor item in geometry:
\t\tif lob and item.kind == "low": continue
\t\tfirst = minf(first,segment_fraction(a,b,item.rect))
\tfor f in fixtures:
\t\tif not _fixture_blocks(f) or (lob and f.kind == "car"): continue
\t\tfirst = minf(first,segment_fraction(a,b,f.rect))
\treturn first

func attack_clear(a: Vector2, b: Vector2, lob: bool = false) -> bool:
\treturn wall_hit(a,b,lob) == INF

func reset_wave():
\tfor f in fixtures:
\t\tf.cooldown = 0.0
\t\tf.timer = 0.0
\t\tif f.kind == "shutter": f.closed = false
\t\tif f.kind == "alarm": f.active = true
\t\tif f.kind == "broadcast": f.active = false
\tinteraction_latched = false
\tinteraction_progress = 0
\t_rebuild_geometry()

func snapshot() -> Dictionary:
\tvar result = {}
\tfor f in fixtures:
\t\tresult[f.id] = {"hp":f.hp,"destroyed":f.destroyed,"closed":f.get("closed",false),"active":f.active,"cooldown":f.cooldown,"timer":f.timer}
\treturn result

func restore(saved: Dictionary):
\tfor f in fixtures:
\t\tvar entry = saved.get(f.id,{})
\t\tif not entry is Dictionary: continue
\t\tfor key in ["hp","cooldown","timer"]:
\t\t\tif entry.get(key) is float or entry.get(key) is int: f[key] = maxf(0,float(entry[key]))
\t\tfor key in ["destroyed","closed","active"]:
\t\t\tif entry.get(key) is bool: f[key] = entry[key]
\t_rebuild_geometry()

func damage_fixture(f: Dictionary, amount: float):
\tif f.destroyed or f.kind not in ["car","door"]: return
\tf.hp -= amount
\tif f.hp <= 0:
\t\tf.destroyed = true
\t\tf.closed = false
\t\tif f.kind == "car": events.append({"kind":"explosion","pos":f.pos,"radius":220.0,"damage":240.0})
\t\t_rebuild_geometry()
\tqueue_redraw()

func blocker(a: Vector2, b: Vector2) -> Dictionary:
\tvar nearest = wall_hit(a,b)
\tfor f in fixtures:
\t\tif _fixture_blocks(f) and f.kind in ["door","car"] and segment_fraction(a,b,f.rect) <= nearest+0.001: return f
\treturn {}

func is_wet(at: Vector2) -> bool:
\tfor f in fixtures:
\t\tif f.kind == "puddle" and f.rect.has_point(at): return true
\treturn false

func noise_target(at: Vector2) -> Vector2:
\tvar best = Vector2.INF
\tvar distance = 620.0
\tfor f in fixtures:
\t\tif f.kind in ["alarm","broadcast"] and f.active and at.distance_to(f.pos) < distance:
\t\t\tbest = f.pos
\t\t\tdistance = at.distance_to(f.pos)
\treturn best

func fixture_label(f: Dictionary) -> String:
\tif f.kind == "door": return "打开木门" if f.closed else "关门拖延 · 会被破坏"
\tif f.kind == "shutter": return "卷帘门：关闭中" if f.closed else ("卷帘门冷却 %s秒" % ceili(f.cooldown) if f.cooldown > 0 else "关闭卷帘门 · 持续8秒")
\tif f.kind == "car": return "点燃漏油车 · 爆破开路"
\tif f.kind == "alarm": return "关闭警铃 · 停止引怪" if f.active else "警铃已关闭"
\treturn "广播冷却 %s秒" % ceili(f.cooldown) if f.cooldown > 0 else "启动广播 · 引怪10秒"

func tick_tactics(delta: float, captain: Vector2, held: bool, rescue_priority: bool, actors: Array):
\tfor f in fixtures:
\t\tf.cooldown = maxf(0,f.cooldown-delta)
\t\tif f.timer > 0:
\t\t\tf.timer -= delta
\t\t\tif f.timer <= 0:
\t\t\t\tif f.kind == "shutter":
\t\t\t\t\tf.closed = false
\t\t\t\t\t_rebuild_geometry()
\t\t\t\tif f.kind == "broadcast": f.active = false
\tvar candidate = {}
\tvar distance = 100.0
\tfor f in fixtures:
\t\tif f.destroyed or f.kind == "puddle": continue
\t\tvar nearest = captain.clamp(f.rect.position,f.rect.end)
\t\tif captain.distance_to(nearest) < distance and attack_clear(captain,nearest.move_toward(captain,1)):
\t\t\tdistance = captain.distance_to(nearest)
\t\t\tcandidate = f
\tif candidate.get("id","") != interaction.get("id",""): interaction_progress = 0
\tinteraction = candidate
\tif not held: interaction_latched = false
\tif rescue_priority or candidate.is_empty() or not held or interaction_latched:
\t\tinteraction_progress = 0
\t\treturn
\tif candidate.cooldown > 0 or (candidate.kind == "alarm" and not candidate.active): return
\tinteraction_progress += delta
\tif interaction_progress < 0.8: return
\tinteraction_latched = true
\tinteraction_progress = 0
\tif candidate.kind in ["door","shutter"]:
\t\tif not candidate.closed:
\t\t\tfor pos in actors:
\t\t\t\tif candidate.rect.grow(25).has_point(pos):
\t\t\t\t\tevents.append({"kind":"message","text":"门口有人 · 移开后再关门"})
\t\t\t\t\treturn
\t\tcandidate.closed = not candidate.closed
\t\tif candidate.kind == "shutter":
\t\t\tcandidate.timer = 8.0
\t\t\tcandidate.cooldown = 23.0
\t\t_rebuild_geometry()
\telif candidate.kind == "car": damage_fixture(candidate,99999)
\telif candidate.kind == "alarm": candidate.active = false
\telif candidate.kind == "broadcast":
\t\tcandidate.active = true
\t\tcandidate.timer = 10.0
\t\tcandidate.cooldown = 22.0
\tqueue_redraw()

func draw_tactics():
\tfor item in geometry:
\t\tif item.kind == "low": draw_rect(item.rect,Color(0.7,0.72,0.55,0.35),false,1.5)
\tfor f in fixtures:
\t\tif f.destroyed:
\t\t\tdraw_line(f.rect.position,f.rect.end,Color(0.17,0.16,0.12,0.8),8)
\t\t\tcontinue
\t\tvar color = Color("baaf85")
\t\tmatch f.kind:
\t\t\t"puddle":
\t\t\t\tdraw_style_box(_water_style(),f.rect)
\t\t\t\tfor i in range(5): draw_arc(f.pos+Vector2(i*27-54,i%2*22),22,0.1,2.8,16,Color(0.54,0.72,0.72,0.35),1)
\t\t\t"car":
\t\t\t\tdraw_texture_rect(content.prop_textures[4],Rect2(f.rect.position-Vector2(26,30),f.rect.size+Vector2(52,46)),false)
\t\t\t\tdraw_rect(f.rect,Color("a07849"),false,2)
\t\t\t\tdraw_circle(f.pos+Vector2(65,30),28,Color(0.15,0.12,0.04,0.6))
\t\t\t"door", "shutter":
\t\t\t\tif f.closed:
\t\t\t\t\tdraw_rect(f.rect,Color("776149") if f.kind == "door" else Color("687370"))
\t\t\t\t\tfor y in range(int(f.rect.position.y),int(f.rect.end.y),14): draw_line(Vector2(f.rect.position.x,y),Vector2(f.rect.end.x,y+3),Color("31392e"),2)
\t\t\t\telse: draw_rect(f.rect,Color(0.69,0.71,0.53,0.28),false,2)
\t\t\t\tdraw_string(content.font,f.pos+Vector2(-22,-f.rect.size.y/2-15),"木门" if f.kind == "door" else "卷帘",0,-1,16,color)
\t\t\t"alarm", "broadcast":
\t\t\t\tdraw_rect(f.rect,Color("3d493f"))
\t\t\t\tdraw_circle(f.pos,14,Color("bf7059") if f.active else Color("91ad8a"))
\t\t\t\tif f.active: draw_arc(f.pos,34,0,TAU,24,Color(0.8,0.6,0.3,0.55),2)
\t\t\t\tdraw_string(content.font,f.pos+Vector2(-23,-32),"警铃" if f.kind == "alarm" else "广播",0,-1,16,color)

func _water_style() -> StyleBoxFlat:
\tvar style = StyleBoxFlat.new()
\tstyle.bg_color = Color(0.23,0.42,0.45,0.32)
\tstyle.set_corner_radius_all(40)
\treturn style
'''
p=p.replace('\tdraw_rect(bounds.grow(-18)', '\tdraw_tactics()\n\tdraw_rect(bounds.grow(-18)',1)
write('scripts/city_map.gd',p)

