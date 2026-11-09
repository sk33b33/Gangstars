#!/usr/bin/env python3
"""Generate the Vleirand starter district data (30 houses + residents).

Deterministic: every house/resident draws from its own RNG seeded by its stable id, so
editing one row never reshuffles the others. Hand-authored entries in KEEP_* are copied
through unchanged. Output:
  data/houses/starter_houses.json
  data/npcs/starter_residents.json
Run: python3 tools/generate_starter_data.py
"""
import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HOUSES_OUT = ROOT / "data/houses/starter_houses.json"
RESIDENTS_OUT = ROOT / "data/npcs/starter_residents.json"

# Street edges (road half width + sidewalk) must match data/districts/starter.json.
# Each row: street id, street name, facing, fixed coordinate of the fence line, and the
# positions along the street. Plot front-centres sit 0.5 m behind the sidewalk edge.
ROWS = [
    # Duif Street (z = 0, edge 6.5): south side, doors face north.
    ("duif", "Duif Street", "north", ("z", 7.0), [-48, -36, -24, -12, 0, 12, 24, 36]),
    # Mossie Street (z = -56, edge 6.5): north side faces south, south side faces north.
    ("mossie", "Mossie Street", "south", ("z", -63.0), [-42, -30, -18, -6, 6, 18, 30, 42]),
    ("mossie", "Mossie Street", "north", ("z", -49.0), [-6, 6]),
    # Kwikkie Street (x = -50, edge 6.5): west side faces east, east side faces west.
    ("kwikkie", "Kwikkie Street", "east", ("x", -57.0), [-16, -28, -40]),
    ("kwikkie", "Kwikkie Street", "west", ("x", -43.0), [-16, -28, -40]),
    # Tortel Lane (x = 50, edge 5.0): narrower lane.
    ("tortel", "Tortel Lane", "east", ("x", 44.5), [-16, -28, -40]),
    ("tortel", "Tortel Lane", "west", ("x", 55.5), [-16, -28, -40]),
]

# Existing Phase 1 houses keep their ids and positions (h01-h05 on Duif Street).
ID_ORDER_DUIF = {-24: 1, -12: 2, 0: 3, 12: 4, 24: 5, 36: 6, -36: 7, -48: 8}

VACANT = {"starter_h14", "starter_h20", "starter_h27"}
HOSTILE = {"starter_h29"}
SAFEHOUSE = "starter_h05"

KITS = ["single_hip"] * 3 + ["single_gable"] * 3 + ["double_semi"] * 2 + ["double_garage"] * 2
PAINT = ["#e8967a", "#f0a58a", "#a6d455", "#9fd8b8", "#8fb8d8", "#f2e4b8", "#f1d36b",
         "#c3b0d8", "#bfc3c8", "#ece9e2", "#f4c59a", "#7cc7c4"]
SURNAMES = ["Abrahams", "Arendse", "Booysen", "Carelse", "Cupido", "Davids", "Fortuin",
            "Fredericks", "Hendricks", "Isaacs", "Jansen", "Josephs", "Klaasen", "Lakay",
            "Meyer", "Pietersen", "Ruiters", "Samuels", "Snyders", "Solomons", "Williams",
            "Wyngaard", "Kannemeyer", "Marthinus", "Swartz", "Visagie"]
FIRST = ["Ashraf", "Bianca", "Cheslyn", "Dawood", "Ebrahim", "Fatima", "Gadija", "Jerome",
         "Kaylin", "Lee-Ann", "Marlon", "Nazeem", "Natasha", "Owen", "Riaan", "Ruwayda",
         "Shafiek", "Tamsin", "Waseem", "Yusuf", "Zaida", "Chantal", "Denver", "Gershwin",
         "Monique", "Taariq", "Ilse", "Clint", "Mymoena", "Achmat"]
SHIRTS = ["#c0392b", "#2e86c1", "#f4d03f", "#27ae60", "#8e44ad", "#e67e22", "#16a085",
          "#d35400", "#ecf0f1", "#2c3e50", "#e84393", "#00b894", "#fdcb6e", "#6c5ce7"]
