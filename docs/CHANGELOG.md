# Changelog

All notable development milestones should be recorded here.

## Unreleased

### Polish pass over Phases 0–4: characters, motion, infrastructure (2026-11-09)
- **Characters:**
  - New jointed rig: legs with shoes, arms with hands, neck, head, eyes.
  - Hair styles: short, long, doek, beanie, bald, with per-person colour, height and sleeves.
  - Generated deterministically for every resident; the original five got hand-picked looks.
  - Meshes are shared between characters.
- **Walk cycle:** stride-matched leg and arm swing (no foot sliding), hip bob, torso twist,
  and idle breathing. Gait blends in and out smoothly.
- **Smooth motion:**
  - Godot physics interpolation is on.
  - The camera rig is top-level and follows the interpolated player position (with vertical smoothing).
  - Residents accelerate, decelerate and ease into arrivals.
  - Far-tier residents move every frame instead of in 0.25 s steps (animation at 10 Hz).
  - Leaving the collision-free far tier gives a 1.5 s NPC-ghost window, so overlaps separate
    instead of popping (this fixed two teleport flags).
- **Doors:** hinged front doors with a dark doorway swing open when a resident leaves or enters,
  or when someone answers your knock.
- **Plot dressing** (data-driven `props` per house, deterministic): paved or lawn front yards,
  wheelie bins, open gate leaves, satellite dishes, washing lines, backyard wendy houses,
  front-yard trees. Solid props only go where no path runs.
- **Streets:** 9 parked cars, power lines sagging between same-side poles, crew graffiti on
  Tortel Lane, café posters, backdrop houses beyond the boundary (the street continues past the
  barrier), and depth fog from 80 m that follows the sky colour through the day.
- **New pxl textures:** washing, wendy_wall, tag_tortel, poster_cafe.
- **Tests:** physics interpolation on, jointed rig present, gait animates while walking, doors
  swing, every house dressed. 401/401 in 2 consecutive runs; frame cost 0.93 ms (was 0.70; the
  rig and per-frame far movement cost about 0.2 ms for 28 NPCs).


### Phase 4: player progression and missions (2026-11-09)
- `ProgressionState`: cash, reputation, crew influence, relationships (first meeting +1 rep,
  daily talk +2 relationship), completed/failed missions, recruits, safehouse upgrades and
  unlocked districts. Rewards go through `grant(key)`, which pays out once per key, ever.
- `MissionManager` + `data/missions/intro.json`: New Face (auto-start), A Favour (4-hour time
  limit, can fail and be retried), Know the Block, First Crew (recruits Boeta), Local Respect.
  Objective types: talk_to (or knock while they're home), knock, visit (optional time window),
  talk_distinct, reputation. Missions start from their giver; locked ones list what's missing.
- Recruits join the player crew: red cap, follow the player, guard the safehouse gate, hang at the corner.
- Safehouse (13 Duif Street): menu with 4 upgrades from `data/progression/safehouse_upgrades.json`
  (security light, mural, stash with +R40/day, crew stoep), each with a visible prop; rest until
  morning; save; load.
- `SaveSystem`: versioned JSON, atomic temp-file + rename. The session validates every section
  before applying anything; damaged, unknown-version or missing saves leave the current game
  untouched. Saves cover clock, player position/camera, progression and active mission progress.
  NPCs respawn from stable data.
- HUD: cash / rep / crew line; mission tracker with distance; "!" over mission givers, "▼" over the
  target NPC, a light beacon over target places; safehouse menu works with keyboard, mouse and controller.
- `GameSession` node owns gameplay services; `main.gd` stays a bootstrap. `--new-game` skips auto-load.


### Phase 3: living neighbourhood simulation (2026-11-09)
- `SimClock` (1 s = 1 game minute, starts 07:00) and `DayNight`: sun/moon, sky, ambient light and
  streetlight glow follow the time of day. HUD shows the clock; F7 skips an hour.
- Schedules have time windows and each NPC has active hours: shops by day, gatherings into the
  evening, everyone home after curfew. The Tortel crew is out from 10:00 to 02:00.
- `NpcBrain` now has 14 states: + SOCIALIZING, PATROLLING, FOLLOWING, GUARDING, NOTICING,
  INVESTIGATING, FLEEING, REPORTING. Reactions only escalate, never stack, and always resume routine.
- `NeighbourhoodEvents` hub (district child, not an autoload) and `ReactionPolicy` (role +
  personality + severity + distance). Incidents: your whistle (Q), ambient car alarms, arguments
  and scuffles, plus F5/F6 debug incidents. Gossips walk to a neighbour's door to report.
- Crew behaviours: leader patrols the Tortel loop at night, the second member follows him, both guard
  the crew-house gate.
- Social groups: 2+ NPCs at one spot face each other and chat (speech bubbles from `data/npcs/chatter.json`).
- `SimulationDirector`: near/mid/far tiers by distance to the player (think 0.5/1.5/3 s; avoidance
  only when near; far NPCs step along their nav path without physics).
- Benches are now proper obstacles (seat + backrest, 1 m collider). Low props were invisible to the
  nav bake and caused most "stuck" NPCs.
- Personalities, active hours and crew schedules generated by `tools/generate_starter_data.py`.
- Tests: clock, policy and brain units (windows, curfew, every reaction, patrol/guard/follow);
  integration for tiers, incidents, a day soak and a night run. Movement guards now separate
  teleports (>0.5 m per frame, must be 0) from rare physics nudges.


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
