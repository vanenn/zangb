from pathlib import Path
R=Path(__file__).resolve().parents[1]
p=R/'scripts/progress.gd';s=p.read_text(encoding='utf-8');a=s.index('func _init(');b=s.index('func _read(',a)
s=s[:a]+'''func _init(path: String = "user://"):
	directory=path
	DirAccess.make_dir_recursive_absolute(directory)
	var marker=_read("schema.json")
	if int(marker.get("version",0))!=3:
		# Exact allowlist only: no directory traversal or recursive deletion.
		var root=ProjectSettings.globalize_path(directory).simplify_path().trim_suffix("/")
		for stem in ["run","progress","settings"]:
			for tail in [".json",".json.bak",".json.tmp",".pre-v2.json"]:
				var target=root.path_join(stem+tail).simplify_path()
				if target.get_base_dir()!=root:
					last_error="存档目录验证失败"
					return
				if FileAccess.file_exists(target) and DirAccess.remove_absolute(target)!=OK:
					last_error="无法清理旧存档，请关闭旧版游戏后重试。"
					return
		if not _write("schema.json",{"version":3}): return
	var saved_settings=_read("settings.json")
	for key in settings:
		if saved_settings.has(key): settings[key]=saved_settings[key]
	var saved_meta=_read("progress.json")
	for key in meta:
		if saved_meta.has(key): meta[key]=saved_meta[key]
	meta.version=3
	meta.unlocked=["chemist","repairer","officer","nurse","chef","courier","electrician","chemical_worker","firefighter","hunter","sound_tech","sanitation"]
	meta.difficulties=saved_meta.get("difficulties",{"easy":{"runs":0,"wins":0},"challenge":{"runs":0,"wins":0}})
	for key in ["runs","wins","best_kills","best_team","best_wave"]: meta[key]=int(meta[key])

''' +s[b:]
a=s.index('func save_run(');b=s.index('func save_settings',a);s=s[:a]+'''func save_run(run) -> bool:
	return _write("run.json",run.snapshot())

''' +s[b:]
a=s.index('func unlock_for_wave');b=s.index('func finish(',a);s=s[:a]+'''func unlock_for_wave(wave: int) -> Array:
	meta.best_wave=maxi(meta.best_wave,wave)
	_write("progress.json",meta)
	return []

''' +s[b:]
s=s.replace('\tmeta.runs += 1','\tmeta.runs += 1\n\tmeta.difficulties[run.difficulty].runs += 1\n\tif win: meta.difficulties[run.difficulty].wins += 1')
s=s.replace('{"class":run.class_id,','{"difficulty":run.difficulty,"mods":run.mods.duplicate(),"equipment":run.equipment.duplicate(),"class":run.class_id,')
p.write_text(s,encoding='utf-8')
p=R/'scripts/main.gd';s=p.read_text(encoding='utf-8')
s=s.replace('var selected_class = "teacher"','var selected_class = "teacher"\nvar selected_difficulty = "challenge"\nvar previews = []\nvar preview_clock = 0.0\nvar selected_equipment = ""')
s=s.replace('第二册 · 重回街巷','第三册 · 各寻生路')
s=s.replace('\tvar ids = content.classes.keys()','''	_button(ui,"轻松" if selected_difficulty!="easy" else "轻松 ✓",Rect2(995,110,150,42),func(): selected_difficulty="easy"; show_classes(),selected_difficulty=="easy","DifficultyEasy")
	_button(ui,"挑战" if selected_difficulty!="challenge" else "挑战 ✓",Rect2(1158,110,150,42),func(): selected_difficulty="challenge"; show_classes(),selected_difficulty=="challenge","DifficultyChallenge")
	_label(ui,"轻松：血量/伤害70%，数量75% · 挑战：完整尸潮",Rect2(660,155,850,23),15,MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
	var ids = content.classes.keys()''',1)
s=s.replace('run.start(id,seed_value)','run.start(id,seed_value,selected_difficulty)')
s=s.replace('\tsim.level_requested.connect(show_level)','\tsim.level_requested.connect(show_level)\n\tsim.equipment_requested.connect(show_equipment)')
s=s.replace('func _begin_wave():','''func _begin_wave():
	if run.wave==1 and not run.first_core:
		run.make_equipment_choices()
		run.equipment_return="camp"
		run.mode="equipment"
		progress.save_run(run)
		show_equipment()
		return
	if not run.equipment_choices.is_empty():
		show_equipment()
		return''')
s=s.replace('\tshow_camp(run.wave == 0)','\tif not run.equipment_choices.is_empty(): show_equipment()\n\telse: show_camp(run.wave == 0)')
s=s.replace('\t_update_hud()\n\nfunc _update_hud()', '''	hud.build_status=_label(ui,"",Rect2(25,241,600,36),16,GREEN)
	hud.equipment_labels=[]
	for i in range(4):
		var label=_label(ui,"",Rect2(25,282+i*30,300,27),15,PAPER)
		hud.equipment_labels.append(label)
	_button(ui,"构筑 / B",Rect2(26,407,165,35),func(): show_build("combat"),false,"Build")
	_update_hud()

func _update_hud()''')
s=s.replace('\thud.health.text =','''	if hud.has("build_status"):
		hud.build_status.text="护盾 %s · 移动蓄力 %s%% · 电池 %s/8" % [ceili(sim.build.shield),int(sim.build.move_charge/4*100),sim.build.battery_charge]
		for i in range(4): hud.equipment_labels[i].text="%s. %s" % [i+1,content.equipment[run.equipment[i]].name if i<run.equipment.size() else "空装备槽"]
	hud.health.text =''')
