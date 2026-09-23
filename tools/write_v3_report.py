"""Produce a factual report from the final test files; never invent missing measurements."""
from pathlib import Path
import hashlib,json,statistics
from datetime import date
ROOT=Path(__file__).resolve().parents[1]
def read(name): return json.loads((ROOT/'tests'/name).read_text(encoding='utf-8-sig'))
classes={'teacher':'学校','mechanic':'街道','guard':'商城'}
runs=[read(f'campaign-v3-{c}-{d}-{s}-{p}.json') for s in (4471,8197,13003) for d,p in [('challenge','build'),('challenge','random'),('easy','build')] for c in classes]
(ROOT/'tests/matrix-v3-result.json').write_text(json.dumps(runs,ensure_ascii=False,indent=2),encoding='utf-8')
performance=read('performance-v3-result.json')
release=read('release-v3/release-result.json')
assert len(runs)==27 and len(performance)==6
lines=['# 第三版验收记录','',f'整理日期：{date.today().isoformat()}。Windows 本机，Godot 4.7.2 stable，OpenGL Compatibility，NVIDIA GeForce RTX 3060 Laptop GPU。','',
'## 交付范围','',
'完成36项一次性改装、12件核心装备、四槽替换、每波二选一搜刮、早期装备保底、两档难度、固定波次编组、版本3存档与中文构筑图鉴。透明序列帧沿用第二版图集，新机制通过不同轨迹、次数与落点呈现。','',
'## 规则、组合与窗口检查','',
'| 检查 | 结果 | 原始记录 |','| --- | --- | --- |']
for label,file in [('构筑规则与1000组奖励种子','v3-result.json'),('30项改装独立前后对比及安全规则','mechanisms-v3-result.json'),('四个方向与两种混搭','builds-v3-result.json'),('墙边、门框、地图与战斗回归','safety-v3-result.json'),('序列帧、声音、镜头反馈','feedback-result.json')]:
    item=read(file)
    assert not item['failures'],(file,item['failures'])
    lines.append(f"| {label} | {item['checks']}项通过 | tests/{file} |")
visual=read('visual-v3-result.json'); tactics=read('tactics-result.json')
assert not visual['issues'] and not tactics['failures'] and not release['issues']
lines += [f"| 窗口与中文界面 | 问题列表为空，保存{len(visual['screenshots'])}张画面 | tests/visual-v3-result.json |",
'| 场景机关对照 | 三地图各有开/关对照，共6组 | tests/tactics-result.json |',
'| 独立发布程序 | 12类输入/流程检查通过 | tests/release-v3/release-result.json |','',
'奖励种子检查覆盖候选不重复、武器归属、装备依赖、读档与刷新一致性；额外消耗战斗随机数不会改变刷新结果。单项改装在固定靶场逐项比较获得前后，记录伤害、弹体、区域、热量、护盾或掉落差异。通用改装和12件装备检查实际触发、全队冷却、合并物资计数、最多四槽与追加攻击不递归。',
'', '混搭固定靶场包括水电＋腐蚀近战、火场＋回收游击。靶场目标不移动，按固定节奏输入物资和急救；这些结果只证明机制能组合运行，不用于说明难度。',
'', '墙边覆盖15种武器、实体墙/低掩体、门框与拐角、整段弹道首个交点、逐跳电弧遮挡、同源持续伤害与首领控制限制。地图对照在固定20名敌人、关闭友军攻击的场景进行：学校关门延缓接触，街道车辆爆炸清除20名目标，商城广播减少近身敌人停留。',
'', '成品在独立发布目录运行，通过窗口鼠标/按键输入检查选难度、招募、移动、自动攻击、暂停、升级刷新、改装选择、E搜刮、四槽替换、构筑读档、失败与重开。测得向右移动约 %.1f 像素，测试目标生命由1000下降到 %.1f。开发与发布检查均使用隔离存档。' % (release['movement_pixels'],release['automatic_attack_hp']),
'','## 27次完整流程模拟','',
'固定种子4471、8197、13003。三地图×两难度×三个种子为18次有目的构筑；另做9次同种子挑战随机选择对照。每次调用实际战斗逻辑，以30Hz推进，未开启无敌或增加伤害。策略优先救援、搜刮、收集，按周围敌人与危险区选择移动方向。失败照实记录。',
'', '有目的策略优先招募相关职业、选择相应标签的改装和装备、强化常用武器并预留部分治疗资金。随机策略随机选牌和装备，照常招募，主要强化队长武器。两者使用同一套走位算法；对照同时改变招募、选牌与强化支出，差异不能全部归因于装备。',
'','| 地图 | 难度/策略 | 通关 | 平均承伤 | 通关平均战斗时长 | 通关平均首领存活 |','| --- | --- | ---: | ---: | ---: | ---: |']
for c in classes:
    for d,p in [('easy','build'),('challenge','build'),('challenge','random')]:
        selected=[r for r in runs if r['class']==c and r['difficulty']==d and r['strategy']==p]
        wins=[r for r in selected if r['completed']]
        total=statistics.mean(sum(w['seconds'] for w in r['waves']) for r in wins)/60 if wins else 0
        boss=statistics.mean(r['waves'][-1]['boss_seconds'] for r in wins) if wins else 0
        damage=statistics.mean(r['waves'][-1]['damage_taken'] for r in selected)
        label=('轻松' if d=='easy' else '挑战')+('/构筑' if p=='build' else '/随机')
        lines.append(f'| {classes[c]} | {label} | {len(wins)}/3 | {damage:.1f} | {total:.1f}分钟 | {boss:.1f}秒 |')
