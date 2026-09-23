extends Node2D

var content
var definition = {}
var bounds = Rect2(0,0,2400,1800)
var geometry = []
var fixtures = []
var revision = 0
var astar = AStarGrid2D.new()
var interaction = {}
var interaction_progress = 0.0
var interaction_latched = false
var events = []
var obstacles: Array[Rect2] = []
var props = []
var rooms: Array[Rect2] = []
var flow = PackedInt32Array()
var solids = PackedByteArray()
var grid_size = Vector2i(50,38)
var cell_size = 48.0
var flow_target = Vector2i(-100,-100)
var local_rng = RandomNumberGenerator.new()

func setup(book, id: String):
	content = book
	definition = book.maps[id]
	local_rng.seed = 61107
	_build()
	for data in definition.get("barriers",[]):
		var r = data.rect
		geometry.append({"rect":Rect2(r[0],r[1],r[2],r[3]),"kind":data.kind,"sprite":data.get("sprite",-1)})
	_build_tactics()
	_rebuild_geometry()
	update_flow(Vector2(1200,900))
	queue_redraw()

func wall(rect: Rect2):
	geometry.append({"rect":rect,"kind":"wall"})
	obstacles.append(rect)

func prop(index: int, pos: Vector2, size_value: Vector2, solid_rect: Rect2 = Rect2()):
	props.append({"index":index,"pos":pos,"size":size_value})
	if solid_rect.size != Vector2.ZERO:
		geometry.append({"rect":solid_rect,"kind":"low"})
		obstacles.append(solid_rect)

func _build():
	geometry.clear()
	obstacles.clear()
	props.clear()
	rooms.clear()
	if definition.id == "school":
		for base in [Vector2(240,210), Vector2(1530,210), Vector2(240,1120), Vector2(1530,1120)]:
			var room = Rect2(base,Vector2(630,480))
			rooms.append(room)
			wall(Rect2(base,Vector2(630,22)))
			wall(Rect2(base+Vector2(0,458),Vector2(630,22)))
			wall(Rect2(base,Vector2(22,170)))
			wall(Rect2(base+Vector2(0,310),Vector2(22,170)))
			wall(Rect2(base+Vector2(608,0),Vector2(22,170)))
			wall(Rect2(base+Vector2(608,310),Vector2(22,170)))
			for dx in [160,420]:
				var at = base+Vector2(dx,225)
				prop(0,at,Vector2(138,132),Rect2(at+Vector2(-48,-28),Vector2(96,50)))
			prop(2,base+Vector2(305,96),Vector2(155,138))
			prop(3,base+Vector2(545,382),Vector2(100,125),Rect2(base+Vector2(510,348),Vector2(72,45)))
		for y in [365,1280]:
			prop(1,Vector2(1050,y),Vector2(120,145),Rect2(1015,y-30,76,50))
			prop(1,Vector2(1360,y),Vector2(120,145),Rect2(1325,y-30,76,50))
	elif definition.id == "street":
		for index in range(12):
			var x = 500.0 if index % 2 == 0 else 1850.0
			var y = 220.0 + (index / 2) * 258.0
			var pos = Vector2(x + local_rng.randf_range(-95,95),y)
			# The additional oil cars are interactive; outer wrecks remain low cover.
			prop(4 + index % 2,pos,Vector2(164,224),Rect2(pos+Vector2(-53,-130),Vector2(106,163)))
		for pos in [Vector2(970,400),Vector2(1430,1350),Vector2(1120,1550)]:
			prop(6,pos,Vector2(170,115),Rect2(pos+Vector2(-68,-28),Vector2(136,52)))
		for y in [240,820,1440]:
			prop(7,Vector2(280,y),Vector2(120,180))
			prop(7,Vector2(2140,y),Vector2(120,180))
	else:
		for base in [Vector2(200,200),Vector2(1580,200),Vector2(200,1130),Vector2(1580,1130)]:
			rooms.append(Rect2(base,Vector2(620,460)))
			wall(Rect2(base,Vector2(620,18)))
			wall(Rect2(base+Vector2(0,442),Vector2(620,18)))
			for x in [0,602]:
				wall(Rect2(base+Vector2(x,0),Vector2(18,130)))
				wall(Rect2(base+Vector2(x,330),Vector2(18,130)))
			prop(8,base+Vector2(185,170),Vector2(200,142),Rect2(base+Vector2(110,128),Vector2(150,62)))
			prop(9,base+Vector2(430,330),Vector2(176,164),Rect2(base+Vector2(378,298),Vector2(105,50)))
			prop(11,base+Vector2(430,92),Vector2(145,128))
		prop(10,Vector2(1200,590),Vector2(300,250),Rect2(1080,500,240,133))
		prop(15,Vector2(1200,1500),Vector2(210,155),Rect2(1130,1470,140,58))
	for index in range(45):
		var pos = Vector2(local_rng.randf_range(80,2320),local_rng.randf_range(80,1720))
		prop(14,pos,Vector2(38,35) * local_rng.randf_range(0.8,1.6))

