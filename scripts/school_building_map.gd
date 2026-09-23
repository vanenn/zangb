extends "res://scripts/school_sample_map.gd"

func setup_floor(book, data: Dictionary):
	content = book
	definition = book.maps.school.duplicate(true)
	definition.name = ""
	layout = data
	bounds = Rect2(0, 0, data.size[0], data.size[1])
	grid_size = Vector2i(ceili(bounds.size.x / cell_size), ceili(bounds.size.y / cell_size))
	geometry.clear()
	obstacles.clear()
	props.clear()
	rooms.clear()
	fixtures.clear()
	for row in data.rooms: rooms.append(rect_from(row.rect))
	for row in data.walls: wall(rect_from(row))
	for row in data.covers:
		var r = rect_from(row.rect)
		prop(int(row.sprite), r.get_center() + Vector2(0, 16), Vector2(r.size.x + 34, maxf(98, r.size.y + 48)), r)
	for row in data.doors:
		var r = rect_from(row.rect)
		fixtures.append({"id":row.id, "kind":"door", "rect":r, "pos":r.get_center(),
			"hp":160.0, "max_hp":160.0, "closed":row.closed, "destroyed":false,
			"cooldown":0.0, "timer":0.0, "active":false})
	flow_target = Vector2i(-100, -100)
	_rebuild_geometry()
	update_flow(Vector2(data.spawn[0], data.spawn[1]))
	queue_redraw()

func _draw():
	if content == null or layout.is_empty(): return
	draw_rect(bounds, Color("18221e"))
	for y in range(140, 1640, 500):
		for x in range(140, 3220, 500):
			var tile = Rect2(x, y, minf(500, 3220-x), minf(500, 1640-y))
			draw_texture_rect(content.floor_textures[0], tile, false, Color(0.85, 0.91, 0.84))
	for room in layout.rooms:
		var r = rect_from(room.rect)
		draw_rect(r, Color(0.15, 0.2, 0.16, 0.22) if room.kind == "classroom" else Color(0.26, 0.24, 0.18, 0.2))
		for line_x in range(int(r.position.x)+24, int(r.end.x), 70):
			draw_line(Vector2(line_x, r.position.y+8), Vector2(line_x, r.end.y-8), Color(0.08, 0.1, 0.08, 0.12), 1)
		var window_y = 158 if r.position.y < 800 else 1620
		draw_line(Vector2(r.position.x+180, window_y), Vector2(r.position.x+540, window_y), Color("77948c"), 8)
		if room.kind == "classroom":
			draw_rect(Rect2(r.position.x+220, r.position.y+24, 290, 28), Color("284237"))
	var hall = rect_from(layout.corridor)
	draw_rect(hall, Color(0.19, 0.25, 0.21, 0.26))
	for x in range(230, 3120, 310):
		draw_line(Vector2(x, hall.position.y+hall.size.y/2), Vector2(x+92, hall.position.y+hall.size.y/2), Color(0.76, 0.73, 0.57, 0.16), 3)
	for r in obstacles:
		if minf(r.size.x, r.size.y) <= 22:
			draw_rect(r.grow(3), Color(0.05, 0.08, 0.06, 0.28))
			draw_rect(r, Color("303e34"))
			draw_rect(r.grow(-3), Color("8c947c"), false, 1.5)
	for item in props:
		draw_texture_rect(content.prop_textures[item.index],
			Rect2(item.pos-Vector2(item.size.x/2, item.size.y*0.78), item.size), false,
			Color(0.91, 0.93, 0.84))
	draw_tactics()
	for room in layout.rooms:
		var text_size = 41 if room.kind == "classroom" else 38
		var at = Vector2(room.label[0], room.label[1])
		var width = content.font.get_string_size(room.name, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		draw_string(content.font, at-Vector2(width/2, 0), room.name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color("ddd8bd"))
	draw_string(content.font, Vector2(190, 925), "西端入口", HORIZONTAL_ALIGNMENT_LEFT, -1, 33, Color("c7b889"))
	draw_string(content.font, Vector2(2920, 925), "东楼梯", HORIZONTAL_ALIGNMENT_LEFT, -1, 33, Color("c7b889"))
	draw_rect(bounds.grow(-130), Color("9c9974"), false, 2)