PANTS = ["#2c3e50", "#34495e", "#1c2833", "#5d6d7e", "#212f3d", "#4a4e6a", "#6b4630"]
SKIN = ["#7b4f33", "#8d5a3b", "#a7754f", "#b98458", "#c49a6c", "#6a4128", "#9a6a45"]
POIS = ["poi_shop", "poi_bus_stop", "poi_bus_stop_mossie", "poi_corner", "poi_court", "poi_park"]
ACTIVITY = {"poi_shop": "shopping", "poi_bus_stop": "waiting", "poi_bus_stop_mossie": "waiting",
            "poi_corner": "socializing", "poi_court": "playing", "poi_park": "relaxing"}
LINES = [
    "Môre! Lovely day, hey?", "The café ran out of bread again.", "Ag shame, you look lost.",
    "Everybody knows everybody here.", "My laaitie is at the court, have you seen him?",
    "Don't park in front of my gate, ne.", "The bus is always late on Mossie Street.",
    "Who are you looking for?", "My ouma has lived here forty years.", "Shame, this wind."]
WINDOWS = {"shopping": [7, 19], "waiting": [6, 20], "socializing": [10, 22], "playing": [9, 20],
           "relaxing": [8, 20], "visiting": [9, 21]}
PERSONALITIES = ["curious"] * 3 + ["timid"] * 3 + ["gossip"] * 2 + ["steady"] * 3
ACTIVE_HOURS = [[6, 22]] * 4 + [[5, 21], [8, 23]]
KEEP_PERSONALITY = {"npc_faiza": "gossip", "npc_boeta": "curious", "npc_shireen": "timid",
                    "npc_lionel": "steady", "npc_tasneem": "curious"}
# Rival crew (Tortel Lane): the leader patrols at night, the second member follows him.
CREW_SCHEDULES = {
    1: [{"activity": "patrol", "route": "tortel_loop", "duration": 1, "window": [17, 2]},
        {"activity": "socializing", "destination": "poi_corner", "duration": 25},
        {"activity": "guard", "destination": "{home}:gate", "duration": 30},
        {"activity": "home", "destination": "home", "duration": 20}],
    2: [{"activity": "follow", "destination": "@leader:{leader}", "duration": 70, "window": [17, 2]},
        {"activity": "guard", "destination": "{home}:gate", "duration": 35},
        {"activity": "socializing", "destination": "poi_corner", "duration": 20},
        {"activity": "home", "destination": "home", "duration": 15}],
}
PATROL_ROUTES = {"tortel_loop": 6}
CREW_LINES = ["This is Tortel Lane. You lost?", "Move along, my bru.", "We're watching you, new face."]

HAIR_STYLES = ["short"] * 4 + ["long"] * 2 + ["doek"] * 2 + ["beanie", "bald"]
HAIR_COLORS = ["#1d1b24", "#2b1d16", "#3a2a1e", "#1d1b24", "#5a4636", "#9a9a9a"]
DOEK_COLORS = ["#c0392b", "#8e44ad", "#16a085", "#f1d36b", "#2e86c1", "#e67e22"]
BEANIE_COLORS = ["#2c3e50", "#c0392b", "#27ae60", "#f4d03f"]
KEEP_LOOKS = {  # hand-picked looks for the original five
    "npc_faiza": {"hair_style": "doek", "hair_color": "#8e44ad", "height": 0.94, "sleeves": "long"},
    "npc_boeta": {"hair_style": "short", "hair_color": "#1d1b24", "height": 1.04, "sleeves": "short"},
    "npc_shireen": {"hair_style": "long", "hair_color": "#2b1d16", "height": 0.96, "sleeves": "short"},
    "npc_lionel": {"hair_style": "beanie", "hair_color": "#2c3e50", "height": 1.06, "sleeves": "long"},
    "npc_tasneem": {"hair_style": "doek", "hair_color": "#16a085", "height": 0.97, "sleeves": "long"},
}


def make_look(rng, hostile=False):
    style = "beanie" if hostile else rng.choice(HAIR_STYLES)
    color = {"doek": rng.choice(DOEK_COLORS), "beanie": rng.choice(BEANIE_COLORS)}.get(style, rng.choice(HAIR_COLORS))
    return {"hair_style": style, "hair_color": "#1d1b24" if hostile else color,
            "height": round(rng.uniform(0.9, 1.08), 2), "sleeves": rng.choice(["long", "short"])}


