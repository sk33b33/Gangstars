#!/usr/bin/env python3
"""Generic, repeatable district data generator (Phase 7 pipeline).

    python3 tools/generate_district.py tools/specs/rooiduin.json

A spec lists street rows (kit, plot size, residents per house), palettes, name pools, the
district's points of interest, named characters and a rival crew. Output: houses + residents
JSON in the same formats Vleirand uses, so the game builds the district with the same code.
Deterministic: every house/resident uses its own RNG seeded by spec seed + stable id.
"""
import json
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHIRTS = ["#c0392b", "#2e86c1", "#f4d03f", "#27ae60", "#8e44ad", "#e67e22", "#16a085", "#d35400",
          "#ecf0f1", "#2c3e50", "#e84393", "#00b894", "#fdcb6e", "#6c5ce7"]
PANTS = ["#2c3e50", "#34495e", "#1c2833", "#5d6d7e", "#212f3d", "#4a4e6a", "#6b4630"]
SKIN = ["#7b4f33", "#8d5a3b", "#a7754f", "#b98458", "#c49a6c", "#6a4128", "#9a6a45"]
HAIR = ["short"] * 4 + ["long"] * 2 + ["doek"] * 2 + ["beanie", "bald"]
HAIR_COLORS = ["#1d1b24", "#2b1d16", "#3a2a1e", "#5a4636", "#9a9a9a"]
DOEK = ["#c0392b", "#8e44ad", "#16a085", "#f1d36b", "#2e86c1", "#e67e22"]
PERSONALITIES = ["curious"] * 3 + ["timid"] * 3 + ["gossip"] * 2 + ["steady"] * 3


def rng_for(spec, kind, ident):
    return random.Random("%s-%s-%s" % (spec["seed"], kind, ident))


def houses_from_rows(spec):
    out, idx = [], 1
    for row in spec["rows"]:
        for a in row["positions"]:
            pos = [a, row["fixed"]] if row["axis"] == "z" else [row["fixed"], a]
            out.append({"row": row, "id": "%s%02d" % (spec["house_prefix"], idx), "position": pos})
            idx += 1
    # Street numbers: odd on north/east-facing sides, even on the others, ordered along the street.
    sides = {}
    for h in out:
        sides.setdefault((h["row"]["street"], h["row"]["facing"]), []).append(h)
    for (street, facing), items in sides.items():
        items.sort(key=lambda h: (h["position"][0], h["position"][1]))
        for i, h in enumerate(items):
            h["number"] = 2 * i + (1 if facing in ("north", "east") else 2)
    return out


def make_house(spec, h):
    row, hid = h["row"], h["id"]
    rng = rng_for(spec, "house", hid)
    roll, fence = rng.random(), None
    for kind, weight in spec["fences"].items():  # weighted pick, in spec order
        roll -= weight
        if roll < 0:
            fence = kind
            break
    fence = fence or list(spec["fences"])[-1]
    wall = rng.choice(spec["paint"])
    kit = rng.choice(row["kits"]) if "kits" in row else row["kit"]
    flats = kit == "flats"
    house = {
        "id": hid, "number": h["number"], "street": row["street"], "district_id": spec["district_id"],
        "display_name": ("%s block" if flats else "%s family") % rng.choice(spec["surnames"]),
        "kit": kit, "position": h["position"], "facing": row["facing"], "plot_size": row["plot_size"],
        "wall_color": wall, "roof": "ibr" if rng.random() < 0.5 else "tiles",
        "fence": fence, "fence_color": {"palisade": "#56606e", "stone": "#efe9dc"}.get(fence, wall),
        "occupancy": "vacant" if hid in spec.get("vacant", []) else "occupied",
        "ownership": "hostile" if hid == spec.get("hostile", {}).get("house") else "neutral",
        "occupant_ids": [],
        "props": {"yard": rng.choice(["sand", "sand", "paved"]), "bin": rng.random() < 0.7, "dish": rng.random() < 0.5,
                  "washing": rng.random() < (0.85 if flats else 0.5), "wendy": (not flats) and rng.random() < 0.2,
                  "tree": rng.random() < 0.15, "gate": rng.random() < 0.6},
    }
    if house["occupancy"] == "vacant":
        house["display_name"] = "Empty flats" if flats else "Empty house"
    return house


def look(rng, crew=False):
    style = "beanie" if crew else rng.choice(HAIR)
    color = rng.choice(DOEK) if style == "doek" else ("#1d1b24" if crew else rng.choice(HAIR_COLORS))
    return {"hair_style": style, "hair_color": color, "height": round(rng.uniform(0.9, 1.08), 2),
            "sleeves": rng.choice(["long", "short"])}


