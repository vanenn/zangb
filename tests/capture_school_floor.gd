extends SceneTree

func _initialize(): call_deferred("capture")

func capture():
	var sample = load("res://school_building.tscn").instantiate()
	root.add_child(sample)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	print("overview: ", image.get_size(), " ", image.save_png("res://tests/school-floor-1-overview.png"))
	sample.overview = false
	sample.captain = Vector2(1350, 875)
	sample.player.position = sample.captain + Vector2(0, -13)
	sample._refresh_view()
	await process_frame
	await RenderingServer.frame_post_draw
	image = root.get_texture().get_image()
	print("walk: ", image.get_size(), " ", image.save_png("res://tests/school-floor-1-walk.png"))
	quit()
