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

## As built (Phase 2)

| Street | Axis | Houses | Notes |
|---|---|---|---|
| AZ Berman Drive | east-west, z = 0 | 8 (south side, h01–h08) | Main road; café, Duif bus stop and the corner on the north side |
| Spine Road | east-west, z = −56 | 10 (8 north side h09–h16, 2 south side h17–h18) | Mossie bus stop |
| Kwikkie Street | north-south, x = −50 | 6 (h19–h24) | Western connector |
| Tortel Lane | north-south, x = 50 | 6 (h25–h30) | Narrower lane; h29 is the hostile crew house |

The central block (between the four streets) holds the café, the sand court and the park.
Both east-west streets leave the district through "LOCKED TURF" barriers (Rocklands west, Lentegeur east).
Edit the generator rows in `tools/generate_starter_data.py`, rerun it, then run the tests.
