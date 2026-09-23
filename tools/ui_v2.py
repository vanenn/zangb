exec((__import__('pathlib').Path(__file__).parent/'update_v2.py').read_text(encoding='utf-8').split('new = [')[0])
p=read('scripts/main.gd')
start=p.index('\thud.synergies = []');end=p.index('\t_button(ui,"暂停',start)
p=p[:start]+'''\thud.synergies = []
\thud.roster_kinds = run.counts.size()
\tvar strip = ScrollContainer.new()
\tstrip.position = Vector2(23,811)
\tstrip.size = Vector2(1320,86)
\tstrip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
\tui.add_child(strip)
\tvar row = HBoxContainer.new()
\tstrip.add_child(row)
\tfor id in run.counts:
\t\tvar cell = Control.new()
\t\tcell.custom_minimum_size = Vector2(221,72)
\t\trow.add_child(cell)
\t\t_texture(cell,content.character_textures[content.survivors[id].sprite],Rect2(0,0,57,63))
\t\tvar title = _label(cell,"",Rect2(58,0,158,33),19,PAPER)
\t\tvar desc = _label(cell,"",Rect2(58,34,158,29),15,MUTED)
\t\thud.synergies.append({"id":id,"title":title,"desc":desc})
\tif run.counts.is_empty():
\t\tvar cell = Control.new()
\t\tcell.custom_minimum_size = Vector2(900,65)
\t\trow.add_child(cell)
\t\t_label(cell,"暂时独行。回应呼救，找到第一位同行者。",Rect2(15,15,880,39),20,MUTED)
''' +p[end:]
p=p.replace('\thud.health.text =', '\tif hud.get("roster_kinds",-1) != run.counts.size():\n\t\t_build_hud()\n\t\treturn\n\thud.health.text =',1)
p=p.replace('按住 E 救援\\nTab','按住 E 救援 / 操作\\nTab')
start=p.index('\t\tvar short_descriptions =');end=p.index('\t\tvar button = _button(ui,"已同行"',start)
p=p[:start]+ '\t\t_label(ui,data.description,Rect2(x+20,458,268,60),16,MUTED)\n'+p[end:]
p=p.replace('"获救者  %02d" % (index+1)','offer.get("label","获救者  %02d" % (index+1))')
p=p.replace('Vector2(960,109)','Vector2(960,125)').replace('Vector2(222,95)','Vector2(304,116)').replace('Rect2(0,0,222,89)','Rect2(0,0,304,115)').replace('Rect2(12,2,200,38)','Rect2(12,0,280,30)').replace('Rect2(10,46,202,34)','Rect2(10,83,284,29)')
p=p.replace('\t\tvar maxed = int(run.weapon_levels[weapon_id]) >= 5','\t\t_label(cell,content.weapons[weapon_id].preview,Rect2(12,31,280,47),14,MUTED)\n\t\tvar maxed = int(run.weapon_levels[weapon_id]) >= 5')
# Scrollable full rosters, preserving the footer and header positions.
start=p.index('func show_roster(');end=p.index('func show_settings(',start)
part=p[start:end].replace('\tvar index = 0','\tvar body = _scroll_body(modal,Rect2(80,189,1440,600),Vector2(1420,1170))\n\tvar index = 0',1)
part=part.replace('var x = 80+(index%2)*740','var x = (index%2)*716').replace('var y = 199+(index/2)*195','var y = (index/2)*195')
for method in ['_panel','_texture','_label']: part=part.replace('\t\t'+method+'(modal,','\t\t'+method+'(body,')
p=p[:start]+part+p[end:]
start=p.index('func show_codex(');end=p.index('func _finish(',start)
part=p[start:end].replace('\tvar index = 0','\tvar body = _scroll_body(ui,Rect2(70,186,1460,512),Vector2(1440,980))\n\tvar index = 0',1)
part=part.replace('var x = 70+(index%3)*501','var x = (index%3)*482').replace('var y = 196+(index/3)*245','var y = (index/3)*245').replace('474,223','463,223')
for method in ['_panel','_texture','_label']: part=part.replace('\t\t'+method+'(ui,','\t\t'+method+'(body,')
part=part.replace('\t\t_label(body,"已归档" if unlocked else "尚无回音",Rect2(x+179,y+184,265,26),15,GREEN if unlocked else RED)','\t\t_label(body,content.weapons[data.weapon].preview if unlocked else "尚无回音",Rect2(x+179,y+182,270,39),13,GREEN if unlocked else RED)')
p=p[:start]+part+p[end:]
p+='''
func _scroll_body(parent: Node, rect: Rect2, extent: Vector2) -> Control:
\tvar scroll = ScrollContainer.new()
\tscroll.position = rect.position
\tscroll.size = rect.size
\tscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
\tparent.add_child(scroll)
\tvar body = Control.new()
\tbody.custom_minimum_size = extent
\tscroll.add_child(body)
\treturn body
'''
write('scripts/main.gd',p)
p=read('scripts/sound.gd')
p=p.replace('"victory","click"]','"victory","click","charge","hammer","baton","cleaver","saw","book","nail","shotgun","pistol","brick","bow","decoy","arc","acid","water","explosion"]')
p=p.replace('\t\t"melee": duration', '''\t\t"charge": duration = 0.45; frequency = 110
\t\t"hammer": duration = 0.27; frequency = 60
\t\t"baton": duration = 0.1; frequency = 240
\t\t"cleaver": duration = 0.18; frequency = 340
\t\t"saw": duration = 0.18; frequency = 87
\t\t"book": duration = 0.23; frequency = 410
\t\t"nail": duration = 0.08; frequency = 1100
\t\t"shotgun": duration = 0.3; frequency = 58
\t\t"pistol": duration = 0.12; frequency = 260
\t\t"brick": duration = 0.2; frequency = 72
\t\t"bow": duration = 0.25; frequency = 370
\t\t"decoy": duration = 0.4; frequency = 550
\t\t"arc": duration = 0.22; frequency = 930
\t\t"acid": duration = 0.4; frequency = 630
\t\t"water": duration = 0.2; frequency = 410
\t\t"explosion": duration = 0.7; frequency = 38
\t\t"melee": duration''')
p=p.replace('\t\telif id in ["rescue","victory"]:', '''\t\telif id in ["hammer","baton","cleaver","nail","shotgun","pistol","brick","explosion"]:
\t\t\tvalue = filtered_noise*1.4+sin(t*frequency*TAU)*0.4*exp(-phase*6)
\t\telif id == "saw": value = sin(t*frequency*TAU)*0.3+sin(t*frequency*3*TAU)*0.18+filtered_noise
\t\telif id == "arc": value = random.randf_range(-0.6,0.6)*sin(t*140*TAU)+sin(t*frequency*TAU)*0.18
\t\telif id in ["water","acid"]: value = filtered_noise*1.8
\t\telif id == "charge": value = sin(t*(frequency+phase*200)*TAU)*0.3*phase
\t\telif id in ["rescue","victory"]:''')
write('scripts/sound.gd',p)