s=s.replace('hud.wave.text = "%s   /   第 %02d 波" % [content.maps[run.map_id].name,run.wave]','hud.wave.text = "%s · %s / 第 %02d 波" % [content.maps[run.map_id].name,"轻松" if run.difficulty=="easy" else "挑战",run.wave]')
s=s.replace('func _process(delta: float):','''func _process(delta: float):
	preview_clock+=delta
	for item in previews:
		if is_instance_valid(item.node): item.node.texture=content.effect_frame(item.clip,fposmod(preview_clock*1.6,1.0))''')
s=s.replace('func _unhandled_key_input(event: InputEvent):','''func _unhandled_key_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_B and screen=="combat":
		show_build("combat")
		return''')
s=s.replace('elif screen == "roster":','elif screen in ["roster","build"]:')
s=s.replace('"急救 +40生命  /  16物资"','"急救 +%s生命 / 20物资" % (40 if run.difficulty=="easy" else 25)').replace('run.supplies < 16','run.supplies < 20')
s=s.replace('func(): show_roster("camp"),false,"CampRoster")','func(): show_roster("camp"),false,"CampRoster")\n\t_button(ui,"构筑档案",Rect2(1107,581,406,40),func(): show_build("camp"),false,"CampBuild")')
s=s.replace('content.weapons[weapon_id].preview','"每级伤害 +12% · 行为改装在战斗升级中选择"')
a=s.index('func show_level():');b=s.index('func show_roster(',a)
s=s[:a]+'''func animate(parent,clip: String,rect: Rect2):
	var node=TextureRect.new()
	node.position=rect.position
	node.size=rect.size
	node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	previews.append({"node":node,"clip":clip})

func show_level():
	screen="upgrade"
	_clear(modal)
	previews.clear()
	_modal_base("这一课，改变打法","本局改装 %s / 16 · 同类武器共同受益" % (run.level-1-run.pending_levels))
	for index in range(run.choices.size()):
		var id=run.choices[index]
		var item=content.mods.get(id,{"name":{"aid":"紧急救治","supply":"备用物资","refresh":"重新搜索"}.get(id,id),"text":{"aid":"回复25生命","supply":"获得20物资","refresh":"获得1次刷新"}.get(id,""),"weapon":"","tags":[],"clip":"dust"})
		var x=225+index*385
		_panel(modal,Rect2(x,290,360,415),Color("26342a"),GOLD)
		animate(modal,item.clip,Rect2(x+110,300,140,115))
		_label(modal,item.name,Rect2(x+20,422,320,42),26,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
		_label(modal,item.text,Rect2(x+22,474,316,66),19,GREEN)
		var beneficiaries=run.roster.size()+1 if item.weapon.is_empty() else int(content.classes[run.class_id].weapon==item.weapon)
		if not item.weapon.is_empty():
			for person in run.roster:
				if content.survivors[person].weapon==item.weapon: beneficiaries+=1
		var links=[]
		for eq in run.equipment:
			if content.equipment[eq].tags.any(func(t): return t in item.tags): links.append(content.equipment[eq].name)
		_label(modal,"受益 %s人\\n联动：%s" % [beneficiaries,"、".join(links) if not links.is_empty() else "等待更多组件"],Rect2(x+22,551,316,63),16,MUTED)
		_button(modal,"学习改装",Rect2(x+25,636,310,46),func(): _choose_level(id),true,"Perk_"+id)
	var refresh=_button(modal,"刷新选择 · 剩余%s次" % run.rerolls,Rect2(585,733,430,44),func():
		if run.refresh_choices(): show_level(),false,"Reroll")
	refresh.disabled=run.rerolls<=0

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
	_modal_base("从废墟里，带走一种可能","全队共用四个装备槽 · 可以自由混搭")
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
	_modal_base("四个槽位，做一次取舍","将获得："+content.equipment[id].name+" · "+content.equipment[id].text)
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
	_modal_base("队伍构筑档案","自由混搭 · 四种流派是建议，不是套装限制")
	var body=_scroll_body(modal,Rect2(285,275,1030,445),Vector2(985,1500))
	var y=0
	for id in run.equipment:
		_label(body,"装备 / "+content.equipment[id].name+"："+content.equipment[id].text,Rect2(12,y,950,52),19,GREEN)
		y+=57
	for id in run.mods:
		_label(body,"改装 / "+content.mods[id].name+"："+content.mods[id].text,Rect2(12,y,950,48),18,PAPER)
		y+=50
	_label(body,"流派线索\\n水电：湿润＋电击＋拾取充能\\n腐蚀近战：强酸＋电锯＋治疗护盾\\n诱饵火场：声波聚怪＋地面火区\\n回收游击：移动蓄能＋拾取波＋急救",Rect2(12,y+15,945,175),20,GOLD)
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
	_button(modal,"返回",Rect2(650,745,300,43),func(): show_camp() if origin=="camp" else _resume(),true,"CloseBuild")

''' +s[b:]
p.write_text(s,encoding='utf-8')
