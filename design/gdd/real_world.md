# Real Westridge world

Status: stages 1 to 3 done and the old districts removed (2026-11-16); phone tuning and Windows build remain. Code: `scripts/world/real/`. Data: `data/world/westridge/`.
Tool: `tools/osm/build_westridge.py`. Preview scene: `scenes/real/real_westridge.tscn`.

## 1. Overview

The game moves from five small made-up districts to **one accurate district: the whole of real Westridge,
Mitchells Plain** (about 1.6 km by 2.5 km). Streets follow their real lines, bends and angles. Every real
building outline gets a building. The world is cut into 200 m pieces ("chunks") that are built when you come
near and freed when you leave; a desktop builds all of them, a phone only those around you.

| Stage | What | State |
|---|---|---|
| 1 | Real data, the new builder, loading in pieces, a walk-around preview | done |
| 2 | People: navigation on the real streets, residents living in real houses, traffic on real roads, doors and windows | done |
| 3 | The game moves in: safehouse, shops, missions, crews, turf, police, survival spots, saves; turf sectors inside Westridge replace the locked districts | next |
| 4 | The old districts (Lentegeur, Rocklands, Town Centre, Tafelsig, old Westridge) and their code are removed; phone tuning; Windows build | |

The real Westridge is now the only world; the old districts and the preview button are gone.

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

### Navigation (`RealNav`, in `RealWorld`)
- Chunks within `sim_radius` of you get a navigation mesh: the chunk's ground with every building outline of the chunk
  and its eight neighbours cut out. It is baked on a background thread, one chunk at a time, nearest first.
- All chunks share one cell grid and are baked with a 1 m border, so neighbouring meshes meet edge to edge and a route
  can cross any number of chunks. The mesh is dropped beyond `sim_radius + sim_margin`.
- People may walk anywhere that is not a building (streets, pavements, open ground, parks). Keeping them to pavements
  and crossings is stage 3 work.

### Homes and places
- A building that is not public and is 30 to 450 m2 is a home. Its front door is in the middle of the wall nearest a
  street, skipping a wall whose doorstep would be inside another outline. The door gets a door panel; long walls get windows.
- Each home's doorstep (1.2 m outside the door) is a destination, `<house id>:door`. House ids are
  `h_<chunk x>_<chunk z>_<index>` and never change while the data stays the same.
- Named real places are destinations too: parks and playgrounds, shops (the shopping centre, mini mart, garages, KFC),
  meeting places (civic centre, clinic, churches and mosques) and pitches.

### Residents (`RealPopulation`)
- When a chunk's navigation is ready and the navigation map has taken it in, up to `homes_per_chunk` of its homes get
  a resident, always the same homes and the same person (name, look and day come from the house id).
- A resident is the game's ordinary `Resident`: it starts indoors at its own door, leaves on its schedule, walks with
  `NavigationAgent3D`, stays a while, and walks home. Its day is built from what is near: the nearest shop (within 700 m),
  park (500 m), meeting place (700 m) and one fixed neighbour 25 to 120 m away.
- Residents are removed when their chunk's navigation is dropped (they are at least `sim_radius + sim_margin` away then).
- At most `max_residents` exist at once.

### Traffic (`RealRoadGraph`, `RealCar`, `RealTraffic`)
- The map tool cuts every street at its junctions, so road pieces are the edges of a network and their ends the nodes.
  One-way carriageways (Wespoort Drive, Eisleben Road...) are only entered at their start.
- A car drives along its street's centre line on the **left** lane, steering towards a point 5 m ahead, so it turns
  into the next street instead of jumping. It slows into junctions, stops for a car, the player or a person in its lane,
  and at each junction picks any street it may enter except the one it came from (unless it is a dead end).
- If two cars have waited for each other for 5 s, one creeps through.
- Cars start at the beginning of a street at least `spawn_min` from you and are removed beyond `far_distance` or when
  they run off the loaded network. Up to `max_cars` at once.

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
- A home whose every wall is hemmed in by other outlines has no door and no resident.
- A resident whose destination cannot be reached (a walled-in yard, a place whose chunk has no navigation) skips it
  and takes the next stop in their day (the ordinary `Resident` recovery).
- The navigation map takes new regions in on a background thread; until it has, a query answers with the map origin.
  Residents are only moved in after `RealWorld.nav_synced` says the map knows their chunk.
- A car that reaches the edge of the loaded network with nowhere to go is marked lost and removed.
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
| `sim_radius` / `sim_margin` | `RealWorld` | 300 m (desktop), 220 m (touch) / 150 m | 150 to 500 / 60 to 300 | Where people and navigation exist; bake load |
| `RealNav.CELL`, `AGENT_RADIUS`, `BORDER` | `RealNav` | 0.25, 0.5, 1.0 m | | Navigation detail and the gap people keep from walls |
| `HOME_MIN_AREA` / `HOME_MAX_AREA` | builder | 30 / 450 m2 | | Which outlines count as homes |
| `max_residents` / `homes_per_chunk` | `RealPopulation` | 48 / 6 (touch: 18 / 3) | 10 to 120 / 1 to 15 | How busy the streets are; CPU |
| `max_cars` / `spawn_min` / `far_distance` | `RealTraffic` | 14 (touch: 6) / 70 m / 380 m | 0 to 40 | Traffic density |
| `RealCar.SPEEDS` | `RealCar` | 12 / 9.5 / 7 m/s (main / collector / street) | | Driving speeds |
| names, shirts, lines | `data/world/westridge/people.json` | | | Who the residents are |

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
9. Navigation is baked only near you; the map takes it in; routes join homes across several chunks and go round buildings.
10. Homes have front doors on open ground; homes and real places are destinations.
11. Residents move into real houses up to the cap, start at their own door, and every stop in their day exists.
12. Over a minute and a half residents leave, walk and arrive; nobody moves more than 0.3 m in a frame or stands inside an outline.
13. The streets form a network with junctions; one-way streets are entered only the right way.
14. Cars drive, never jump, stay on the road, keep left, never appear beside you, and stop for something in their lane.
15. Freeing a chunk removes its homes, navigation, streets and residents.
(`_test_real_people_and_traffic`; run just these with `tests/run.sh --real-only`.)
