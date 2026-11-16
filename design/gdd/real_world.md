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
- A road is a flat ribbon along its points, mitred at bends, with a round cap at both ends. Under it, from the top
  down: a concrete gutter ribbon (the road's full width; the asphalt is `2 * GUTTER_WIDTH` narrower), a kerb ribbon
  (`2 * KERB_WIDTH` wider) and the pavement (widest). Each layer sits a few millimetres lower, so where streets meet,
  one street's asphalt covers the other's kerb and gutter and junctions at any angle close without gaps.
  Main roads and collectors get centre dashes; main roads also get yellow edge lines `EDGE_LINE_IN` in from the
  edge, stopped `EDGE_LINE_TRIM` short of each end (the ends are junctions).
- Footpaths are narrow paved ribbons. Parks, pitches, school grounds, parking, dunes and the pool are flat coloured areas.
- A building is walls on its outline up to its height, a darker plinth band (`PLINTH_HEIGHT`) at the foot, and a roof.
  A house (not public, under 420 m2) whose outline fills at least `ROOF_FILL` of its smallest surrounding rectangle
  gets a pitched roof over that rectangle: hip or gable (gable ends painted like the walls), with `EAVES` overhang,
  fascia boards and a soffit. Every other building gets a flat roof behind a `PARAPET` with a concrete cap.
  Windows have concrete sills. Paint, plinth, fascia, roof material and hip/gable are picked from the outline's
  position, so a house always looks the same.
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

### Pavements
- Residential streets: from the kerb to the boundary walls a sandy, trodden verge with grass tufts (texture `verge`),
  as most Mitchells Plain side streets have. Main roads and collectors: a paved slab footway `FOOTWAY` wide beside
  the kerb, verge behind it. Car parks and the shopping centre's grounds are tarmac.

### Public buildings (`RealLandmarks`)
- Unnamed outlines whose centre lies in school grounds, the shopping centre, a sports ground, park, pitch, playground
  or the pool are given a kind by `tools/osm/classify_buildings.py` (school_block, shop_block, sports_block,
  park_building, pool_building), so they are never homes (no door, yard or residents). The game's family homes are
  never reclassified; five that had been placed in school buildings moved to the nearest real house (2026-11-16).
- Each public kind has a shape (`RealLandmarks.style_of`):
  - church: face brick or white walls 5 m, steep gable roof (`CHURCH_PITCH`) along the long side, a cross on the
    gable nearest the street, and a bell tower with a pyramid cap beside the front when bigger than `TOWER_AREA`;
  - mosque (name holds "masjid" or "mosque"): white walls, flat roof, a green dome on a drum, an octagonal minaret with
    a balcony at the front corner;
  - civic centre: face brick, flat roof, the middle third raised into a hall with a low gable roof, an entrance
    canopy on posts and a flagpole;
  - clinic and crèche: white with a green plinth, flat roof, entrance canopy;
  - school blocks: face brick, one storey (`SCHOOL_STOREY`) or two over `TWO_STOREY_AREA`, low gable iron roof,
    rows of barred windows on every long wall;
  - shops: cream walls, a coloured sign band (parapet), roller shutters and a veranda on posts along the front;
  - fuel stations: kiosk, plus a forecourt canopy on four columns over two pump islands between kiosk and road
    (left out when there is no room); a canopy outline in the data is built as a roof on columns;
  - sports halls: tall walls, low gable iron roof; everything else: a plain flat-roofed block.

### Yards (`RealYards`)
- A home whose front wall is at least `MIN_WALL` long gets a front yard: a fence along the street side, parallel to
  the front wall, with a `GATE` opening centred on the front door, and side walls from the fence back to the two
  front corners of the house. About one yard in eight is left open (style "none").
- Style, from the outline's position: precast concrete panels (1.5 m), steel palisade between plaster pillars (1.6 m),
  a low plastered wall in the house's paint (1.0 m), or a 0.6 m wall with palisade on top (1.8 m). Posts at every end.
- Depth: the deepest of `MAX_DEPTH`, `MAX_DEPTH - 0.2`, ... down to `MIN_DEPTH` at which the whole fence line keeps
  `PAVE_GAP` clear of every street's pavement (only `PAVE_KEEP` of a wider pavement is kept; the rest joins the yard)
  and of every footpath. No depth fits: no yard (the house fronts the pavement).
- A fence piece is left out when it would cross another building, cross its own house anywhere but its ends, pass
  within `DOOR_KEEP` of another home's doorstep, or cross another home's walk-out lane (from its doorstep `LANE`
  metres straight out). A yard that would enclose another home's doorstep is not built at all.
- The game's own homes (story homes): depth between `STORY_MIN_DEPTH` and `STORY_MAX_DEPTH` (their yard dog runs up
  to 3.5 m out, their gate spot is 5 m out), the fence spans at least `STORY_HALF` either side of the door, and the
  sides stay open.
