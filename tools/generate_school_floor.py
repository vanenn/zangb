"""Build the compact first-floor teaching-block layout used by the walkable preview."""
import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WIDTH, HEIGHT = 3360, 1760
ROOM_X = [180, 930, 1680, 2430]
ROOM_NAMES = [
    [("office", "行政办公室"), ("class-101", "101教室"), ("class-102", "102教室"), ("faculty", "教师办公室")],
    [("storage", "器材室"), ("class-103", "103教室"), ("class-104", "104教室"), ("clinic", "医务室")],
]


def build():
    layout = {
        "id": "school-floor-1", "name": "第七中学 · 教学楼一层", "size": [WIDTH, HEIGHT],
        "spawn": [245, 880], "corridor": [160, 720, 3040, 320],
        "rooms": [], "walls": [], "doors": [], "covers": [],
    }
    walls, covers = layout["walls"], layout["covers"]
    # Two end entrances leave the long central passage open from side to side.
    walls.extend([[140, 140, 3080, 20], [140, 1620, 3080, 20],
                  [140, 140, 20, 700], [140, 960, 20, 680],
                  [3200, 140, 20, 700], [3200, 960, 20, 680]])
    for row, y in enumerate((160, 1060)):
        for col, x in enumerate(ROOM_X):
            room_id, name = ROOM_NAMES[row][col]
            layout["rooms"].append({"id": room_id, "name": name,
                                    "rect": [x, y, 730, 540], "label": [x + 365, y + 112],
                                    "kind": "classroom" if "class-" in room_id else "service"})
            if col:
                walls.append([x - 20, y, 20, 540])
            if col == 3:
                walls.append([x + 730, y, 20, 540])
            # Each room has one clear doorway into the passage.
            door_x = x + 280
            wall_y = 700 if row == 0 else 1040
            walls.extend([[x, wall_y, 280, 20], [door_x + 170, wall_y, 280, 20]])
            layout["doors"].append({"id": room_id + "-door", "rect": [door_x, wall_y, 170, 20],
                                    "closed": room_id in ("office", "class-104")})
            if "class-" in room_id:
                # Readable desk islands with a path between rows and to the door.
                for dx in (115, 455):
                    for dy in (205, 370):
                        covers.append({"rect": [x + dx, y + dy, 140, 62], "sprite": 0})
            elif room_id in ("office", "faculty"):
                covers.extend([{"rect": [x + 105, y + 255, 160, 70], "sprite": 0},
                               {"rect": [x + 475, y + 340, 145, 70], "sprite": 3}])
            elif room_id == "storage":
                covers.extend([{"rect": [x + 90, y + 230, 125, 75], "sprite": 1},
                               {"rect": [x + 475, y + 320, 150, 70], "sprite": 3}])
            else:
                covers.extend([{"rect": [x + 100, y + 245, 150, 75], "sprite": 0},
                               {"rect": [x + 470, y + 340, 120, 75], "sprite": 12}])

    # A fixed seed gives the impression of scattered abandoned furniture while
    # keeping doorway clearances and the through route stable on every launch.
    rng = random.Random(7101)
    for index, x in enumerate((355, 885, 1135, 1615, 1885, 2370, 2630, 3060)):
        near_top = index % 2 == 0
        covers.append({"rect": [x + rng.randint(-24, 24),
                                (748 if near_top else 948) + rng.randint(-8, 8),
                                138, 62], "sprite": 0})
    path = ROOT / "data" / "school_floor_1.json"
    path.write_text(json.dumps(layout, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    build()
