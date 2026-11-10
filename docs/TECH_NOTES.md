# Technical Notes

## Engine

- **Godot 4.5.1 stable** (`4.5.1.stable.official.f62fdbde1`), standard (non-.NET) build.
- Renderer: **Compatibility (OpenGL 3)**. Chosen so the game runs on low-end hardware and in
  CI containers with software GL (Mesa llvmpipe). Switch to Forward+ later if needed.
- Physics: Godot Physics 3D, 60 ticks/s.

## Commands

```bash
# One-time / after adding assets: import resources (creates .godot/, ignored by git)
godot --headless --path . --import

# Run the game
godot --path .

# Automated tests: data, NPC brain, district integration, 10-minute simulated soak
godot --headless --path . --fixed-fps 60 -s tests/run_tests.gd -- --soak-minutes=10

# Screenshots (needs a display; in a container use xvfb-run)
xvfb-run -a godot --path . --rendering-driver opengl3 -- \
  --shot=res://tests/output/street.png --player=-20,2 --yaw=-140 --pitch=-8 --shot-delay=14
#   other flags: --view=overview|street  --debug  --interact

# Rebuild pixel textures (Node >= 22.18)
tools/build_textures.sh

# Regenerate house/resident data (deterministic; keeps h01-h05 and the first 5 residents)
python3 tools/generate_starter_data.py
```

`--fixed-fps 60` advances exactly 1/60 s per frame, so a 10-minute soak runs in about 12 s.

## Architecture (Phase 0–1)

| Area | Files | Notes |
|---|---|---|
| Bootstrap | `scenes/main/main.tscn`, `scripts/core/main.gd` | Wires district, player, HUD and debug overlay with signals; screenshot CLI |
| District | `scenes/world/vleirand.tscn`, `scripts/world/district.gd`, `street_builder.gd` | Builds from `data/districts/starter.json`; bakes navigation at load |
| Houses | `scenes/houses/house_plot.tscn`, `scripts/houses/*` | `HouseData` (Resource), `HouseRegistry` (validation), `HousePlot` (4 kits from reference photos) |
| Navigation | `scripts/navigation/destination_registry.gd` | Destination IDs → nav-snapped points with spread radius |
| NPCs | `scenes/npcs/resident.tscn`, `scripts/npcs/*` | `NpcBrain` (pure FSM), `Resident` (CharacterBody3D + NavigationAgent3D), `NpcData` |
| Player | `scenes/characters/player.tscn`, `scripts/player/player.gd` | Third-person SpringArm camera, camera-relative movement, interaction sensor |
| UI/debug | `scripts/ui/hud.gd`, `scripts/ui/debug_overlay.gd` | Prompt, messages, F3 debug, F4 reachability |
| Art | `art/vleirand.px.js` → `assets/textures/pxl/` | pxl pixel textures; world-triplanar at 16 px/m |

Physics layers: 1 world, 2 player, 3 NPCs, 4 interactables.

## Navigation details and gotchas

- The NavigationMesh is baked at runtime from **static colliders** under `NavigationRegion3D`.
  Houses, fences and landmarks are `StaticBody3D`, so they are carved out of the mesh;
  ground surfaces such as roads and paths are visual-only planes on one ground slab.
- Agent radius 0.5 m (voxel-aligned to the 0.25 m cell size). Gates are 1.8 m wide.
- The baked surface sits about 0.5 m above the ground, so `NavigationAgent3D.path_height_offset = 0.5`.
  Without it the first path point is never "reached" and NPCs stand still at their doors.
- After a bake the map syncs on a later physics frame. `District` waits until the region owns
  map points before spawning NPCs; otherwise queries return the origin.
- Two residents of one house never step out together: an NPC waits inside until the doorway
  is clear, which avoids capsule overlap and depenetration pops.

## Performance (Phase 2)

28 residents with avoidance: about 0.72 ms per physics frame headless (10-minute soak, 36,000 frames).
The debug overlay lists only the 6 nearest residents, so it stays cheap at scale.

## NPC recovery chain

1. No path: retry up to 3 times with a wider random spread around the anchor.
2. Stuck (moved < 0.3 m in 2.5 s): step for 0.8 s along the last wall normal plus a sideways
   component, then re-path.
3. Still failing: the brain skips to the next schedule entry. After repeated failures, or when the
   route home fails, the NPC goes `UNAVAILABLE` and retries home after 6 s.

