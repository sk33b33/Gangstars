# APPLIED MIGRATION (record only): the old districts were removed and this already ran; the data it read has been
# overwritten, so it no longer runs. The real world is built by tools/osm/build_westridge.py.
"""One-off migration (2026-11-15): rebuilds Lentegeur on its real streets (OpenStreetMap): the
Hyacinth Avenue crescent off Firethorn Road, with Marguerite Road to the north. Already applied
to data/; kept as the record of what changed. Do not run it again.

Game frame (same 22-degree turn as Westridge): x = u + 206, z = v - 209.6, where (u, v) are metres
east/south of the Lentegeur suburb point on the turned map. Firethorn Road is at x = 114, the south
leg of Hyacinth Avenue at z = 0, the north leg at z = -44.6, the bend at x = 222 (real 228: the
legs are 5% short so the bend fits inside the area), Marguerite Road at z = -70 (real -75.6).
"""
import json, re
R = '/home/user/Gangstars/'
N = -44.6   # north leg of the crescent

p = R + 'data/districts/rooiduin.json'
d = json.load(open(p))
d['street_name'] = 'Lentegeur'
d['streets'] = [
    {"id": "duif_r", "name": "Hyacinth Avenue", "axis": "x", "at": 0, "from": 88, "to": 240, "half_width": 4.0, "sidewalk": 2.5},
    {"id": "mossie_r", "name": "Marguerite Road", "axis": "x", "at": -70.0, "from": 88, "to": 240, "half_width": 4.0, "sidewalk": 2.5},
    {"id": "hyacinth_n", "name": "Hyacinth Avenue", "axis": "x", "at": N, "from": 118, "to": 219, "half_width": 3.0, "sidewalk": 2.0,
     "sidewalk_from": 120.5, "sidewalk_to": 217},
    {"id": "firethorn", "name": "Firethorn Road", "axis": "z", "at": 114, "from": -4, "to": -66.0, "half_width": 4.0, "sidewalk": 2.0,
     "sidewalk_from": -6.5, "sidewalk_to": -63.5},
    {"id": "hyacinth_bend", "name": "Hyacinth Avenue", "axis": "z", "at": 222, "from": -4, "to": N - 3.0, "half_width": 3.0, "sidewalk": 2.0,
     "sidewalk_from": -6.5, "sidewalk_to": N - 5.0},
]
d['real'] = {"bearing_deg": -22.1, "anchor": {"local": [114, 0], "uv": [-92.0, 209.6], "suburb": "Lentegeur"},
    "note": "The real Hyacinth Avenue crescent between Firethorn Road and Marguerite Road (OpenStreetMap), turned 22 degrees. The crescent legs are 108 m (real 114) and Marguerite Road is 70 m north of the south leg (real 76). Hyacinth Avenue and Marguerite Road beyond the area's edges are link roads to the neighbouring districts until those are rebuilt. The soccer field, shops and taxi rank are the game's own, placed inside the crescent."}
d['landmarks'] = [
    {"type": "container_shop", "position": [190, -10], "facing": "south", "sign": "sign_spaza", "color": "#2b6fb5"},
    {"type": "container_shop", "position": [204, -10], "facing": "south", "sign": "sign_barber", "color": "#d64541"},
    {"type": "soccer_field", "position": [136, -23]},
    {"type": "taxi_rank", "position": [136, -8.2], "facing": "south"},
    {"type": "courtyard", "position": [200, -27]},
    {"type": "police_post", "id": "saps_rooi", "position": [176, -56.5], "facing": "south"},
]
pos = {"rooi_spaza": [190, -7.4], "rooi_barber": [204, -7.4], "rooi_field": [136, -23], "rooi_taxi": [136, -5.3], "rooi_courtyard": [200, -27]}
for poi in d['pois']:
    poi['position'] = pos[poi['id']]
d['patrol_routes'] = {
    "rooi_loop": [[160, -5.4], [214, -5.4], [218, -12], [218, -36], [200, -40.6], [130, -40.6], [119.3, -36], [119.3, -12]],
    "saps_rooi_beat": [[125, -5.4], [160, -5.4], [214, -5.4], [218, -12], [218, -36], [200, -40.6], [125, -40.6], [119.3, -30]],
}
for dc in d['decals']:
    if abs(dc['position'][0] - 199.0) < 0.01:
        dc['position'][0] = 203.0
d['traffic']['loops'][0]['points'] = [[114, 0], [222, 0], [222, N], [114, N]]
d['traffic']['loops'][1]['points'] = [[114, N], [222, N], [222, 0], [114, 0]]
d['kickabouts'] = [{"poi": "rooi_field", "center": [136, -23], "half": [12.0, 7.6]}]
json.dump(d, open(p, 'w'), indent=2); open(p, 'a').write('\n')

p = R + 'data/houses/rooiduin_houses.json'
h = json.load(open(p))
inside = {  # the six row houses that stood on the made-up Duin Road: now inside the crescent, back to back
    "rooi_h15": (160, N + 5.5, "north", 2), "rooi_h16": (168, N + 5.5, "north", 4), "rooi_h17": (176, N + 5.5, "north", 6),
    "rooi_h18": (160, -7.0, "south", 8), "rooi_h19": (168, -7.0, "south", 10), "rooi_h20": (176, -7.0, "south", 12),
}
for x in h['houses']:
    x['street'] = {"AZ Berman Drive": "Hyacinth Avenue", "Spine Road": "Marguerite Road", "Duin Road": "Hyacinth Avenue"}[x['street']]
    if x['id'] in inside:
        px, pz, facing, number = inside[x['id']]
        x.update(position=[px, round(pz, 1)], facing=facing, number=number)
json.dump(h, open(p, 'w'), indent=2); open(p, 'a').write('\n')

for f in ['data/missions/rooiduin.json', 'data/npcs/rooiduin_residents.json', 'data/missions/story.json', 'data/missions/crews.json',
          'data/missions/life.json', 'data/missions/kalkbos.json', 'data/story/scenes.json']:
    s = open(R + f).read(); o = s
    s = s.replace("flats (8 Spine Road)", "flats (8 Marguerite Road)").replace("Duin Road", "Hyacinth Avenue").replace("Kers Street", "Firethorn Road")
    if s != o:
        open(R + f, 'w').write(s); print('updated', f)
p = R + 'data/districts/districts.json'
s = open(p).read()
s = s.replace("Flats, container shops and the soccer field, east along AZ Berman Drive.",
              "Flats, container shops and the soccer field on the Hyacinth Avenue crescent, off Marguerite Road.")
open(p, 'w').write(s)
print('done')