def make_resident(spec, rid, house, rng, name, role="resident"):
    pois = list(spec["pois"].keys())
    stops = rng.sample(pois, 2)
    schedule = [{"activity": spec["pois"][s], "destination": s, "duration": rng.randint(8, 18),
                 "window": spec["windows"][spec["pois"][s]]} for s in stops]
    schedule.append({"activity": "home", "destination": "home", "duration": rng.randint(15, 35)})
    r = {"id": rid, "display_name": name, "home_id": house["id"], "role": role,
         "shirt_color": rng.choice(SHIRTS), "pants_color": rng.choice(PANTS), "skin_color": rng.choice(SKIN),
         "walk_speed": round(rng.uniform(1.25, 1.8), 2), "start_delay": round(rng.uniform(1.0, 45.0), 1),
         "personality": rng.choice(PERSONALITIES), "active_hours": [6, 22], "schedule": schedule,
         "lines": rng.sample(spec["lines"], 2)}
    r.update(look(rng))
    return r


def make_crew(spec, house):
    hc = spec["hostile"]
    route = ["patrol:%s:%d" % (hc["route"], i) for i in range(hc["route_len"])]
    out = []
    for k, (rid, name) in enumerate(zip(hc["members"], hc["names"])):
        rng = rng_for(spec, "crew", rid)
        if k == 0:
            schedule = [{"activity": "patrol", "route": route, "duration": 1, "window": [17, 2]},
                        {"activity": "socializing", "destination": hc["hangout"], "duration": 25},
                        {"activity": "guard", "destination": house["id"] + ":gate", "duration": 30},
                        {"activity": "home", "destination": "home", "duration": 20}]
        else:
            schedule = [{"activity": "follow", "destination": "@leader:" + hc["members"][0], "duration": 70, "window": [17, 2]},
                        {"activity": "guard", "destination": house["id"] + ":gate", "duration": 35},
                        {"activity": "socializing", "destination": hc["hangout"], "duration": 20},
                        {"activity": "home", "destination": "home", "duration": 15}]
        r = {"id": rid, "display_name": name, "home_id": house["id"], "role": "crew", "faction_id": hc["faction_id"],
             "shirt_color": "#7a1f1f", "pants_color": rng.choice(PANTS), "skin_color": rng.choice(SKIN),
             "walk_speed": round(rng.uniform(1.4, 1.8), 2), "start_delay": round(rng.uniform(1.0, 30.0), 1),
             "personality": "tough", "active_hours": [10, 2], "schedule": schedule,
             "lines": rng.sample(spec["crew_lines"], 2)}
        r.update(look(rng, crew=True))
        out.append(r)
    return out


def main(spec_path):
    spec = json.loads(Path(spec_path).read_text())
    rows = houses_from_rows(spec)
    houses = [make_house(spec, h) for h in rows]
    by_id = {h["id"]: h for h in houses}
    residents = []
    # Named characters first (hand-written schedules), then the crew, then everyone else.
    for rid, n in spec.get("named", {}).items():
        house = by_id[n["house"]]
        rng = rng_for(spec, "npc", rid)
        r = make_resident(spec, rid, house, rng, n["display_name"])
        r.update({k: v for k, v in n.items() if k != "house"})
        residents.append(r)
        house["occupant_ids"].append(rid)
    if "hostile" in spec:
        house = by_id[spec["hostile"]["house"]]
        for r in make_crew(spec, house):
            residents.append(r)
            house["occupant_ids"].append(r["id"])
    for h, src in zip(houses, rows):
        if h["occupancy"] != "occupied" or h["ownership"] == "hostile":
            continue
        want = src["row"].get("residents", 1)
        k = 1
        while len(h["occupant_ids"]) < want:
            rid = "%s%s_%d" % (spec["npc_prefix"], h["id"].replace(spec["house_prefix"], "h"), k)
            rng = rng_for(spec, "npc", rid)
            name = "%s %s" % (rng.choice(spec["first_names"]), h["display_name"].split(" ")[0])
            residents.append(make_resident(spec, rid, h, rng, name))
            h["occupant_ids"].append(rid)
            k += 1
    (ROOT / spec["houses_out"]).write_text(json.dumps({"district_id": spec["district_id"], "houses": houses}, indent=2, ensure_ascii=False) + "\n")
    (ROOT / spec["residents_out"]).write_text(json.dumps({"residents": residents}, indent=2, ensure_ascii=False) + "\n")
    print("%d houses, %d residents -> %s, %s" % (len(houses), len(residents), spec["houses_out"], spec["residents_out"]))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else str(ROOT / "tools/specs/rooiduin.json"))
