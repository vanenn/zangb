extends SceneTree

func _initialize(): call_deferred("verify")

func verify():
	var scene = load("res://school_building.tscn")
	if scene == null:
		push_error("First-floor scene did not load")
		quit(1)
		return
	var sample = scene.instantiate()
	root.add_child(sample)
	await process_frame
	var map = sample.city
	var layout = sample.layout
	var failures = []
	if layout.rooms.size() != 8: failures.append("expected eight side rooms")
	if layout.covers.size() < 25: failures.append("missing room or corridor furniture")
	if not map.point_free(Vector2(layout.spawn[0], layout.spawn[1]), 17): failures.append("spawn blocked")
	if map.astar.get_point_path(map.to_cell(Vector2(245, 884)), map.to_cell(Vector2(3100, 884))).is_empty():
		failures.append("main corridor does not connect both ends")
	for x in range(220, 3120, 80):
		if not map.point_free(Vector2(x, 884), 17): failures.append("central corridor blocked at %d" % x)
	for door in layout.doors:
		var r = map.rect_from(door.rect)
		var doorway = r.get_center() + Vector2(0, -55 if r.position.y < 900 else 55)
		if not map.point_free(doorway, 17): failures.append("door approach blocked: " + door.id)
		map.set_door(door.id, false)
		var room_side = r.get_center() + Vector2(0, -75 if r.position.y < 900 else 75)
		if map.astar.get_point_path(map.to_cell(Vector2(1680, 884)), map.to_cell(room_side)).is_empty():
			failures.append("room inaccessible: " + door.id)
	print(JSON.stringify({"rooms":layout.rooms.size(), "furniture":layout.covers.size(),
		"doors":layout.doors.size(), "failures":failures}))
	quit(0 if failures.is_empty() else 1)
