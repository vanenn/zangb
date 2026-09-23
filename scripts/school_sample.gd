extends Node2D

const Book = preload("res://scripts/content.gd")
const Map = preload("res://scripts/school_sample_map.gd")
const Layer = preload("res://scripts/school_sample_layer.gd")
const PAPER = Color("e6dcc3")
const MUTED = Color("adae99")
const GREEN = Color("acd5b2")
const GOLD = Color("d7b771")
const RED = Color("dc9784")
const BLUE = Color("8ac1cb")
var content
var city
var viewport: SubViewport
var world: Node2D
var marks
var fog_layer
var layout = {}
var captain = Vector2(360,1510)
var companions = []
var sites = []
var overview = true
var fog_enabled = true
var paused = false
var done = false
var route = 0
var selected_room = "entry"
var health = 60
var supplies = 0
var rescued = false
var equipment = false
var alarm = true
var clock_value = 0.0
var exit_timer = -1.0
var cache_timer = -1.0
var elapsed = 0.0
var hold = 0.0
var active_id = ""
var latched = false
var vision_clock = 0.0
var vision_points = PackedVector2Array()
var status_label: Label
var detail_label: Label
var prompt_label: Label
var counters_label: Label
var mode_button: Button
var fog_button: Button
var pause_button: Button
var notice = "三条路线均通向北侧安全门。点击路线，查看通路和奖励位置。"

func _ready():
	DisplayServer.window_set_title("灰城余生 · 学校地图样板 01")
	_setup_keys()
	content = Book.new()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1140,735)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var container = SubViewportContainer.new()
	container.position = Vector2(24,110)
	container.size = Vector2(1140,735)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(viewport)
	add_child(container)
	world = Node2D.new()
	viewport.add_child(world)
	city = Map.new()
	world.add_child(city)
	city.setup_sample(content)
	layout = city.layout
	marks = Layer.new()
	marks.sample = self
	world.add_child(marks)
	fog_layer = Layer.new()
	fog_layer.sample = self
	fog_layer.fog = true
	world.add_child(fog_layer)
	_make_ui()
	restart()
	if "--sample-capture" in OS.get_cmdline_user_args(): _capture.call_deferred()

func _setup_keys():
	var bindings = {"sample_left":[KEY_A,KEY_LEFT],"sample_right":[KEY_D,KEY_RIGHT],"sample_up":[KEY_W,KEY_UP],"sample_down":[KEY_S,KEY_DOWN],"sample_interact":[KEY_E]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in bindings[action]:
			var event = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)

func _label(text: String, at: Vector2, size_value: Vector2, font_size: int=20, color: Color=PAPER) -> Label:
	var node = Label.new()
	node.text = text
	node.position = at
	node.size = size_value
	node.add_theme_font_override("font",content.font)
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node

