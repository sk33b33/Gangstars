"""Builds data/world/mitchells_plain_real.json from raw OpenStreetMap tiles.

  python3 tools/osm/fetch_osm.py <raw_dir>            # downloads the tiles (api.openstreetmap.org)
  python3 tools/osm/build_real_map.py <raw_dir>       # writes the two data files

Coordinates are metres from the centre of the KnoxMap outline: x = east, z = south (Godot's
-z is north). Map data (c) OpenStreetMap contributors, ODbL 1.0.
"""
import sys, glob, json, math, os
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PRESET = json.load(open(os.path.join(ROOT, "data/world/mitchells_plain.knoxmap.json")))
LAT0 = (PRESET["south"] + PRESET["north"]) / 2
LON0 = (PRESET["west"] + PRESET["east"]) / 2
M_LAT = 110574.0
M_LON = 111320.0 * math.cos(math.radians(LAT0))
MAIN = {"motorway": "freeway", "motorway_link": "freeway", "trunk": "freeway", "primary": "main", "primary_link": "main",
        "secondary": "main", "secondary_link": "main", "tertiary": "collector", "tertiary_link": "collector"}
LOCAL = {"residential": "street", "unclassified": "street", "living_street": "street"}


def xz(lat, lon):
    return [round((lon - LON0) * M_LON, 1), round(-(lat - LAT0) * M_LAT, 1)]


OUTLINE = [xz(lat, lon) for lon, lat in PRESET["shape"]["coordinates"][0][0]]


def inside(p):
    x, z = p; hit = False
    for i in range(len(OUTLINE) - 1):
        (x1, z1), (x2, z2) = OUTLINE[i], OUTLINE[i + 1]
        if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1:
            hit = not hit
    return hit


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


def main(raw):
    nodes, ways, suburbs, stations = {}, {}, {}, {}
    for f in sorted(glob.glob(raw + "/t_*.osm")):
        for el in ET.parse(f).getroot():
            if el.tag == "node":
                nodes[el.get("id")] = (float(el.get("lat")), float(el.get("lon")))
                tags = {t.get("k"): t.get("v") for t in el.findall("tag")}
                if tags.get("place") == "suburb" and tags.get("name"):
                    suburbs[el.get("id")] = {"name": tags["name"], "at": xz(*nodes[el.get("id")])}
                if tags.get("railway") == "station" and tags.get("name"):
                    stations[tags["name"]] = {"name": tags["name"], "at": xz(*nodes[el.get("id")])}
            elif el.tag == "way":
                ways[el.get("id")] = ({t.get("k"): t.get("v") for t in el.findall("tag")}, [n.get("ref") for n in el.findall("nd")])
    roads, streets, rails = [], [], []
    for tags, refs in ways.values():
        pts = [xz(*nodes[r]) for r in refs if r in nodes]
        if len(pts) < 2 or not any(inside(p) for p in pts):
            continue
        hw = tags.get("highway")
        if hw in MAIN:
            roads.append({"class": MAIN[hw], "name": tags.get("name", ""), "pts": simplify(pts, 2.0)})
        elif hw in LOCAL:
            streets.append({"name": tags.get("name", ""), "pts": simplify(pts, 1.0)})
        elif tags.get("railway") == "rail" and tags.get("service") is None:
            rails.append(simplify(pts, 3.0))
    credit = "Map data (c) OpenStreetMap contributors, ODbL 1.0 (openstreetmap.org/copyright)"
    real = {"credit": credit, "origin": {"lat": LAT0, "lon": LON0}, "outline": OUTLINE, "roads": roads, "rail": rails,
            "suburbs": sorted((s for s in suburbs.values() if inside(s["at"])), key=lambda s: s["name"]),
            "stations": sorted((s for s in stations.values() if inside(s["at"])), key=lambda s: s["name"])}
    out = os.path.join(ROOT, "data/world")
    json.dump(real, open(os.path.join(out, "mitchells_plain_real.json"), "w"), separators=(",", ":"))
    json.dump({"credit": credit, "streets": streets}, open(os.path.join(out, "mitchells_plain_streets.json"), "w"), separators=(",", ":"))
    print("main roads", len(roads), "streets", len(streets), "rail", len(rails), "suburbs", [s["name"] for s in real["suburbs"]],
          "stations", [s["name"] for s in real["stations"]])


if __name__ == "__main__":
    main(sys.argv[1])
