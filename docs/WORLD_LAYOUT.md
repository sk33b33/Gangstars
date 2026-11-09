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