func _button(text: String, at: Vector2, size_value: Vector2, callback: Callable) -> Button:
	var node = Button.new()
	node.text = text
	node.position = at
	node.size = size_value
	node.add_theme_font_override("font",content.font)
	node.add_theme_font_size_override("font_size",19)
	node.add_theme_color_override("font_color",PAPER)
	for state in ["normal","hover","pressed","focus"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("334138") if state=="hover" else Color("243229")
		style.border_color = GOLD if state=="focus" else Color("60705b")
		style.set_border_width_all(1)
		node.add_theme_stylebox_override(state,style)
	node.pressed.connect(callback)
	add_child(node)
	return node

func _make_ui():
	_label("灰城余生 / 第七中学",Vector2(26,20),Vector2(700,48),32)
	_label("地图样板 01　·　真实通路 / 门 / 遮挡 / 救援 / 搜刮 / 撤离",Vector2(28,70),Vector2(1090,32),19,MUTED)
	_label("路线与记录",Vector2(1200,26),Vector2(350,50),28)
	for i in range(layout.routes.size()):
		var index = i
		_button(layout.routes[i].name,Vector2(1200,110+i*52),Vector2(370,44),func(): route=index; overview=true; paused=false; notice="总览中虚线标出所选路线；红色区域为遭遇预留。"; refresh())
	mode_button = _button("从入口开始走图 [Tab]",Vector2(1200,285),Vector2(370,48),toggle_mode)
	fog_button = _button("墙体遮挡：开 [F]",Vector2(1200,345),Vector2(370,44),func(): fog_enabled=not fog_enabled; refresh())
	pause_button = _button("暂停 [Esc]",Vector2(1200,399),Vector2(175,42),func(): paused=not paused; refresh())
	_button("重新走图",Vector2(1390,399),Vector2(180,42),restart)
	detail_label = _label("",Vector2(1200,475),Vector2(370,140),21)
	counters_label = _label("",Vector2(1200,630),Vector2(370,95),20,GREEN)
	status_label = _label("",Vector2(1200,741),Vector2(370,108),18,MUTED)
	prompt_label = _label("",Vector2(28,851),Vector2(1540,40),20,GOLD)

func restart():
	captain = Vector2(layout.spawn[0],layout.spawn[1])
	companions = [{"sprite":6,"pos":captain+Vector2(-32,30)},{"sprite":16,"pos":captain+Vector2(30,42)}]
	sites = layout.sites.duplicate(true)
	for site in sites: site["used"]=false
	for door in layout.doors: city.set_door(door.id,door.closed)
	health=60
	supplies=0
	rescued=false
	equipment=false
	alarm=true
	done=false
	paused=false
	exit_timer=-1
	cache_timer=-1
	elapsed=0
	hold=0
	active_id=""
	latched=false
	selected_room="entry"
	notice="布局试玩：无战斗伤害。红色遭遇区仅用于评审布点。"
	refresh()

func toggle_mode():
	overview = not overview
	paused = false
	notice = "WASD / 方向键移动，靠近目标按住E。Tab返回总览。" if not overview else "点击地图房间查看用途；走图进度保留。"
	refresh()

func _input(event):
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_TAB:
			toggle_mode()
			get_viewport().set_input_as_handled()
		KEY_F:
			fog_enabled=not fog_enabled
			refresh()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			paused=not paused
			refresh()
			get_viewport().set_input_as_handled()

func _unhandled_input(event):
	if overview and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if Rect2(24,110,1140,735).has_point(event.position):
			var at = (event.position-Vector2(24,110)-world.position)/world.scale
			for room in layout.rooms:
				if city.rect_from(room.rect).has_point(at): selected_room=room.id; refresh(); break

func _process(delta):
	if city == null: return
	var movement = Input.get_vector("sample_left","sample_right","sample_up","sample_down")
	tick_sample(minf(delta,0.05),movement,Input.is_action_pressed("sample_interact"))
	if overview:
		world.scale = Vector2.ONE*0.40
		world.position = Vector2(90,8)
	else:
		world.scale = Vector2.ONE*0.92
		var center = captain.clamp(Vector2(620,400),Vector2(1780,1400))
		world.position = Vector2(570,367.5)-center*0.92
	vision_clock -= delta
	if vision_clock <= 0:
		vision_clock=0.06
		update_vision()
	marks.queue_redraw()
	fog_layer.queue_redraw()
	refresh()

func tick_sample(delta: float, movement: Vector2, held: bool):
	if overview or paused or done: return
	clock_value += delta
	elapsed += delta
	captain = city.move_actor(captain,movement.limit_length()*220*delta,16)
	city.update_flow(captain)
	for i in range(companions.size()):
		var person = companions[i]
		var goal = captain+Vector2.from_angle(float(i)*TAU/companions.size()+1.1)*48
		if not city.point_free(goal,13): goal=captain
		if person.pos.distance_to(goal)>15:
			person.pos = city.move_actor(person.pos,city.steer(person.pos,goal)*230*delta,13)
	if cache_timer>0: cache_timer=maxf(0,cache_timer-delta)
	if exit_timer>0: exit_timer=maxf(0,exit_timer-delta)
	for room in layout.rooms:
		if city.rect_from(room.rect).has_point(captain): selected_room=room.id; break
	var candidate = nearby()
	var candidate_id = candidate.get("id","")
	if active_id != candidate_id: hold=0; active_id=candidate_id
	if not held:
		latched=false
		hold=0
		return
	if latched or candidate.is_empty(): return
	if candidate.get("kind","")=="cache" and cache_timer>0: return
	if candidate.get("kind","")=="exit" and exit_timer>0: return
	hold += delta
	if hold>=candidate.get("hold",0.6):
		apply_interaction(candidate)
		hold=0
		latched=true

func nearby() -> Dictionary:
	for site in sites:
		if site.used: continue
		var at=Vector2(site.pos[0],site.pos[1])
		if captain.distance_to(at)<90 and city.attack_clear(captain,at): return site
	for door in city.fixtures:
		var at=captain.clamp(door.rect.position,door.rect.end)
		if captain.distance_to(at)<78 and city.attack_clear(captain,at.move_toward(captain,1)):
			return {"id":door.id,"kind":"door","name":"木门","hold":0.6,"closed":door.closed}
	return {}

func apply_interaction(item: Dictionary):
	if item.get("used",false): return
	match item.kind:
		"door":
			for door in city.fixtures:
				if door.id!=item.id: continue
				if not door.closed:
					if door.rect.grow(20).has_point(captain): notice="请先离开门框再关门。"; return
					for person in companions:
						if door.rect.grow(18).has_point(person.pos): notice="同伴还在门框内，请等他们通过。"; return
				city.set_door(item.id,not door.closed)
				notice="门的碰撞、寻路和视野遮挡已同步更新。"
		"medical":
			health=mini(100,health+35)
			item.used=true
			notice="取回急救：恢复35生命。医务室还有东门，可以继续前往实验室。"
		"rescue":
			rescued=true
			item.used=true
			companions.append({"sprite":18,"pos":Vector2(item.pos[0],item.pos[1])})
			notice="消防员加入队伍。东门能直达出口，南门能回到主廊。"
		"cache":
			if cache_timer<0:
				cache_timer=8
				notice="设备箱正在开启，可以离开。8秒后回来按E领取。"
			elif cache_timer==0:
				equipment=true
				item.used=true
				supplies+=30
				notice="取回电池样件与30物资。本样板记录领取，装备战斗触发未接入。"
		"alarm":
			alarm=false
			item.used=true
			notice="走廊警铃已关闭。本样板展示机关状态，未接入敌人听觉。"
		"exit":
			if exit_timer<0:
				exit_timer=15
				notice="撤离准备中。可以离开终端，15秒后回来按E离开。"
			elif exit_timer==0:
				item.used=true
				done=true
				notice="抵达北侧安全门。可以切回总览比较路线，或重新走图。"
	refresh()

func visible_at(at: Vector2) -> bool:
	return captain.distance_to(at)<=480 and city.attack_clear(captain,at,true)

func update_vision():
	vision_points.clear()
	for index in range(240):
		var end=captain+Vector2.from_angle(float(index)/240*TAU)*480
		var hit=city.wall_hit(captain,end,true)
		vision_points.append(captain.lerp(end,minf(1,hit+0.012)) if hit<INF else end)

func paint_fog(canvas):
	if overview or not fog_enabled or vision_points.size()<3: return
	for index in range(vision_points.size()):
		var a=vision_points[index]
		var b=vision_points[(index+1)%vision_points.size()]
		var far_a=captain+captain.direction_to(a)*6000
		var far_b=captain+captain.direction_to(b)*6000
		canvas.draw_colored_polygon(PackedVector2Array([a,b,far_b,far_a]),Color(0.035,0.05,0.043,0.96))

func paint_world(canvas):
	for room in layout.rooms:
		var pos=Vector2(room.label[0],room.label[1])
		canvas.draw_string(content.font,pos-Vector2(content.font.get_string_size(room.name,HORIZONTAL_ALIGNMENT_LEFT,-1,34).x/2,0),room.name,HORIZONTAL_ALIGNMENT_LEFT,-1,34,PAPER)
	if overview:
		var colors=[GOLD,GREEN,BLUE]
		var points=layout.routes[route].points
		for i in range(points.size()-1):
			var a=Vector2(points[i][0],points[i][1])
			var b=Vector2(points[i+1][0],points[i+1][1])
			canvas.draw_dashed_line(a,b,colors[route],6,22,true)
		for zone in layout.encounters:
			var at=Vector2(zone.pos[0],zone.pos[1])
			canvas.draw_circle(at,zone.radius,Color(0.68,0.26,0.19,0.19))
			canvas.draw_arc(at,zone.radius,0,TAU,48,RED,3)
			canvas.draw_string(content.font,at+Vector2(-95,zone.radius+40),zone.name,HORIZONTAL_ALIGNMENT_LEFT,-1,26,RED)
	for site in sites:
		var at=Vector2(site.pos[0],site.pos[1])
		var color=GREEN if site.kind in ["rescue","medical"] else GOLD
		if site.used: color=Color("69776c")
		canvas.draw_arc(at,39,0,TAU,32,color,3)
		if site.kind=="rescue":
			if not site.used: canvas.draw_texture_rect(content.character_textures[18],Rect2(at-Vector2(39,65),Vector2(78,85)),false)
		elif site.kind=="exit":
			canvas.draw_rect(Rect2(at-Vector2(30,24),Vector2(60,48)),Color("345b45"))
			canvas.draw_string(content.font,at+Vector2(-18,11),"出",0,-1,31,PAPER)
		elif site.kind=="alarm":
			canvas.draw_circle(at,17,RED if alarm else GREEN)
		else:
			canvas.draw_texture_rect(content.prop_textures[12],Rect2(at-Vector2(39,48),Vector2(78,75)),false)
		var label=site.name+(" ✓" if site.used else "")
		if site.kind=="cache" and cache_timer>=0 and not site.used: label="领取设备" if cache_timer==0 else "开启中 %d秒"%ceili(cache_timer)
		if site.kind=="exit" and exit_timer>=0 and not done: label="可以撤离" if exit_timer==0 else "撤离准备 %d秒"%ceili(exit_timer)
		canvas.draw_string(content.font,at+Vector2(-50,76),label,0,-1,29,color)
	for person in companions:
		var bob=sin(clock_value*9+person.sprite)*2
		canvas.draw_texture_rect(content.character_textures[person.sprite],Rect2(person.pos+Vector2(-32,-62+bob),Vector2(64,76)),false,Color(0.8,0.88,0.81))
	canvas.draw_circle(captain,24,Color(0.75,0.79,0.6,0.18))
	canvas.draw_arc(captain,24,0,TAU,32,GOLD,3)
	canvas.draw_texture_rect(content.character_textures[0],Rect2(captain+Vector2(-34,-67),Vector2(68,80)),false)
	if not overview:
		var item=nearby()
		if not item.is_empty():
			canvas.draw_rect(Rect2(captain+Vector2(-40,36),Vector2(80,6)),Color("394437"))
			canvas.draw_rect(Rect2(captain+Vector2(-40,36),Vector2(80*minf(1,hold/item.get("hold",0.6)),6)),GOLD)

func refresh():
	if mode_button == null: return
	mode_button.text="继续走图 [Tab]" if overview else "查看全图 [Tab]"
	fog_button.text="墙体遮挡：%s [F]"%("开" if fog_enabled else "关")
	pause_button.text="继续 [Esc]" if paused else "暂停 [Esc]"
	for room in layout.rooms:
		if room.id==selected_room: detail_label.text=room.name+"\n\n"+room.note
	counters_label.text="生命 %d / 100　物资 %d\n队伍 %d 人　消防员 %s\n设备：%s"%[health,supplies,companions.size()+1,"已救出" if rescued else "未救出","电池样件" if equipment else "未取得"]
	status_label.text=notice
	if done: prompt_label.text="已撤离　·　用时 %d秒　·　救援 %s　·　设备 %s"%[int(elapsed),"完成" if rescued else "放弃","取得" if equipment else "放弃"]
	elif paused: prompt_label.text="已暂停　·　走图、开箱与撤离计时全部停止"
	elif overview: prompt_label.text="虚线：所选路线　金色门框：可操作木门　红色圆区：遭遇预留（本样板无战斗）"
	else:
		var item=nearby()
		prompt_label.text="WASD / 方向键移动　E交互　Tab全图　F遮挡　Esc暂停"
		if not item.is_empty():
			var name=item.name
			if item.kind=="door": name="打开木门" if item.closed else "关闭木门"
			prompt_label.text="按住 E · %s　%s"%[name,"（%.1f / %.1f秒）"%[hold,item.get("hold",0.6)] if hold>0 else ""]

func _capture():
	await get_tree().process_frame
	await get_tree().process_frame
	var output="res://tests/school-map-sample"
	var args=OS.get_cmdline_user_args()
	var flag=args.find("--sample-capture")
	if flag>=0 and flag+1<args.size(): output=args[flag+1]
	DirAccess.make_dir_recursive_absolute(output)
	for i in range(3):
		route=i
		overview=true
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output+"/route-%d.png"%i)
	overview=false
	captain=Vector2(1425,340)
	selected_room="lab"
	update_vision()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/door-vision.png")
	city.set_door("lab-exit",false)
	update_vision()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/door-open.png")
	get_tree().quit()
