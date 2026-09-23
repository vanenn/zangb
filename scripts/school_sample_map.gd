extends "res://scripts/city_map.gd"

var layout = {}

func setup_sample(book):
	content = book
	definition = book.maps.school.duplicate(true)
	definition.name = ""
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/school_sample.json"))
	geometry.clear()
	obstacles.clear()
	props.clear()
	rooms.clear()
	fixtures.clear()
	for row in layout.rooms:
		rooms.append(rect_from(row.rect))
	for row in layout.walls:
		wall(rect_from(row))
	for row in layout.covers:
		var r = rect_from(row.rect)
		prop(int(row.sprite),r.get_center()+Vector2(0,20),Vector2(r.size.x+35,maxf(110,r.size.y+50)),r)
	for row in layout.doors:
		var r = rect_from(row.rect)
		fixtures.append({"id":row.id,"kind":"door","rect":r,"pos":r.get_center(),"hp":160.0,"max_hp":160.0,"closed":row.closed,"destroyed":false,"cooldown":0.0,"timer":0.0,"active":false})
	_rebuild_geometry()
	update_flow(Vector2(layout.spawn[0],layout.spawn[1]))
	queue_redraw()

func rect_from(row) -> Rect2:
	return Rect2(row[0],row[1],row[2],row[3])

func _draw():
	super._draw()
	# Stair cores are solid footprints, unlike the thin partition walls.
	for item in geometry:
		if item.kind!="wall" or minf(item.rect.size.x,item.rect.size.y)<=22: continue
		draw_rect(item.rect,Color("222d26"))
		draw_rect(item.rect.grow(-4),Color("7b8775"),false,2)
		for y in range(int(item.rect.position.y)+15,int(item.rect.end.y)-8,21):
			draw_line(Vector2(item.rect.position.x+10,y),Vector2(item.rect.end.x-10,y),Color("525f4f"),2)

func set_door(id: String, closed: bool) -> bool:
	for item in fixtures:
		if item.id == id:
			item.closed = closed
			_rebuild_geometry()
			queue_redraw()
			return true
	return false
