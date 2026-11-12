# Development Roadmap

The roadmap is intentionally ordered around playable milestones. Do not skip ahead because a later feature sounds exciting.

## Phase 0 — Project foundation

**Deliverables**
- Godot 4.x project opens and runs.
- Git-friendly folder structure and naming conventions.
- Main scene, world scene, input actions, basic debug overlay.
- A short technical note recording the exact Godot version.

**Acceptance**
- No parse errors.
- Project launches from the editor and command line.
- A placeholder ground plane and camera are visible.

## Phase 1 — First playable street slice

**Deliverables**
- Third-person player movement and camera.
- One short street with 3–5 reusable house plots.
- Sidewalk/road navigation geometry.
- 3–5 NPCs using NavigationAgent3D.
- NPCs visibly walk from house entrances to street destinations and back.
- Contextual interaction prompt on one door or person.

**Acceptance**
- Player can walk around without falling through the world.
- NPCs move continuously; no routine teleporting.
- NPCs follow valid paths and do not walk through house walls.
- Scene runs for at least 10 minutes without errors or stuck agents.
- Headless project validation passes.

## Phase 2 — Complete 30-house starter neighbourhood

**Deliverables**
- Approximately 30 house plots populated from data.
- At least 3 street segments and a coherent connected street/sidewalk network.
- Reusable house exterior and entrance scene.
- House registry with stable IDs and occupancy/ownership states.
- 8–12 active NPCs, scaling toward 20–30 visible/active NPCs.
- Corner shop, gathering point, park/court, and player safehouse.
- Simple day schedule: home → destination → social/work activity → home.

**Acceptance**
- All 30 house IDs are unique and registered.
- Every occupied house has a valid entrance point and reachable street destination.
- NPCs can travel between at least two distinct destination types.
- No routine teleporting.
- NPCs recover from blocked or invalid paths.
- Performance remains acceptable on the agreed target hardware.

## Phase 3 — Living neighbourhood simulation

**Deliverables**
- NPC state machine and schedule data.
- Social groups and simple conversations/gathering.
- Event reactions: notice, investigate, flee, report, return to routine.
- Crew patrol/follow/guard behaviours.
- Time-of-day schedule progression.
- Off-screen simulation tiers to control CPU use.

**Acceptance**
- NPCs show visibly different behaviours.
- AI updates are staggered and distance-aware.
- Disabling or losing a destination does not crash the simulation.
- Debug view can show each NPC's state, target, and path status.

## Phase 4 — Player progression and missions

**Deliverables**
- Mission framework with objectives, prerequisites, rewards, and completion state.
- 3–5 introductory missions.
- Cash, reputation, crew influence, and relationship progression.
- Recruitable crew members.
- Safehouse interaction and basic upgrades.
- Save/load for player and progression.

**Acceptance**
- Missions can start, progress, fail where relevant, and complete.
- Rewards are granted once only.
- Save/load restores stable progression and player state.
- Mission logic is data-driven.

## Phase 5 — Turf control and locked expansion

**Deliverables**
- Starter district ownership/influence.
- Turf status UI and map.
- At least two neighbouring districts represented as locked.
- Explicit unlock requirements (e.g. reputation threshold, key mission, local influence).
- Unlock animation/feedback and persistent save state.

**Acceptance**
- New districts cannot be entered or claimed before unlock.
- Unlock requirement is visible and understandable.
- Unlocking one district persists after reload.
- Starter district remains playable and populated.

## Phase 6 — Vehicles, richer interactions, and polish

**Deliverables**
- Basic traffic/parked vehicles.
- Vehicle entry/exit and simple driving if scope permits.
- Improved animation, audio, lighting, weather, and UI.
- More mission variety and neighbourhood events.
- Performance profiling and optimization.

**Acceptance**
- Vehicles respect the road layout and do not collide with pedestrians unpredictably.
- Visual/audio settings are exposed.
- No major regressions in NPC movement or save/load.

## Phase 7 — Expansion content

**Deliverables**
- First unlockable district with a distinct visual identity and new house/business set.
- New residents, crew, rival faction, missions, and progression.
- Repeatable data-driven district pipeline.

**Acceptance**
- District content reuses proven systems.
- Unlock and travel flow works from the starter district.
- Save compatibility is maintained.

## Current milestone

