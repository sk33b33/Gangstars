# Changelog

All notable development milestones should be recorded here.

## Unreleased

### Renamed to Gangstars (2026-11-09)
- The game is called **Gangstars** everywhere: the window title, HUD, Windows exe
  (`Gangstars.exe`, `Gangstars-windows.zip`), docs and project instructions.
- Godot keys the save folder to the project name, so saves and settings now live in
  `app_userdata/Gangstars/`. Saves made under the old name don't carry over (copy them across by
  hand if needed).

### Gamepad support and Windows build (2026-11-09)
- **Gamepad (Xbox layout; other pads map to the same positions):**

  | Control | Button |
  |---|---|
  | Move | Left stick |
  | Camera | Right stick |
  | Sprint | L3 |
  | Interact / get in a car | A |
  | Jump | B |
  | Whistle / hoot | Y |
  | Turf map | View |
  | Pause | Menu |
  | Accelerate / brake-reverse | RT / LT (the stick also works) |

  - Menus work with the D-pad or stick, A to press and B to back out of the turf map, safehouse
    menu and pause menu. Godot's default `ui_accept`/`ui_cancel` have no pad buttons, so they are
    now overridden in `project.godot`.
  - The A press that closes a menu no longer also interacts in the world on the same frame.
  - On-screen help and the interaction prompt switch between keyboard and pad names, following
    whichever device was used last (`InputHints`). Stick drift doesn't flip them.
  - New settings: stick sensitivity, and controller vibration (short rumble on hoots and when
    getting into a car).
- **Windows build:**
  - `export_presets.cfg` has a "Windows Desktop" preset (x86_64, game data embedded in the exe).
  - `tools/export_windows.sh` produces `build/windows/Gangstars.exe` and a zip.
  - It installs only the Windows export templates, pulling them out of the official archive with
    `tools/remote_zip.py`.
  - The packaged content was verified by booting the exported pack and rendering a screenshot.

### Kalkbos: the west district (2026-11-09)
- **Built through the Phase 7 pipeline** (`tools/specs/kalkbos.json` → 22 houses, 22 residents):
  - limestone cottages (new `cottage` kit with a chimney) on Duif Street;
  - mixed singles and semis on Mossie Street;
  - row houses on Klip Street.
  Two houses are vacant. Stone boundary walls are a new fence type; the generator gained per-row
  kit lists and weighted fence picks, and Rooiduin's output is byte-identical.
- **Characters:** Gail (fish-and-chips container), the Pastor (Kalkbos Hall), Riyaad, and the
  rival Klipspringers (Klip, Bokkie, Vossie) with a night patrol.
- **Landmarks:**
  - a quarry face: jagged worked benches, fallen blocks, a derrick crane, and a danger fence with
    signs;
  - a quarry lookout with a bench and telescope;
  - Kalkbos Hall;
  - "Vis en Tjips" in a container;
  - a courtyard and a bus stop.
  The district has its own chalk ground, traffic loop (a taxi stops at the bus stop) and a church
  bazaar every third morning.
- **New pxl textures:** chalk_ground, limestone_wall, sign_hall, sign_fish, sign_quarry, tag_klip.
- **Missions** (`data/missions/kalkbos.json`):
  - Stone and Salt (tour the lookout and the fish shop);
  - The Long Haul (a timed errand between Kalkbos and Rooiduin);
  - Quarry Night (face Klip, then hold the lookout after dark with your crew → Riyaad joins,
    plus Kalkbos influence).
  Mission prerequisites can now require unlocked districts.
- **Unlock:** reputation 100, 2 crew, 80% Vleirand influence, and "Beyond the Block". The starter
  district's west edge now opens straight onto Kalkbos' Duif and Mossie Streets.
- **Fixes:**
  - **Districts not connecting after an unlock:** the nav rebake now waits for two fresh
    navigation-map iterations. Godot 4.5 builds them asynchronously, so a fixed 3-frame wait
    sometimes read the old map and left a hole at the gate.
  - **Gate colliders:** opened gates detach their collider rather than relying on layer
    filtering.
  - **Crew catching up:** crew more than 30 m behind the player jog (1.8×). A recruit who gets
    home after a crew call is nudged straight back out, so a hold across three districts doesn't
    wait for a long home timer.
  - **Turf map:** district names are drawn last, above each zone, so houses and landmarks no
    longer hide them.

### Phase 7: expansion content — Rooiduin (2026-11-09)
- **Repeatable district pipeline:**
  - `tools/generate_district.py <spec>` turns a district spec (street rows, building types, plot
    sizes, palettes, name pools, landmarks/POIs, named characters, rival crew) into house and
    resident data. It is deterministic, with a per-id seed.
  - `districts.json` entries carry `data` (district file) and `missions`.
  - `District` builds every catalog area with the existing StreetBuilder / HousePlot / residents /
    traffic / patrol / calendar code into one navigation bake.
  - Gates (solid at bake time) keep areas apart until unlocked.
- **Rooiduin (east):**
  - 20 houses: 6 three-storey flats blocks with stair towers, balconies, railings and laundry,
    plus 14 row houses (2 vacant).
  - 25 residents, including Ma Rachel, Uncle Solly (barber), Kaylin, and the rival Duin Boys
    (Spider + 2) with a flats-block HQ and a night patrol.
  - Landmarks: Duin Spaza and Kings Cuts in shipping containers, a soccer field, a taxi rank and a
    courtyard. The district has its own red-dune ground, traffic loop with a taxi, and a daily
    soccer-match event.
  - New pxl textures: sand_red, container_wall, sign_barber, sign_spaza, sign_taxi, tag_duin.
  - It's turf like Vleirand: contested/controlled by its own influence; the turf map and HUD
    show it. Entering shows a district banner.
