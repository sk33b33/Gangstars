# Changelog

All notable development milestones should be recorded here.

## Unreleased

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