def make_props(rng, hid):
    """Deterministic plot dressing: yard surface, bin, dish, washing line or wendy house, tree."""
    wendy = rng.random() < 0.3
    return {"yard": rng.choice(["sand", "sand", "paved", "lawn"]), "bin": rng.random() < 0.75,
            "dish": rng.random() < 0.4, "washing": (not wendy) and rng.random() < 0.6,
            "wendy": wendy, "tree": rng.random() < 0.3, "gate": rng.random() < 0.7}


KEEP_HOUSES = {
    "starter_h01": {"display_name": "Daniels family", "kit": "single_hip", "wall_color": "#e8967a", "roof": "tiles",
                    "fence": "precast", "fence_color": "#efb59c", "occupant_ids": ["npc_faiza", "npc_boeta"]},
    "starter_h02": {"display_name": "Jacobs family", "kit": "single_gable", "wall_color": "#a6d455", "roof": "tiles",
                    "fence": "precast", "fence_color": "#a6d455", "occupant_ids": ["npc_shireen"]},
    "starter_h03": {"display_name": "Petersen family", "kit": "double_semi", "wall_color": "#ece9e2", "roof": "ibr",
                    "fence": "palisade", "fence_color": "#ffffff", "occupant_ids": ["npc_lionel"]},
    "starter_h04": {"display_name": "Adams family", "kit": "double_garage", "wall_color": "#bfc3c8", "roof": "ibr",
                    "fence": "palisade", "fence_color": "#ffffff", "occupant_ids": ["npc_tasneem"]},
    "starter_h05": {"display_name": "Your safehouse", "kit": "single_hip", "wall_color": "#8fb8d8", "roof": "tiles",
                    "fence": "precast", "fence_color": "#d9e4ea", "occupant_ids": []},
}


def house_ids():
    """Yield (id, street, street_name, facing, position) in stable id order."""
    rows = []
    for street, name, facing, (axis, fixed), along in ROWS:
        for a in along:
            pos = [a, fixed] if axis == "z" else [fixed, a]
            rows.append((street, name, facing, pos))
    out = {}
    nxt = 9
    for street, name, facing, pos in rows:
        if street == "duif":
            idx = ID_ORDER_DUIF[pos[0]]
        else:
            idx, nxt = nxt, nxt + 1
        out[f"starter_h{idx:02d}"] = (street, name, facing, pos)
    return dict(sorted(out.items()))


def number_houses(houses):
    """Number each street west->east / north->south: odd on one side, even on the other."""
    by_side = {}
    for hid, (street, _n, facing, pos) in houses.items():
        by_side.setdefault((street, facing), []).append((pos, hid))
    numbers = {}
    for (street, facing), items in by_side.items():
        odd = facing in ("north", "east")
        items.sort(key=lambda p: (p[0][0], p[0][1]))
        for i, (_pos, hid) in enumerate(items):
            numbers[hid] = 2 * i + (1 if odd else 2)
    return numbers


def make_houses():
    houses = house_ids()
    numbers = number_houses(houses)
    out = []
    for hid, (street, street_name, facing, pos) in houses.items():
        rng = random.Random("vleirand-house-" + hid)
        h = {
            "id": hid, "number": numbers[hid], "street": street_name,
            "display_name": rng.choice(SURNAMES) + " family",
            "kit": rng.choice(KITS), "position": pos, "facing": facing,
            "wall_color": rng.choice(PAINT), "roof": "tiles" if rng.random() < 0.6 else "ibr",
        }
        if rng.random() < 0.6:
            h["fence"] = "precast"
            h["fence_color"] = h["wall_color"] if rng.random() < 0.5 else "#d9d4c8"
        else:
            h["fence"] = "palisade"
            h["fence_color"] = "#ffffff" if rng.random() < 0.6 else "#56606e"
        h["occupancy"] = "vacant" if hid in VACANT or hid == SAFEHOUSE else "occupied"
        h["ownership"] = "player" if hid == SAFEHOUSE else ("hostile" if hid in HOSTILE else "neutral")
        if hid in VACANT:
            h["display_name"] = "Empty house"
        h["occupant_ids"] = []
        h["props"] = make_props(random.Random("vleirand-props-" + hid), hid)
        if hid == SAFEHOUSE:
            h["props"].update({"wendy": False, "washing": False, "dish": False, "tree": False, "yard": "sand"})
        h.update(KEEP_HOUSES.get(hid, {}))
        out.append(h)
    return out


