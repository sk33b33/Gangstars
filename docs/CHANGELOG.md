# Changelog

All notable development milestones should be recorded here.

## Unreleased

### Phase 2: complete 30-house starter neighbourhood (2026-11-09)
- Vleirand now has 4 streets: Duif Street and Mossie Street (east-west through roads), plus
  Kwikkie Street and Tortel Lane (north-south connectors) around a central public block.
- 30 houses (`starter_h01`–`starter_h30`) with street addresses, generated deterministically
  (per-id RNG) by `tools/generate_starter_data.py`; h01–h05 and the original residents are preserved.
  3 vacant houses, the player safehouse, and one hostile house (Tortel crew).
- 28 residents with varied schedules: café, two bus stops, corner, court, the new park, and
  visits to other houses' doors.
- `StreetBuilder` builds any list of streets from data (roads, sidewalks, kerbs, lane markings,
  kerbside streetlights), street-name signs at junctions, rotatable bus stops, a park, and
  boundary barriers wherever a street leaves the district.
- NPC "unstick" recovery: a wedged resident steps away from the obstacle before re-pathing.
- Debug overlay shows a per-state summary and the 6 nearest residents (scales to many NPCs).
- Tests: district size, unique addresses, occupants for every occupied house, 162 reachability
  paths, missing-destination recovery, and a frame-cost budget.
- Fixed: a streetlight in front of a gate cut off a house; mirrored street-sign text; washed-out sand.


### Phase 0 + 1: first playable street slice (2026-11-09)
- Godot 4.5.1 project (Compatibility renderer), input map (keyboard + controller), main scene.
- Vleirand starter district: Duif Street with road, sidewalks, streetlights, Vleirand Cafe,
  bus stop, sand court, corner wall, and a boundary with "LOCKED TURF" barriers to the east and west.
- Reusable `HousePlot` with 4 kits based on the reference photos (single hip, single gable +
  garage, double semi, double + garage), precast/palisade fences, gates, burglar-barred windows.
  5 houses (`starter_h01`–`starter_h05`) loaded from JSON, one of them the player safehouse.
- Pixel-art textures generated as code with pxl (`art/vleirand.px.js`, 16 textures).
- 5 residents with a schedule FSM (`NpcBrain`): leave home → walk → activity → next stop → home.
  Physics movement on NavigationAgent3D with avoidance, staggered 0.5 s think ticks, stuck and
  unreachable re-pathing, fallback when a destination closes, and a door-clear check on exit.
- Third-person player with camera-relative movement, sprint, and an interaction prompt
  (knock on doors, talk to residents).
- F3 debug overlay (nav mesh, paths, anchors, per-NPC state) and F4 reachability check.
- Headless test suite `tests/run_tests.gd` and screenshot CLI.
- Art brief (`docs/ART_BRIEF.md`) and tech notes (`docs/TECH_NOTES.md`).

- Initial Claude Code development kit created.
- Game concept, architecture, roadmap, NPC simulation, 30-house world, and turf progression documented.
