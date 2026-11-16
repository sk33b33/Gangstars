"""Builds data/world/westridge/ : the real Westridge, Mitchells Plain, in 200 m chunks.

  python3 tools/osm/fetch_osm.py <raw_osm_dir>
  curl -o sa.csv.gz <Microsoft GlobalMLBuildingFootprints, RegionName=SouthAfrica, quadkey=300231032>
  python3 tools/osm/build_westridge.py <raw_osm_dir> <sa.csv.gz>

Streets, parks, schools and named buildings: (c) OpenStreetMap contributors, ODbL 1.0.
House outlines: Microsoft GlobalMLBuildingFootprints (ODbL 1.0); OpenStreetMap has only the public
buildings in Westridge, not the houses.

Coordinates: metres from the Westridge suburb point, x = east, z = south (true north is -z).
Westridge is taken as the land between Morgenster Road (north), Eisleben Road (east), Spine Road
(south), Weltevreden Road and Dagbreek Avenue (west).
"""
import sys, glob, json, math, os, gzip, collections, shutil
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "data/world/westridge")
LAT0, LON0 = -34.038101499999996, 18.616246999999987     # origin of data/world/mitchells_plain_real.json
M_LAT = 110574.0
M_LON = 111320.0 * math.cos(math.radians(LAT0))
NODE = (-1244.2, 1509.5)                                  # the Westridge suburb point in that file's metres
CHUNK = 200.0
BOUNDARY = [(-862, -962), (150, -1187), (375, -550), (425, -212), (700, 500), (925, 1137), (575, 1312), (-150, 1560),
            (-1137, 475), (-637, 225), (-775, 100), (-925, -500)]
MARGIN = 60.0   # roads and buildings up to this far outside the boundary are kept, so the edge roads are whole
ROAD = {  # class -> [width, pavement each side]
    "primary": ("main", 7.5, 2.5), "primary_link": ("main", 6.0, 2.0), "secondary": ("main", 7.5, 2.5), "secondary_link": ("main", 6.0, 2.0),
    "tertiary": ("collector", 7.0, 2.0), "tertiary_link": ("collector", 6.0, 2.0),
    "residential": ("street", 6.0, 1.8), "unclassified": ("street", 6.0, 1.8), "living_street": ("street", 5.0, 1.5),
    "service": ("lane", 4.0, 0.0), "footway": ("path", 1.6, 0.0), "path": ("path", 1.4, 0.0), "pedestrian": ("path", 3.0, 0.0), "steps": ("path", 1.6, 0.0),
}
AREA = {("leisure", "park"): "park", ("leisure", "garden"): "park", ("leisure", "playground"): "playground", ("leisure", "pitch"): "pitch",
        ("leisure", "nature_reserve"): "dunes", ("natural", "heath"): "dunes", ("natural", "scrub"): "dunes", ("landuse", "grass"): "park",
        ("amenity", "school"): "school", ("amenity", "parking"): "parking", ("landuse", "retail"): "retail", ("leisure", "swimming_pool"): "pool",
        ("leisure", "sports_centre"): "sports"}


def xz(lat, lon):
    return ((lon - LON0) * M_LON - NODE[0], -(lat - LAT0) * M_LAT - NODE[1])


def inside(p, poly=BOUNDARY):
    x, z = p; hit = False
    for i in range(len(poly)):
        (x1, z1), (x2, z2) = poly[i], poly[(i + 1) % len(poly)]
        if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1:
            hit = not hit
    return hit


def dist_to_boundary(p):
    best = 1e9
    for i in range(len(BOUNDARY)):
        (ax, az), (bx, bz) = BOUNDARY[i], BOUNDARY[(i + 1) % len(BOUNDARY)]
        dx, dz = bx - ax, bz - az
        t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - az) * dz) / (dx * dx + dz * dz)))
        best = min(best, math.hypot(p[0] - ax - t * dx, p[1] - az - t * dz))
    return best


def near(p):
    return inside(p) or dist_to_boundary(p) < MARGIN


def simplify(pts, tol):
    if len(pts) < 3:
        return pts
    (ax, az), (bx, bz) = pts[0], pts[-1]
    dx, dz = bx - ax, bz - az; L = math.hypot(dx, dz) or 1e-9
    best, idx = 0.0, 0
    for i in range(1, len(pts) - 1):
        d = abs((pts[i][0] - ax) * dz - (pts[i][1] - az) * dx) / L
        if d > best: best, idx = d, i
    if best <= tol:
        return [pts[0], pts[-1]]
    return simplify(pts[:idx + 1], tol)[:-1] + simplify(pts[idx:], tol)


