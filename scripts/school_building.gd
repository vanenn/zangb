extends Node2D

const Book = preload("res://scripts/content.gd")
const Map = preload("res://scripts/school_building_map.gd")
const PAPER = Color("e6dcc3")
const MUTED = Color("aeb39e")
const GOLD = Color("d3b879")

var content
var city
var layout: Dictionary
var world: Node2D
var player: Sprite2D
var captain = Vector2.ZERO
var overview = true
var title_label: Label
var help_label: Label
var location_label: Label
var hint_label: Label

func _ready():
	DisplayServer.window_set_title("灰城余生 · 教学楼一层")
	_setup_keys()
	content = Book.new()
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/school_floor_1.json"))
	world = Node2D.new()
	add_child(world)
	city = Map.new()
	world.add_child(city)
	city.setup_floor(content, layout)
	captain = Vector2(layout.spawn[0], layout.spawn[1])
	player = Sprite2D.new()
	player.texture = content.character_textures[0]
	player.scale = Vector2.ONE * 0.23
	player.position = captain + Vector2(0, -13)
	world.add_child(player)
	var top_bar = ColorRect.new()
	top_bar.color = Color("101713")
	top_bar.size = Vector2(1600, 76)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)
	var bottom_bar = ColorRect.new()
	bottom_bar.color = Color("101713")
	bottom_bar.position = Vector2(0, 836)
	bottom_bar.size = Vector2(1600, 64)
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_bar)
	title_label = _label("灰城余生 / 第七中学 · 教学楼一层", Vector2(27, 12), 31, PAPER)
	help_label = _label("中央主过道  ·  两侧教室与办公室  ·  桌椅可碰撞", Vector2(29, 52), 18, MUTED)
	location_label = _label("", Vector2(26, 843), 21, PAPER)
	hint_label = _label("", Vector2(26, 872), 18, GOLD)
	_refresh_view()

func _setup_keys():
	var bindings = {"floor_left":[KEY_A, KEY_LEFT], "floor_right":[KEY_D, KEY_RIGHT],
		"floor_up":[KEY_W, KEY_UP], "floor_down":[KEY_S, KEY_DOWN]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in bindings[action]:
			var event = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _label(value: String, at: Vector2, font_size: int, color: Color) -> Label:
	var node = Label.new()
	node.text = value
	node.position = at
	node.add_theme_font_override("font", content.font)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	add_child(node)
	return node

func _draw():
	draw_rect(Rect2(0, 0, 1600, 900), Color("131b17"))

func _input(event):
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_TAB:
			overview = not overview
			_refresh_view()
			get_viewport().set_input_as_handled()
		KEY_R:
			captain = Vector2(layout.spawn[0], layout.spawn[1])
			for door in layout.doors: city.set_door(door.id, door.closed)
			_refresh_view()
			get_viewport().set_input_as_handled()
		KEY_E:
			if not overview: _toggle_nearby_door()
			get_viewport().set_input_as_handled()

func _process(delta):
	if city == null: return
	if not overview:
		var movement = Input.get_vector("floor_left", "floor_right", "floor_up", "floor_down")
		captain = city.move_actor(captain, movement * 230 * minf(delta, 0.05), 17)
		player.position = captain + Vector2(0, -13)
	_refresh_view()

func _nearby_door() -> Dictionary:
	var closest: Dictionary = {}
	var distance = 86.0
	for door in city.fixtures:
		var at = captain.clamp(door.rect.position, door.rect.end)
		var candidate = captain.distance_to(at)
		if candidate < distance and city.attack_clear(captain, at.move_toward(captain, 1)):
			distance = candidate
			closest = door
	return closest

func _toggle_nearby_door():
	var door = _nearby_door()
	if door.is_empty(): return
	if not door.closed and door.rect.grow(24).has_point(captain): return
	city.set_door(door.id, not door.closed)
	_refresh_view()

func _refresh_view():
	if world == null: return
	if overview:
		world.scale = Vector2.ONE * 0.42
		world.position = Vector2(94, 86)
	else:
		world.scale = Vector2.ONE * 0.9
		var center = captain.clamp(Vector2(890, 500), Vector2(2470, 1260))
		world.position = Vector2(800, 454) - center * 0.9
	var where = "主过道"
	for room in layout.rooms:
		if city.rect_from(room.rect).has_point(captain):
			where = room.name
			break
	location_label.text = ("全图预览" if overview else "走图中") + "   /   当前：" + where
	var door = _nearby_door()
	hint_label.text = "Tab 进入走图  ·  WASD / 方向键移动  ·  R 返回入口" if overview else \
		("E %s  ·  Tab 查看全图  ·  R 返回入口" % ("开门" if door.closed else "关门") if not door.is_empty() else \
		"WASD / 方向键移动  ·  靠近门按 E  ·  Tab 查看全图  ·  R 返回入口")
