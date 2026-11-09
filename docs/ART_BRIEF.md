# Art Brief — Vleirand (starter district)

Produced with the `design-brief-from-conversation` skill from the four reference photos supplied by
the project owner. Anything inferred rather than stated is marked **[to confirm]**. This brief is a
reviewable draft; the owner confirms or corrects it.

## 1. What the owner is trying to achieve

A starter neighbourhood that looks like a real Cape Flats community (Mitchells Plain / Lentegeur
style housing), not a generic American suburb. It is a **fictional suburb** called **Vleirand**;
no real street names, gangs, or people.

Look: **low-poly 3D with crisp pixel-art textures** generated as code by `pxl`
(`art/vleirand.px.js` → `assets/textures/pxl/`). Strong silhouettes, flat painted plaster, readable
colours.

## 2. Housing kit (what the photos show)

| Photo | Type | Kit id | Key features |
|---|---|---|---|
| 1 (grey/white, garage) | Double-storey with attached single garage, mono-pitch roof | `double_garage` | Paved brick driveway, roll-up garage door, burglar-barred windows, upstairs balcony/pergola [to confirm] |
| 2 (salmon/pink) | Single-storey, hip roof, recessed front stoep | `single_hip` | Precast concrete fence with lattice top band, ornate steel palisade gate, diamond burglar bars, peeling paint |
| 3 (lime green) | Single-storey gable/hip, garage at side | `single_gable` | Fence painted the same colour as the house, white fence posts, white-framed windows, satellite dish |
| 4 (white, narrow) | Double-storey semi, mono-pitch roof | `double_semi` | Narrow plot, steel security gate on door, top-hung windows, sandy/broken yard paving |

Common elements across all houses:
- Painted plaster walls in a wide colour range: pink/salmon, lime, mint, sky blue, cream, grey, white.
- Burglar bars on every window, security gates on doors.
- Precast concrete (vibracrete-style) fences or steel palisade fences; gate gap at the path.
- Sandy yards, concrete or brick paving, small stoeps.
- Concrete roof tiles (terracotta, charcoal) or corrugated IBR sheeting.

## 3. Texture list (pxl)

Density: **16 px per metre**. Wall and ground textures tile; facade parts are quads with UV 0..1.

| Texture | Size | Use |
|---|---|---|
| `wall_plaster` | 32×32 (2 m) | Neutral off-white, tinted per house via material albedo |
| `wall_grime` | 32×8 | Splash-back grime band along wall base |
| `window_bars` | 24×20 | Window with frame, sill and diamond burglar bars |
| `door_gate` | 16×32 | Front door behind steel security gate |
| `garage_door` | 40×32 | Panelled garage door |
| `fence_precast` | 32×24 | Precast panels with lattice top band (tinted) |
| `fence_palisade` | 32×24 | Steel palisade with ornate tops (alpha) |
| `roof_tiles` / `roof_ibr` | 32×32 | Roof coverings |
| `road_asphalt`, `sidewalk`, `yard_sand`, `paving_brick` | 32×32 | Ground surfaces |
| `sign_shop`, `sign_bus` | various | Corner café sign, bus stop sign |

## 4. Decisions taken and deferred

- Taken: fictional suburb, pixel textures on low-poly geometry, data-driven variation
  (`data/houses/starter_houses.json`), placeholder capsule characters.
- Deferred: character sprites/models, day/night lighting, interiors, vehicles (owner: project lead).

## 5. Questions that most need an answer

1. Should characters stay low-poly capsules, or become billboard pixel sprites (pxl can animate them)? [to confirm]
2. Is mild wear such as peeling paint and rust welcome on most houses, or only a few? [to confirm]
3. Should the first expansion district get a different look, for example flats (courts) instead of houses? [to confirm]

## Update — polish pass

- Characters: jointed low-poly figures. Hair styles come from the community the photos show:
  doeks (headscarves) for aunties, beanies for the crew, short and long hair. Height and sleeve
  length vary per person. The player crew wears the player's red cap.
- Yard life: wheelie bins, washing lines, wendy houses, satellite dishes (photo 3), open steel gate
  leaves (photo 2), paved driveways (photo 1).
- Street life: parked hatchbacks, overhead power lines, posters, and a fictional crew tag on Tortel Lane.