func _build_grid():
	astar.region = Rect2i(Vector2i.ZERO,grid_size)
	astar.cell_size = Vector2.ONE*cell_size
	astar.offset = Vector2.ONE*cell_size*0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	var amount = grid_size.x * grid_size.y
	solids.resize(amount)
	flow.resize(amount)
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var point = (Vector2(x,y)+Vector2(0.5,0.5))*cell_size
			solids[y*grid_size.x+x] = 0 if point_free(point,18) else 1
			astar.set_point_solid(Vector2i(x,y),solids[y*grid_size.x+x] == 1)

func point_free(pos: Vector2, radius: float = 13) -> bool:
	if not bounds.grow(-radius-24).has_point(pos):
		return false
	for obstacle in obstacles:
		if obstacle.grow(radius).has_point(pos):
			return false
	return true

func move_actor(pos: Vector2, movement: Vector2, radius: float = 13) -> Vector2:
	var distance = movement.length()
	var parts = maxi(1,int(ceil(distance/12.0)))
	var step = movement / float(parts)
	for unused in range(parts):
		if point_free(pos+step,radius):
			pos += step
		else:
			if point_free(pos+Vector2(step.x,0),radius):
				pos.x += step.x
			if point_free(pos+Vector2(0,step.y),radius):
				pos.y += step.y
	return pos

func to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(clampi(int(pos.x/cell_size),0,grid_size.x-1),clampi(int(pos.y/cell_size),0,grid_size.y-1))