- **Missions** (`data/missions/rooiduin.json`): New Turf, Clean Cut (a cross-district errand to
  Vleirand's café and back), Dune Truce (hold the soccer field after dark with your crew →
  Kaylin joins, so Kalkbos' 2-crew requirement can be met).
- **Navigation:**
  - Unlocking (or loading a save with an unlock) rebakes the nav mesh on a thread, so the
    player's crew can follow across districts.
  - Residents keep to their own district.
  - Roads are carved out of the pedestrian nav mesh except at zebra crossings every 24 m, so
    people walk on pavements and cross at crossings. This fixed traffic crawling behind people
    walking in the road.
- **Crew:** follow without giving up while catching up to the player; when an objective needs
  the crew beside you, they are called over; recruits are active until 02:00.
- **Save compatibility:** `tests/fixtures/save_v1_phase5.json` (written before Rooiduin existed)
  loads and restores the unlock.
- New screenshot flags: `--cam=x,y,z,tx,ty,tz`; `--hour` now applies after `--load`.


### Phase 6: vehicles, richer interactions and polish (2026-11-09)
- **Traffic:**
  - 4 AI vehicles, including a minibus taxi that pauses at both bus stops.
  - They drive on the left on two concentric loops (Duif → Tortel → Mossie → Kwikkie) with
    rounded corners, and brake for anything in their lane box.
  - Blocked for 3 s, they hoot, and the pedestrian steps aside.
  - Kinematic, on their own physics layer (residents can't be shoved); a NavigationObstacle3D
    only while moving.
  - Spawned after the nav bake.
- **Driving:**
  - 2 drivable cars (blue hatchback by the safehouse, yellow Golf on Mossie Street).
  - E get in/out, W/S throttle and brake, A/D steer, Q hoot; the camera follows.
  - Speeding past pedestrians makes them scatter.
  - Car positions are saved.
- **Audio** (`AudioBank`, all synthesized at runtime, no assets):
  - horn, door, whistle, car alarm, jingle, click, birds, engine loop, wind, rain, crickets;
  - buses SFX / Ambient / UI;
  - ambience follows clock and weather; engine pitch follows speed.
- **Pause menu (Esc):** volumes, mouse sensitivity, invert Y, FOV, render scale, MSAA, shadows,
  fog, fullscreen, VSync, FPS counter, weather and traffic toggles. Saved to `user://settings.cfg`.
- **Weather:** clear / cloudy / windy / rain spells from day 2. Rain shows as particles and an
  overcast sky with closer fog; residents skip outdoor leisure but still run errands.
- **Lighting:** windows glow at night; `LightPool` moves 6 real lights to the streetlights
  nearest the camera.
- **Calendar** (`data/events/calendar.json`):
  - street braai (drum grill with smoke, about half the residents go);
  - load-shedding (lights out 19:00–21:00 on even days, neighbours chat at their gates).
- **Missions:** Spaza Run (timed multi-delivery), Car Trouble (`enter_vehicle` + `drive_to`
  objectives), Braai Night (objectives gated on the braai event).
- **Animation:** chat gestures, folded arms on guard, heads turn to incidents, the group, or the
  nearby player.
- **Performance:** `MeshMerger` batches static meshes per 40 m cell and material (1,252 → 266);
  `Lod` visibility ranges; `--profile` / `--no-lod`. Street-view draw calls 1,551 → 909.
- **Robustness fixes found by tests:**
  - parked cars were nudged by passing traffic (now no physics while parked);
  - the far→mid ghost window ends only when clear of overlaps;
  - a 90 s "moving but not arriving" trip re-plan;
  - lanes and parked cars given clearances; Tortel and Kwikkie keep their kerbs clear;
  - a stopped car can't deadlock a pedestrian;
  - day 1 is always clear weather.


### Phase 5: turf control and locked expansion (2026-11-09)
- `data/districts/districts.json`: Vleirand (starter), Rooiduin (east) and Kalkbos (west), each
  with unlock requirements (missions, reputation, crew, Vleirand influence).
- `DistrictManager` is the only authority: `can_unlock`, `get_unlock_requirements`,
  `unlock_district` (validates first), states locked / unlockable / unlocked, and contested /
  controlled for Vleirand. "Unlockable" is announced once. Unlocks live in
  `ProgressionState.unlocked_district_ids` (saved).
- Influence: mission and upgrade rewards (`influence: {starter: n}`) + 2 per friendly house
  (any occupant at relationship 15+ or in your crew), capped at 100.
- `DistrictGate`: striped boom gates where Duif and Mossie Streets leave the district, with a
  3 m invisible collider, a sign and a "LOCKED TURF — open the turf map (M)" label. Unlocking
  raises the boom (animated) and relabels it "OPEN". Behind each gate is an enclosed approach
  street ending in an "under construction" wall (real content in Phase 7).
- Turf map (M / controller Back): district map with houses coloured yours / friendly / neutral /
  rival / empty, landmarks, player arrow, crew dots, neighbour zones; side panel with influence
  bar and breakdown, ✓/✗ requirement checklists and an Unlock button (a request; the manager decides).
- Missions: Hold the Corner (stand at the corner 30 game minutes after dark with crew; stepping
  away or losing your crew resets the count) and Beyond the Block (unlock Rooiduin, walk in).
  New objective types `hold` and `district_unlocked`; earlier missions now also grant influence.
- HUD banner for big moments ("ROOIDUIN UNLOCKED"). `--load=<save>` and `--turf-map` flags for
  screenshots.
- Fixed: stale deferred focus on rebuilt menus; map buttons replaced by name immediately.


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
