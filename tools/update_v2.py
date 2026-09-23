from pathlib import Path
import json
ROOT = Path(__file__).resolve().parents[1]
def read(name): return (ROOT/name).read_text(encoding='utf-8-sig')
def write(name, s): (ROOT/name).write_text(s, encoding='utf-8')
def table(name): return json.loads(read('data/'+name+'.json'))
def save(name, data): write('data/'+name+'.json', json.dumps(data,ensure_ascii=False,indent=2)+'\n')

new = [
('electrician','电工','chain','97cdd5','电弧逐跳衰减，优先湿润目标。','每档电弧多跳 1 个目标',28),
('chemical_worker','化工','acid','b5c56c','扇形强酸持续腐蚀，削弱正面护甲。','每档酸区持续时间 +0.5秒',26),
('firefighter','消防员','chainsaw','db9a62','前方电锯持续切割，过热后停机。','每档连续工作时间 +0.4秒',28),
('hunter','猎人','crossbow','c5b98b','蓄力重弩贯穿直线，优先精英与首领。','每档重弩多穿透 1 个目标',28),
('sound_tech','音响师','decoy','bb9fbf','声源聚拢普通感染者，结束时释放震荡。','每档诱饵吸引范围 +15%',24),
('sanitation','环卫工','water','8fbdc5','高压水流推开并湿润目标，配合电击。','每档水流推力 +15%',24)]
s = table('survivors')[:6]
for i,(id,name,weapon,color,desc,syn,cost) in enumerate(new):
    s.append(dict(id=id,name=name,sprite=16+i,weapon=weapon,color=color,description=desc,synergy=syn+'（2 / 4 / 6人）',effect=id,step=1,cost=cost))
s[1]['description']='长钉贯穿一条直线；同业提高全队攻速。'
s[2]['description']='扇形霰弹击退敌人，距离越近伤害越高。'
s[4]['description']='定向菜刀横扫，连续命中触发追加一刀。'
s[5]['description']='抛物线砖块越过低掩体，落地冲击并打断。'
save('survivors',s)

weapons=table('weapons')[:9]
extra=[('chain','接地电弧','chain',24,1.25,320,0,0,'97cdd5'),('acid','腐蚀喷罐','acid',19,2.6,250,0,80,'b5c56c'),('chainsaw','救援电锯','chainsaw',12,.16,115,0,0,'db9a62'),('crossbow','蓄力重弩','crossbow',65,2.4,640,1000,0,'c5b98b'),('decoy','回声诱饵','decoy',28,6.5,380,380,125,'bb9fbf'),('water','高压水炮','water',4,.18,230,0,0,'8fbdc5')]
for id,name,mode,dmg,cd,reach,speed,splash,color in extra:
    weapons.append(dict(id=id,name=name,mode=mode,damage=dmg,cooldown=cd,range=reach,speed=speed,splash=splash,color=color))
config={
'book':('boomerang','nearest',4,0,0,'三级：回程可再次命中；五级：额外一本侧旋书'),
'wrench':('heavy','nearest',0,0,0,'三级：重击范围扩大；五级：击退与伤害提高'),
'baton':('combo','nearest',0,0,0,'三级：每三击追加一段；五级：眩晕延长'),
'molotov':('lob_fire','cluster',0,3,0,'三级：火区持续更久；五级：落点扩大'),
'nailgun':('pierce','nearest',2,0,0,'三级：贯穿3人；五级：贯穿5人'),
'shotgun':('spread','nearest',1,0,0,'三级：多两颗霰弹；五级：散射更宽、击退更强'),
'pistol':('precision','nearest',1,0,0,'三级：双重点射；五级：点射间隔缩短'),
'cleaver':('sweep','nearest',0,0,0,'三级：两次命中追刀；五级：追刀范围扩大'),
'brick':('lob_impact','cluster',0,0,0,'三级：冲击范围扩大；五级：硬直延长'),
'chain':('chain','wet',0,0,3,'三级：多跳一次；五级：再多跳两次'),
'acid':('fan_zone','cluster',0,3.5,0,'三级：酸区更宽；五级：留下更长腐蚀带'),
'chainsaw':('contact','nearest',0,2.4,0,'三级：工作时间+0.8秒；五级：再+1.2秒'),
'crossbow':('charge_pierce','elite',3,0,0,'三级：贯穿5人；五级：贯穿8人'),
'decoy':('lob_lure','cluster',0,4.0,0,'三级：诱饵持续更久；五级：更大震荡脉冲'),
'water':('stream','nearest',0,0,0,'三级：扇形更宽；五级：喷射距离更远')}
for w in weapons:
    shape,target,penetration,duration,jumps,preview=config[w['id']]
    w.update(shape=shape,targeting=target,penetration=penetration,duration=duration,jumps=jumps,preview=preview,lob=w['id'] in ['molotov','brick','decoy'],status={'chain':'shock','acid':'corrode','water':'wet','baton':'stun','brick':'stun'}.get(w['id'],''))
save('weapons',weapons)