def ring(pts, tol):
    """Simplifies a closed ring (first == last dropped); returns it counter-clockwise seen from above (x east, z south)."""
    if pts[0] == pts[-1]:
        pts = pts[:-1]
    if len(pts) < 3:
        return []
    far = max(range(len(pts)), key=lambda i: (pts[i][0] - pts[0][0]) ** 2 + (pts[i][1] - pts[0][1]) ** 2)
    a = simplify(pts[:far + 1], tol); b = simplify(pts[far:] + [pts[0]], tol)
    out = a[:-1] + b[:-1]
    if len(out) < 3:
        return []
    if area2(out) < 0:
        out.reverse()
    return out


def area2(p):
    return sum(p[i][0] * p[(i + 1) % len(p)][1] - p[(i + 1) % len(p)][0] * p[i][1] for i in range(len(p)))


def centroid(p):
    return (sum(q[0] for q in p) / len(p), sum(q[1] for q in p) / len(p))


def rnd(p):
    return [[round(q[0], 1), round(q[1], 1)] for q in p]


def chunk_of(p):
    return (math.floor(p[0] / CHUNK), math.floor(p[1] / CHUNK))


def densify(pts, step=20.0):
    out = [pts[0]]
    for a, b in zip(pts, pts[1:]):
        n = max(1, int(math.ceil(math.hypot(b[0] - a[0], b[1] - a[1]) / step)))
        for i in range(1, n + 1):
            out.append((a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n))
    return out


def road_rec(tags, cls, width, pave, oneway, run):
    rec = {"n": tags.get("name", ""), "c": cls, "w": width, "s": pave, "p": rnd(run)}
    if oneway:
        rec["o"] = 1
    return rec


