#!/usr/bin/env python3
"""Gives the unnamed building outlines that stand inside school grounds, the shopping centre, sports
grounds and parks a kind ("k"), so the game builds them as classroom blocks, shops or pavilions instead
of homes (no front door, yard or residents). Runs on data/world/westridge/ in place; safe to run again.

The game's own family homes (data/houses/*.json "real_id") are never changed.
Run after tools/osm/build_westridge.py (which calls it). Design: design/gdd/real_world.md ("Buildings").
"""
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WORLD = os.path.join(ROOT, "data", "world", "westridge")
# area kind -> building kind given to an unnamed outline whose centre lies inside it
KINDS = {"school": "school_block", "retail": "shop_block", "sports": "sports_block",
         "park": "park_building", "pitch": "park_building", "playground": "park_building", "pool": "pool_building"}


def inside(p, ring):
    x, y = p
    c = False
    for i in range(len(ring)):
        x1, y1 = ring[i]
        x2, y2 = ring[i - 1]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            c = not c
    return c


def centre(ring):
    return (sum(p[0] for p in ring) / len(ring), sum(p[1] for p in ring) / len(ring))


def story_ids():
    ids = set()
    for f in glob.glob(os.path.join(ROOT, "data", "houses", "*.json")):
        for h in json.load(open(f)).get("houses", []):
            if h.get("real_id"):
                ids.add(h["real_id"])
    return ids


def main(world=WORLD):
    files = sorted(glob.glob(os.path.join(world, "c_*.json")))
    chunks = {f: json.load(open(f)) for f in files}
    areas = [a for d in chunks.values() for a in d.get("areas", []) if a["k"] in KINDS]
    keep = story_ids()
    changed = {}
    for f, d in chunks.items():
        cx, cz = (int(v) for v in os.path.basename(f)[2:-5].split("_"))
        for i, b in enumerate(d.get("buildings", [])):
            if b.get("k") or "h_%d_%d_%d" % (cx, cz, i) in keep:
                continue
            c = centre(b["p"])
            for a in areas:
                if inside(c, a["p"]):
                    b["k"] = KINDS[a["k"]]
                    changed[b["k"]] = changed.get(b["k"], 0) + 1
                    break
    for f, d in chunks.items():
        json.dump(d, open(f, "w"), separators=(",", ":"))
    print("classified:", changed)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else WORLD)
