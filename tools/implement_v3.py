from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
def write(name,data): (R/name).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
rows=[
('book','paper_hit','回程点名','回程再次命中','侧旋书页','额外投出侧旋书',['physical']),
('wrench','wrench','震地重击','重击追加前方冲击波','防守反击','重击命中获得短暂护盾',['melee']),
('baton','baton','震慑节奏','每第三击发出眩晕脉冲','前后照应','攻击追加身后连击',['melee']),
('molotov','fire_burst','火线封锁','落点形成三段火区','交叉投掷','每第二次投掷追加侧投火瓶',['fire']),
('nailgun','nail_hit','折射长钉','首个命中后折射另一目标','碎钉散射','贯穿耗尽时散出三枚短钉',['physical']),
('shotgun','shotgun_hit','独头贯穿','五颗散弹改为高伤贯穿独头弹','背后开火','开火时向身后补射三颗霰弹',['physical']),
('pistol','pistol_hit','双重点射','每轮发射两次精准点射','急救弹匣','每四轮射击落下急救包',['physical','healing']),
('cleaver','cleaver','连续追刀','连续两次命中后追加一刀','回身斩','斩杀后追加反向横扫',['melee']),
('brick','brick_hit','跳弹砖块','落地后弹向另一名敌人','冲击回收','落地冲击吸附附近掉落',['physical','pickup']),
('chain','lightning','分叉电路','第二跳分出一条支链','末端放电','最后一跳造成范围放电',['electric']),
('acid','acid_spray','余压飞溅','酸区消散时向外飞溅','腐蚀通道','喷洒路径留下连续酸带',['acid']),
('chainsaw','chainsaw','蒸汽排压','过热时释放蒸汽冲击','斩杀散热','斩杀降低热量，每秒一次',['melee']),
('crossbow','bolt_hit','破甲分矢','命中精英后分出两支短弩','三箭连发','蓄力后纵向连续射出三箭',['physical']),
('decoy','sonic','双重回声','诱饵结束时发出两次震荡','持续共鸣','诱饵存续时周期发出音波',['sonic']),
('water','water_jet','交叉水束','喷射分成两束交叉水流','蓄压水浪','连续喷射两秒推出宽浪',['wet'])]
mods=[]
for weapon,clip,n1,t1,n2,t2,tags in rows:
 for n,(name,text) in enumerate([(n1,t1),(n2,t2)],1):mods.append(dict(id=f'{weapon}_{n}',weapon=weapon,name=name,text=text,tags=tags,clip=clip))
