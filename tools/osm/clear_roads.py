#!/usr/bin/env python3
"""Pulls building outlines off the carriageway. The Microsoft footprints and the OpenStreetMap streets do not agree to the
metre, so about 40 houses in Westridge reach 1 to 3 m onto a street (a corner of roof and wall standing in the road). Each
outline corner that lies closer to a street's centre line than half its width plus a kerb is moved straight away from it,
to that distance. Footpaths are not roads. Runs on data/world/westridge/ in place; safe to run again.

Run after tools/osm/build_westridge.py (which calls it). Design: design/gdd/real_world.md ("Buildings").
  python3 tools/osm/clear_roads.py [--dry]
"""
import collections
import glob
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WORLD = os.path.join(ROOT, "data", "world", "westridge")
KERB = 0.5            # metres of kerb and gutter kept clear beyond the carriageway
GRID = 20.0
SKIP_KINDS = ()       # building kinds that are left alone (none: every outline is pulled off the road)


def load_segments(chunks):
    segs = []
    for d in chunks.values():
        for r in d["roads"]:
            if r["c"] == "path" or len(r["p"]) < 2:
                continue
            p = r["p"]
            for i in range(len(p) - 1):
                segs.append((p[i][0], p[i][1], p[i + 1][0], p[i + 1][1], r["w"] / 2.0 + KERB))
    index = collections.defaultdict(list)
    for s in segs:
        for gx in range(int((min(s[0], s[2]) - 12) // GRID), int((max(s[0], s[2]) + 12) // GRID) + 1):
            for gy in range(int((min(s[1], s[3]) - 12) // GRID), int((max(s[1], s[3]) + 12) // GRID) + 1):
                index[(gx, gy)].append(s)
    return index


def nearest_on(px, py, s):
    x1, y1, x2, y2 = s[:4]
    dx, dy = x2 - x1, y2 - y1
    l = dx * dx + dy * dy
    t = 0.0 if l == 0 else max(0.0, min(1.0, ((px - x1) * dx + (py - y1) * dy) / l))
    return x1 + t * dx, y1 + t * dy


def push_out(point, index):
    """The point moved off any street it is too close to (a few passes: a corner can sit between two streets)."""
    x, y = point
    for _ in range(4):
        moved = False
        for s in index[(int(x // GRID), int(y // GRID))]:
            nx, ny = nearest_on(x, y, s)
            d = math.hypot(x - nx, y - ny)
            if d < s[4] - 0.05:
                if d < 1e-6:   # exactly on the line: step to the side of the street
                    ux, uy = -(s[3] - s[1]), s[2] - s[0]
                    n = math.hypot(ux, uy) or 1.0
                    ux, uy = ux / n, uy / n
                else:
                    ux, uy = (x - nx) / d, (y - ny) / d
                x, y = nx + ux * s[4], ny + uy * s[4]
                moved = True
        if not moved:
            break
    return [round(x, 1), round(y, 1)]


def main(world=WORLD, dry=False):
    files = sorted(glob.glob(os.path.join(world, "c_*.json")))
    chunks = {f: json.load(open(f)) for f in files}
    index = load_segments(chunks)
    houses = changed = corners = 0
    worst = 0.0
    for f, d in chunks.items():
        dirty = False
        for b in d["buildings"]:
            if b.get("k") in SKIP_KINDS:
                continue
            new = [push_out(p, index) for p in b["p"]]
            move = max(math.hypot(a[0] - c[0], a[1] - c[1]) for a, c in zip(b["p"], new))
            if move > 0.05:
                changed += 1
                corners += sum(1 for a, c in zip(b["p"], new) if math.hypot(a[0] - c[0], a[1] - c[1]) > 0.05)
                worst = max(worst, move)
                b["p"] = new
                dirty = True
            houses += 1
        if dirty and not dry:
            json.dump(d, open(f, "w"), separators=(",", ":"))
    print("buildings %d, pulled off a street %d (%d corners), the biggest move %.1f m%s" % (houses, changed, corners, worst, " (dry run)" if dry else ""))
    return changed


if __name__ == "__main__":
    main(dry="--dry" in sys.argv)
