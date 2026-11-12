#!/usr/bin/env python3
"""One-off authoring script for the fifth area, Tafelsig (east of Town Centre).

Takes Lentegeur's layout (flats along the main roads, row-house courts between them) and shifts
it 312 m east, then gives it its own names, landmarks and people. Writes:
  tools/specs/tafelsig.json      (input for tools/generate_district.py: houses + residents)
  data/districts/tafelsig.json   (streets, landmarks, pois, routes, traffic)
Run, then: python3 tools/generate_district.py tools/specs/tafelsig.json
The output files are what the game reads; this script is kept so the layout can be regenerated.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DX = 312.0


def sx(v):
    return round(v + DX, 2)


def rename(s):
    return s.replace("rooi_", "taf_").replace("saps_rooi", "saps_taf")


# ---------------------------------------------------------------- spec (houses + residents)
spec = json.loads((ROOT / "tools/specs/rooiduin.json").read_text())
spec["district_id"] = "district_tafelsig"
spec["seed"] = "tafelsig"
spec["house_prefix"] = "taf_h"
spec["npc_prefix"] = "npc_taf_"
spec["houses_out"] = "data/houses/tafelsig_houses.json"
spec["residents_out"] = "data/npcs/tafelsig_residents.json"
for row in spec["rows"]:
    if row["axis"] == "z":
        row["positions"] = [sx(p) for p in row["positions"]]
    else:
        row["fixed"] = sx(row["fixed"])
    if row["street"] == "Duin Road":
        row["street"] = "Court Lane"
spec["vacant"] = ["taf_h06", "taf_h17"]
spec["hostile"] = {
    "house": "taf_h14", "faction_id": "tortel_crew",
    "members": ["npc_taf_dawie", "npc_taf_tortel_2", "npc_taf_tortel_3"],
    "route": "taf_loop", "route_len": 6, "hangout": "taf_courtyard",
    "names": ["Dawie", "Brandon", "Mervyn"],
}
spec["pois"] = {"taf_spaza": "shopping", "taf_stoep_shop": "shopping", "taf_court": "playing",
                "taf_taxi": "waiting", "taf_courtyard": "socializing"}
spec["windows"] = {"shopping": [7, 19], "waiting": [6, 20], "socializing": [10, 22], "playing": [9, 21]}
spec["named"] = {
    "npc_taf_gadija": {
        "house": "taf_h03", "display_name": "Aunty Gadija", "personality": "gossip", "hair_style": "doek",
        "hair_color": "#c0392b", "height": 0.94, "shirt_color": "#16a085",
        "schedule": [
            {"activity": "working", "destination": "taf_spaza", "duration": 45, "window": [7, 19]},
            {"activity": "home", "destination": "home", "duration": 15}],
        "lines": ["Sand in everything out here. Sand in my bread, even.",
                  "Tafelsig is quiet, hey. Don't let the quiet fool you.",
                  "The Laaities' cousins come through on a Friday. I close early."]},
    "npc_taf_ricardo": {
        "house": "taf_h09", "display_name": "Ricardo Fortuin", "personality": "steady", "hair_style": "fade",
        "height": 1.04, "shirt_color": "#e67e22",
        "schedule": [
            {"activity": "playing", "destination": "taf_court", "duration": 40, "window": [9, 21]},
            {"activity": "waiting", "destination": "taf_taxi", "duration": 10, "window": [6, 20]},
            {"activity": "home", "destination": "home", "duration": 15}],
        "lines": ["I coach the juniors on this court. Somebody has to.",
                  "Every kid on this court is one bad decision from the streets."]},
    "npc_taf_hester": {
        "house": "taf_h12", "display_name": "Ouma Hester", "personality": "timid", "hair_style": "bun",
        "hair_color": "#9a9a9a", "height": 0.9, "shirt_color": "#8e44ad",
        "schedule": [
            {"activity": "socializing", "destination": "taf_courtyard", "duration": 40, "window": [9, 17]},
            {"activity": "home", "destination": "home", "duration": 20}],
        "lines": ["I watched these dunes move forty years. People move slower.",
                  "Sit, sit. The wind will pass."]},
}
spec["lines"] = ["The wind never stops out here.", "Sand under the door again.", "You can see the dunes from my bedroom.",
                 "Quiet out here, until it isn't.", "The court's busy from three."]
spec["crew_lines"] = ["The Laaities hold this side.", "Nothing to see here, bru.", "Move along."]
(ROOT / "tools/specs/tafelsig.json").write_text(json.dumps(spec, indent=1))

# ---------------------------------------------------------------- district data
d = json.loads((ROOT / "data/districts/rooiduin.json").read_text())
d["id"] = "district_tafelsig"
d["display_name"] = "Tafelsig"
d["street_name"] = "Tafelsig"
d["bounds"] = [sx(d["bounds"][0]), d["bounds"][1], sx(d["bounds"][2]), d["bounds"][3]]
d["houses_file"] = "res://data/houses/tafelsig_houses.json"
d["residents_file"] = "res://data/npcs/tafelsig_residents.json"
d["ground_texture"] = "yard_sand"
d["ground_tint"] = "#f4ead2"
d["dogs"] = {"street": 3, "yard": 2}
d.pop("neighbours", None)
for s in d["streets"]:
    s["id"] = s["id"].replace("_r", "_f") if s["id"].endswith("_r") else s["id"] + "_taf"
    if s["axis"] == "x":
        s["from"], s["to"] = 408.0, 552.0   # 12 m past the area, like Town Centre
    else:
        s["at"] = sx(s["at"])
    if s["name"] == "Duin Road":
        s["name"] = "Court Lane"
    if s["name"] == "Kers Street":
        s["name"] = "Dune Street"
d["landmarks"] = [
    {"type": "container_shop", "position": [sx(120), -10], "facing": "south", "sign": "sign_spaza", "color": "#16a085"},
    {"type": "container_shop", "position": [sx(200), -10], "facing": "south", "sign": "sign_spaza", "color": "#d35400"},
    {"type": "court", "position": [sx(130), -34]},
    {"type": "taxi_rank", "position": [sx(196), -48.8], "facing": "north"},
    {"type": "courtyard", "position": [sx(204), -30]},
]
d["pois"] = [
    {"id": "taf_spaza", "name": "Gadija's Spaza", "kind": "shop", "position": [sx(120), -7.4], "radius": 1.0, "map_label": "spaza"},
    {"id": "taf_stoep_shop", "name": "Dune Street Tuck Shop", "kind": "shop", "position": [sx(200), -7.4], "radius": 1.0, "map_label": "tuck shop"},
    {"id": "taf_court", "name": "the sand court", "kind": "court", "position": [sx(130), -34], "radius": 4.0, "map_label": "court"},
    {"id": "taf_taxi", "name": "the Tafelsig taxi rank", "kind": "transit", "position": [sx(196), -50.7], "radius": 1.0, "map_label": "taxi"},
    {"id": "taf_courtyard", "name": "the courtyard", "kind": "gathering", "position": [sx(204), -30], "radius": 2.5, "map_label": "yard"},
]
d["patrol_routes"] = {"taf_loop": [[sx(x), z] for x, z in d["patrol_routes"]["rooi_loop"]]}
d["parked_cars"] = [{"position": [sx(140), 3.4], "rot": 0, "color": "#bdc3c7"}, {"position": [sx(210), -3.4], "rot": 180, "color": "#2e86c1"}]
d["decals"] = [{"texture": "tag_tortel", "position": [sx(186), 0.8, -62.94], "size": [2.2, 0.92], "rot": 0},
               {"texture": "tag_tortel", "position": [sx(199), 0.45, -8.78], "size": [1.6, 0.66], "rot": 0}]
t = d["traffic"]
t["taxi_stops"] = ["taf_taxi"]
for loop in t["loops"]:
    loop["points"] = [[sx(x), z] for x, z in loop["points"]]
    for c in loop["cars"]:
        c["id"] = rename(c["id"]).replace("saps_bakkie_taf", "taf_bakkie")
        if c.get("model") == "police":
            c["model"] = "bakkie"
            c["color"] = "#b5651d"
d["traffic"]["loops"][0]["cars"][1]["id"] = "taf_bakkie_1"
d["traffic"]["loops"][1]["cars"][1]["id"] = "taf_combi_1"
d["kickabouts"] = [{"poi": "taf_court", "center": [sx(130), -34], "half": [12.0, 7.6]}]
(ROOT / "data/districts/tafelsig.json").write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
print("wrote spec + district data")
