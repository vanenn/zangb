extends Control

const Content = preload("res://scripts/content.gd")
const RunState = preload("res://scripts/run_state.gd")
const Progress = preload("res://scripts/progress.gd")
const Shop = preload("res://scripts/shop.gd")
const CityMap = preload("res://scripts/city_map.gd")
const Combat = preload("res://scripts/combat.gd")
const Sound = preload("res://scripts/sound.gd")
const Minimap = preload("res://scripts/minimap.gd")

const INK = Color("18221e")
const PANEL = Color("202b25")
const PAPER = Color("e6dcc3")
const MUTED = Color("aaa991")
const GOLD = Color("c3ad7a")
const RED = Color("bb7765")
const GREEN = Color("adc49d")

var content
var progress
var shop
var run
var sim
var city
var world: Node2D
var backdrop: Control
var atmosphere: ColorRect
var ui: Control
var modal: Control
var audio
var screen = "menu"
var selected_class = "teacher"
var selected_difficulty = "challenge"
var previews = []
var preview_clock = 0.0
var selected_equipment = ""
var notice = ""
var notice_time = 0.0
var hud = {}
var modal_return = ""
var last_unlocks = []
var last_win = false
var test_storage_path = ""
var _ui_clock = 0.0
var _mini_clock = 0.0

func _ready():
	var arguments = OS.get_cmdline_user_args()
	if "--school-floor" in arguments:
		get_tree().change_scene_to_file.call_deferred("res://school_building.tscn")
		return
	if OS.has_feature("school_map_sample") or "--school-map" in arguments:
		get_tree().change_scene_to_file.call_deferred("res://school_sample.tscn")
		return
	var release_check = arguments.size() == 2 and arguments[0] == "--verify-release"
	if release_check: test_storage_path = arguments[1].path_join("user")
	content = Content.new()
	progress = Progress.new(test_storage_path if not test_storage_path.is_empty() else "user://")
	shop = Shop.new(content)
	_setup_input()
	var theme_resource = Theme.new()
	theme_resource.default_font = content.font
	theme_resource.default_font_size = 20
	theme = theme_resource
	backdrop = Control.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	world = Node2D.new()
	add_child(world)
	atmosphere = ColorRect.new()
	atmosphere.size = Vector2(1600,900)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shading = ShaderMaterial.new()
	shading.shader = load("res://assets/vignette.gdshader")
	atmosphere.material = shading
	add_child(atmosphere)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal)
	audio = Sound.new()
	add_child(audio)
	audio.set_level(progress.settings.volume)
	if progress.settings.fullscreen and not DisplayServer.get_name() == "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	show_menu()
	if not progress.last_error.is_empty():
		_clear(ui)
		_label(ui,progress.last_error+"\n为保护存档，本次未开启游戏。",Rect2(250,300,1100,200),32,PAPER)
		_button(ui,"退出",Rect2(650,550,300,60),func(): get_tree().quit())
		return
	if release_check:
		var validator = preload("res://scripts/release_validation.gd").new()
		add_child(validator)
		validator.call_deferred("execute",self,arguments[1])

func _setup_input():
	var keys = {"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN],"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"interact":[KEY_E],"pause":[KEY_ESCAPE],"roster":[KEY_TAB]}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in keys[action]:
			var event = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)

