from pathlib import Path
R=Path(__file__).resolve().parents[1]
p=R/'tests/v2.gd';s=p.read_text(encoding='utf-8')
s=s.replace('state.weapon("chain").jumps == 9,"level three and five add chain jumps"','state.weapon("chain").jumps == 6,"weapon ranks no longer grant automatic mechanics"')
s=s.replace('state.weapon_levels.book = 3','state.weapon_levels.book = 3\n\tstate.mods.append("book_1")')
a=s.index('\t# Version one fields');b=s.index('\tvar file = FileAccess.open(',a)
s=s[:a]+'''	state.mode="camp"
	shop.stock(state,storage.meta.unlocked)
	var legacy=state.snapshot()
	legacy.version=2
	var restored=State.new(book)
	check(not restored.restore(legacy),"v2 checkpoints rejected after deliberate reset")
	check(restored.restore(JSON.parse_string(JSON.stringify(state.snapshot())))),"v3 checkpoint restores")
''' +s[b:]
s=s.replace('tests/v2-result.json','tests/safety-v3-result.json').replace('V2 CHECKS','SAFETY V3')
(R/'tests/safety_v3.gd').write_text(s,encoding='utf-8')
p=R/'tests/visual.gd';s=p.read_text(encoding='utf-8')
s=s.replace('await click("Class_guard")','await click("DifficultyEasy")\n\tif game.selected_difficulty!="easy": issues.append("Difficulty selector failed")\n\tawait click("Class_guard")',1)
s=s.replace('game.run.supplies = 120','if game.run.difficulty!="easy": issues.append("Difficulty not applied")\n\tgame.run.supplies = 120',1)
s=s.replace('game.show_roster()\n\tawait capture("06-roster")','''game.run.equipment=["battery","magnet","flywheel","medbox"]
	game.run.equipment_choices=["coil","oil","thermos"]
	game.run.equipment_return="combat"
	game.show_equipment()
	await capture("14-equipment")
	await click("Equip_coil")
	await capture("15-replacement")
	await click("Replace_1")
	if game.run.equipment[1]!="coil" or game.run.equipment.size()!=4: issues.append("Equipment replacement failed")
	game.show_build()
	await capture("16-build")
	await click("CloseBuild")
	game.show_roster()
	await capture("06-roster")''')
s=s.replace('game.run.pending_levels = 1','game.run.pending_levels = 1\n\tgame.run.choices.clear()')
s=s.replace('tests/visual-result.json','tests/visual-v3-result.json')
(R/'tests/visual_v3.gd').write_text(s,encoding='utf-8')
import json
weapons=json.loads((R/'data/weapons.json').read_text(encoding='utf-8'))
mods=json.loads((R/'data/mods.json').read_text(encoding='utf-8'))
for w in weapons:w['preview']='可选改装：'+' / '.join(m['name'] for m in mods if m['weapon']==w['id'])
(R/'data/weapons.json').write_text(json.dumps(weapons,ensure_ascii=False,indent=2),encoding='utf-8')
