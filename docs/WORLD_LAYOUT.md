# Starter District — World Layout

## Layout goals

Create a compact, believable community containing roughly 30 house plots. Prioritize readable circulation and navigable routes over architectural complexity.

## Suggested block plan

Use a simple block arrangement as a starting point, then tune it for playability:

- Street A: 8 houses.
- Street B: 8 houses.
- Street C: 8 houses.
- Short connecting lane / cul-de-sac: 6 houses.
- Total: 30 houses.

Add one main through-road, two side streets, sidewalks, crossings, and a small central public space. Put the shop and gathering point where the street network naturally meets.

## House identity

Use stable IDs such as `starter_h01` through `starter_h30`. Each plot should have:
- Unique position and orientation.
- House number or visible sign.
- Reusable exterior variation (roof, wall material, colour, fence, yard props).
- Door marker and reachable approach point.
- Occupancy and ownership metadata.
- Optional resident home assignment.

A small number of landmark buildings can have custom geometry. Ordinary houses should use a modular kit with randomized but deterministic variations.

## Navigation checklist

- Sidewalks connect all street segments.
- Every plot entrance connects to the sidewalk/yard navigation mesh.
- Fences and walls do not accidentally seal entrances.
- Roads and sidewalks are walkable where intended.
- No navigation polygons cross building interiors.
- Destination points are sampled or validated against the navigation map.
- Add a debug command to test reachability from every occupied house to at least one public destination.

## Street life

Place destination anchors:
- Corner shop entrance.
- Basketball court / small park.
- Bus stop or taxi pickup point.
- Community gathering corner.
- Player safehouse.
- A few benches and social spots.

Use anchors as NPC destinations rather than arbitrary world coordinates.

## Expansion boundary

The starter district should have a visible boundary: road barrier, gate, bridge, map edge, or transition point. Beyond it, hint at additional streets without allowing access. Locked areas should communicate that they are future territory, not broken geometry.

## As built: Westridge on its real streets (2026-11-15)

Westridge is the real block around Excelsior Street in Westridge, Mitchells Plain, taken from OpenStreetMap
(`data/world/`), turned 22 degrees so that its streets run along the game's axes (`real.bearing_deg` in
`data/districts/starter.json`; the compass and the city map correct for it). Origin = the middle of Excelsior Street.

| Street (real name) | Where | Real size | Houses | Notes |
|---|---|---|---|---|
| Excelsior Street (`duif`) | east-west, z = 0 | 100 m between the cross streets | 6 on the south side (h01, h02, h04–h07) | Cafe, bus stop and the corner on the north side |
| Rhone Way (`mossie`) | east-west, z = −70 | 60–78 m north of Excelsior Street (it bends; drawn straight) | 8 north side (h09–h16), 2 south side (h17, h18) | Bus stop |
| Coetzenburg Street (`kwikkie`, `kwikkie_s`) | north-south, x = −50 | runs on south towards Valencia Street | 6 (h19–h24) | The south part is a stub ending at the wall |
| Constantia Street (`tortel`, `tortel_s`) | north-south, x = 50 | a long through street | 6 (h25–h30) | h29 is the hostile crew house |
| Rhone Close (`rhone_close`) | x = −2, from Rhone Way 36 m south | 52 m dead end | | Ends near the park |
| Excelsior Close (`excelsior_close`) | x = −2, from Excelsior Street 34 m south | 39 m dead end | 2 (h03, h08) | |

What is not real yet: the 40 m of Excelsior Street and Rhone Way beyond the cross streets are link roads to the
neighbouring districts (which still use made-up layouts and call those roads AZ Berman Drive and Spine Road);
the houses, shops and families are the game's own; Valencia Street (south) and the streets north of Rhone Way are
behind the wall. Every area's block was deepened from 56 to 70 m so the two link roads still line up.
The migration is recorded in `tools/world/rebuild_westridge_real.py`. `tools/generate_starter_data.py` is the
original Phase 2 generator and no longer matches the data: do not run it.

## As built (Phase 2, superseded)


| Street | Axis | Houses | Notes |
|---|---|---|---|
| AZ Berman Drive | east-west, z = 0 | 8 (south side, h01–h08) | Main road; café, Duif bus stop and the corner on the north side |
| Spine Road | east-west, z = −56 | 10 (8 north side h09–h16, 2 south side h17–h18) | Mossie bus stop |
| Kwikkie Street | north-south, x = −50 | 6 (h19–h24) | Western connector |
| Tortel Lane | north-south, x = 50 | 6 (h25–h30) | Narrower lane; h29 is the hostile crew house |

The central block (between the four streets) holds the café, the sand court and the park.
Both east-west streets leave the district through "LOCKED TURF" barriers (Rocklands west, Lentegeur east).
Edit the generator rows in `tools/generate_starter_data.py`, rerun it, then run the tests.
