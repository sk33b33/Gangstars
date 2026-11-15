# Real Westridge world

Status: stage 1 of 4 done (2026-11-15). Code: `scripts/world/real/`. Data: `data/world/westridge/`.
Tool: `tools/osm/build_westridge.py`. Preview scene: `scenes/real/real_westridge.tscn`.

## 1. Overview

The game moves from five small made-up districts to **one accurate district: the whole of real Westridge,
Mitchells Plain** (about 1.6 km by 2.5 km). Streets follow their real lines, bends and angles. Every real
building outline gets a building. The world is cut into 200 m pieces ("chunks") that are built when you come
near and freed when you leave; a desktop builds all of them, a phone only those around you.

| Stage | What | State |
|---|---|---|
| 1 | Real data, the new builder, loading in pieces, a walk-around preview | done |
| 2 | People: navigation on the real streets, residents living in real houses, traffic on real roads | next |
| 3 | The game moves in: safehouse, shops, missions, crews, turf, police, survival spots, saves; turf sectors inside Westridge replace the locked districts | |
| 4 | The old districts (Lentegeur, Rocklands, Town Centre, Tafelsig, old Westridge) and their code are removed; phone tuning; Windows build | |

Until stage 3 is finished the existing game keeps running unchanged, and the real Westridge is a preview you
open from the pause menu. Nothing is removed before its replacement works.

## 2. Player Fantasy

This is Westridge as it is: you can find Excelsior Street, walk down Park Avenue to the Civic Centre, cross
Wespoort Drive, cut through Westridge Gardens. Someone who lives there recognises the streets.

## 3. Detailed Rules

### Data (built once by the tool, stored in the project)
- **Streets, footpaths, parks, pitches, school grounds, parking, named public buildings:** OpenStreetMap.
- **House outlines:** Microsoft GlobalMLBuildingFootprints (open data). OpenStreetMap has only 65 public buildings in
  Westridge and none of the houses, so the outlines come from this second source. They were traced from aerial
  images by a program: most houses are right, some neighbours are merged into one outline.
- **Boundary:** Morgenster Road (north), Eisleben Road (east), Spine Road (south), Weltevreden Road and Dagbreek
  Avenue (west). OpenStreetMap has no outline for the suburb, so this is drawn along those roads.
- Coordinates are metres from the Westridge suburb point: x east, z south. True north is -z: nothing is turned.
- Each chunk file holds road pieces (name, class, width, pavement width, points), buildings (outline, height, and
  for public buildings a kind and name) and areas (kind, name, outline). A road is cut into pieces of at most 20 m
  steps and each piece belongs to the chunk its middle lies in, so no piece is drawn twice.

### Builder (`RealChunkBuilder`)
- A road is a flat ribbon along its points, mitred at bends, with a round cap at both ends. Pavements are a wider
  ribbon underneath, so junctions at any angle close without gaps. Main roads and collectors get centre dashes.
- Footpaths are narrow paved ribbons. Parks, pitches, school grounds, parking, dunes and the pool are flat coloured areas.
- A building is walls on its outline up to its height plus a roof: a low hip roof for house-sized convex outlines,
  flat otherwise. Paint and roof type are picked from the outline's position, so a house always looks the same.
- Named streets get a sign every piece longer than 35 m; named buildings get a label.
- Everything in a chunk is merged into one mesh per material and one collision body for the walls.

### Loading (`RealWorld`)
- Every half second (when you have moved 10 m or work is waiting) the chunks within `load_radius` are queued,
  nearest first, and `builds_per_frame` of them are built per frame.
- Chunks further than `load_radius + unload_margin` are freed.
- `load_radius` infinite means the whole suburb is built and kept (desktop). On a touchscreen it is 320 m.

## 4. Formulas

- Chunk of a point: `(floor(x / 200), floor(z / 200))`.
- A chunk is wanted when `distance(chunk centre, you) <= load_radius + 0.71 * 200` (so every chunk touching the circle is in).
- Mitre length at a bend: `half_width / max(0.35, cos(half the turn))`; the limit stops spikes at sharp corners.
  Example: a 6 m street turning 90 degrees: `3 / cos(45 deg)` = 4.2 m.
- Default building height when the data has none: outline under 220 m2: 3.0 m; under 600 m2: 3.4 m; larger: 5.5 m;
  places of worship 7 m; schools, halls and the civic centre 6 m.
- Hip roof rise: `clamp(0.12 * sqrt(area), 0.8, 1.8)` m.

## 5. Edge Cases

- A chunk with no data file (outside the suburb): nothing is built; the ground slab still carries you.
- You walk outside the boundary: allowed in the preview (the HUD says "outside Westridge"); stage 3 decides the edge.
- An outline that cannot be cut into triangles (self-crossing): its roof is skipped, the walls are still built.
- Two outlines that overlap (merged or doubled houses in the source): both are built; they intersect harmlessly.
- Moving faster than chunks build (driving): the queue is re-sorted from your new position every half second,
  so the nearest pieces always come first; far pieces already queued are dropped.
- Returning to the game from the preview reloads the main scene (the preview has no save of its own).

## 6. Dependencies

- Uses: `DataFiles`, `PixelMaterials` (existing textures: asphalt, pavement, plaster, roofs, sand), `Player`,
  `TouchControls`, `InputHints`.
- Used by: the pause menu (preview button). From stage 2: navigation, residents, traffic; from stage 3: `GameSession`
  and everything that today reads `District` (missions, turf, police, dealing, interiors, survival, turf map, saves).
- Replaces (stage 4): `StreetBuilder`, the area pipeline in `District`, `DistrictGate`, the five district data sets.

## 7. Tuning Knobs

| Knob | Where | Default | Safe range | Affects |
|---|---|---|---|---|
| `CHUNK` | tool | 200 m | 100 to 400 | Piece size: smaller = smoother loading, more files |
| `MARGIN` | tool | 60 m | 0 to 150 | How much outside the boundary is kept so edge roads are whole |
| road widths and pavements (`ROAD`) | tool | 4 to 7.5 m, 0 to 2.5 m | | Look of each street class |
| `load_radius` | `RealWorld` | infinite (desktop), 320 m (touch) | 200 m and up | How much is built around you; memory and loading time |
| `unload_margin` | `RealWorld` | 120 m | 50 to 300 | How soon far pieces are freed (too small = pieces flicker at the edge) |
| `builds_per_frame` | `RealWorld` | 2 (desktop), 1 (touch) | 1 to 4 | Loading speed against hitches |
| sign and label ranges | builder | 70 m, 160 m | | How far names are readable |

## 8. Acceptance Criteria

Each has a check in `tests/run_tests.gd` (`_test_real_world_units`, `_test_real_world_streaming`).

1. The data is the whole suburb (over 1.5 by 2 km) with more than 5,000 building outlines and the real street names.
2. Every chunk file loads and holds valid buildings; the total matches the index.
3. Streets bend and run at many angles (not a grid).
4. A road ribbon follows a bend.
5. A chunk builds into meshes, a collision body and street signs, within the time budget (400 ms).
6. With a limited radius only nearby chunks are built; moving away frees them and builds the new ones.
7. With an unlimited radius the whole suburb is queued.
8. Both data sources are credited on screen and in `docs/THIRD_PARTY.md`.