maps=table('maps')
for m in maps:
    m['affinity']={'school':['electrician','nurse','sound_tech','chemist'],'street':['firefighter','sanitation','repairer','courier'],'mall':['chemical_worker','hunter','officer','chef']}[m['id']]
    m['tactical']=[]
    def add(id,kind,rect,hp=0,**kw): m['tactical'].append(dict(id=id,kind=kind,rect=rect,hp=hp,**kw))
    if m['id']=='school':
        for i,(x,y) in enumerate([(240,210),(1530,210),(240,1120),(1530,1120)]):
            add('door'+str(i),'door',[x+608,y+170,22,140],240,closed=False)
        add('alarm0','alarm',[1120,560,44,44],enabled=True)
        add('alarm1','alarm',[1250,1190,44,44],enabled=True)
        m['tag']='教室木门 · 走廊警铃 · 门口火区'
    elif m['id']=='street':
        for i,(x,y) in enumerate([(920,610),(1370,690),(970,1180),(1480,1130)]):
            add('car'+str(i),'car',[x,y,110,170],180)
        for i,(x,y) in enumerate([(1090,580),(1250,1100),(730,930)]):
            add('water'+str(i),'puddle',[x,y,220,140])
        m['tag']='油漏车辆 · 积水导电 · 爆破开路'
    else:
        for i,(x,y) in enumerate([(200,200),(1580,200),(200,1130),(1580,1130)]):
            add('shutter'+str(i),'shutter',[x+602,y+130,18,200],closed=False)
        add('speaker0','broadcast',[1020,770,50,50])
        add('speaker1','broadcast',[1390,1040,50,50])
        m['tag']='限时卷帘门 · 定点广播 · 绕后破甲'
save('maps',maps)

p=read('scripts/content.gd').replace('\tprop_textures = _atlas', '''\tvar added = preload("res://assets/characters-v2.png")
\tfor index in range(6):
\t\tvar tile = AtlasTexture.new()
\t\ttile.atlas = added
\t\ttile.region = Rect2(Vector2(index%3,index/3)*added.get_size()/Vector2(3,2),added.get_size()/Vector2(3,2))
\t\ttile.filter_clip = true
\t\tcharacter_textures.append(tile)
\tprop_textures = _atlas''')
write('scripts/content.gd',p)
p=read('scripts/run_state.gd').replace('var checkpoint_position', 'var map_state = {}\nvar checkpoint_position').replace('stats[data.effect] += value','stats[data.effect] = stats.get(data.effect,0.0) + value').replace('"version":1,"class_id"','"version":2,"map_state":map_state.duplicate(true),"class_id"').replace('data.get("version",0) != 1','data.get("version",0) not in [1,2]').replace('\tcheckpoint_position = data.get','\tmap_state = data.get("map_state",{}).duplicate(true)\n\tcheckpoint_position = data.get')
p=p.replace('\tresult.rank = rank', '''\tresult.rank = rank
\tvar bonus = int(rank >= 3) + int(rank >= 5)
\tresult.penetration += bonus * (2 if id == "crossbow" else 1)
\tif rank >= 5 and id in ["nailgun","crossbow"]: result.penetration += 1
\tresult.jumps += bonus + int(rank >= 5) + synergy_tier("electrician")
\tif id == "acid": result.duration += synergy_tier("chemical_worker")*0.5
\tif id == "chainsaw": result.duration += bonus*0.8 + int(rank >= 5)*0.4 + synergy_tier("firefighter")*0.4
\tif id == "crossbow": result.penetration += synergy_tier("hunter")
\tif id in ["molotov","decoy"]: result.duration += bonus
\tif id in ["acid","brick","molotov","decoy"]: result.splash *= 1.0+bonus*0.2
\tif id == "water" and rank >= 5: result.range *= 1.25''')
p=p.replace('\tfor key in ["wave","supplies","health"', '\tif not data.get("map_state",{}) is Dictionary: return false\n\tfor key in ["wave","supplies","health"',1)
write('scripts/run_state.gd',p)
p=read('scripts/progress.gd').replace('\tfor key in ["version","runs"', '''\tfor id in ["electrician","chemical_worker","firefighter","hunter","sound_tech","sanitation"]:
\t\tif id not in meta.unlocked: meta.unlocked.append(id)
\tfor key in ["version","runs"''')
p=p.replace('func save_run(run) -> bool:\n\treturn', '''func save_run(run) -> bool:
\tvar old = _read("run.json")
\tif old.get("version",0) == 1:
\t\tvar backup = directory.path_join("run.pre-v2.json")
\t\tif not FileAccess.file_exists(backup):
\t\t\tvar file = FileAccess.open(backup,FileAccess.WRITE)
\t\t\tif file == null: return false
\t\t\tfile.store_string(JSON.stringify(old,"\\t"))
\t\t\tfile.close()
\treturn''')
write('scripts/progress.gd',p)
p=read('scripts/shop.gd').replace('\t\tvar id = pool[run.rng.randi_range(0, pool.size()-1)]', '''\t\tvar candidates = pool.duplicate()
\t\tvar label = "随机人选"
\t\tif index == 0:
\t\t\tlabel = "已有职业补员"
\t\t\tif not run.roster.is_empty(): candidates = run.counts.keys()
\t\t\tif run.shop_serial == 1:
\t\t\t\tcandidates = ["electrician","chemical_worker","firefighter","hunter","sound_tech","sanitation"]
\t\t\t\tlabel = "新面孔 · 首次保证"
\t\tif index == 1:
\t\t\tlabel = "地图倾向人选"
\t\t\tcandidates = content.maps[run.map_id].affinity.filter(func(id): return id in unlocked)
\t\tif candidates.is_empty(): candidates = pool
\t\tvar id = candidates[run.rng.randi_range(0, candidates.size()-1)]''').replace('"kind":"person","id":id','"kind":"person","label":label,"id":id')
write('scripts/shop.gd',p)