## Phase 3 simulation

| Piece | File | Role |
|---|---|---|
| `SimClock` | `scripts/core/sim_clock.gd` | Time of day, advanced on physics ticks (deterministic) |
| `SimulationDirector` | `scripts/npcs/simulation_director.gd` | Tiers, social groups, incident delivery, ambient incidents |
| `NeighbourhoodEvents` | `scripts/world/neighbourhood_events.gd` | Incident hub; HUD listens to `message` |
| `ReactionPolicy` | `scripts/npcs/reaction_policy.gd` | Pure choice of notice/investigate/flee/report |
| `DayNight` | `scripts/world/day_night.gd` | Sun/moon, sky, ambient, lamp emission |

Tiers, by distance from the player:

| Tier | Distance | Think interval | Movement |
|---|---|---|---|
| near | < 30 m | 0.5 s | physics + avoidance, bubbles, walk bob |
| mid | 30–60 m | 1.5 s | physics, no avoidance |
| far | > 60 m | 3.0 s | steps along the same nav path every 0.25 s, no physics |

Movement guards: a **teleport** (more than 0.5 m in one frame) must never happen and is asserted
to be 0. A **nudge** (more than a walking step, from physics depenetration after brief contact,
mostly when leaving the far tier) is counted and kept rare. The test allows 20 per run;
typical runs show 0–2 across about 1M NPC-frames.

Avoidance and physics make runs slightly non-deterministic, so validate with 2–3 consecutive
runs. Set `CK_DEBUG=1` to print every travel failure and jump with its cause.

## Phase 4 progression and saves

| Piece | File |
|---|---|
| Session wiring | `scripts/core/game_session.gd` |
| Progression model | `scripts/progression/progression_state.gd` |
| Missions | `scripts/missions/mission_data.gd`, `mission_manager.gd`, `data/missions/intro.json` |
| Safehouse | `scripts/progression/safehouse.gd`, `data/progression/safehouse_upgrades.json` |
| Saves | `scripts/save/save_system.gd` → `user://savegame.json` |

- Gameplay systems learn what the player interacted with from `Interactable.kind` / `.target`
  ("npc"/npc id, "door"/house id) via `Player.interacted_with`.
- The mission manager only talks to the world through injected callables (`resident_info`,
  `occupants_inside`, `anchor_position`), so it is unit-tested without scenes.
- Saving stores stable state only. Residents restart from their homes and recruits are reapplied
  from `recruited_crew_ids`.
- Adding a mission: append to `data/missions/intro.json` and run the tests. They check that
  prerequisites, givers, NPC targets and houses exist.

## Smoothness and detail (polish pass)

- `physics/common/physics_interpolation=true`. Anything moved directly (spawning at a door,
  loading, debug teleports) must call `reset_physics_interpolation()`. The player has
  `snap_camera()` for this.
- Camera: `CameraPivot` is `top_level` with interpolation off; `Player._process` places it at
  `get_global_transform_interpolated()` + 1.6 m (vertical smoothing only).
- `CharacterModel`: Hips → LegL/LegR, Torso → ArmL/ArmR/Head(Hair, Cap). `animate(delta, speed)`
  drives the gait; meshes are cached statically.
- Plot dressing comes from `props` in `data/houses/starter_houses.json`, produced by the
  generator with a per-house seed. `HousePlot._free_side()` keeps solid props off paths and driveways.
- Street dressing (`parked_cars`, `decals`) is in `data/districts/starter.json`; backdrop houses
  and wires are generated in `StreetBuilder`.

## Phase 5 turf

| Piece | File |
|---|---|
| District catalog | `data/districts/districts.json` |
| Unlock authority | `scripts/progression/district_manager.gd` |
| Gates + approach streets | `scripts/world/district_gate.gd`, `StreetBuilder._build_boundary/_build_approach` |
| Turf map | `scripts/ui/turf_map.gd` |

- The flow is: TurfMap Unlock button → `GameSession.request_unlock` → `DistrictManager.unlock_district`
  (validates) → `district_unlocked` signal → `District.set_district_open` (boom animation) + banner.
  Nothing else opens gates. On start and after loading, `GameSession.sync_gates()` mirrors the saved state.
- Gate colliders exist when the nav mesh is baked, so NPCs never route into neighbouring districts,
  even after an unlock.
- Adding a district: add an entry with a `side` to `districts.json`. Its gates and approach streets
  appear wherever an east-west street crosses that side of the boundary.