def main(raw, ms_file):
    nodes, ways = {}, {}
    for f in sorted(glob.glob(raw + "/t_*.osm")):
        for el in ET.parse(f).getroot():
            if el.tag == "node":
                nodes[el.get("id")] = xz(float(el.get("lat")), float(el.get("lon")))
            elif el.tag == "way":
                ways[el.get("id")] = ({t.get("k"): t.get("v") for t in el.findall("tag")}, [n.get("ref") for n in el.findall("nd")])
    chunks = collections.defaultdict(lambda: {"roads": [], "buildings": [], "areas": []})
    counts = collections.Counter()
    landmarks, street_names, osm_buildings = [], set(), []
    # Junctions: a node used by two road ways (or twice by one). Ways are cut there, so every
    # junction is the end of a road piece and traffic can turn at it.
    uses = collections.Counter()
    for tags, refs in ways.values():
        if tags.get("highway") in ROAD and ROAD[tags["highway"]][0] != "path":
            for i, r in enumerate(refs):
                uses[r] += 1 if 0 < i < len(refs) - 1 else 2   # an end always counts as a junction
    sections = []   # (tags, [points])
    for wid, (tags, refs) in sorted(ways.items()):
        hw = tags.get("highway")
        if hw not in ROAD:
            continue
        refs = [r for r in refs if r in nodes]
        if len(refs) < 2:
            continue
        if ROAD[hw][0] == "path":
            sections.append((tags, [nodes[r] for r in refs]))
            continue
        run = [refs[0]]
        for r in refs[1:]:
            run.append(r)
            if uses[r] >= 2:
                sections.append((tags, [nodes[q] for q in run]))
                run = [r]
        if len(run) > 1:
            sections.append((tags, [nodes[q] for q in run]))
    for tags, pts in sections:
        hw = tags.get("highway")
        if True:
            if not any(near(p) for p in pts):
                continue
            cls, width, pave = ROAD[hw]
            oneway = tags.get("oneway") in ("yes", "1", "true") or tags.get("junction") == "roundabout"
            line = densify(simplify(pts, 0.6))
            run, run_chunk = [line[0]], None
            for a, b in zip(line, line[1:]):
                mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
                c = chunk_of(mid)
                keep = near(mid)
                if run_chunk is not None and (c != run_chunk or not keep):
                    if len(run) > 1:
                        chunks[run_chunk]["roads"].append(road_rec(tags, cls, width, pave, oneway, run))
                    run = [a]
                if keep:
                    run.append(b); run_chunk = c
                else:
                    run = [b]; run_chunk = None
            if run_chunk is not None and len(run) > 1:
                chunks[run_chunk]["roads"].append(road_rec(tags, cls, width, pave, oneway, run))
            counts["road_" + cls] += 1
            if tags.get("name") and cls != "path":
                street_names.add(tags["name"])
    for wid, (tags, refs) in sorted(ways.items()):
        if tags.get("highway") in ROAD:
            continue
        pts = [nodes[r] for r in refs if r in nodes]
        if len(pts) < 2:
            continue
        closed = refs[0] == refs[-1] and len(pts) >= 4
        if not closed:
            continue
        c = centroid(pts[:-1])
        if "building" in tags:
            if inside(c):
                osm_buildings.append((ring(pts, 0.4), tags))
            continue
        for (k, v), kind in AREA.items():
            if tags.get(k) == v and inside(c):
                r = ring(pts, 1.0)
                if r:
                    chunks[chunk_of(c)]["areas"].append({"k": kind, "n": tags.get("name", ""), "p": rnd(r)})
                    counts["area_" + kind] += 1
                    if tags.get("name"):
                        landmarks.append({"name": tags["name"], "kind": kind, "at": [round(c[0], 1), round(c[1], 1)]})
                break
    # Houses: Microsoft footprints inside the boundary.
    lat_lo, lat_hi = LAT0 - (NODE[1] + 1700) / M_LAT, LAT0 - (NODE[1] - 1300) / M_LAT
    lon_lo, lon_hi = LON0 + (NODE[0] - 1250) / M_LON, LON0 + (NODE[0] + 1050) / M_LON
    ms = []
    for line in gzip.open(ms_file, "rt"):
        i = line.find('"coordinates"')
        j = line.find("[[[", i)
        k = line.find(",", j)
        lon = float(line[j + 3:k])
        if not (lon_lo < lon < lon_hi):
            continue
        feat = json.loads(line)
        coords = feat["geometry"]["coordinates"][0]
        if not (lat_lo < coords[0][1] < lat_hi):
            continue
        pts = [xz(la, lo) for lo, la in coords]
        c = centroid(pts[:-1])
        if not inside(c):
            continue
        r = ring(pts, 0.35)
        if len(r) < 3 or abs(area2(r)) / 2 < 12.0:
            continue
        ms.append({"p": r, "c": c, "h": float(feat["properties"].get("height", -1.0)), "a": abs(area2(r)) / 2})
    # Named public buildings from OpenStreetMap: label the footprint they sit on, or add them.
    for r, tags in osm_buildings:
        if not r:
            continue
        c = centroid(r)
        kind = tags.get("amenity") or tags.get("shop") or tags.get("leisure") or (tags["building"] if tags["building"] != "yes" else "")
        hit = None
        for b in ms:
            if abs(b["c"][0] - c[0]) < 40 and abs(b["c"][1] - c[1]) < 40 and (inside(b["c"], r) or inside(c, b["p"])):
                hit = b; break
        if hit is None:
            hit = {"p": r, "c": c, "h": -1.0, "a": abs(area2(r)) / 2}
            ms.append(hit)
        hit["n"] = tags.get("name", ""); hit["k"] = kind
        if tags.get("building:levels"):
            hit["h"] = 3.0 * float(tags["building:levels"])
        if tags.get("name"):
            landmarks.append({"name": tags["name"], "kind": kind or "building", "at": [round(c[0], 1), round(c[1], 1)]})
    for b in ms:
        h = b["h"]
        if h <= 0:
            h = 3.0 if b["a"] < 220 else (3.4 if b["a"] < 600 else 5.5)
            if b.get("k") in ("place_of_worship", "church"): h = 7.0
            if b.get("k") in ("school", "community_centre", "sports_hall"): h = 6.0
        rec = {"p": rnd(b["p"]), "h": round(min(h, 12.0), 1)}
        if b.get("k"): rec["k"] = b["k"]
        if b.get("n"): rec["n"] = b["n"]
        chunks[chunk_of(b["c"])]["buildings"].append(rec)
        counts["buildings"] += 1
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    os.makedirs(OUT)
    keys = sorted(chunks)
    for (cx, cz) in keys:
        json.dump(chunks[(cx, cz)], open(os.path.join(OUT, "c_%d_%d.json" % (cx, cz)), "w"), separators=(",", ":"))
    meta = {"credit": "Streets and places (c) OpenStreetMap contributors, ODbL 1.0. House outlines: Microsoft GlobalMLBuildingFootprints, ODbL 1.0.",
            "origin": {"lat": LAT0 - NODE[1] / M_LAT, "lon": LON0 + NODE[0] / M_LON}, "chunk": CHUNK, "boundary": rnd(BOUNDARY),
            "chunks": [[cx, cz] for cx, cz in keys], "counts": dict(counts), "streets": sorted(street_names),
            "landmarks": sorted(landmarks, key=lambda l: l["name"])}
    json.dump(meta, open(os.path.join(OUT, "meta.json"), "w"), indent=1)
    size = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT))
    print(dict(counts)); print("chunks", len(keys), "streets", len(street_names), "landmarks", len(landmarks), "bytes", size)
    import classify_buildings   # unnamed outlines in school grounds, shops, sports grounds, parks
    classify_buildings.main(OUT)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
