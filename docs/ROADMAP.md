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

**Phase 5 — Turf control and locked expansion** is next. Phases 0–4 are validated (see the log below). Do not mark a phase complete until its acceptance criteria are demonstrated in the running game.

## Milestone log

| Phase | Status | Evidence / notes |
|---|---|---|
| 0 | Done (2026-11-09) | Godot 4.5.1 project launches headless and windowed; input map, main/world scenes, F3 debug overlay; `docs/TECH_NOTES.md` |
| 1 | Done (2026-11-09) | 5 data-driven house plots (4 kits), 5 NavigationAgent3D residents, door → shop/bus stop/corner/court loops, door + NPC interactions. `tests/run_tests.gd`: 65/65 pass incl. 20/20 reachability and 10-min soak (0 teleports, 0 stuck, recovery from closed café). Screenshots in `docs/screenshots/` |
| 2 | Done (2026-11-09) | 30 houses on 4 connected streets from deterministic data (`tools/generate_starter_data.py`), 28 residents (incl. 2 rival crew), 6 public destinations + house visits. Tests 284/284: 162/162 door→destination paths, 10-min soak with 0 teleports, max trip <90 s, 0.72 ms/physics frame headless, recovery from a closed café and a missing destination. Screenshots `docs/screenshots/district_*.png` |
| 3 | Done (2026-11-09) | 14-state brain FSM with time windows/curfew; reactions (notice/investigate/flee/report → resume) via `ReactionPolicy`; social groups with chat bubbles; crew patrol/follow/guard; SimClock + day/night lighting; near/mid/far tiers (think 0.5/1.5/3 s, far = physics-free path stepping). Tests 328/328 (3 consecutive runs): incident → all back to routine in 90 s, crew patrols/follows at night, all residents home by 00:30, 0 teleports, 0.60 ms/physics frame. Screenshots `docs/screenshots/{night_duif,dusk_tortel,incident_debug}.png` |
| 4 | Done (2026-11-09) | `ProgressionState` (cash/rep/crew/relationships, grant-once keys), `MissionManager` + 5 data-driven intro missions (talk/knock/visit/talk_distinct/reputation objectives, auto/giver start, time-limit fail + retry), recruit Boeta into player crew (follows player, guards safehouse), safehouse menu with 4 upgrades (visible props, daily income), rest, versioned atomic JSON save/load with validation. Tests 396/396 (2 consecutive runs) incl. full 5-mission playthrough, reward-once, fail/retry, save→mutate→load restore, corrupt/unknown-version/missing save fallback. Screenshots `docs/screenshots/{mission_tracker,safehouse_menu}.png` |
| 5 | Not started | |
| 6 | Not started | |
| 7 | Not started | |