- Fences are solid (collision, both sides) and are obstacles in the navigation bake, so people walk out through the gate.
- Worked out from the data only (`RealDistrictData.yards`), so the builder and the navigation bake always agree.

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
- Pitched roof rise: `clamp(0.45 * half_width, 0.8, 1.8)` m, where half_width is half the short side of the roof
  rectangle. Example: a 7 m wide house: `0.45 * 3.5` = 1.6 m. Hip ridge length: `2 * max(0, half_length - half_width)`
  (eaves included); a gable ridge runs the full length.
- Smallest rectangle: for each edge of the convex hull, project the hull on that edge and its normal; keep the
  smallest box. Fill = outline area / rectangle area.

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
- A house too close to the street for a 2.2 m yard, or with a front wall under 4 m: no fence.
- A neighbour's doorstep near a fence piece, or a neighbour's way straight out of their door crossing it: that piece
  is dropped, so the neighbour can still get out (found when a neighbour's side wall shut a story family in).
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
| `KERB_WIDTH` / `GUTTER_WIDTH` | builder | 0.25 / 0.35 m | 0.1 to 0.5 | Width of the kerb and gutter strips |
| `EDGE_LINE_IN` / `EDGE_LINE_TRIM` | builder | 0.45 / 6 m | 0.2 to 1 / 3 to 12 | Where main-road edge lines run and stop |
| `PLINTH_HEIGHT` / `PLINTH_PAINTS` | builder | 0.5 m / 5 colours | 0.3 to 0.9 | The painted band at the foot of walls |
| `ROOF_FILL` | builder | 0.75 | 0.6 to 0.9 | Which outlines get a pitched roof (lower = more pitched roofs, worse fits) |
| `EAVES` / `FASCIA_DEPTH` / `PARAPET` | builder | 0.35 / 0.2 / 0.35 m | | Roof overhang, fascia board, flat-roof parapet |
| `KINDS` / `HEIGHTS` | `RealYards` | 4 styles + open (1 in 8) / 1.0 to 1.8 m | | Which fences appear and how tall |
| `GATE` | `RealYards` | 2.0 m | 1.8 to 3 | Gate opening (people keep 0.6 m from fences: below 1.8 m nobody fits) |
| `MIN_DEPTH` / `MAX_DEPTH` | `RealYards` | 2.2 / 4.5 m | 2.2 to 3 / 3 to 6 | How shallow / deep a front yard may be |
| `PAVE_GAP` / `PAVE_KEEP` | `RealYards` | 0.3 / 1.5 m | 0 to 1 / 1 to 2.5 | How much pavement stays in front of a fence |
| `DOOR_KEEP` / `LANE` / `MIN_WALL` | `RealYards` | 1.0 / 4.0 / 4.0 m | | Fences keep away from other doors and their way out; shortest front wall with a yard |
| `FOOTWAY` | builder | 1.5 m | 1 to 2.5 | Paved footway on main roads and collectors |
| `CHURCH_PITCH` / `TOWER_AREA` | `RealLandmarks` | 0.9 / 600 m2 | 0.6 to 1.2 | Church roof steepness; which churches get a tower |
| `SCHOOL_STOREY` / `TWO_STOREY_AREA` | `RealLandmarks` | 3.3 m / 500 m2 | | Classroom block height |
| `VERANDA_DEPTH` / `CANOPY_HEIGHT` / `MINARET_HEIGHT` | `RealLandmarks` | 2.6 / 5.2 / 17 m | | Shop verandas, forecourt canopies, the minaret |
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
17. Many homes have a fence in all four styles; working out a piece's yards takes under 250 ms; a story home's fence
    stands between its dog's yard and its gate spot; a fenced family walks out through the gate (aiming beyond the
    fence, 90% get past it within a few metres) and no route passes through a fence; no fence crosses the way straight
    out of any story family's front door.
18. No home stands in school grounds, the shopping centre or a sports ground; each public kind maps to its shape; the
    mosque chunk builds a dome and the church chunks crosses.
16. Streets have kerbs and gutters; houses have plinths, fascias and sills; a tilted outline gets a fitting roof
    rectangle; road lines can be trimmed and offset for edge lines.
(`_test_real_people_and_traffic`; run just these with `tests/run.sh --real-only`.)