## Phase 6 systems

| Piece | File |
|---|---|
| AI traffic | `scripts/vehicles/traffic_system.gd`, `traffic_car.gd` (data: `traffic` in starter.json) |
| Drivable cars | `scripts/vehicles/drivable_car.gd`, `Player.enter_vehicle/exit_vehicle` |
| Audio | `scripts/audio/audio_bank.gd` (synth), `audio_director.gd`, `default_bus_layout.tres` |
| Settings / pause | `scripts/core/settings_store.gd`, `scripts/ui/pause_menu.gd`, `main.apply_settings()` |
| Weather | `scripts/world/weather.gd` (+ `DayNight.overcast`, `NpcBrain.raining`) |
| Lighting | `DayNight.power_on`, window emission, `scripts/world/light_pool.gd` |
| Events | `scripts/world/neighbourhood_calendar.gd`, `data/events/calendar.json`, `NpcBrain.pending_event` |
| Batching / LOD | `scripts/core/mesh_merger.gd`, `scripts/core/lod.gd` |

Physics layers: 1 world, 2 player, 3 NPCs, 4 interactables, 5 drivable vehicles, 6 AI traffic.
Residents collide with world, player, NPCs and drivable cars, but not AI traffic.

Profiling (Xvfb + llvmpipe, street view, 1280×720):

| | draw calls | objects | nodes |
|---|---|---|---|
| no batching / LOD | 1,551 | 1,927 | 3,390 |
| batching + LOD | 909 | 1,285 | 2,605 |

Frame time under software rendering (~200 ms) is not representative of a GPU. Headless
simulation cost is about 1.2 ms per physics frame with 28 residents and 4 cars.

Extra flags: `--profile`, `--no-lod`, `--day=N`, `--weather=rain`, `--drive=car_player`, `--pause-menu`.

## Phase 7: adding a district

1. Write a spec like `tools/specs/rooiduin.json` and run `python3 tools/generate_district.py <spec>`.
2. Write the district file (like `data/districts/rooiduin.json`): bounds, streets, landmarks, pois,
   patrol_routes, traffic, parked_cars, decals, ground_texture, ground_margin / open_sides /
   backdrop_skip for sides shared with a neighbour, houses_file, residents_file.
3. Add `data` and `missions` to its entry in `data/districts/districts.json` (with a `side` and
   `unlock_requirements` if it starts locked).
4. Add missions in their own file; give calendar events a `district`.
5. Run the tests. Reachability is checked per district, and every door must reach every POI of
   its own district.

Building types available: single_hip, single_gable, double_semi, double_garage, flats, row_house, cottage.
Fence types: low_wall, palisade, precast, stone (spec `fences` is a weighted dict; rows may list `kits`).
Landmark types: cafe, bus_stop, court, park, corner, container_shop, soccer_field, taxi_rank, courtyard,
church_hall, quarry_face, lookout. Missions can require unlocked districts (`prerequisites.districts`).

Navigation rebakes (`District.rebake_navigation`) run on a thread, then wait for two fresh
navigation-map iterations before emitting `navigation_rebaked`: Godot 4.5 syncs maps
asynchronously, and reading the map a fixed few frames after `bake_finished` can still see the
old mesh. Rocklands is the worked example of a second district (`tools/specs/kalkbos.json`).

## Models and rendering

- **Renderer:** Forward+ on desktop; `rendering_method.web` / `.mobile` stay `gl_compatibility`.
  - `RenderQuality.apply()` turns on SSAO, SSIL, glow and filmic tonemapping, only under Forward+
    and when the "video/effects" setting is on.
  - Screenshots in this container use Mesa's lavapipe Vulkan driver
    (`apt-get install mesa-vulkan-drivers`): drop `--rendering-driver opengl3` from the `--shot`
    command.
- **Models are code:** see `.claude/skills/blender-assets/SKILL.md`.
  - Blender 4.5 LTS headless: `blender -b --factory-startup --python tools/blender/build_character.py`
    (or `build_props.py`), then `godot --headless --path . --import`.
  - Character line-up: `xvfb-run -a godot --path . -s tools/godot/lineup.gd -- --out=res://tests/output/lineup.png [--close | --named]`.
