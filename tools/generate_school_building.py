"""Author the fixed, playable school-building layout used by the review sample."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
W, H = 7200, 2280
LINKS = ["west", "east", "west", "east"]


def horizontal_with_gaps(y, left, right, gaps):
    result, at = [], left
    for a, b in sorted(gaps):
        if a > at:
            result.append([at, y, a-at, 20])
        at = b
    if at < right:
        result.append([at, y, right-at, 20])
    return result


def make_floor(index):
    roof = index == 4
    d = dict(id=f"school-building-{index}", index=index, name="屋顶" if roof else f"{index+1}F",
             size=[W, H], rooms=[], walls=[], doors=[], covers=[], sites=[], encounters=[], routes=[],
             spawn=[3600, 2060] if index == 0 else [6680, 1100],
             note=["门厅与行政区；从南门进入，找到西楼梯。", "普通教学层；中段走廊被杂物堵住，可借双门教室绕行。",
                   "实验教学层；搜救消防员，穿过实验区前往西楼梯。", "高年级与机房层；启用无线电，再从东楼梯登顶。",
                   "屋顶设备区；从东楼梯到接应区，等待直升机悬停并撤离。"][index])
    d["walls"] += [[180,180,6840,20],[180,180,20,1720],[7000,180,20,1720]]
    d["walls"] += horizontal_with_gaps(1880,180,7020,[(3450,3750)] if index==0 else [])
    if roof:
        d["rooms"] = [dict(id="roof",name="屋顶接应区",rect=[200,200,6800,1680],label=[3600,360],note=d["note"])]
        # Stair enclosures remain vertically aligned with the teaching floors.
        for x, side in [(220,"west"),(6340,"east")]:
            d["walls"] += [[x,730,620,20],[x,1450,620,20],[x,730,20,720]]
            d["walls"] += [[x+600,730,20,230],[x+600,1260,20,210]]
        for x,y in [(1300,520),(2300,1380),(4050,500),(5350,1320)]:
            d["covers"].append(dict(rect=[x,y,370,150],sprite=3))
        d["sites"] += [dict(id="roof-exit",name="直升机接应点",pos=[3600,1080],kind="helicopter",hold=2.0,reward="呼叫接应后等待20秒，再次交互撤离")]
        d["encounters"] = [dict(pos=[4250,1050],name="屋顶防守遭遇预留",radius=180)]
        return d
    # End stairwells, toilets and service rooms repeat in the same structural bays.
    for x, side, title in [(200,"west","西"),(6340,"east","东")]:
        d["rooms"].append(dict(id=side,name=title+"楼梯间",rect=[x,200,640,1680],label=[x+320,490],note=f"{title}侧双跑楼梯；上下楼方向由两个独立交互点标明，整支队伍一同转场。"))
        d["walls"] += [[x,700,640,20],[x,1490,640,20]]
        d["walls"] += horizontal_with_gaps(1490,x,x+640,[(x+240,x+390)])
        # Remove the solid service-room divider, leaving its actual door opening.
        d["walls"].remove([x,1490,640,20])
        d["doors"].append(dict(id=f"{side}-wc",rect=[x+240,1490,150,20],closed=False))
        d["rooms"].append(dict(id=side+"-wc",name="卫生间" if side=="west" else "清洁间",rect=[x,1510,640,370],label=[x+310,1660],note="位于端部服务区；不会作为跨楼层捷径。"))
    north_names = [
        ["医务室","教务处","教师办公室","会议室","资料室","值班室","美术室","器材室"],
        ["201教室","202教室","203教室","204教室","205教室","206教室","207教室","208教室"],
        ["生物实验室","生物准备室","化学准备室","化学实验室","物理实验室","物理准备室","器材室","教师办公室"],
        ["401教室","广播室","402教室","403教室","阅览室","图书室","计算机室","机房"]
    ][index]
    north_gaps, south_gaps = [], []
    for side,y,depth in [("north",200,740),("south",1280,600)]:
        for col in range(8):
            x=860+680*col
            # Ground-floor central entrance hall spans two classroom bays.
            if index==0 and side=="south" and col in (3,4):
                if col==3:
                    d["rooms"].append(dict(id="entrance",name="主入口门厅",rect=[x,1280,1340,600],label=[3580,1620],note="南门通向室外集合点；抬头可见长走廊，东西两端都有楼梯。"))
                    south_gaps.append((3450,3750))
                    d["walls"].append([x-20,1280,20,600])
                continue
            name = north_names[col] if side=="north" else f"{index+1}{col+9:02d}教室"
            if index==0 and side=="south" and col==0: name="保卫室"
            if index==3 and side=="south" and col==7: name="活动室"
            room_id=f"{side}-{col}"
            d["rooms"].append(dict(id=room_id,name=name,rect=[x,y,660,depth],label=[x+330,y+135],note=f"{name}：临走廊设置前后两道门，窗在外墙一侧。课桌之间可通行；前后门可用于绕过走廊阻挡。"))
            d["walls"].append([x-20,y,20,depth])
            for n,offset in enumerate((70,490)):
                gap=(x+offset,x+offset+120)
                (north_gaps if side=="north" else south_gaps).append(gap)
                d["doors"].append(dict(id=f"{side}-{col}-{n}",rect=[gap[0],940 if side=="north" else 1260,120,20],closed=False))
            # Outer-wall blackboard and desk rows; actual collision follows each desk.
            for dx in (130,370):
                for dy in (260,440):
                    d["covers"].append(dict(rect=[x+dx,y+dy,135,55],sprite=0))
    for y,gaps in [(940,north_gaps),(1260,south_gaps)]:
        d["walls"] += horizontal_with_gaps(y,840,6340,gaps)
    d["walls"] += [[6300,200,20,740],[6300,1280,20,600]]
    d["rooms"].append(dict(id="corridor",name="教学楼长走廊",rect=[840,960,5500,300],label=[3560,1160],note=d["note"]+"东西楼梯端头和教室门编号用于辨认方向。"))
    if index==0:
        d["sites"] += [dict(id="gate",name="南门撤离",pos=[3600,2080],kind="ground_exit",hold=2.0,reward="离开教学楼"),
                       dict(id="medical-1",name="急救柜",pos=[1170,410],kind="medical",hold=2.0,reward="恢复35生命")]
    if index==1:
        d["covers"].append(dict(rect=[3230,960,100,300],sprite=1))
        d["sites"] += [dict(id="rescue-2",name="被困护士",pos=[5260,420],kind="rescue",survivor="nurse",hold=1.6,reward="护士加入队伍")]
    if index==2:
        d["sites"] += [dict(id="rescue-3",name="消防员",pos=[3220,420],kind="rescue",survivor="firefighter",hold=1.6,reward="消防员加入队伍"),
                       dict(id="cache-3",name="实验室物资",pos=[4570,420],kind="cache",hold=2.0,reward="等待8秒后领取30物资")]
    if index==3:
        d["covers"].append(dict(rect=[5260,960,110,300],sprite=1))
        d["sites"] += [dict(id="radio-4",name="应急无线电",pos=[1850,420],kind="radio",hold=2.0,reward="通知直升机接应"),
                       dict(id="cache-4",name="机房设备箱",pos=[5950,420],kind="cache",hold=2.0,reward="等待8秒后领取电池样件")]
    d["encounters"] = [dict(pos=[4400,1110],name="走廊遭遇预留",radius=110)]
    return d


def main():
    floors=[make_floor(i) for i in range(5)]
    for i,f in enumerate(floors):
        for side,x in [("west",520),("east",6680)]:
            for direction,dx in [(1,-110),(-1,110)]:
                target=i+direction
                enabled=0<=target<5 and LINKS[min(i,target)]==side
                f["sites"].append(dict(id=f"stairs-{side}-{'up' if direction==1 else 'down'}",name=("西" if side=="west" else "东")+("楼梯 ↑" if direction==1 else "楼梯 ↓"),
                    pos=[x+dx,1100],kind="stairs",hold=0.6,side=side,direction=direction,target=target,enabled=enabled,
                    reward=(f"前往 {'屋顶' if target==4 else str(target+1)+'F'}" if enabled else "此梯段受损 / 无相邻楼层")))
    result=dict(version=2,name="第七中学 · 教学楼撤离",size=[W,H],floor_count=4,links=LINKS,floors=floors,
                modes={"ascent":"南门进入 → 逐层上行 → 屋顶直升机撤离","descent":"屋顶降落 → 逐层下行 → 南门离开"})
    (ROOT/"data/school_building.json").write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding="utf-8")


if __name__=="__main__": main()