def expand_crew(template, home_id, leader_id):
    out = []
    for e in template:
        e = dict(e)
        if "route" in e:
            e["route"] = ["patrol:%s:%d" % (e["route"], i) for i in range(PATROL_ROUTES[e["route"]])]
        if "destination" in e:
            e["destination"] = e["destination"].replace("{home}", home_id).replace("{leader}", leader_id)
        out.append(e)
    return out


def patch_kept(r):
    """Phase 3 fields for the hand-authored residents (kept otherwise unchanged)."""
    r = dict(r)
    r["personality"] = KEEP_PERSONALITY.get(r["id"], "steady")
    r.update(KEEP_LOOKS.get(r["id"], {}))
    r.setdefault("active_hours", [6, 22])
    for e in r["schedule"]:
        if e["destination"] != "home":
            e["window"] = WINDOWS.get(e["activity"], [6, 22])
    return r


def make_residents(houses, kept):
    occupied = [h for h in houses if h["occupancy"] == "occupied"]
    doors = [h["id"] + ":door" for h in occupied]
    residents = [patch_kept(r) for r in kept]
    kept_ids = {r["id"] for r in kept}
    for h in occupied:
        if h["occupant_ids"]:
            continue  # hand-authored house keeps its residents
        hostile = h["ownership"] == "hostile"
        count = 2 if hostile else 1
        surname = h["display_name"].replace(" family", "")
        for k in range(count):
            rid = "npc_%s_%d" % (h["id"].replace("starter_", ""), k + 1)
            rng = random.Random("vleirand-npc-" + rid)
            first = rng.choice(FIRST)
            if hostile:
                schedule = expand_crew(CREW_SCHEDULES[k + 1], h["id"], "npc_%s_1" % h["id"].replace("starter_", ""))
            else:
                stops = rng.sample(POIS, 2)
                if rng.random() < 0.35:
                    other = rng.choice([d for d in doors if d != h["id"] + ":door"])
                    stops[rng.randrange(2)] = other
                schedule = []
                for s in stops:
                    act = "visiting" if s.endswith(":door") else ACTIVITY[s]
                    schedule.append({"activity": act, "destination": s, "duration": rng.randint(8, 18),
                                     "window": WINDOWS[act]})
                schedule.append({"activity": "home", "destination": "home", "duration": rng.randint(15, 35)})
            r = {
                "id": rid, "display_name": f"{first} {surname}", "home_id": h["id"],
                "role": "crew" if hostile else "resident",
                "shirt_color": "#1d1b24" if hostile else rng.choice(SHIRTS),
                "pants_color": rng.choice(PANTS), "skin_color": rng.choice(SKIN),
                "walk_speed": round(rng.uniform(1.25, 1.8), 2), "start_delay": round(rng.uniform(1.0, 45.0), 1),
                "personality": "tough" if hostile else rng.choice(PERSONALITIES),
                "active_hours": [10, 2] if hostile else rng.choice(ACTIVE_HOURS),
                "schedule": schedule,
                "lines": rng.sample(CREW_LINES if hostile else LINES, 2),
            }
            r.update(make_look(random.Random("vleirand-look-" + rid), hostile))
            if hostile:
                r["faction_id"] = "tortel_crew"
            assert r["id"] not in kept_ids
            residents.append(r)
            h["occupant_ids"].append(rid)
    return residents


def main():
    kept = json.loads(RESIDENTS_OUT.read_text())["residents"][:5] if RESIDENTS_OUT.exists() else []
    kept = [r for r in kept if r["id"] in {"npc_faiza", "npc_boeta", "npc_shireen", "npc_lionel", "npc_tasneem"}]
    houses = make_houses()
    residents = make_residents(houses, kept)
    HOUSES_OUT.write_text(json.dumps({"district_id": "starter", "houses": houses}, indent=2, ensure_ascii=False) + "\n")
    RESIDENTS_OUT.write_text(json.dumps({"residents": residents}, indent=2, ensure_ascii=False) + "\n")
    print(f"{len(houses)} houses, {len(residents)} residents")


if __name__ == "__main__":
    main()