func _clear(node):
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _panel(parent, rect: Rect2, color: Color = PANEL, border: Color = Color("4a5443")) -> Panel:
	var panel = Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 2
	style.corner_radius_bottom_right = 2
	panel.add_theme_stylebox_override("panel",style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel

func _label(parent, text: String, rect: Rect2, font_size: int = 20, color: Color = PAPER, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label = Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = rect.size
	parent.add_child(label)
	return label

func _button(parent, text: String, rect: Rect2, callback: Callable, primary: bool = false, id: String = "") -> Button:
	var button = Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size",21)
	button.add_theme_color_override("font_color",INK if primary else PAPER)
	button.add_theme_color_override("font_hover_color",INK if primary else Color.WHITE)
	button.add_theme_color_override("font_pressed_color",INK if primary else PAPER)
	button.add_theme_color_override("font_disabled_color",Color("646e5e"))
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style = StyleBoxFlat.new()
		style.bg_color = GOLD if primary else Color("28372d")
		style.border_color = GOLD if primary else Color("626c54")
		style.set_border_width_all(1)
		if state == "hover":
			style.bg_color = style.bg_color.lightened(0.12)
		if state == "pressed":
			style.bg_color = style.bg_color.darkened(0.12)
		if state == "disabled":
			style.bg_color = Color("242b24")
			style.border_color = Color("414b3d")
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = PAPER
			style.set_border_width_all(2)
		button.add_theme_stylebox_override(state,style)
	if not id.is_empty():
		button.name = id
	button.pressed.connect(func(): audio.play("click"); callback.call())
	button.size = rect.size
	parent.add_child(button)
	return button

func _texture(parent, texture: Texture2D, rect: Rect2, color: Color = Color.WHITE) -> TextureRect:
	var image = TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture = texture
	image.position = rect.position
	image.size = rect.size
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.modulate = color
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _bar(parent, rect: Rect2, color: Color) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.show_percentage = false
	for state in ["background","fill"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("344235") if state == "background" else color
		bar.add_theme_stylebox_override(state,style)
	bar.position = rect.position
	bar.size = rect.size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar

func _cover(darkness: float):
	_clear(backdrop)
	var image = _texture(backdrop,content.cover,Rect2(0,0,1600,900))
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var veil = ColorRect.new()
	veil.color = Color(0.025,0.05,0.035,darkness)
	veil.size = Vector2(1600,900)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(veil)

func show_menu():
	screen = "menu"
	_clear(ui)
	_clear(modal)
	world.visible = false
	_cover(0.20)
	_panel(ui,Rect2(0,0,730,900),Color(0.06,0.09,0.073,0.79),Color.TRANSPARENT)
	_label(ui,"G R E Y C I T Y   /   S U R V I V O R S",Rect2(94,102,620,30),17,GOLD)
	_label(ui,"灰城余生",Rect2(86,146,670,122),96,PAPER)
	_label(ui,"带他们，活过这一夜。",Rect2(98,286,550,55),30,PAPER)
	_label(ui,"城里的灯一盏盏熄了。\n还有人在等，你敲响下一扇门。",Rect2(100,367,520,88),22,MUTED)
	var saved = progress.load_run()
	if not saved.is_empty():
		_button(ui,"继续同行    /    第 %s 波前" % (int(saved.get("wave",0))+1),Rect2(100,500,395,62),_continue_run,true,"ContinueRun")
		_button(ui,"重新登记",Rect2(100,577,190,54),show_classes,false,"NewRun")
		_button(ui,"幸存者档案",Rect2(305,577,190,54),show_codex,false,"Codex")
	else:
		_button(ui,"翻开登记册    →",Rect2(100,500,395,64),show_classes,true,"NewRun")
		_button(ui,"幸存者档案",Rect2(100,580,395,53),show_codex,false,"Codex")
	_button(ui,"声音与画面",Rect2(100,650,190,47),func(): show_settings("menu"),false,"Settings")
	_button(ui,"离开灰城",Rect2(305,650,190,47),func(): get_tree().quit(),false,"Quit")
	_label(ui,"独行是求生，同行才有余生。",Rect2(100,782,540,36),18,MUTED)
	_label(ui,"第三册 · 各寻生路",Rect2(1240,80,280,35),22,PAPER,HORIZONTAL_ALIGNMENT_RIGHT)
	_panel(ui,Rect2(1140,659,360,150),Color(0.085,0.12,0.09,0.88),Color("77775a"))
	_label(ui,"已归档的夜晚",Rect2(1165,676,300,30),18,MUTED)
	_label(ui,"%02d 次生还     %02d 人同行" % [progress.meta.wins,progress.meta.best_team],Rect2(1165,713,305,45),25,PAPER)
	_label(ui,"十波尸潮  /  三条生路",Rect2(1165,762,300,26),16,GOLD)

func show_classes():
	screen = "classes"
	_clear(ui)
	_clear(modal)
	world.visible = false
	_cover(0.76)
	_label(ui,"失踪人口登记册",Rect2(74,44,900,68),46,PAPER)
	_label(ui,"先记下你的名字，再带更多人回来。",Rect2(78,111,950,36),21,MUTED)
	_button(ui,"返回",Rect2(1398,60,126,45),show_menu)
	_button(ui,"轻松" if selected_difficulty!="easy" else "轻松 ✓",Rect2(995,110,150,42),func(): selected_difficulty="easy"; show_classes(),selected_difficulty=="easy","DifficultyEasy")
	_button(ui,"挑战" if selected_difficulty!="challenge" else "挑战 ✓",Rect2(1158,110,150,42),func(): selected_difficulty="challenge"; show_classes(),selected_difficulty=="challenge","DifficultyChallenge")
	_label(ui,"轻松：血量/伤害70%，数量75% · 挑战：完整尸潮",Rect2(660,155,850,23),15,MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
	var ids = content.classes.keys()
	for index in range(ids.size()):
		var id = ids[index]
		var person = content.classes[id]
		var map_data = content.maps[person.map]
		var x = 78+index*493
		var selected = selected_class == id
		_panel(ui,Rect2(x,180,461,525),Color("29342b") if selected else Color("1d2821"),GOLD if selected else Color("566047"))
		_label(ui,"档案 0%s     %s" % [index+1,person.name],Rect2(x+25,198,390,35),20,GOLD)
		_texture(ui,content.character_textures[person.sprite],Rect2(x+192,249,254,280))
		_label(ui,person.person,Rect2(x+25,260,210,65),40,PAPER)
		_label(ui,map_data.name,Rect2(x+26,327,208,40),24,GREEN)
		_label(ui,person.bonus,Rect2(x+26,377,202,70),22,PAPER)
		_label(ui,person.bio,Rect2(x+25,529,413,75),18,MUTED)
		_button(ui,"已选定此人" if selected else "选择「%s」" % person.name,Rect2(x+24,633,413,48),func(): selected_class=id; show_classes(),selected,"Class_"+id)
	var selected_data = content.classes[selected_class]
	_label(ui,content.maps[selected_data.map].tag+"    /    初始武器："+content.weapons[selected_data.weapon].name,Rect2(80,736,930,36),21,MUTED)
	_label(ui,"WASD 移动  ·  自动攻击  ·  按住 E 救人  ·  Esc 暂停",Rect2(80,790,970,35),20,PAPER)
	_button(ui,"走进"+content.maps[selected_data.map].name+"   →",Rect2(1135,763,385,67),_request_start,true,"StartRun")

func _request_start():
	if not progress.load_run().is_empty():
		_clear(modal)
		_modal_base("另一支队伍还在等你", "重新开始会替换当前对局；图鉴与两档难度的战绩保留。")
		_button(modal,"继续原对局",Rect2(476,530,295,58),_continue_run)
		_button(modal,"开始这段旅程",Rect2(807,530,295,58),func(): start_run(selected_class),true)
	else:
		start_run(selected_class)

func start_run(id: String, seed_value: int = 0):
	run = RunState.new(content)
	run.start(id,seed_value,selected_difficulty)
	shop.stock(run,progress.meta.unlocked)
	_make_world()
	if not progress.save_run(run):
		_toast(progress.last_error)
	show_camp(true)

func _continue_run():
	var state = RunState.new(content)
	if not state.restore(progress.load_run()):
		_toast("这份登记记录无法读取，请重新开始。")
		show_classes()
		return
	run = state
	_make_world()
	if not run.equipment_choices.is_empty(): show_equipment()
	else: show_camp(run.wave == 0)

func _make_world():
	_clear(world)
	city = CityMap.new()
	city.setup(content,run.map_id)
	world.add_child(city)
	sim = Combat.new()
	sim.setup(content,run,progress,city)
	world.add_child(sim)
	sim.wave_finished.connect(_wave_finished)
	sim.defeated.connect(func(): _finish(false))
	sim.level_requested.connect(show_level)
	sim.equipment_requested.connect(show_equipment)
	sim.message.connect(_toast)
	sim.sound_requested.connect(audio.play)
	sim.spatial_sound_requested.connect(func(kind,at,intensity): audio.play_at(kind,at-sim.captain,intensity))

func _begin_wave():
	if run.wave==1 and not run.first_core:
		run.make_equipment_choices()
		run.equipment_return="camp"
		run.mode="equipment"
		progress.save_run(run)
		show_equipment()
		return
	if not run.equipment_choices.is_empty():
		show_equipment()
		return
	if not progress.save_run(run):
		_toast(progress.last_error)
		return
	_clear(modal)
	_clear(ui)
	world.visible = true
	_clear(backdrop)
	screen = "combat"
	sim.begin_wave()
	_build_hud()
	_toast("第 %s 波 · 救援标记已经出现" % run.wave)

func _build_hud():
	_clear(ui)
	hud.clear()
	_panel(ui,Rect2(0,0,1600,99),Color(0.065,0.10,0.077,0.96),Color("515d49"))
	_label(ui,content.classes[run.class_id].person+"  /  "+content.classes[run.class_id].name,Rect2(28,15,370,29),21,PAPER)
	hud.health = _label(ui,"",Rect2(287,15,162,29),18,MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
	hud.health_bar = _bar(ui,Rect2(29,55,420,13),Color("b97563"))
	hud.xp_bar = _bar(ui,Rect2(29,80,420,4),Color("9aac82"))
	hud.wave = _label(ui,"",Rect2(525,13,550,40),26,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	hud.time = _label(ui,"",Rect2(547,53,506,30),19,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	hud.resources = _label(ui,"",Rect2(1150,14,410,35),24,GOLD,HORIZONTAL_ALIGNMENT_RIGHT)
	hud.status = _label(ui,"",Rect2(1110,52,454,29),17,MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
	_panel(ui,Rect2(0,806,1600,94),Color(0.065,0.10,0.077,0.97),Color("515d49"))
	hud.synergies = []
	hud.roster_kinds = run.counts.size()
	var strip = ScrollContainer.new()
	strip.position = Vector2(23,811)
	strip.size = Vector2(1320,86)
	strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.add_child(strip)
	var row = HBoxContainer.new()
	strip.add_child(row)
	for id in run.counts:
		var cell = Control.new()
		cell.custom_minimum_size = Vector2(221,72)
		row.add_child(cell)
		_texture(cell,content.character_textures[content.survivors[id].sprite],Rect2(0,0,57,63))
		var title = _label(cell,"",Rect2(58,0,158,33),19,PAPER)
		var desc = _label(cell,"",Rect2(58,34,158,29),15,MUTED)
		hud.synergies.append({"id":id,"title":title,"desc":desc})
	if run.counts.is_empty():
		var cell = Control.new()
		cell.custom_minimum_size = Vector2(900,65)
		row.add_child(cell)
		_label(cell,"暂时独行。回应呼救，找到第一位同行者。",Rect2(15,15,880,39),20,MUTED)
	_button(ui,"暂停 / Esc",Rect2(1370,827,201,48),show_pause,false,"Pause")
	hud.notice = _label(ui,"",Rect2(355,739,890,48),22,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	hud.minimap = Minimap.new()
	hud.minimap.sim = sim
	hud.minimap.position = Vector2(1394,120)
	hud.minimap.size = Vector2(178,134)
	hud.minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud.minimap)
	hud.rescue = _label(ui,"",Rect2(1280,263,290,70),17,GREEN,HORIZONTAL_ALIGNMENT_RIGHT)
	hud.search = _label(ui,"",Rect2(1250,346,320,115),16,GOLD,HORIZONTAL_ALIGNMENT_RIGHT)
	hud.help = _label(ui,"WASD 移动\n按住 E 救援 / 搜刮 / 操作\nTab 队伍 · B 构筑",Rect2(27,125,275,106),17,Color(0.91,0.89,0.77,0.8))
	hud.boss_label = _label(ui,"",Rect2(505,111,590,37),22,RED,HORIZONTAL_ALIGNMENT_CENTER)
	hud.boss_bar = _bar(ui,Rect2(550,157,500,8),RED)
	hud.boss_bar.visible = false
	hud.build_status=_label(ui,"",Rect2(25,241,600,36),16,GREEN)
	hud.equipment_labels=[]
	for i in range(4):
		var label=_label(ui,"",Rect2(25,282+i*30,300,27),15,PAPER)
		hud.equipment_labels.append(label)
	_button(ui,"构筑 / B",Rect2(26,407,165,35),func(): show_build("combat"),false,"Build")
	_update_hud()

func _update_hud():
	if hud.is_empty() or not is_instance_valid(hud.health):
		return
	if hud.get("roster_kinds",-1) != run.counts.size():
		_build_hud()
		return
	if hud.has("build_status"):
		var charges=["护盾 %s" % ceili(sim.build.shield)]
		if run.has_mod("move_charge") or "flywheel" in run.equipment: charges.append("蓄力 %s%%" % int(sim.build.move_charge/4*100))
		if "battery" in run.equipment: charges.append("电池 %s/8" % sim.build.battery_charge)
		if run.has_mod("pickup_echo"): charges.append("追击 %s/10" % sim.build.pickup_charge)
		if "magnet" in run.equipment: charges.append("磁吸 %s/10" % sim.build.magnet_charge)
		hud.build_status.text=" · ".join(charges)
		for i in range(4): hud.equipment_labels[i].text="%s. %s" % [i+1,content.equipment[run.equipment[i]].name if i<run.equipment.size() else "空装备槽"]
	hud.health.text = "%s / %s" % [ceili(run.health),int(run.stats.max_health)]
	hud.health_bar.max_value = run.stats.max_health
	hud.health_bar.value = run.health
	hud.xp_bar.max_value = run.xp_target()
	hud.xp_bar.value = run.xp
	hud.wave.text = "%s · %s / 第 %02d 波" % [content.maps[run.map_id].name,"轻松" if run.difficulty=="easy" else "挑战",run.wave]
	var seconds = maxi(0,ceili(60-sim.elapsed))
	hud.time.text = "%02d:%02d   ·   %s" % [seconds/60,seconds%60,"清理剩余 %s 名感染者" % sim.active_count if seconds == 0 else "撑过这一轮尸潮"]
	hud.resources.text = "物资  %s     同行  %s 人" % [run.supplies,run.roster.size()+1]
	hud.status.text = "等级 %s     击退 %s     已救援 %s 人" % [run.level,run.kills,run.rescued]
	for item in hud.synergies:
		var count = int(run.counts.get(item.id,0))
		var tier = run.synergy_tier(item.id)
		item.title.text = "%s  ×%s" % [content.survivors[item.id].name,count]
		item.desc.text = "协同 %s/3  ·  %s" % [tier,"已达最高" if count >= 6 else "%s人再提升" % (2-count%2)] if count > 0 else "等待回应"
		item.title.modulate = Color.WHITE if count > 0 else Color(0.65,0.7,0.62)
	hud.notice.text = notice if notice_time > 0 else ""
	if sim.rescue_done:
		hud.rescue.text = "本波救援完成 ✓"
	elif not sim.rescue.is_empty():
		var distance = sim.captain.distance_to(sim.rescue.pos)
		var angle = sim.captain.direction_to(sim.rescue.pos).angle()
		var arrows = ["→","↘","↓","↙","←","↖","↑","↗"]
		var arrow = arrows[posmod(roundi(angle/(PI/4)),8)]
		hud.rescue.text = "%s  呼救声 · %s米\n靠近后按住 E" % [arrow,int(distance/12)]
	var searches=[]
	if sim.scavenging.opened: searches.append("本波搜刮完成 ✓")
	else:
		for site in sim.scavenging.sites:
			var angle=sim.captain.direction_to(site.pos).angle()
			var arrow=["→","↘","↓","↙","←","↖","↑","↗"][posmod(roundi(angle/(PI/4)),8)]
			searches.append("%s %s · %s米" % [arrow,site.label,int(sim.captain.distance_to(site.pos)/12)])
		searches.append("小地图金框 · 每波只取一处")
	hud.search.text="\n".join(searches)
	var boss = sim.boss_status()
	hud.boss_bar.visible = not boss.is_empty()
	hud.boss_label.text = "" if boss.is_empty() else content.enemies[boss.id].name
	if not boss.is_empty():
		hud.boss_bar.max_value = boss.max_hp
		hud.boss_bar.value = boss.hp

func _process(delta: float):
	preview_clock+=delta
	for item in previews:
		if is_instance_valid(item.node): item.node.texture=content.effect_frame(item.clip,fposmod(preview_clock*1.6,1.0))
	notice_time = maxf(0,notice_time-delta)
	if atmosphere != null:
		atmosphere.visible = world.visible
	if sim != null and is_instance_valid(sim) and world.visible:
		var center = Vector2(800,456)
		var camera = Vector2(clampf(sim.captain.x,800,1600),clampf(sim.captain.y,440,1360))
		world.position = center-camera
		if sim.shake_amount > 0 and progress.settings.shake:
			var jitter = Vector2(sin(sim.clock*103)+sin(sim.clock*157)*0.33,cos(sim.clock*89)+cos(sim.clock*137)*0.28)*0.72
			world.position += jitter*sim.shake_amount+sim.feedback.camera_kick
	if screen == "combat":
		_ui_clock -= delta
		if _ui_clock <= 0:
			_ui_clock = 0.1
			_update_hud()
		_mini_clock -= delta
		if _mini_clock <= 0:
			_mini_clock = 0.3
			hud.minimap.queue_redraw()

func _unhandled_key_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_B and screen=="combat":
		show_build("combat")
		return
	if event.is_action_pressed("pause"):
		if screen == "combat" and run.mode == "combat":
			show_pause()
		elif screen == "pause":
			_resume()
		elif screen in ["roster","build"]:
			show_camp() if modal_return == "camp" else _resume()
		elif screen == "settings":
			_close_settings()
	elif event.is_action_pressed("roster"):
		if screen == "combat" and run.mode == "combat":
			show_roster()
		elif screen in ["roster","build"]:
			show_camp() if modal_return == "camp" else _resume()

func _toast(text: String):
	notice = text
	notice_time = 5.0

func _wave_finished():
	last_unlocks = progress.unlock_for_wave(run.wave)
	if run.wave == 10:
		_finish(true)
		return
	run.refreshes = 0
	shop.stock(run,progress.meta.unlocked)
	if not progress.save_run(run):
		_toast(progress.last_error)
	audio.play("rescue")
	show_camp()

func show_camp(first: bool = false):
	screen = "camp"
	run.mode = "camp"
	world.visible = false
	_clear(ui)
	_clear(modal)
	_cover(0.88)
	_label(ui,"出发之前" if first else "还有人活着",Rect2(61,34,960,73),45,PAPER)
	var caption = "灯还亮着。带好补给，去回应第一声呼救。" if first else "第 %s 波结束  ·  已收拢散落物资  ·  整备奖励 +%s" % [run.wave,int(content.wave(run.wave).reward)]
	_label(ui,caption,Rect2(65,107,1140,34),19,MUTED)
	_label(ui,"物资  %s" % run.supplies,Rect2(1250,47,290,52),32,GOLD,HORIZONTAL_ALIGNMENT_RIGHT)
	_label(ui,"同行者登记   /   同类可重复招募",Rect2(66,163,880,35),23,PAPER)
	for index in range(3):
		var offer = run.offers[index]
		var data = content.survivors[offer.id]
		var x = 65+index*329
		_panel(ui,Rect2(x,212,308,365),Color("253026"),Color("566047"))
		_label(ui,offer.get("label","获救者  %02d" % (index+1)),Rect2(x+19,221,260,30),16,GOLD)
		_texture(ui,content.character_textures[data.sprite],Rect2(x+80,254,161,166))
		_label(ui,data.name,Rect2(x+20,418,268,37),26,PAPER)
		_label(ui,data.description,Rect2(x+20,458,268,60),16,MUTED)
		var button = _button(ui,"已同行" if offer.sold else "招募  /  %s 物资" % offer.cost,Rect2(x+18,525,272,37),func(): _buy(offer.uid),not offer.sold,"Buy_"+str(index))
		button.add_theme_font_size_override("font_size",18)
		button.disabled = offer.sold or run.supplies < offer.cost
	_panel(ui,Rect2(1081,167,458,410),Color("202b23"),Color("606b50"))
	_label(ui,"这支队伍",Rect2(1104,185,407,40),27,PAPER)
	_label(ui,"%s 人同行    /    已救援 %s 人" % [run.roster.size()+1,run.rescued],Rect2(1105,234,408,36),22,GREEN)
	var health_bar = _bar(ui,Rect2(1108,295,406,12),RED)
	health_bar.max_value = run.stats.max_health
	health_bar.value = run.health
	_label(ui,"生命 %s / %s" % [ceili(run.health),int(run.stats.max_health)],Rect2(1105,266,405,27),17,MUTED)
	var heal_button = _button(ui,"急救 +%s生命 / 20物资" % (40 if run.difficulty=="easy" else 25),Rect2(1107,329,406,46),_heal,false,"Heal")
	heal_button.disabled = run.health >= run.stats.max_health or run.supplies < 20
	_label(ui,"2 / 4 / 6 名同业激活职业协同\n武器升级对所有同类成员生效\n下一波开始前，时间不会流逝",Rect2(1108,394,400,108),18,MUTED)
	_button(ui,"查看队伍与协同",Rect2(1107,515,406,40),func(): show_roster("camp"),false,"CampRoster")
	_button(ui,"构筑档案",Rect2(1107,581,406,40),func(): show_build("camp"),false,"CampBuild")
	_label(ui,"改装台   /   所有持有者共享等级",Rect2(67,602,900,33),22,PAPER)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(65,649)
	scroll.size = Vector2(960,125)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.add_child(scroll)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	scroll.add_child(row)
	for weapon_id in run.weapon_levels:
		var cell = Control.new()
		cell.custom_minimum_size = Vector2(304,116)
		row.add_child(cell)
		_panel(cell,Rect2(0,0,304,115),Color("28332a"))
		_label(cell,"%s  Lv.%s" % [content.weapons[weapon_id].name,run.weapon_levels[weapon_id]],Rect2(12,0,280,30),19,PAPER)
		_label(cell,"每级伤害 +12% · 行为改装在战斗升级中选择",Rect2(12,31,280,47),14,MUTED)
		var maxed = int(run.weapon_levels[weapon_id]) >= 5
		var button = _button(cell,"已满级" if maxed else "升级 · %s物资" % run.upgrade_price(weapon_id),Rect2(10,83,284,29),func(): _upgrade_weapon(weapon_id),false,"Upgrade_"+weapon_id)
		button.add_theme_font_size_override("font_size",16)
		button.disabled = maxed or run.supplies < run.upgrade_price(weapon_id)
	var refresh_price = 8+run.refreshes*4
	var refresh_button = _button(ui,"打听新面孔  /  %s物资" % refresh_price,Rect2(1081,612,458,48),_refresh,false,"Refresh")
	refresh_button.disabled = run.supplies < refresh_price
	_button(ui,"声音与画面",Rect2(1081,680,217,44),func(): show_settings("camp"))
	_button(ui,"保存并返回",Rect2(1320,680,219,44),_camp_to_menu)
	var footer = "整备进度已自动记录。" if progress.last_error.is_empty() else progress.last_error
	if not last_unlocks.is_empty():
		footer = "新档案解锁：" + "、".join(last_unlocks.map(func(id): return content.survivors[id].name)) + "。已加入本局招募与救援名单。"
	_label(ui,footer,Rect2(67,780,1040,65),18,GREEN)
	_button(ui,"出发 · 第 %s 波    →" % (run.wave+1),Rect2(1136,775,402,65),_begin_wave,true,"NextWave")

func _transaction(action: Callable):
	var before = run.snapshot()
	if not action.call():
		return
	if not progress.save_run(run):
		var error = progress.last_error
		run.restore(before)
		_toast(error)
	if not run.equipment_choices.is_empty(): show_equipment()
	else: show_camp(run.wave == 0)

func _buy(uid: String):
	_transaction(func(): return shop.buy(run,uid))

func _heal():
	_transaction(func(): return shop.heal(run))

func _upgrade_weapon(id: String):
	_transaction(func(): return shop.upgrade(run,id))

func _refresh():
	_transaction(func(): return shop.refresh(run,progress.meta.unlocked))

func _camp_to_menu():
	if progress.save_run(run):
		show_menu()
	else:
		_toast(progress.last_error)
		show_camp()

func _modal_base(title: String, subtitle: String):
	var veil = ColorRect.new()
	veil.size = Vector2(1600,900)
	veil.color = Color(0.025,0.045,0.03,0.82)
	modal.add_child(veil)
	_panel(modal,Rect2(395,253,810,391),Color("202b24"),GOLD)
	_label(modal,title,Rect2(441,287,719,70),39,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	_label(modal,subtitle,Rect2(451,377,698,103),20,MUTED,HORIZONTAL_ALIGNMENT_CENTER)

func show_pause():
	if run.mode != "combat":
		return
	run.mode = "paused"
	screen = "pause"
	_clear(modal)
	_modal_base("喘一口气", "时间已经停下。你的同行者都在。\n离开战斗会回到本波出发前的整备记录。")
	_button(modal,"继续前行",Rect2(442,519,221,58),_resume,true,"Resume")
	_button(modal,"声音与画面",Rect2(689,519,221,58),func(): show_settings("pause"))
	_button(modal,"返回登记册",Rect2(936,519,221,58),show_menu)

func _resume():
	_clear(modal)
	screen = "combat"
	run.mode = "combat"

func animate(parent,clip: String,rect: Rect2):
	var node=TextureRect.new()
	node.position=rect.position
	node.size=rect.size
	node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	previews.append({"node":node,"clip":clip})

func build_modal(title: String, subtitle: String):
	var veil=ColorRect.new()
	veil.size=Vector2(1600,900)
	veil.color=Color(0.025,0.045,0.03,0.94)
	modal.add_child(veil)
	_label(modal,title,Rect2(230,110,1140,65),38,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	_label(modal,subtitle,Rect2(260,190,1080,70),20,MUTED,HORIZONTAL_ALIGNMENT_CENTER)

func benefit_count(id: String) -> int:
	if id in ["pickup_stride","move_charge","pickup_echo"]: return 1
	var weapon=content.mods.get(id,{"weapon":""}).weapon
	if weapon.is_empty(): return run.roster.size()+1
	var count=int(content.classes[run.class_id].weapon==weapon)
	for person in run.roster:
		if content.survivors[person].weapon==weapon: count+=1
	return count

func show_level():
	screen="upgrade"
	_clear(modal)
	previews.clear()
	build_modal("这一课，改变打法","已学改装 %s 项 · 本局最多选择16次 · 同类武器共同受益" % run.mods.size())
	for index in range(run.choices.size()):
		var id=run.choices[index]
		var item=content.mods.get(id,{"name":{"aid":"紧急救治","supply":"备用物资","refresh":"重新搜索"}.get(id,id),"text":{"aid":"回复25生命","supply":"获得20物资","refresh":"获得1次刷新"}.get(id,""),"weapon":"","tags":[],"clip":"dust"})
		var x=225+index*385
		_panel(modal,Rect2(x,290,360,415),Color("26342a"),GOLD)
		animate(modal,item.clip,Rect2(x+110,300,140,115))
		_label(modal,item.name,Rect2(x+20,422,320,42),26,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
		_label(modal,item.text,Rect2(x+22,474,316,66),19,GREEN)
		var beneficiaries=benefit_count(id)
		var links=[]
		for eq in run.equipment:
			if content.equipment[eq].tags.any(func(t): return t in item.tags): links.append(content.equipment[eq].name)
		_label(modal,"受益 %s人\n联动：%s" % [beneficiaries,"、".join(links) if not links.is_empty() else "等待更多组件"],Rect2(x+22,551,316,63),16,MUTED)
		_button(modal,"学习改装",Rect2(x+25,636,310,46),func(): _choose_level(id),true,"Perk_"+id)
	var refresh=_button(modal,"刷新选择 · 剩余%s次" % run.rerolls,Rect2(585,733,430,44),func():
		if run.refresh_choices(): show_level(),false,"Reroll")
	refresh.disabled=run.rerolls<=0
	_label(modal,"追加攻击通常造成50%伤害；不会继续触发追加攻击。",Rect2(350,799,900,35),16,MUTED,HORIZONTAL_ALIGNMENT_CENTER)

func _choose_level(id: String):
	if not run.choose_perk(id): return
	audio.play("pickup")
	_toast("获得："+content.mods.get(id,{"name":"补给"}).name)
	if run.pending_levels>0:
		run.make_choices()
		show_level()
	else: _resume()

func show_equipment():
	screen="equipment"
	run.mode="equipment"
	_clear(modal)
	previews.clear()
	build_modal("从废墟里，带走一种可能","全队共用四个装备槽 · 可以自由混搭")
	for i in range(run.equipment_choices.size()):
		var id=run.equipment_choices[i]
		var item=content.equipment[id]
		var x=225+i*385
		_panel(modal,Rect2(x,310,360,355),Color("26342a"),GOLD)
		animate(modal,item.clip,Rect2(x+115,319,130,110))
		_label(modal,item.name,Rect2(x+20,440,320,40),26,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
		_label(modal,item.text,Rect2(x+22,495,316,90),19,GREEN)
		_button(modal,"替换一件装备" if run.equipment.size()==4 else "带上它",Rect2(x+25,603,310,43),func(): _select_equipment(id),true,"Equip_"+id)
	_button(modal,"放弃本次装备",Rect2(615,708,370,42),func(): run.equipment_choices.clear(); run.first_core=true; _close_equipment(),false,"SkipEquipment")

func _select_equipment(id: String):
	if id not in run.equipment_choices: return
	if run.equipment.size()<4:
		if run.choose_equipment(id): _close_equipment()
		return
	selected_equipment=id
	_clear(modal)
	build_modal("四个槽位，做一次取舍","将获得："+content.equipment[id].name+" · "+content.equipment[id].text)
	for i in range(4):
		var old=content.equipment[run.equipment[i]]
		_label(modal,"失去："+old.name+" · "+old.text,Rect2(315,315+i*91,730,70),18,MUTED)
		_button(modal,"替换此件",Rect2(1070,324+i*91,215,44),func():
			if run.choose_equipment(selected_equipment,i): _close_equipment(),false,"Replace_"+str(i))
	_button(modal,"返回候选",Rect2(650,725,300,42),show_equipment)

func _close_equipment():
	if run.equipment_return=="camp":
		run.mode="camp"
		progress.save_run(run)
		show_camp()
	else: _resume()

func show_build(origin: String="combat"):
	modal_return=origin
	if origin=="combat": run.mode="paused"
	screen="build"
	_clear(modal)
	build_modal("队伍构筑档案","自由混搭 · 四种流派是建议，不是套装限制")
	var body=_scroll_body(modal,Rect2(285,275,1030,445),Vector2(985,1500))
	var y=0
	var available=run.tags()
	var tag_names={"wet":"湿润","electric":"电击","chainsaw":"电锯","melee":"近战","acid":"腐蚀","fire":"火焰","healing":"治疗","sonic":"声波","brick":"板砖"}
	for id in run.equipment:
		var missing=content.equipment[id].requires.filter(func(t): return t not in available)
		var hint=""
		if not missing.is_empty():
			var labels=[]
			for tag in missing: labels.append(tag_names.get(tag,tag))
			hint="\n暂缺触发来源："+"、".join(labels)
		_label(body,"装备 / "+content.equipment[id].name+"："+content.equipment[id].text+hint,Rect2(12,y,950,78),19,GREEN)
		y+=83
	for id in run.mods:
		_label(body,"改装 / "+content.mods[id].name+" · 受益%s人：" % benefit_count(id)+content.mods[id].text,Rect2(12,y,950,65),18,PAPER)
		y+=68
	_label(body,"流派线索\n水电：湿润＋电击＋拾取充能\n腐蚀近战：强酸＋电锯＋治疗护盾\n诱饵火场：声波聚怪＋地面火区\n回收游击：移动蓄能＋拾取波＋急救",Rect2(12,y+15,945,175),20,GOLD)
	y+=205
	var tags=run.tags()
	for id in content.equipment:
		if id in run.equipment: continue
		var missing=content.equipment[id].requires.filter(func(t): return t not in tags)
		var names={"wet":"湿润","electric":"电击","chainsaw":"电锯","melee":"近战","acid":"腐蚀","fire":"火焰","healing":"治疗","sonic":"声波","brick":"板砖"}
		var text=[]
		for tag in missing: text.append(names.get(tag,tag))
		_label(body,content.equipment[id].name+" / "+("已满足获取条件" if missing.is_empty() else "尚缺："+"、".join(text)),Rect2(12,y,940,32),16,MUTED)
		y+=35
	body.custom_minimum_size.y=y+25
	_button(modal,"返回",Rect2(650,745,300,43),func(): show_camp() if origin=="camp" else _resume(),true,"CloseBuild")

func show_roster(origin: String = "combat"):
	if origin == "combat":
		run.mode = "paused"
	screen = "roster"
	modal_return = origin
	_clear(modal)
	var veil = ColorRect.new()
	veil.size = Vector2(1600,900)
	veil.color = Color(0.025,0.045,0.03,0.95)
	modal.add_child(veil)
	_label(modal,"同行者名册",Rect2(80,45,900,70),43,PAPER)
	_label(modal,"%s 人同行 · 全员自动作战 · 共同生命 %s / %s" % [run.roster.size()+1,ceili(run.health),int(run.stats.max_health)],Rect2(82,118,1230,42),22,GREEN)
	_button(modal,"合上名册",Rect2(1330,60,188,47),func(): show_camp() if origin == "camp" else _resume())
	var body = _scroll_body(modal,Rect2(80,189,1440,600),Vector2(1420,1170))
	var index = 0
	for id in content.survivors:
		var data = content.survivors[id]
		var count = int(run.counts.get(id,0))
		var x = (index%2)*716
		var y = (index/2)*195
		_panel(body,Rect2(x,y,706,174),Color("243127"))
		_texture(body,content.character_textures[data.sprite],Rect2(x+10,y+14,130,142))
		_label(body,"%s × %s" % [data.name,count],Rect2(x+153,y+12,519,41),25,PAPER)
		_label(body,data.synergy,Rect2(x+153,y+61,528,53),18,MUTED)
		_label(body,"协同 %s/3  ·  %s Lv.%s" % [run.synergy_tier(id),content.weapons[data.weapon].name,run.weapon_levels.get(data.weapon,1)],Rect2(x+153,y+120,525,31),17,GREEN)
		index += 1
	_label(modal,"全队伤害 ×%.2f     攻速 ×%.2f     减伤 %s     每秒回复 %.2f" % [run.stats.damage,run.stats.attack_speed,run.stats.armor,run.stats.regen],Rect2(83,808,1430,40),21,GOLD)

func show_settings(origin: String):
	modal_return = origin
	screen = "settings"
	_clear(modal)
	var veil = ColorRect.new()
	veil.size = Vector2(1600,900)
	veil.color = Color(0.025,0.045,0.03,0.94)
	modal.add_child(veil)
	_panel(modal,Rect2(400,155,800,585),PANEL,GOLD)
	_label(modal,"让这一夜，适合你",Rect2(445,184,710,75),38,PAPER)
	_label(modal,"声音音量",Rect2(456,285,250,40),22,PAPER)
	var slider = HSlider.new()
	slider.position = Vector2(729,293)
	slider.size = Vector2(411,32)
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.05
	slider.value = progress.settings.volume
	slider.value_changed.connect(func(value): progress.settings.volume=value; audio.set_level(value); progress.save_settings())
	modal.add_child(slider)
	var options = [["shake","屏幕震动"],["flash","受击闪烁"],["blood","地面血迹"],["fullscreen","全屏显示"]]
	for index in range(options.size()):
		var option = options[index]
		var toggle = CheckButton.new()
		toggle.text = option[1]
		toggle.position = Vector2(455,355+index*57)
		toggle.size = Vector2(680,40)
		toggle.add_theme_color_override("font_color",PAPER)
		toggle.button_pressed = progress.settings[option[0]]
		toggle.toggled.connect(func(value):
			progress.settings[option[0]]=value
			if option[0] == "fullscreen" and DisplayServer.get_name() != "headless":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
			progress.save_settings())
		modal.add_child(toggle)
	_button(modal,"保存并返回",Rect2(456,641,684,58),_close_settings,true,"CloseSettings")

func _close_settings():
	_clear(modal)
	match modal_return:
		"camp": show_camp()
		"pause":
			run.mode = "combat"
			show_pause()
		_: show_menu()

func show_codex():
	screen = "codex"
	_clear(ui)
	_clear(modal)
	_cover(0.88)
	_label(ui,"活着的人，留下名字",Rect2(70,39,1110,70),43,PAPER)
	_label(ui,"十二种职业与全部构筑已开放。每次旅程从普通人开始。",Rect2(70,113,1120,40),21,MUTED)
	_button(ui,"构筑图鉴",Rect2(1090,60,200,48),show_build_codex,false,"BuildCodex")
	_button(ui,"返回登记册",Rect2(1320,60,210,48),show_menu)
	var body = _scroll_body(ui,Rect2(70,186,1460,512),Vector2(1440,980))
	var index = 0
	for id in content.survivors:
		var data = content.survivors[id]
		var unlocked = id in progress.meta.unlocked
		var x = (index%3)*482
		var y = (index/3)*245
		_panel(body,Rect2(x,y,463,223),PANEL)
		_texture(body,content.character_textures[data.sprite],Rect2(x+10,y+24,155,176),Color.WHITE if unlocked else Color(0.25,0.31,0.25))
		_label(body,data.name,Rect2(x+178,y+20,277,40),25,PAPER)
		_label(body,content.weapons[data.weapon].name,Rect2(x+180,y+68,265,34),19,GOLD)
		_label(body,data.description if unlocked else "生还第 %s 波后解锁。" % (3 if id == "chef" else 5),Rect2(x+179,y+112,267,73),18,MUTED)
		_label(body,content.weapons[data.weapon].preview if unlocked else "尚无回音",Rect2(x+179,y+182,270,39),13,GREEN if unlocked else RED)
		index += 1
	_label(ui,"轻松 %s/%s 次生还　·　挑战 %s/%s 次生还　·　最多 %s 人同行" % [progress.meta.difficulties.easy.wins,progress.meta.difficulties.easy.runs,progress.meta.difficulties.challenge.wins,progress.meta.difficulties.challenge.runs,progress.meta.best_team],Rect2(70,724,1460,50),23,GOLD)
	var known = []
	for id in progress.meta.seen:
		if content.enemies.has(id): known.append(content.enemies[id].name)
	_label(ui,"感染者记录："+("、".join(known) if not known.is_empty() else "暂无目击记录"),Rect2(70,787,1460,60),17,MUTED)

func show_build_codex():
	screen="build_codex"
	_clear(ui)
	_clear(modal)
	_cover(0.88)
	_label(ui,"构筑图鉴",Rect2(70,39,1000,70),43,PAPER)
	_label(ui,"水电 / 腐蚀近战 / 诱饵火场 / 回收游击：可以自由混搭，没有隐藏套装奖励。",Rect2(70,113,1440,42),20,MUTED)
	_button(ui,"返回人物图鉴",Rect2(1300,60,230,48),show_codex)
	var body=_scroll_body(ui,Rect2(70,180,1460,650),Vector2(1420,4400))
	var y=0
	for table in [content.equipment,content.mods]:
		for id in table:
			var item=table[id]
			_label(body,item.name,Rect2(10,y,340,40),24,GOLD)
			_label(body,item.text,Rect2(365,y,1030,60),20,PAPER)
			y+=80
	body.custom_minimum_size.y=y+20

func _finish(win: bool):
	last_win = win
	run.mode = "result"
	if not progress.finish(run,win):
		_toast(progress.last_error)
	audio.play("victory" if win else "boss")
	show_result()

func show_result():
	screen = "result"
	world.visible = false
	_clear(ui)
	_clear(modal)
	_cover(0.79)
	_label(ui,"天快亮了" if last_win else "最后一盏灯，熄了",Rect2(100,66,1400,105),65,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	_label(ui,"你们从%s走了出来。请记住这些同行者。" % content.maps[run.map_id].name if last_win else "这一次没能走出去。已经记下的名字，会留在下一页。",Rect2(200,180,1200,60),23,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	_panel(ui,Rect2(238,274,1124,350),Color(0.10,0.15,0.11,0.91),Color("6c755a"))
	var all_sprites = [int(content.classes[run.class_id].sprite)]
	for id in run.roster:
		all_sprites.append(int(content.survivors[id].sprite))
	var shown = mini(all_sprites.size(),45)
	var step = minf(81,1000.0/maxi(1,shown))
	var start_x = 800-(shown-1)*step/2
	for index in range(shown):
		_texture(ui,content.character_textures[all_sprites[index]],Rect2(start_x+index*step-55,314+(index%2)*23,110,141))
	_label(ui,"%s 人同行     %s 人获救     击退 %s 名感染者" % [run.roster.size()+1,run.rescued,run.kills],Rect2(267,496,1067,50),27,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	_label(ui,"第 %s 波  ·  等级 %s  ·  战斗 %02d:%02d  ·  剩余物资 %s" % [run.wave,run.level,int(run.elapsed_total)/60,int(run.elapsed_total)%60,run.supplies],Rect2(270,562,1060,30),20,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	_button(ui,"再带一队人回来",Rect2(380,678,395,64),show_classes,true,"Restart")
	_button(ui,"合上这页登记册",Rect2(825,678,395,64),show_menu,false,"ResultMenu")
	_label(ui,"本次难度："+("轻松" if run.difficulty=="easy" else "挑战")+" · 战绩分档记录；下局重新构筑，无永久战斗加成。",Rect2(250,789,1100,40),18,MUTED,HORIZONTAL_ALIGNMENT_CENTER)

func _scroll_body(parent: Node, rect: Rect2, extent: Vector2) -> Control:
	var scroll = ScrollContainer.new()
	scroll.position = rect.position
	scroll.size = rect.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var body = Control.new()
	body.custom_minimum_size = extent
	scroll.add_child(body)
	return body