lines+=['','逐次数据如下。承伤为护盾吸收后的累计生命伤害；清场耗时为每波超过60秒部分的累计值，不含整备和选牌时间。','',
'| 地图/难度/策略/种子 | 结果 | 承伤 | 最低生命 | 首领存活 | 清场累计 | 人数 | 改装数 | 支出/剩余 |','| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |']
for r in runs:
    w=r['waves'][-1]
    result='通关' if r['completed'] else f"第{w['wave']}波阵亡" if w['health']<=0 else f"第{w['wave']}波超时"
    low=min(x['minimum_hp'] for x in r['waves'])
    cleanup=sum(max(0,x['seconds']-60) for x in r['waves'])
    label=f"{classes[r['class']]}/{'轻松' if r['difficulty']=='easy' else '挑战'}/{'构筑' if r['strategy']=='build' else '随机'}/{r['seed']}"
    lines.append(f"| {label} | {result} | {w['damage_taken']:.1f} | {low:.1f} | {w['boss_seconds']:.1f}秒 | {cleanup:.1f}秒 | {w['team']} | {len(r['mods'])} | {r['supplies_spent']}/{w['supplies']} |")
normal=[r for r in runs if r['strategy']=='build']
reserves=[]
for r in normal:
    for before,after in zip(r['waves'],r['waves'][1:]): reserves.append(before['supplies']-(after['spent']-before['spent']))
lines+=['',f"正常救援招募策略后期人数范围为{min(r['waves'][-1]['team'] for r in normal)}—{max(r['waves'][-1]['team'] for r in normal)}人，含队长；实际学习{min(len(r['mods']) for r in normal)}—{max(len(r['mods']) for r in normal)}项改装。整备购买后剩余物资中位数约{statistics.median(reserves):.0f}。策略主动限制每波招募数量，因此这里只证明预算支持目标人数，不证明所有玩法的人数自然收敛。最后一波奖励无法再消费，结算剩余物资不等于整备资金闲置。",'']
lines+=['## 1080p性能','',
'1920×1080，关闭垂直同步，30名同伴加1名队长，混合16项改装与4件触发装备。每个场景预热150帧、采样600帧，200与220名敌人各跑三地图。压力测试开启队长无敌并把敌人生命设高，以保持人口；定期注入8物资以覆盖电池触发。该测试与完整生存模拟分开，测量时未并行运行其它游戏测试。','',
'| 地图 | 敌人 | 平均FPS | P95帧耗时 | P99帧耗时 |','| --- | ---: | ---: | ---: | ---: |']
for p in performance:
    lines.append(f"| {dict(school='学校',street='街道',mall='商城')[p['map']]} | {p['enemies']} | {p['average_fps']} | {p['frame_ms_p95']}ms | {p['frame_ms_p99']}ms |")
lines+=['','这是一台机器上的短时渲染测试，不代表所有配置，也没有把平均帧率当作稳定最低帧率。完整采样与分项开销见 tests/performance-v3-result.json。','',
'## 旧档与已知限制','',
'实际旧存档清理记录见 tests/save-reset-v3-result.json。仅移除了明确的 run.json、progress.json 及各自 .bak，共4个文件，已写入版本3标记；没有递归删除目录。隔离测试还覆盖临时文件、旧备份、无关文件保留、二次启动不清新档与标记丢失后的保护。',
'', '1. 挑战仍为首轮平衡：学校路线对这套精确避险策略较宽松，人数增长对强度的贡献仍很大。相对击杀速度与失败样本说明选择有影响，但尚不足以证明所有流派同样强、随机招人一定失败。',
'2. 真人连续试玩尚未完成。已完成真实窗口渲染与脚本输入检查，不能称为真人体验验收；升级选择是否有吸引力、长局是否疲劳、机关是否好用与主观打击感需继续试玩。',
'3. 战斗中退出恢复整备检查点，不保留当前波内新获得的成长。当前波重新打完后才归档。',
'4. 新技能复用已有28段透明序列帧，没有新增36套专属动画；人物仍使用分层动作，音效为本地合成。',
'5. 引擎启动有系统证书存储读取警告，离线游戏流程与成品验证通过。快速无窗口音频测试退出时出现2个音频对象释放警告，窗口成品验证未复现。','',
'## 复现','',
'使用 Godot 4.7.2，先导入项目。规则脚本为 tests/v3.gd、tests/mechanisms_v3.gd、tests/builds_v3.gd、tests/safety_v3.gd、tests/feedback.gd、tests/tactics_compare.gd。完整矩阵由 tools/run_v3_matrix.py 调用 tests/campaign_v3.gd；窗口检查用 tests/visual_v3.gd，性能用 tests/performance_v3.gd。所有命令从项目根目录运行。','',
'例如：`Godot --headless --path . --script tests/v3.gd`。成品使用 `GreycitySurvivors.exe -- --verify-release <隔离输出绝对路径>` 检查实际导出资源和输入流程；不需要也不支持给导出程序传入 `--path`。','']
(ROOT/'docs/VERIFICATION.md').write_text('\n'.join(lines),encoding='utf-8')
manifest={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for folder in ('scripts','data') for p in sorted((ROOT/folder).iterdir()) if p.suffix in ('.gd','.json')}
(ROOT/'tests/runtime-v3-hashes.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print('Report generated from',len(runs),'campaigns and',len(performance),'rendered performance scenarios')