func _index(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y:
		return -1
	return cell.y*grid_size.x+cell.x

func update_flow(target: Vector2):
	var cell = to_cell(target)
	if cell == flow_target:
		return
	flow_target = cell
	flow.fill(-1)
	var start = _index(cell)
	var queue = PackedInt32Array([start])
	flow[start] = 0
	var head = 0
	while head < queue.size():
		var current = queue[head]
		head += 1
		var at = Vector2i(current % grid_size.x,current / grid_size.x)
		for step in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var next = _index(at+step)
			if next >= 0 and solids[next] == 0 and flow[next] == -1:
				flow[next] = flow[current]+1
				queue.append(next)

func steer(pos: Vector2, target: Vector2, clearance: float = 13.0) -> Vector2:
	if clear_line(pos,target,clearance):
		return pos.direction_to(target)
	var start_cell = to_cell(pos)
	var end_cell = to_cell(target)
	if end_cell != flow_target and not astar.is_point_solid(start_cell) and not astar.is_point_solid(end_cell):
		var path = astar.get_point_path(start_cell,end_cell)
		for i in range(mini(4,path.size()-1),0,-1):
			if clear_line(pos,path[i],clearance): return pos.direction_to(path[i])
	var cell = to_cell(pos)
	var best_point = pos
	var best_score = INF
	for dy in range(-2,3):
		for dx in range(-2,3):
			var next_cell = cell+Vector2i(dx,dy)
			var index = _index(next_cell)
			if index < 0 or flow[index] < 0:
				continue
			var point = (Vector2(next_cell)+Vector2(0.5,0.5))*cell_size
			if not clear_line(pos,point,clearance):
				continue
			var score = flow[index]*cell_size+pos.distance_to(point)*0.18
			if score < best_score:
				best_point = point
				best_score = score
	return pos.direction_to(best_point)

func clear_line(a: Vector2, b: Vector2, clearance: float = 0.0) -> bool:
	for rect in obstacles:
		if _segment_rect(a,b,rect.grow(clearance)):
			return false
	return true

func _segment_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if maxf(a.x,b.x) < rect.position.x or minf(a.x,b.x) > rect.end.x or maxf(a.y,b.y) < rect.position.y or minf(a.y,b.y) > rect.end.y: return false
	var delta = b-a
	var near = 0.0
	var far = 1.0
	for axis in range(2):
		if absf(delta[axis]) < 0.001:
			if a[axis] < rect.position[axis] or a[axis] > rect.end[axis]:
				return false
		else:
			var first = (rect.position[axis]-a[axis])/delta[axis]
			var second = (rect.end[axis]-a[axis])/delta[axis]
			near = maxf(near,minf(first,second))
			far = minf(far,maxf(first,second))
			if near > far:
				return false
	return true

func nearby_open(pos: Vector2, radius: float, random: RandomNumberGenerator) -> Vector2:
	for attempt in range(60):
		var at = pos + Vector2.from_angle(random.randf()*TAU)*random.randf_range(radius*0.65,radius)
		var index = _index(to_cell(at))
		if point_free(at,23) and flow[index] >= 0:
			return at
	return Vector2(1200,900)

func _draw():
	if content == null:
		return
	local_rng.seed = 73411
	var floor_color = Color(definition.floor)
	draw_rect(bounds,floor_color)
	var floor_index = {"school":0,"street":1,"mall":2}[definition.id]
	for y in range(0,1800,600):
		for x in range(0,2400,600):
			draw_texture_rect(content.floor_textures[floor_index],Rect2(x,y,600,600),false,Color(0.92,0.98,0.9,0.76))
	if definition.id == "street":
		draw_rect(Rect2(690,0,1000,1800),Color(0.17,0.22,0.21,0.26))
		for y in range(20,1800,120):
			draw_rect(Rect2(1189,y,12,62),Color(0.73,0.71,0.55,0.3))
		for x in [340,2030]:
			draw_line(Vector2(x,0),Vector2(x,1800),Color(0.2,0.25,0.23,0.55),8)
	for room in rooms:
		draw_rect(room,Color(0.19,0.22,0.16,0.22) if definition.id == "school" else Color(0.40,0.34,0.21,0.15))
		for x in range(int(room.position.x)+8,int(room.end.x),28):
			draw_line(Vector2(x,room.position.y),Vector2(x,room.end.y),Color(0.12,0.13,0.1,0.13),1)
	for index in range(2100):
		var at = Vector2(local_rng.randf_range(0,2400),local_rng.randf_range(0,1800))
		var length = local_rng.randf_range(1,13)
		draw_line(at,at+Vector2(length,local_rng.randf_range(-2,3)),Color(0.05,0.07,0.06,local_rng.randf_range(0.06,0.19)),1.0)
	for index in range(90):
		var at = Vector2(local_rng.randf_range(0,2400),local_rng.randf_range(0,1800))
		draw_circle(at,local_rng.randf_range(15,62),Color(0.16,0.19,0.16,0.045))
	for wall_rect in obstacles:
		if minf(wall_rect.size.x,wall_rect.size.y) <= 22:
			draw_rect(wall_rect.grow(4),Color(0.07,0.085,0.07,0.28))
			draw_rect(wall_rect,Color("343e36"))
			draw_rect(wall_rect.grow(-3),Color("87907b"),false,1.5)
	for item in props:
		var rect = Rect2(item.pos-Vector2(item.size.x*0.5,item.size.y*0.78),item.size)
		draw_texture_rect(content.prop_textures[item.index],rect,false,Color(0.9,0.92,0.85))
	draw_tactics()
	draw_rect(bounds.grow(-18),Color("222e28"),false,36)
	draw_rect(bounds.grow(-38),Color(0.76,0.74,0.57,0.24),false,2)
	var name_position = Vector2(1020,190)
	draw_string(content.font,name_position,definition.name,HORIZONTAL_ALIGNMENT_LEFT,-1,40,Color(0.8,0.79,0.64,0.22))

func _build_tactics():
	fixtures.clear()
	for data in definition.get("tactical",[]):
		var entry = data.duplicate(true)
		entry.rect = Rect2(data.rect[0],data.rect[1],data.rect[2],data.rect[3])
		entry.pos = entry.rect.get_center()
		entry.max_hp = entry.hp
		entry.destroyed = false
		entry.cooldown = 0.0
		entry.timer = 0.0
		entry.active = entry.get("enabled",false)
		fixtures.append(entry)

func _fixture_blocks(f: Dictionary) -> bool:
	return not f.destroyed and (f.kind == "car" or (f.kind in ["door","shutter"] and f.get("closed",false)))

func _rebuild_geometry():
	obstacles.clear()
	for item in geometry: obstacles.append(item.rect)
	for f in fixtures:
		if _fixture_blocks(f): obstacles.append(f.rect)
	revision += 1
	var previous = (Vector2(flow_target)+Vector2.ONE*0.5)*cell_size
	_build_grid()
	flow_target = Vector2i(-100,-100)
	update_flow(previous.clamp(Vector2(50,50),bounds.end-Vector2(50,50)))
	queue_redraw()

func segment_fraction(a: Vector2, b: Vector2, rect: Rect2) -> float:
	if maxf(a.x,b.x) < rect.position.x or minf(a.x,b.x) > rect.end.x or maxf(a.y,b.y) < rect.position.y or minf(a.y,b.y) > rect.end.y: return INF
	var direction = b-a
	var near = 0.0
	var far = 1.0
	for axis in range(2):
		if absf(direction[axis]) < 0.00001:
			if a[axis] < rect.position[axis] or a[axis] > rect.end[axis]: return INF
		else:
			var first = (rect.position[axis]-a[axis])/direction[axis]
			var second = (rect.end[axis]-a[axis])/direction[axis]
			near = maxf(near,minf(first,second))
			far = minf(far,maxf(first,second))
			if near > far: return INF
	return near

func wall_hit(a: Vector2, b: Vector2, lob: bool = false) -> float:
	var first = INF
	for item in geometry:
		if lob and item.kind == "low": continue
		first = minf(first,segment_fraction(a,b,item.rect))
	for f in fixtures:
		if not _fixture_blocks(f) or (lob and f.kind == "car"): continue
		first = minf(first,segment_fraction(a,b,f.rect))
	return first

func attack_clear(a: Vector2, b: Vector2, lob: bool = false) -> bool:
	return wall_hit(a,b,lob) == INF

func reset_wave():
	for f in fixtures:
		f.cooldown = 0.0
		f.timer = 0.0
		if f.kind == "shutter": f.closed = false
		if f.kind == "alarm": f.active = true
		if f.kind == "broadcast": f.active = false
	interaction_latched = false
	interaction_progress = 0
	_rebuild_geometry()

func snapshot() -> Dictionary:
	var result = {}
	for f in fixtures:
		result[f.id] = {"hp":f.hp,"destroyed":f.destroyed,"closed":f.get("closed",false),"active":f.active,"cooldown":f.cooldown,"timer":f.timer}
	return result

func restore(saved: Dictionary):
	for f in fixtures:
		var entry = saved.get(f.id,{})
		if not entry is Dictionary: continue
		for key in ["hp","cooldown","timer"]:
			if entry.get(key) is float or entry.get(key) is int: f[key] = maxf(0,float(entry[key]))
		for key in ["destroyed","closed","active"]:
			if entry.get(key) is bool: f[key] = entry[key]
	_rebuild_geometry()

func damage_fixture(f: Dictionary, amount: float):
	if f.destroyed or f.kind not in ["car","door"]: return
	f.hp -= amount
	if f.hp <= 0:
		f.destroyed = true
		f.closed = false
		if f.kind == "car": events.append({"kind":"explosion","pos":f.pos,"radius":220.0,"damage":240.0})
		_rebuild_geometry()
	queue_redraw()

func blocker(a: Vector2, b: Vector2, distance_limit: float = INF) -> Dictionary:
	var nearest = -1.0
	for f in fixtures:
		if not _fixture_blocks(f) or f.kind not in ["door","car"]: continue
		if a.distance_to(a.clamp(f.rect.position,f.rect.end)) > distance_limit: continue
		var hit = segment_fraction(a,b,f.rect)
		if hit == INF: continue
		if nearest < 0: nearest = wall_hit(a,b)
		if hit <= nearest+0.001: return f
	return {}

func is_wet(at: Vector2) -> bool:
	for f in fixtures:
		if f.kind == "puddle" and f.rect.has_point(at): return true
	return false

func noise_target(at: Vector2) -> Vector2:
	var best = Vector2.INF
	var distance = 620.0
	for f in fixtures:
		if f.kind in ["alarm","broadcast"] and f.active and at.distance_to(f.pos) < distance:
			best = f.pos
			distance = at.distance_to(f.pos)
	return best

func fixture_label(f: Dictionary) -> String:
	if f.kind == "door": return "打开木门" if f.closed else "关门拖延 · 会被破坏"
	if f.kind == "shutter": return "卷帘门：关闭中" if f.closed else ("卷帘门冷却 %s秒" % ceili(f.cooldown) if f.cooldown > 0 else "关闭卷帘门 · 持续8秒")
	if f.kind == "car": return "点燃漏油车 · 爆破开路"
	if f.kind == "alarm": return "关闭警铃 · 停止引怪" if f.active else "警铃已关闭"
	return "广播冷却 %s秒" % ceili(f.cooldown) if f.cooldown > 0 else "启动广播 · 引怪10秒"

func tick_tactics(delta: float, captain: Vector2, held: bool, rescue_priority: bool, actors: Array):
	for f in fixtures:
		f.cooldown = maxf(0,f.cooldown-delta)
		if f.timer > 0:
			f.timer -= delta
			if f.timer <= 0:
				if f.kind == "shutter":
					f.closed = false
					_rebuild_geometry()
				if f.kind == "broadcast": f.active = false
	var candidate = {}
	var distance = 100.0
	for f in fixtures:
		if f.destroyed or f.kind == "puddle": continue
		var nearest = captain.clamp(f.rect.position,f.rect.end)
		if captain.distance_to(nearest) < distance and attack_clear(captain,nearest.move_toward(captain,1)):
			distance = captain.distance_to(nearest)
			candidate = f
	if candidate.get("id","") != interaction.get("id",""): interaction_progress = 0
	interaction = candidate
	if not held: interaction_latched = false
	if rescue_priority or candidate.is_empty() or not held or interaction_latched:
		interaction_progress = 0
		return
	if candidate.cooldown > 0 or (candidate.kind == "alarm" and not candidate.active): return
	interaction_progress += delta
	if interaction_progress < 0.8: return
	interaction_latched = true
	interaction_progress = 0
	if candidate.kind in ["door","shutter"]:
		if not candidate.closed:
			for pos in actors:
				if candidate.rect.grow(25).has_point(pos):
					events.append({"kind":"message","text":"门口有人 · 移开后再关门"})
					return
		candidate.closed = not candidate.closed
		if candidate.kind == "shutter":
			candidate.timer = 8.0
			candidate.cooldown = 23.0
		_rebuild_geometry()
	elif candidate.kind == "car": damage_fixture(candidate,99999)
	elif candidate.kind == "alarm": candidate.active = false
	elif candidate.kind == "broadcast":
		candidate.active = true
		candidate.timer = 10.0
		candidate.cooldown = 22.0
	queue_redraw()

func draw_tactics():
	for item in geometry:
		if item.get("sprite",-1) >= 0:
			draw_texture_rect(content.prop_textures[item.sprite],Rect2(item.rect.position-Vector2(6,50),item.rect.size+Vector2(12,65)),false)
		if item.kind == "low": draw_rect(item.rect,Color(0.7,0.72,0.55,0.35),false,1.5)
	for f in fixtures:
		if f.destroyed:
			draw_line(f.rect.position,f.rect.end,Color(0.17,0.16,0.12,0.8),8)
			continue
		var color = Color("baaf85")
		match f.kind:
			"puddle":
				draw_style_box(_water_style(),f.rect)
				for i in range(5): draw_arc(f.pos+Vector2(i*27-54,i%2*22),22,0.1,2.8,16,Color(0.54,0.72,0.72,0.35),1)
			"car":
				draw_texture_rect(content.prop_textures[4],Rect2(f.rect.position-Vector2(26,30),f.rect.size+Vector2(52,46)),false)
				draw_rect(f.rect,Color("a07849"),false,2)
				draw_circle(f.pos+Vector2(65,30),28,Color(0.15,0.12,0.04,0.6))
			"door", "shutter":
				if f.closed:
					draw_rect(f.rect,Color("776149") if f.kind == "door" else Color("687370"))
					for y in range(int(f.rect.position.y),int(f.rect.end.y),14): draw_line(Vector2(f.rect.position.x,y),Vector2(f.rect.end.x,y+3),Color("31392e"),2)
				else: draw_rect(f.rect,Color(0.69,0.71,0.53,0.28),false,2)
				draw_string(content.font,f.pos+Vector2(-22,-f.rect.size.y/2-15),"木门" if f.kind == "door" else "卷帘",0,-1,16,color)
			"alarm", "broadcast":
				draw_rect(f.rect,Color("3d493f"))
				draw_circle(f.pos,14,Color("bf7059") if f.active else Color("91ad8a"))
				if f.active: draw_arc(f.pos,34,0,TAU,24,Color(0.8,0.6,0.3,0.55),2)
				draw_string(content.font,f.pos+Vector2(-23,-32),"警铃" if f.kind == "alarm" else "广播",0,-1,16,color)

func _water_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.23,0.42,0.45,0.32)
	style.set_corner_radius_all(40)
	return style

func recovery_steer(pos: Vector2, target: Vector2, clearance: float) -> Vector2:
	if clear_line(pos,target,clearance): return pos.direction_to(target)
	var end = to_cell(target)
	if astar.is_point_solid(end): return steer(pos,target,clearance)
	var start = to_cell(pos)
	var best = Vector2.ZERO
	var score = INF
	for dy in range(-2,3):
		for dx in range(-2,3):
			var cell = start+Vector2i(dx,dy)
			if _index(cell) < 0 or astar.is_point_solid(cell): continue
			var at = (Vector2(cell)+Vector2.ONE*0.5)*cell_size
			if not clear_line(pos,at,clearance): continue
			var path = astar.get_point_path(cell,end)
			if path.is_empty(): continue
			var cost = path.size()*cell_size+pos.distance_to(at)
			if cost < score:
				score = cost
				best = pos.direction_to(at)
				if pos.distance_to(at) < 12 and path.size() > 1 and clear_line(pos,path[1],clearance): best = pos.direction_to(path[1])
	return best