All roadmap phases (0–7) are validated, and Kalkbos (the second expansion district) is built with the same pipeline. Next candidates: interiors, combat-free conflict systems, a district beyond Rooiduin/Kalkbos. Phases 0–7 are validated (see the log below). Do not mark a phase complete until its acceptance criteria are demonstrated in the running game.

## Milestone log

| Phase | Status | Evidence / notes |
|---|---|---|
| 0 | Done (2026-11-09) | Godot 4.5.1 project launches headless and windowed; input map, main/world scenes, F3 debug overlay; `docs/TECH_NOTES.md` |
| 1 | Done (2026-11-09) | 5 data-driven house plots (4 kits), 5 NavigationAgent3D residents, door → shop/bus stop/corner/court loops, door + NPC interactions. `tests/run_tests.gd`: 65/65 pass incl. 20/20 reachability and 10-min soak (0 teleports, 0 stuck, recovery from closed café). Screenshots in `docs/screenshots/` |
| 2 | Done (2026-11-09) | 30 houses on 4 connected streets from deterministic data (`tools/generate_starter_data.py`), 28 residents (incl. 2 rival crew), 6 public destinations + house visits. Tests 284/284: 162/162 door→destination paths, 10-min soak with 0 teleports, max trip <90 s, 0.72 ms/physics frame headless, recovery from a closed café and a missing destination. Screenshots `docs/screenshots/district_*.png` |
| 3 | Done (2026-11-09) | 14-state brain FSM with time windows/curfew; reactions (notice/investigate/flee/report → resume) via `ReactionPolicy`; social groups with chat bubbles; crew patrol/follow/guard; SimClock + day/night lighting; near/mid/far tiers (think 0.5/1.5/3 s, far = physics-free path stepping). Tests 328/328 (3 consecutive runs): incident → all back to routine in 90 s, crew patrols/follows at night, all residents home by 00:30, 0 teleports, 0.60 ms/physics frame. Screenshots `docs/screenshots/{night_duif,dusk_tortel,incident_debug}.png` |
| 4 | Done (2026-11-09) | `ProgressionState` (cash/rep/crew/relationships, grant-once keys), `MissionManager` + 5 data-driven intro missions (talk/knock/visit/talk_distinct/reputation objectives, auto/giver start, time-limit fail + retry), recruit Boeta into player crew (follows player, guards safehouse), safehouse menu with 4 upgrades (visible props, daily income), rest, versioned atomic JSON save/load with validation. Tests 396/396 (2 consecutive runs) incl. full 5-mission playthrough, reward-once, fail/retry, save→mutate→load restore, corrupt/unknown-version/missing save fallback. Screenshots `docs/screenshots/{mission_tracker,safehouse_menu}.png` |
| 4.5 | Done (2026-11-09) | Polish pass: jointed characters + walk cycle, physics interpolation + smooth camera, NPC acceleration, swinging doors, plot dressing, parked cars, power lines, backdrop city + depth fog. Tests 401/401 ×2. Screenshots `docs/screenshots/polish_*.png` |
| 5 | Done (2026-11-09) | `DistrictManager` (sole unlock authority, data `data/districts/districts.json`), starter influence (rewards + friendly houses) with contested/controlled state, Rooiduin + Kalkbos locked behind boom gates (3 m colliders) with approach streets, turf map (M) with house turf states and ✓/✗ requirement checklists, unlock button → animated gate + banner, Hold the Corner + Beyond the Block missions, unlock persisted and restored on load. Tests 446/446 ×2: gate blocks simulated input, early unlocks refused, full unlock playthrough, walk-through, Kalkbos stays locked, save→relock→load. Screenshots `docs/screenshots/turf_*.png` |
| 6 | Done (2026-11-09) | Left-hand AI traffic (4 cars incl. minibus taxi with stops), brakes for anything in lane, hoot makes pedestrians step aside; 2 drivable cars (enter/drive/hoot/exit, saved); synthesized audio (11 sounds, 3 buses, ambience by time/weather, engines); Esc pause + persisted settings (audio, controls, video, gameplay); weather spells (rain → residents skip leisure); window glow + light pool; calendar events (braai, load-shedding); 3 missions (Spaza Run, Car Trouble, Braai Night); gestures/head look; static mesh batching + LOD (draw calls 1551 → 909). Tests 518/518 ×4 incl. traffic on-road + braking, driving, events, settings, pause. Screenshots `docs/screenshots/p6_*.png` |
| 7 | Done (2026-11-09) | Rooiduin built through the data pipeline (`tools/generate_district.py` + spec; `District` builds every catalog area into one nav bake): 20 houses (flats, row houses), 25 residents incl. Duin Boys crew, container spaza + barber, soccer field, taxi rank, courtyard, red-sand identity, own traffic loop + soccer event. Missions New Turf, Clean Cut (cross-district), Dune Truce (recruits Kaylin). Gates rebake nav on unlock so crew follow across; zebra crossings (roads carved for pedestrians). Phase 5 save fixture loads. Tests 657/657 ×2, 53 NPCs at 1.7 ms/frame. Screenshots `docs/screenshots/p7_*.png` |
| 7b | Done (2026-11-09) | Kalkbos (west) through the pipeline: 22 houses (new limestone cottage kit, stone walls, row houses), 22 residents incl. Klipspringers crew, quarry face + lookout, Kalkbos Hall, fish container, own traffic + church bazaar. Missions Stone and Salt, The Long Haul (Kalkbos ↔ Rooiduin), Quarry Night (recruits Riyaad). Districts-unlocked mission prerequisite. Nav rebake waits for async map iterations (all three areas connect). Tests 765/765 ×2 (10-min soak), 75 NPCs at 1.9 ms/frame. Screenshots `docs/screenshots/kalk_*.png` |
| — | Done (2026-11-09) | Gamepad support (A/B menus, RT/LT driving, pad prompts, stick sensitivity, rumble) and Windows export (`tools/export_windows.sh`, 97 MB exe with embedded data; exported pack boots and renders). Tests 778/778 (10-min soak) |
| — | Done (2026-11-09) | Visual upgrade: Forward+ lighting (SSAO/SSIL/bloom; web keeps Compatibility), Blender-built rigged characters (skinned body, clothing slots, body shapes, hair/hat/skirt, idle/walk/run/talk/guard via AnimationTree), Blender props (bins, trees with wind, aloes, dishes, washing lines, tyre planters, JoJo tanks, chairs, gas bottles), `blender-assets` skill. Tests 780/780 (10-min soak), 75 NPCs at 2.5 ms/physics frame headless. Screenshots `docs/screenshots/v2_*.png` |
| — | Done (2026-11-09) | Sit/lean/wave animations; residents settle onto benches, stoep chairs and walls (SpotRegistry, scripted settle with no teleports); friendly residents wave at the player; named characters get unique looks from `data/npcs/looks.json` (glasses, beards, aprons, collar, chain, afro, ponytail). Tests 791/791 (10-min soak: 99 sits, 4 leans), 2.95 ms/physics frame headless. Screenshots `docs/screenshots/v2_named_characters.png`, `v2_bus_stop_seated.png` |
| — | Done (2026-11-09) | Ambient life: 13 kids (child-sized residents) walk to pitches and play kick-about with a scripted ball (court, Rooiduin field, new Kalkbos lot); 14 yard dogs and 10 street dogs (Blender dog rig: idle/walk/trot/lie/bark), yard dogs bark at the fence, synthesized bark, distance LOD. Tests 842/842 (10-min soak), 88 NPCs + 24 dogs at 3.5 ms/physics frame headless. Screenshots `docs/screenshots/v2_kickabout.png`, `v2_yard_dog.png`, `v2_dogs.png` |
| — | Done (2026-11-10) | Police and combat: Blender vehicles (incl. SAPS-inspired bakkie), police posts, 10 officers on beats, bakkie patrols, pistol/shotgun, arcade combat (aim/shoot, knock-downs, NPC fights, crew back-up), heat and police response, knock-out to safehouse. Tests 911/911 (10-min soak), 98 NPCs at 5.9 ms/physics frame headless. Screenshots `docs/screenshots/v3_*.png` |
| — | Done (2026-11-10) | Set in Mitchells Plain: Westridge (starter), Lentegeur (east), Rocklands (west); AZ Berman Drive and Spine Road; Tafelsig, Beacon Valley, Portlands, Eastridge, Strandfontein and Town Centre listed as planned turf. Internal ids unchanged (saves compatible). Tests 913/913 (4-min soak) |
| — | Done (2026-11-10) | Joinable fictional crews: crew picker at new game, 4 crews with perks, colours, allies/rivals, turf warnings, 8 crew missions, crew-aware story intros, saved crew. Tests 938/938 (10-min soak), 100 NPCs at 6.0 ms/physics frame headless. Screenshots `docs/screenshots/v4_*.png` |
| — | Done (2026-11-10) | The hustle: Aunty Mavis' smokkie (counter, evening crowd, 2 missions), stock from the safehouse runner, phone (P / D-pad up) with contacts, calls and orders, street hand-overs that SAPS can bust, client moods with emoji faces, and lost clients going to rival crews. Tests 973/973 (10-min soak). Screenshots `docs/screenshots/v5_*.png` |
| — | Done (2026-11-11) | Mitchells Plain aunty look: house dresses and maxis in bright prints, slippers/sandals/sneakers, doeks or curlers, gold hoops, handbags, cardigans; 16 of 28 grown women plus named aunties (Mavis, Faiza, Rachel, Gail). Screenshots `docs/screenshots/v6_*.png` |
| — | Done (2026-11-11) | Detail quick wins: painted faces (eyelids, lips, wrinkles, stubble), skin/cloth materials, denim/tracksuits/hoodies/soles/crew cap logos; vehicles with spinning and steering spoked wheels, suspension tilt, clear-coat paint and reflective glass, brake lights, blinking indicators, night headlight beams, made-up Cape plates. Screenshots `docs/screenshots/v7_*.png` |
| — | Done (2026-11-11) | Modeling pass: sculpted heads, fingers, 5 new hair styles, blinking and talking mouths, idle variants, stooped elders; vehicle interiors behind see-through glass with drivers, passengers and two-officer police crews, body details, the skorokoro, dusty cars. Draw calls 2,813 vs 2,800. Screenshots `docs/screenshots/v8_*.png` |
| — | Done (2026-11-11) | House interiors: walk into your safehouse (stash menu, bed), Aunty Mavis' smokkie (bar, pool table, jukebox; Mavis and regulars) and neighbours' homes after they invite you in (residents at home sit inside and can be talked to). Rooms built on entry and freed on exit; police can't see you indoors; saving indoors puts you at the door. Screenshots `docs/screenshots/v9_*.png` |
| — | Done (2026-11-11) | Turf wars: 10 corners held by crews; take corners by standing on them (fight the owners off, crew-mates speed it up); rival pushes on your corners (defend or lose them, with client fallout); wall tags you can paint over; corners on the turf map; saved. Screenshots `docs/screenshots/v10_*.png` |
| — | Done (2026-11-11) | Deeper hustle: house smokkies in Lentegeur (Doreen's) and Rocklands (Ma Lena's), prices that follow heat and turf, hireable runners for phone orders, restock as a timed pick-up drop. |
| — | Done (2026-11-11) | Varied interiors: bedrooms in every home, cottage/flat/double-storey styles, rival crew houses and dens to raid when empty, police posts where you pay off heat. Screenshots `docs/screenshots/v11_*.png` |
| — | Done (2026-11-11) | Town Centre: fourth area east of Lentegeur (the Promenade mall, the market, the big taxi rank, flats, 21 residents, traffic), gated from Lentegeur, 2 missions, 2 corners. Screenshots `docs/screenshots/v12_*.png` |
| — | Done (2026-11-11) | Main storyline with dialogue choices: six story missions across Westridge, Lentegeur and Town Centre; choices set flags, hand over corners, make allies, change later intros; saved. |
| — | Done (2026-11-11) | Sound and music: synthesized radio stations (car radio, R / D-pad down), smokkie music on smokkie nights and indoors, taxi hooters, market callers, church bells, gibberish voices; Music bus with its own slider. |
| — | Done (2026-11-12) | More detail: street litter/potholes/drains/bins, house gutters/meters/aerials/geysers, school uniforms/overalls/Sunday best, phone and shopping-bag animations, hollow taxi with passengers, combi and bakery van, 19 traffic cars, golden hour, dust haze, cloud shadows, wet ground, lamp glow on the ground. |
| — | Done (2026-11-12) | Tafelsig (fifth area, 20 houses, 25 residents, 3 missions, 2 corners); story grudges (retaliation pushes) with Payback, Marlon's Favour and The Dune Debt; puddles and thicker dust; HUD hint fade, scrolling menus, turf map labels; `tests/run.sh`. |
| — | Done (2026-11-12) | Visual pass grounded in research (`docs/MITCHELLS_PLAIN_REFERENCE.md`): Table Mountain and the ranges on the horizon, ground and vegetation detail, owner-added house variety, headscarves/school bags/sway/blob shadows, window glow, SSR + volumetric haze, HUD panels, compass, vignette. |