- **Spots:** `SpotRegistry` collects Marker3D nodes in the groups `spot_sit` and `spot_lean`. Add one
  with `SpotRegistry.marker(parent, kind, local_pos, rot_y)`, facing the way the person should face.
  - Sit markers go at the middle of the seat.
  - Lean markers go 0.3 m out from the wall face.
  - The approach point (0.85 m for sit, 0.55 m for lean, straight out in front) must be on the
    navigation mesh.

## Ambient life

- **Kids:** residents with role `kid` (`data/npcs/kids.json`, loaded through
  `District.extra_residents_files`) and activity `soccer`.
  - `KickAbout` (one per entry in an area's `kickabouts`: poi, center, half extents) sets
    `Resident.play_target` and `play_speed` for the kids dwelling at its POI. The resident's
    physics does the moving.
  - Kids at play bypass RVO avoidance.
  - The ball is a scripted mesh, never a body.
- **Dogs:** `DogPack` reads the area's `"dogs"` counts.
  - Yard dogs steer inside `HousePlot.front_yard()`.
  - Street dogs path on the navigation mesh between nearby `house_gate` anchors.
  - They have no collision layer (mask = world only).
  - LOD: physics stops beyond 60 m.
  - Barks go `District.dog_barked` → `AudioDirector` ("bark").

## Police and combat

- **Shots:** `CombatSystem` (District child). `fire()` raycasts on `SHOT_MASK` (world, player,
  NPCs, cars) and calls `on_shot(damage, shooter)` on the target. It also emits `shot_fired` /
  `target_hit` and raises a "gunfire" incident (severity 4; at most one per shooter per 2 s).
- **Health:** `Health` (pure) handles knock-downs; never lethal.
- **Brain:** FIGHTING (schedule paused) and DOWN states. `Resident.start_fight(target)` /
  `end_fight()`. Fighters are roles crew, police and player_crew, armed in `Resident._arm()`.
- **Police:** `PoliceDispatch` (GameSession child) owns `Heat` and decides who fights whom. It also
  runs the bakkie lights (`VehicleLibrary.set_lights`) and sirens, and the player's knock-out.
  - Officers come from `data/npcs/police.json`; their home is a post's `<id>:door` anchor, which
    the police_post landmark registers.
- **Screenshots:** `--firefight` stages a stand-off with the nearest officer; `--follow` frames them.

## Crews

- `data/factions/crews.json` (`CrewCatalog`) defines the crews: id, name, home district, colour,
  boss, perk, warning line.
- `GameSession.choose_crew(id)` joins a crew (it also re-applies perks after a load).
  `open_crew_picker()` shows the choice. `--crew=<id>` skips it; screenshots default to the
  Vipers, and `--crew-picker` shows the picker.
- `District.set_player_crew` sets `Resident.player_faction`; `Resident.is_ally()` follows from it.
- PoliceDispatch handles ally back-up and rival turf checks: warn at 12 m, fight after 5 s
  within 6 m, or when aimed at within 15 m.
- Crew missions use `prerequisites.member_of`; story text varies with `intro_by_crew`.

## Windows build and gamepad

```bash
tools/export_windows.sh     # -> build/windows/Gangstars.exe + Gangstars-windows.zip (gitignored)
```
- The preset is "Windows Desktop" in `export_presets.cfg`. Non-resource files (`*.json`) are
  included explicitly; tests/tools/docs/art are excluded.
- `application/modify_resources` is off (it would need rcedit), so the exe has Godot's default
  icon and no version info.
- Saves and settings on Windows are in `%APPDATA%\Godot\app_userdata\Gangstars\`.
- The Compatibility renderer uses OpenGL 3.3; on GPUs without it Godot falls back to ANGLE
  (Direct3D 11).
- Gamepad bindings are in `project.godot`.
  - `accelerate`/`brake` are the triggers.
  - `ui_accept`/`ui_cancel` are overridden to add A/B.
  - On-screen button names come from `scripts/ui/input_hints.gd`.
- Tests simulate pad input with `Input.parse_input_event` (`_test_gamepad_in_game`).

## Known limitations

- The Windows build has not yet been tried on real Windows hardware or with a physical controller;
  both are verified only through the exported pack and simulated input.

- Characters are one shared stylized body with mitten hands and no facial animation. Five body
  animations exist (idle, walk, run, talk, guard): no sitting, waving or fighting yet.
- Forward+ cost on real GPUs hasn't been measured. In this container it renders through a CPU Vulkan
  driver, so frame rates here say nothing.
- In software-rendered containers the game runs at about 8 FPS; this is not representative of real GPUs.