for id,name,text,tags,clip in [
('pickup_stride','轻装疾行','拾取物资后移动加快25%，持续2秒',['pickup','movement'],'dust'),
('heal_magnet','急救回收','使用急救包时释放拾取波',['healing','pickup'],'water_loop'),
('move_charge','行进蓄力','移动4秒后强化下一次队长攻击',['movement'],'wrench'),
('rescue_shield','护送约定','完成救援获得8点护盾，持续3秒',['rescue'],'armor_hit'),
('auto_aid','紧急注射','生命低于30%时回复20生命，冷却30秒',['healing'],'water_loop'),
('pickup_echo','物尽其用','每拾取10物资，下一次队长攻击追加一次',['pickup'],'sonic')]:mods.append(dict(id=id,weapon='',name=name,text=text,tags=tags,clip=clip))
write('data/mods.json',mods)
equipment=[]
for id,name,text,requires,tags,clip in [
('battery','回收电池','每拾取8物资，向附近目标释放电弧',[],['pickup','electric'],'lightning'),
('coil','并联线圈','电击湿润目标时追加一次导电',['electric','wet'],['electric','wet'],'lightning'),
('coolant','冷却循环罐','水流命中使附近电锯散热',['wet','chainsaw'],['wet','melee'],'water_loop'),
('filter','腐蚀滤网','近战命中腐蚀目标获得护盾',['melee','acid'],['acid','melee'],'armor_hit'),
('valve','压力阀','电锯过热喷出强酸',['chainsaw'],['acid','melee'],'acid_spray'),
('thermos','急救保温箱','溢出治疗的50%转化为护盾',['healing'],['healing'],'water_loop'),
('oil','废油滤芯','燃烧中的敌人死亡后留下余火',['fire'],['fire'],'fire_burst'),
('resonator','共振扩音器','声波使目标受到的火焰与酸伤提高30%，持续3秒',['sonic'],['sonic','fire','acid'],'sonic'),
('fuse','延时引信','砖块命中燃烧目标产生爆燃',['brick','fire'],['fire','physical'],'explosion'),
('magnet','磁吸背带','每拾取10物资释放一次拾取波',[],['pickup'],'paper_hit'),
('flywheel','动能飞轮','移动4秒后下次队长攻击附加冲击',[],['movement','physical'],'wrench'),
('medbox','应急分装盒','使用急救包后下次攻击发出击退脉冲',['healing'],['healing','physical'],'sonic')]:equipment.append(dict(id=id,name=name,text=text,requires=requires,tags=tags,clip=clip))
write('data/equipment.json',equipment)
hp=[1,1.3,1.8,2.4,3.2,4.2,5.4,6.8,8.3,9.5];dmg=[1,1.05,1.1,1.2,1.3,1.4,1.5,1.6,1.7,1.8];rates=[.9,1.4,2,2.5,3.1,3.7,4.3,4.9,5.5,5];rewards=[18,20,22,24,26,28,30,32,34,50]
write('data/waves.json',[dict(wave=i+1,duration=60,rate=rates[i],hp=hp[i],damage=dmg[i],speed=1+min(i,8)*.02,reward=rewards[i],elite_times=([24] if i==2 else [20,40] if i in [4,6,8] else []),boss=i==9,weights=([1,0,0] if i==0 else [.75,.25,0] if i==1 else [.65,.25,.10] if i<4 else [.55,.28,.17] if i<6 else [.45,.32,.23] if i<9 else [.5,.3,.2])) for i in range(10)])
p=R/'scripts/content.gd';s=p.read_text(encoding='utf-8').replace('var waves = []','var waves = []\nvar mods = {}\nvar equipment = {}').replace('["classes", "survivors", "weapons", "enemies", "maps"]','["classes", "survivors", "weapons", "enemies", "maps", "mods", "equipment"]');p.write_text(s,encoding='utf-8')
p=R/'scripts/run_state.gd';s=p.read_text(encoding='utf-8');s=s[:s.index('const PERKS =')]+s[s.index('func _init(book):'):]
s=s.replace('var content','var difficulty = "challenge"\nvar mods = []\nvar equipment = []\nvar rerolls = 2\nvar equipment_choices = []\nvar equipment_return = "combat"\nvar first_core = false\nvar content',1)
s=s.replace('func start(id: String, seed_value: int = 0):','func start(id: String, seed_value: int = 0, difficulty_id: String = "challenge"):\n\tdifficulty = difficulty_id')
s=s.replace('"max_health":100.0 * content.classes[class_id].health_mult + 15.0 * perks.vitality','"max_health":100.0 * content.classes[class_id].health_mult').replace('"damage":1.0 + perks.damage * 0.12','"damage":1.0').replace('"attack_speed":1.0 + perks.speed * 0.1','"attack_speed":1.0').replace('"range":1.0 + perks.range * 0.1','"range":1.0').replace('"pickup":88.0 * (1.0 + perks.pickup * 0.25)','"pickup":110.0').replace('"move_speed":185.0 * (1.0 + mini(perks.stride, 8) * 0.07)','"move_speed":185.0')
a=s.index('func xp_target()');b=s.index('func weapon(',a)
s=s[:a]+'''func has_mod(id: String) -> bool:
	return id in mods

func tags() -> Array:
	var result = ["pickup","movement","rescue"]
	for id in weapon_levels:
		if id not in result: result.append(id)
		for item in content.mods.values():
			if item.weapon == id:
				for tag in item.tags:
					if tag == "healing" and id == "pistol" and not (counts.get("nurse",0)>0 or has_mod("pistol_2")): continue
					if tag not in result: result.append(tag)
	if "valve" in equipment and "acid" not in result: result.append("acid")
	if "battery" in equipment and "electric" not in result: result.append("electric")
	return result

func xp_target() -> float:
	return 30.0+(level-1)*23.0

func add_xp(amount: float):
	if level >= 17: return
	xp += amount*float(content.classes[class_id].xp_mult)
	while level < 17 and xp >= xp_target():
		xp -= xp_target()
		level += 1
		pending_levels += 1
	if level >= 17: xp = 0

func make_choices():
	if not choices.is_empty(): return
	var pool = []
	for id in content.mods:
		var item = content.mods[id]
		if id not in mods and (item.weapon.is_empty() or weapon_levels.has(item.weapon)): pool.append(id)
	var selected_tags = []
	for id in equipment:
		for tag in content.equipment[id].tags:
			if tag not in selected_tags: selected_tags.append(tag)
	# One synergy, one utility, one broader option; all are unique and usable.
	for slot in range(3):
		var preferred = pool.filter(func(id): return content.mods[id].tags.any(func(t): return t in selected_tags)) if slot == 0 else pool.filter(func(id): return content.mods[id].weapon.is_empty()) if slot == 1 else pool
		if preferred.is_empty(): preferred = pool
		if preferred.is_empty():
			choices.append(["supply","aid","refresh"][slot])
		else:
			var id = preferred[rng.randi_range(0,preferred.size()-1)]
			choices.append(id)
			pool.erase(id)

func refresh_choices() -> bool:
	if mode != "upgrade" or rerolls <= 0 or pending_levels <= 0: return false
	rerolls -= 1
	choices.clear()
	make_choices()
	return true

func choose_perk(id: String) -> bool:
	if pending_levels <= 0 or id not in choices: return false
	if content.mods.has(id):
		if id in mods: return false
		mods.append(id)
	elif id == "aid": health = minf(stats.max_health,health+25)
	elif id == "supply": supplies += 20
	elif id == "refresh": rerolls += 1
	else: return false
	pending_levels -= 1
	choices.clear()
	return true

func make_equipment_choices(bias: String = ""):
	if not equipment_choices.is_empty(): return
	var available = tags()
	var pool = content.equipment.keys().filter(func(id): return id not in equipment and content.equipment[id].requires.all(func(t): return t in available))
	for slot in range(mini(3,pool.size())):
		var preferred = pool.filter(func(id): return bias in content.equipment[id].tags) if slot == 0 else pool
		if preferred.is_empty(): preferred = pool
		var id = preferred[rng.randi_range(0,preferred.size()-1)]
		equipment_choices.append(id)
		pool.erase(id)

func choose_equipment(id: String, replacement: int = -1) -> bool:
	if id not in equipment_choices or id in equipment: return false
	if equipment.size() >= 4:
		if replacement < 0 or replacement >= 4: return false
		equipment[replacement] = id
	else: equipment.append(id)
	equipment_choices.clear()
	first_core = true
	return true

func wave_data() -> Dictionary:
	var data = content.wave(wave).duplicate(true)
	if difficulty == "easy":
		data.hp *= 0.7
		data.damage *= 0.7
		data.rate *= 0.75
	return data

''' +s[b:]
a=s.index('\tresult.damage *=');b=s.index('\n\treturn result',a)
s=s[:a]+'''	result.damage *= (1.0+(rank-1)*0.12)*stats.damage
	result.cooldown /= stats.attack_speed
	result.range *= stats.range
	result.splash *= stats.range
	result.rank = rank
	result.jumps += synergy_tier("electrician")
	if id == "molotov": result.splash *= stats.fire_radius
	if id == "acid": result.duration += synergy_tier("chemical_worker")*0.5
	if id == "chainsaw": result.duration += synergy_tier("firefighter")*0.4
	if id == "crossbow": result.penetration += synergy_tier("hunter")
''' +s[b:]
s=s.replace('"version":2,','"version":3,"difficulty":difficulty,"mods":mods.duplicate(),"equipment":equipment.duplicate(),"rerolls":rerolls,"choices":choices.duplicate(),"pending_levels":pending_levels,"equipment_choices":equipment_choices.duplicate(),"equipment_return":equipment_return,"first_core":first_core,')
s=s.replace('not in [1,2]','!= 3')
s=s.replace('"class_id","map_id","wave","supplies","health","level","xp","kills","rescued","spent","roster","weapon_levels","perks","offers","shop_serial","refreshes","elapsed_total","run_id"]','"class_id","map_id","wave","supplies","health","level","xp","kills","rescued","spent","roster","weapon_levels","perks","offers","shop_serial","refreshes","elapsed_total","run_id","difficulty","mods","equipment","rerolls","choices","pending_levels","equipment_choices","equipment_return","first_core"]')
s=s.replace('\tpending_levels = 0\n\tchoices.clear()','')
s=s.replace('\tfor key in PERKS:','\tfor key in perks:')
s=s.replace('\tif not data.get("map_state",{}) is Dictionary: return false','''	if not data.get("map_state",{}) is Dictionary: return false
	if data.get("difficulty","") not in ["easy","challenge"]: return false
	for key in ["mods","equipment","choices","equipment_choices"]:
		if not data.get(key) is Array: return false
		var unique = {}
		for id in data[key]:
			if not id is String or unique.has(id): return false
			unique[id] = true
			if key in ["mods","choices"] and not content.mods.has(id) and (key == "mods" or id not in ["aid","supply","refresh"]): return false
			if key in ["equipment","equipment_choices"] and not content.equipment.has(id): return false
	if data.equipment.size()>4 or data.mods.size()>16 or int(data.get("rerolls",-1))<0: return false''')
p.write_text(s,encoding='utf-8')
p=R/'scripts/shop.gd';s=p.read_text(encoding='utf-8').replace('run.supplies < 16','run.supplies < 20').replace('run.supplies -= 16','run.supplies -= 20').replace('run.spent += 16','run.spent += 20').replace('run.health + 40','run.health + (40 if run.difficulty == "easy" else 25)');p.write_text(s,encoding='utf-8')
