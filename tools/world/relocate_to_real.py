"""Moves the game's content onto the real Westridge (data/world/westridge/) and writes it to
data/real/, an overlay that DataFiles reads first when the game runs in real-world mode.

  python3 tools/world/relocate_to_real.py

For each of the five old districts it picks a real part of the suburb (an anchor point), then:
  - gives every story home a real house (its `real_id`); the game stands the family's front door
    in the real house's own doorway;
  - puts landmarks (cafe, courts, container shops, police posts, dens...) on clear real ground beside
    a street, or on a real park or pitch;
  - carries every point of interest along with its landmark;
  - draws new patrol routes through real junctions; parks the drivable cars on real streets;
  - rewrites addresses in mission and resident text to the houses' new real addresses.
Deterministic: the same inputs always give the same output. Ids never change.

Coordinates: metres from the Westridge suburb point, x = east, z = south.
"""
import json, glob, math, os, re, shutil, collections

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
W = os.path.join(ROOT, "data/world/westridge")
OUT = os.path.join(ROOT, "data/real")
SETBACK = 4.0

# district id -> (old area file, real name, anchor, description)
SECTORS = [
    ("starter", "starter", "Westridge", (-167, -141),
     "Your home turf: the real streets around Excelsior Street, Rhone Way, Coetzenburg Street and Constantia Street."),
    ("district_east", "rooiduin", "Harvester", (240, -470),
     "Flats, container shops and the soccer field around Harvester Way, in the north-east of Westridge."),
    ("district_west", "kalkbos", "Rocklands", (180, 980),
     "Stone cottages, the church hall and the dunes, south towards Spine Road."),
    ("district_town_centre", "town_centre", "Westridge Centre", (-60, 60),
     "The shopping centre, the taxi rank and the market on Wespoort Drive."),
    ("district_tafelsig", "tafelsig", "Duneside", (430, 160),
     "Courts, flats and sand by the dunes, east towards Eisleben Road."),
]
RENAME = {"Lentegeur": "Harvester", "Tafelsig": "Duneside", "Town Centre": "Westridge Centre"}
# landmark type -> (width along the street, depth, placement: "street" faces a street, "open" is axis-aligned on open ground)
FOOTPRINT = {
    "cafe": (12, 12, "street"), "bus_stop": (5, 3.5, "street"), "taxi_rank": (16, 9, "street"), "container_shop": (8, 6, "street"),
    "police_post": (8, 6, "street"), "shebeen": (11, 10, "street"), "crew_den": (9, 8, "street"), "corner": (8, 3, "street"),
    "church_hall": (14, 14, "street"), "mosque": (16, 16, "street"), "lookout": (6, 4, "street"), "mall": (30, 22, "street"),
    "court": (19, 12, "open"), "park": (17, 17, "open"), "soccer_field": (29, 19, "open"), "courtyard": (13, 13, "open"),
    "market": (22, 14, "open"), "kickabout": (10, 10, "open"), "quarry_face": (36, 30, "open"),
}
OLD_ROT = {"south": 0.0, "north": math.pi, "east": math.pi / 2, "west": -math.pi / 2}


# ----------------------------------------------------------------------------- geometry

def rot(v, a):   # Godot's rotation about Y, for (x, z)
    return (v[0] * math.cos(a) + v[1] * math.sin(a), -v[0] * math.sin(a) + v[1] * math.cos(a))


def add(a, b): return (a[0] + b[0], a[1] + b[1])
def sub(a, b): return (a[0] - b[0], a[1] - b[1])
def mul(a, k): return (a[0] * k, a[1] * k)
def dist(a, b): return math.hypot(a[0] - b[0], a[1] - b[1])


def seg_point_dist(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    L2 = dx * dx + dz * dz
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / L2))
    return math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dz)


def inside(p, poly):
    x, z = p; hit = False
    for i in range(len(poly)):
        (x1, z1), (x2, z2) = poly[i], poly[(i + 1) % len(poly)]
        if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1:
            hit = not hit
    return hit


def segs_cross(a, b, c, d):
    def o(p, q, r): return (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
    return o(a, b, c) * o(a, b, d) < 0 and o(c, d, a) * o(c, d, b) < 0


def polys_overlap(p, q):
    if any(inside(v, q) for v in p) or any(inside(v, p) for v in q):
        return True
    for i in range(len(p)):
        for j in range(len(q)):
            if segs_cross(p[i], p[(i + 1) % len(p)], q[j], q[(j + 1) % len(q)]):
                return True
    return False


def rect(front, yaw, width, depth, grow=0.0):
    """A plot: `front` is the middle of its street edge; it runs `depth` away from the street."""
    t = rot((1, 0), yaw); n = rot((0, 1), yaw)   # local +x and +z (towards the street)
    hw = width / 2 + grow
    f = add(front, mul(n, grow)); b = add(front, mul(n, -depth - grow))
    return [add(f, mul(t, -hw)), add(f, mul(t, hw)), add(b, mul(t, hw)), add(b, mul(t, -hw))]


def centred_rect(c, yaw, width, depth, grow=0.0):
    return rect(add(c, mul(rot((0, 1), yaw), depth / 2)), yaw, width, depth, grow)


def bbox(poly):
    return (min(p[0] for p in poly), min(p[1] for p in poly), max(p[0] for p in poly), max(p[1] for p in poly))


# ----------------------------------------------------------------------------- the real map

class RealMap:
    CELL = 60.0

    def __init__(self):
        self.meta = json.load(open(os.path.join(W, "meta.json")))
        self.boundary = [tuple(p) for p in self.meta["boundary"]]
        self.buildings = []     # {id, ring, c, area, public}
        self.segs = []          # (a, b, half width incl. pavement, name, cls, half road width)
        self.paths = []
        self.areas = []         # {k, ring}
        self.nodes = collections.Counter()
        for f in sorted(glob.glob(os.path.join(W, "c_*.json"))):
            cx, cz = [int(v) for v in os.path.basename(f)[2:-5].split("_")]
            ch = json.load(open(f))
            for i, b in enumerate(ch["buildings"]):
                ring = [tuple(p) for p in b["p"]]
                c = (sum(p[0] for p in ring) / len(ring), sum(p[1] for p in ring) / len(ring))
                area = abs(sum(ring[k][0] * ring[(k + 1) % len(ring)][1] - ring[(k + 1) % len(ring)][0] * ring[k][1] for k in range(len(ring)))) / 2
                self.buildings.append({"id": "h_%d_%d_%d" % (cx, cz, i), "ring": ring, "c": c, "area": area, "public": "k" in b})
            for r in ch["roads"]:
                pts = [tuple(p) for p in r["p"]]
                if r["c"] == "path":
                    self.paths.append(pts); continue
                for a, b in zip(pts, pts[1:]):
                    self.segs.append((a, b, r["w"] / 2 + r["s"], r["n"], r["c"], r["w"] / 2))
                self.nodes[pts[0]] += 1; self.nodes[pts[-1]] += 1
            for a in ch["areas"]:
                self.areas.append({"k": a["k"], "ring": [tuple(p) for p in a["p"]]})
        self.bgrid = collections.defaultdict(list)
        for b in self.buildings:
            x0, z0, x1, z1 = bbox(b["ring"])
            for gx in range(int(x0 // self.CELL), int(x1 // self.CELL) + 1):
                for gz in range(int(z0 // self.CELL), int(z1 // self.CELL) + 1):
                    self.bgrid[(gx, gz)].append(b)
        self.sgrid = collections.defaultdict(list)
        for s in self.segs:
            for gx in range(int(min(s[0][0], s[1][0]) // self.CELL) - 1, int(max(s[0][0], s[1][0]) // self.CELL) + 2):
                for gz in range(int(min(s[0][1], s[1][1]) // self.CELL) - 1, int(max(s[0][1], s[1][1]) // self.CELL) + 2):
                    self.sgrid[(gx, gz)].append(s)
        self.junctions = sorted(p for p, n in self.nodes.items() if n >= 3)

    def buildings_near(self, poly):
        x0, z0, x1, z1 = bbox(poly); seen = {}
        for gx in range(int(x0 // self.CELL), int(x1 // self.CELL) + 1):
            for gz in range(int(z0 // self.CELL), int(z1 // self.CELL) + 1):
                for b in self.bgrid.get((gx, gz), []):
                    seen[b["id"]] = b
        return list(seen.values())

    def segs_near(self, p):
        return self.sgrid.get((int(p[0] // self.CELL), int(p[1] // self.CELL)), [])

    def nearest_seg(self, p, max_d=80.0):
        best, best_d = None, max_d
        for s in self.segs_near(p):
            d = seg_point_dist(p, s[0], s[1])
            if d < best_d:
                best, best_d = s, d
        return best, best_d

    def on_road(self, poly, margin=0.0):
        """True if the polygon touches a street (road + pavement)."""
        c = (sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly))
        for s in self.segs_near(c):
            for i in range(len(poly)):
                a, b = poly[i], poly[(i + 1) % len(poly)]
                if segs_cross(a, b, s[0], s[1]):
                    return True
                for q in (a, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2), c):
                    if seg_point_dist(q, s[0], s[1]) < s[2] + margin:
                        return True
        return False

    def area_kind(self, p):
        for a in self.areas:
            if inside(p, a["ring"]):
                return a["k"]
        return ""


# ----------------------------------------------------------------------------- placement

class Placer:
    def __init__(self, real):
        self.real = real
        self.taken = []        # polygons already used (plots, landmarks)
        self.replaced = {}     # real building id -> True

    def clear(self, poly, allow_building_centroids=False):
        """Is the polygon free? Returns (ok, [real buildings it would replace])."""
        if not all(inside(p, self.real.boundary) for p in poly):
            return False, []
        if self.real.on_road(poly):
            return False, []
        for t in self.taken:
            if polys_overlap(poly, t):
                return False, []
        gone = []
        for b in self.real.buildings_near(poly):
            if b["id"] in self.replaced:
                continue
            if polys_overlap(poly, b["ring"]):
                if allow_building_centroids and not b["public"] and inside(b["c"], poly):
                    gone.append(b)
                else:
                    return False, []
        return True, gone

    def take(self, poly, gone=()):
        self.taken.append(poly)
        for b in gone:
            self.replaced[b["id"]] = True

    def front_street(self, home):
        """The street a real house faces: the one nearest the middle of a wall whose doorstep is on open
        ground (the same rule the game uses to put the front door). None if every wall is hemmed in."""
        ring = home["ring"]; c = home["c"]; walls = []
        for i in range(len(ring)):
            p0, p1 = ring[i], ring[(i + 1) % len(ring)]
            if dist(p0, p1) < 2.2:
                continue
            mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2)
            seg, d = self.real.nearest_seg(mid, 60.0)
            if seg is None:
                continue
            t = sub(p1, p0); L = math.hypot(*t); n = (-t[1] / L, t[0] / L)
            if n[0] * (mid[0] - c[0]) + n[1] * (mid[1] - c[1]) < 0:
                n = (-n[0], -n[1])
            walls.append((d, add(mid, mul(n, 1.2)), seg))
        for d, step, seg in sorted(walls, key=lambda w: w[0]):
            box = [add(step, (-0.1, -0.1)), add(step, (0.1, -0.1)), add(step, (0.1, 0.1)), add(step, (-0.1, 0.1))]
            if any(b is not home and inside(step, b["ring"]) for b in self.real.buildings_near(box)):
                continue
            if d > 40.0:
                return None
            return seg[3]
        return None

    def street_spot(self, want, width, depth, max_r=320.0):
        """Clear ground beside a street, facing it; the nearest such spot to `want`."""
        best = None
        for s in self.real.segs:
            if s[4] not in ("street", "collector", "main") or min(dist(s[0], want), dist(s[1], want)) > max_r:
                continue
            t = sub(s[1], s[0]); L = math.hypot(*t)
            if L < 1.0:
                continue
            t = (t[0] / L, t[1] / L)
            for k in range(int(L // 5) + 1):
                base = add(s[0], mul(t, min(L, k * 5.0 + 2.5)))
                for side in (1, -1):
                    n = (t[1] * side, -t[0] * side)        # away from the street
                    front = add(base, mul(n, s[2] + 0.8))
                    d = dist(front, want)
                    if best is not None and d >= best[0]:
                        continue
                    yaw = math.atan2(-n[0], -n[1])         # facing the street
                    poly = rect(front, yaw, width, depth, 0.6)
                    ok, _ = self.clear(poly)
                    if ok:
                        best = (d, front, yaw, poly)
        return best

    def open_spot(self, want, width, depth, max_r=420.0):
        """A clear axis-aligned rectangle on open ground (parks and pitches preferred)."""
        best = None
        step = 6.0
        n = int(max_r // step)
        for ix in range(-n, n + 1):
            for iz in range(-n, n + 1):
                c = (want[0] + ix * step, want[1] + iz * step)
                d = dist(c, want)
                if d > max_r:
                    continue
                kind = self.real.area_kind(c)
                score = d + (0 if kind in ("park", "pitch", "playground", "dunes", "sports") else 140)
                if best is not None and score >= best[0]:
                    continue
                poly = centred_rect(c, 0.0, width, depth, 0.8)
                ok, _ = self.clear(poly)
                if ok:
                    best = (score, c, poly)
        return best


def nearest_street_name(real, p):
    seg, _ = real.nearest_seg(p, 120.0)
    return seg[3] if seg and seg[3] else "Westridge"


# ----------------------------------------------------------------------------- one sector

def relocate(real, placer, did, old_name, new_name, anchor, description, reports):
    area = json.load(open(os.path.join(ROOT, "data/districts/%s.json" % old_name)))
    houses = json.load(open(os.path.join(ROOT, area.get("houses_file", "res://data/houses/starter_houses.json").replace("res://", ""))))
    ob = area["bounds"]; old_centre = ((ob[0] + ob[2]) / 2, (ob[1] + ob[3]) / 2)
    homes = sorted((b for b in real.buildings if not b["public"] and 30 <= b["area"] <= 450), key=lambda b: dist(b["c"], anchor))
    address_map = {}
    used_numbers = collections.defaultdict(set)
    # Every story home is a real house. A family whose street is a real one here (the Excelsior
    # Street block) gets a house on that street; blocks of flats get the bigger outlines.
    for h in houses["houses"]:
        flats = h.get("kit") == "flats"
        pick = None
        for strict in (True, False):
            for b in homes:
                if b["id"] in placer.replaced:
                    continue
                if dist(b["c"], anchor) > (300 if strict else 450):
                    break
                if (flats and b["area"] < 120) or (not flats and b["area"] > 260):
                    continue
                street = placer.front_street(b)
                if street is None or (strict and street != h["street"]):
                    continue
                pick = (b, street); break
            if pick:
                break
        if pick is None:
            raise SystemExit("no real house for %s" % h["id"])
        b, street = pick
        placer.replaced[b["id"]] = True          # taken: not offered to another family
        placer.taken.append(b["ring"])
        old_address = "%d %s" % (h["number"], h["street"])
        street = street or nearest_street_name(real, b["c"])
        number = h["number"]
        while number in used_numbers[street]:
            number += 2
        used_numbers[street].add(number)
        h["street"] = street; h["number"] = number
        h["real_id"] = b["id"]
        h["position"] = [round(b["c"][0], 2), round(b["c"][1], 2)]   # the game puts it at the real front door when it loads
        address_map[old_address] = "%d %s" % (number, street)
    # Landmarks.
    new_landmarks = []; moved = []   # (old landmark, old pos, old rot, new pos, new yaw)
    for lm in area.get("landmarks", []):
        typ = lm["type"]; w, d, mode = FOOTPRINT[typ]
        if "size" in lm:
            w, d = lm["size"][0] + 2, lm["size"][1] + 2
        old = tuple(lm["position"])
        want = add(anchor, mul(sub(old, old_centre), 1.2))
        old_rot = OLD_ROT.get(lm.get("facing", "south"), 0.0)
        if mode == "street":
            got = placer.street_spot(want, w, d)
            if got is None:
                raise SystemExit("no street spot for %s in %s" % (typ, did))
            _, front, yaw, poly = got
            centre = add(front, mul(rot((0, 1), yaw), -d / 2))
        else:
            got = placer.open_spot(want, w, d)
            if got is None:
                raise SystemExit("no open ground for %s in %s" % (typ, did))
            _, centre, poly = got; yaw = 0.0; old_rot = 0.0
        placer.take(poly)
        lm["position"] = [round(centre[0], 2), round(centre[1], 2)]
        lm["yaw"] = round(math.degrees(yaw), 2)
        lm.pop("facing", None)
        new_landmarks.append(lm); moved.append((old, old_rot, centre, yaw))
        reports.append("%s %s -> %s (%s)" % (did, typ, lm["position"], nearest_street_name(real, centre)))
    area["landmarks"] = new_landmarks
    # Points of interest ride with their landmark; a loose one gets a small clear spot.
    poi_new = {}
    for poi in area.get("pois", []):
        old = tuple(poi["position"])
        near = min(moved, key=lambda m: dist(m[0], old)) if moved else None
        if near and dist(near[0], old) <= 14.0:
            local = rot(sub(old, near[0]), -near[1])
            p = add(near[2], rot(local, near[3]))
        else:
            got = placer.street_spot(add(anchor, mul(sub(old, old_centre), 1.2)), 3, 3)
            p = add(got[1], mul(rot((0, 1), got[2]), -1.5)); placer.take(got[3])
        poi["position"] = [round(p[0], 2), round(p[1], 2)]
        poi_new[poi["id"]] = p
    for k in area.get("kickabouts", []):
        k["center"] = [round(v, 2) for v in poi_new[k["poi"]]]
    # Patrol routes: round the junctions near the anchor; a route that began at a point of interest still does.
    old_pois = {tuple(json.load(open(os.path.join(ROOT, "data/districts/%s.json" % old_name)))["pois"][i]["position"]): p["id"]
                for i, p in enumerate(area.get("pois", []))}
    ring = sorted((j for j in real.junctions if 35 < dist(j, anchor) < 150), key=lambda j: math.atan2(j[1] - anchor[1], j[0] - anchor[0]))
    for name, pts in area.get("patrol_routes", {}).items():
        n = len(pts); out = []
        for i in range(n):
            j = ring[(i * len(ring)) // n] if ring else add(anchor, rot((70, 0), i * 2 * math.pi / n))
            out.append([round(j[0] + 3.5, 2), round(j[1] + 3.5, 2)])
        first = tuple(pts[0])
        for old_p, pid in old_pois.items():
            if dist(old_p, first) < 1.0:
                out[0] = [round(v, 2) for v in poi_new[pid]]
        area["patrol_routes"][name] = out
    # Drivable cars: parked at the kerb of a real street, near the anchor.
    cars = []
    for i, c in enumerate(car for car in area.get("parked_cars", []) if car.get("drivable")):
        want = add(anchor, rot((30 + 40 * i, 0), i * 2.3))
        seg, _ = real.nearest_seg(want, 200.0)
        t = sub(seg[1], seg[0]); L = math.hypot(*t); t = (t[0] / L, t[1] / L)
        left = (t[1], -t[0])
        p = add(add(seg[0], mul(t, L / 2)), mul(left, seg[5] - 1.2))
        c["position"] = [round(p[0], 2), round(p[1], 2)]
        c["rot"] = round(math.degrees(math.atan2(t[0], t[1])) - 90.0, 1)
        cars.append(c)
    area["parked_cars"] = cars
    for key in ("streets", "decals", "traffic", "real", "ground_margin", "open_sides", "backdrop_skip", "neighbours", "ground_texture", "ground_tint"):
        area.pop(key, None)
    area["streets"] = []
    area["display_name"] = new_name
    area["street_name"] = new_name
    area["anchor"] = [anchor[0], anchor[1]]
    pts = [tuple(h["position"]) for h in houses["houses"]] + [tuple(l["position"]) for l in new_landmarks]
    area["bounds"] = [round(min(p[0] for p in pts) - 40), round(min(p[1] for p in pts) - 40), round(max(p[0] for p in pts) + 40), round(max(p[1] for p in pts) + 40)]
    area["houses_file"] = "res://data/houses/%s_houses.json" % old_name if old_name != "starter" else "res://data/houses/starter_houses.json"
    os.makedirs(os.path.join(OUT, "districts"), exist_ok=True); os.makedirs(os.path.join(OUT, "houses"), exist_ok=True)
    json.dump(area, open(os.path.join(OUT, "districts/%s.json" % old_name), "w"), indent=1)
    json.dump(houses, open(os.path.join(OUT, area["houses_file"].replace("res://data/", "")), "w"), indent=1)
    return address_map


def main():
    real = RealMap()
    placer = Placer(real)
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    os.makedirs(OUT)
    reports = []; addresses = {}
    for did, old_name, new_name, anchor, description in SECTORS:
        addresses[did] = relocate(real, placer, did, old_name, new_name, anchor, description, reports)
    # The catalog: the four sectors keep their ids and unlock rules; nothing else is planned.
    cat = json.load(open(os.path.join(ROOT, "data/districts/districts.json")))
    by_id = {s[0]: s for s in SECTORS}
    out = []
    for d in cat["districts"]:
        if d["id"] not in by_id:
            continue
        _, old_name, new_name, anchor, description = by_id[d["id"]]
        d["display_name"] = new_name; d["description"] = description; d["anchor"] = [anchor[0], anchor[1]]
        d["data"] = "res://data/districts/%s.json" % old_name
        if d["id"] != "starter":
            dx, dz = anchor[0] - by_id["starter"][3][0], anchor[1] - by_id["starter"][3][1]
            d["side"] = ("south" if dz > 0 else "north") if abs(dz) > abs(dx) else ("east" if dx > 0 else "west")
        out.append(d)
    json.dump({"real_world": "res://data/world/westridge/", "districts": out}, open(os.path.join(OUT, "districts/districts.json"), "w"), indent=1)
    # Text: old addresses and old suburb names, in every data file that holds words.
    all_addr = {}
    for m in addresses.values():
        all_addr.update(m)
    changed = 0
    for sub_dir in ("missions", "npcs", "story", "factions", "events", "dealing", "progression"):
        for f in sorted(glob.glob(os.path.join(ROOT, "data", sub_dir, "*.json"))):
            s = open(f).read(); o = s
            for old in sorted(all_addr, key=len, reverse=True):
                s = re.sub(r"\b%s\b" % re.escape(old), "\x00" + all_addr[old] + "\x00", s)
            s = s.replace("\x00", "")
            for old, new in RENAME.items():
                s = s.replace(old, new)
            if s != o:
                os.makedirs(os.path.join(OUT, sub_dir), exist_ok=True)
                open(os.path.join(OUT, sub_dir, os.path.basename(f)), "w").write(s); changed += 1
    print("\n".join(reports))
    print("story homes in real houses:", sum(len(m) for m in addresses.values()), "| text files rewritten:", changed)


if __name__ == "__main__":
    main()
