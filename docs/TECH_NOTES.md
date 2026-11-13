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

Extra flags: `--profile`, `--no-lod`, `--day=N`, `--weather=rain|cloudy|windy|clear` (held for the shot), `--wet`, `--drive=car_player`, `--pause-menu`.

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

## Story dialogue

- A `dialogue` objective makes `MissionManager.on_interaction` emit `dialogue_requested`.
- `GameSession.open_dialogue` shows the scene through the HUD menu.
- `choose()` → `apply_effects()` → `missions.finish_dialogue()`.
- Flags live in `ProgressionState.flags` and are saved. "ally:<crew>" flags fill
  `TurfWar.allies`.

## Chained districts

- An area's data can name a locked neighbour on its own side, e.g.
  `"neighbours": {"east": "district_town_centre"}` in rooiduin.json.
  `District._load_areas` turns that into `locked_neighbours`, so that edge gets gates and an
  approach street.
- The catalog entry carries a non-compass `side` ("far east"), so it lists as a neighbour on the
  turf map without Westridge also gating it.

## Turf wars

- **TurfState** (pure, unit-tested): corners {owner, control, push_crew, push_until}.
  `tick(now, dt, presence)` takes a callable returning {player, crew, owners, pushers} for a
  corner. Signals: flipped, push_started, push_ended.
- **TurfWar** (child of the GameSession):
  - Computes presence within 12 m (on foot, not indoors, not down).
  - Starts pushes by giving up to 3 rival members a `pending_event` (guard at the corner
    anchor, event "turf").
  - Provokes pushers within 9 m through `PoliceDispatch._provoke`.
  - Sprays Decal tags on the nearest wall found by 12 ray casts (ground as a fallback), each
    with a "paint over" Interactable.
  - Applies the flip rewards and penalties.
- **Push timing:** `next_push` counts down played minutes, at most 30 per tick. Tests set it to
  1e9.

## Interiors

- `InteriorSystem` (child of the GameSession) owns entering and leaving:
  - `why_not(id)`: the safehouse is always open; the smokkie opens 10–23; houses need a
    welcome.
  - `welcome(id)` is called by `District._on_door` when someone home answers. While welcomed,
    the next door press sets `district.enter_request`, which the GameSession turns into
    `enter()`.
  - `enter()` builds the room with `InteriorBuilder.build(root, kind, seed)` at DEPTH (−40 m)
    under the door, adds stand-ins and fittings, and teleports the player.
  - `leave()` puts the player outside the door and frees the room. `discard()` drops it
    without moving the player.
- **Stand-ins:** CharacterModels dressed from the resident's data. Their Interactable reuses
  the resident's `kind`/`target`/`on_interact`, so missions, dealing contacts and
  relationships behave as outside. They vanish when the resident heads out.
- **Room shell:** the room's solid ceiling blocks police line of sight. A save stores
  `outside_position()`.
- **Layouts:** `home`, `safehouse` and `shebeen` in `interior_builder.gd`. Furniture props
  come from `build_props.py`, with collision sizes in `InteriorBuilder.SOLID`.

## Modeling pass

- **Heads:** `sculpt_skull()` deforms one sphere with gaussian bumps in coordinates normalised
  to the skull radii. Eyes, brows, nose and mouth are placed by ray-casting the sculpted surface
  (`surf_y`). Hair cuts use `cut_below(..., slope=)` so hairlines rise at the front.
- **Hair:** `NpcData._hair_for()` remaps generated hair (not looks.json characters).
- **Life:**
  - `CharacterModel._apply_face()` runs after the animation. It toggles `Blink` and
    `Mouth_open` (talk mode), and bends spine and neck forward by `stoop` (head back up).
  - `opts.idle` picks idle, idle_shift or idle_hips for the locomotion blend space.
- **Vehicles:**
  - `interior()` in build_vehicles.py records `<model>_seat_N` empties; the driver comes first,
    on the right (Blender −X).
  - `VehicleLibrary.add_occupants()` places `occupant_driver` / `occupant_passenger` busts there.
  - Glass is alpha-blended. Body vertex colours hold grime, and dirty cars set
    `vertex_color_use_as_albedo` on the paint.

## Detail pass (faces, clothes, vehicles)

- **Faces:** `Face_paint` is a copy of the head's front, pushed out 1.5 mm, with front-projected
  UVs (0.2 m square, chin to brow). `PixelMaterials.face(tex, skin)` uses an alpha-scissor pxl
  overlay multiplied by the skin colour. The textures are `face_m`, `face_f`, `face_old_m`,
  `face_old_f` and `face_stubble` in `art/vleirand.px.js`.
- **Clothes:**
  - `NpcData._everyday_look()` picks the face, `pants_style` (denim / tracksuit / plain), the
    hood, `sole_color` and `cap_logo` (crew members).
  - Body cloth UVs: the torso wraps 6× around, arms 4× round their slanted axis, and each leg
    once (mirrored, seam inside, u = 0.5 outside). Denim scales it ×4. Tracksuit stripes are a
    detail mask.
- **Vehicles:**
  - `VehicleLibrary.build()` gives pivot > Tilt > Mesh and pivot > Wheels > Wheel0..3. The front
    pair comes first; wheels on the −X side are turned round (meta `flip`).
  - `animate(pivot, speed, steer, accel, indicate, delta, time)` is called every physics frame
    by TrafficCar (steer from yaw rate, indicators from the next curve) and DrivableCar.
  - `add_headlights()` gives moving cars two unshadowed spotlights, visible when
    `VehicleLibrary.night` (set by DayNight) is above 0.4.

## The aunty look

- `NpcData.appearance()` gives grown women residents the Mitchells Plain aunty look by hash
  (`dress == -1`, no hand-made skirt or accessories, figure > 0.5): about 3 in 4 of them.
- `_aunty_look()` picks a print or a solid colour, shoes, and the cardigan and bag colours.
  Hoops (60%), a handbag (40%), a cardigan (1 in 3), and curlers (1 in 5) or a doek (2 in 5).
- `dress: 1` in looks.json uses only the listed accessories and hair; `dress: 0` opts out.
- In `CharacterModel`, `opts.dress` shows `Dress`, hides the skirt and makes the legs skin.
  `opts.print` (a `PRINTS` name) puts `PixelMaterials.fabric()` on the shirt and dress slots.
  The `cardigan` accessory also shows its arm sleeves and recolours the forearm slot.

## Crews

- `data/factions/crews.json` (`CrewCatalog`) defines the crews: id, name, home district, colour,
  boss, perk, warning line.
- `GameSession.choose_crew(id)` joins a crew (it also re-applies perks after a load).
  `open_crew_picker()` shows the choice. `--crew=<id>` skips it; screenshots default to the
  Stylers, and `--crew-picker` shows the picker.
- `District.set_player_crew` sets `Resident.player_faction`; `Resident.is_ally()` follows from it.
- PoliceDispatch handles ally back-up and rival turf checks: warn at 12 m, fight after 5 s
  within 6 m, or when aimed at within 15 m.
- Crew missions use `prerequisites.member_of`; story text varies with `intro_by_crew`.

## Dealing (the hustle)

- **Venues:** `dealing.json` venues {id, name, host, crowd, hours, sign}. An id is either the
  shebeen landmark or a house id. House venues get a sign and a door that enters directly
  (InteriorSystem layout "shebeen").
- **Prices:** `DealingController.price_mult(area)` covers heat and the turf share of the
  suburb's corners. `DealingState.price(p, mult)` rounds to R5.
- **Runners:** `DealingState.send_runner()` / `resolve_runners(minutes, rng, success, mult)`.
- **Drops:** `DealingState.order_drop()` / `collect_drop()` / `expire_drops()`. The controller
  shows each drop as a crate with a Collect Interactable at `drop_anchor()`.

- `data/dealing/dealing.json` holds the tuning: products, restock lots, call timing, order windows
  and mood rules.
- `DealingState` is pure logic and unit-tested. It holds stock, clients (mood, status, rival),
  orders, the ringing call and stats. `tick(minutes, rng, rival_for, can_call)` drives calls and
  expiries.
- `DealingController` (a child of the GameSession) links the state to the world:
  - contacts are saved from chats (`on_chat`);
  - `answer()` sets the client's `brain.pending_event` so they wait at their gate;
  - `try_sell` / `police_watching` handle street deals;
  - the smokkie counter is an Interactable (`serve_counter`);
  - mood faces are Sprite3D billboards.
- `Phone` (`scripts/ui/phone.gd`) is the HUD panel; `GameSession.toggle_phone()` opens it.
- Missions use the `stat` objective, read through `MissionManager.stat_value`
  (`DealingState.stat`).
- Screenshots: `--hustle` stages clients and an open phone; `--hustle=street` shows the faces in
  the world.

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


## Detail pass (2026-11-12)

- `StreetDetail.build(root, area_info)` adds litter, potholes, drains, manholes, bins, humps and a
  transformer box per street from a seeded RNG. Plain meshes with shared `PixelMaterials`, no
  colliders, so MeshMerger batches them and navigation is unchanged.
- `HousePlot._build_facade_details()` adds gutters, downpipes, sills, meter boxes, cracks, rust
  stains, canopies, aerials and solar geysers, rolled from the house id.
- Vehicles: `build_vehicles.py` builds `combi` and `panel_van`; the taxi uses `cabin()` with real
  glass and `interior()` with four seat rows. `VehicleLibrary` gives taxis 4–9 passengers and the
  panel van two `BakeryPanelL/R` quads (`van_bakery` texture).
- Atmosphere: `Weather` feeds `DayNight.dust` (wind), `.wet` (rain, dries slowly) and
  `.cloud_cover`; `PixelMaterials.set_wetness()` darkens and glosses every triplanar surface
  material. Cloud shadows are three 70 m decals with a noise texture built synchronously
  (an async `NoiseTexture2D` never reached the decal atlas). `LightPool` draws one
  MultiMesh of additive ground glows under every lamp at night. `Weather.hold(kind)` fixes the
  weather for screenshots.

## Running the tests, and the exit abort (2026-11-12)

Use `tests/run.sh [--soak-minutes=2] [--units-only]`. It runs the suite and decides pass/fail from
the "N passed, M failed" line. Why: when the suite runs as a SceneTree script (`-s`), Godot 4.5.1
headless aborts at shutdown with "corrupted size vs. prev_size in fastbins" (exit 134) after
printing the summary. What we established:
- it needs the full game scene (the district alone, an empty script and the unit tests alone are
  clean) and a run longer than a few seconds;
- the real game exits cleanly: `--quit-after 8000`, and `SceneTree.quit()` from inside the game;
- valgrind shows engine teardown touching a freed 1.7 KB object (mutex lock) in `main()`'s cleanup,
  i.e. inside the engine, not in game code;
- not caused by audio loops, the PackedScene reference, `auto_load`, `current_scene` or how Main
  is attached. Left as a known engine issue; re-check on the next Godot update.

## Story grudges (2026-11-12)

`GameSession.apply_effects()` understands `retaliation: {crew, minutes}`: it stores
`progression.flags["retaliate:<crew>"] = due game minute` (saved with the flags). `TurfWar` checks
those every tick; when due, and no push is already on, the crew starts a push on one of your
corners (`start_push`, ignoring the push timer and reputation gate). No corners of yours yet: it
waits. The crew has nobody near your corners: the grudge is dropped. An ally never holds a grudge.
Holding off a push increments the `pushes_held` stat (`DealingState.stats`, usable by `stat`
objectives).

## Tafelsig (2026-11-12)

`tools/make_tafelsig.py` shifts Lentegeur's layout 312 m east and writes
`tools/specs/tafelsig.json` + `data/districts/tafelsig.json`; `tools/generate_district.py` then
writes the houses and residents. Town Centre names it as its east neighbour (gates), the catalog
entry in `data/districts/districts.json` carries the unlock requirements.

## The look pass (2026-11-12)

- `Skyline` is a Node3D under the district that copies the camera's X/Z every frame. Its layers are
  ArrayMesh ribbons around a 900 m circle (bearing = compass degrees, 0 = north = -Z), heights from
  control-point tables scaled by `HEIGHT_SCALE`; vertex-colour unshaded materials with
  `disable_fog`, tinted by `DayNight.apply()` through `set_atmosphere(horizon, night, overcast,
  dust, wind)`. The base is 140 m below ground so it never floats at low angles.
- `GroundDetail` and `StreetDetail` add only plain meshes with shared `PixelMaterials.panel`
  materials: MeshMerger batches them, and there are no colliders (navigation is unchanged).
- `HousePlot._build_owner_additions()` is deterministic from the house id and visual only; rear
  rooms are skipped if the plot is too shallow. `NightGlow` is one shared additive material whose
  alpha `DayNight` sets (night x power), so load-shedding darkens the yards too.
- Characters: `Hair_hijab` and `Acc_backpack` come from `tools/blender/build_character.py`
  (`make_hijab`, `make_backpack`); `CharacterModel._apply_sway()` rolls the model root with the
  stride; `BlobShadow` is a shared-material disc.
- `RenderQuality.apply()` adds SSR and volumetric fog on Forward+ only (the web/Compatibility
  renderer ignores them); `DayNight` sets the fog density from dusk and dust.
- `Hud.panel_style()` is the one panel look; `set_heading()` drives the compass (Main computes the
  camera heading), `set_night()` the vignette strength.

## Missions, accessibility and tooling (2026-11-12)

- **Follow objective:** `MissionManager` emits `objective_started`; `GameSession` then gives the person a
  `pending_event` to walk to the destination. Each tick `_update_follow()` completes it when they are
  at the goal and you are within `max_distance`, and fails the mission after `lose_minutes` spent too far
  behind. `npc_position` and `anchor_position` are injected callables.
- **Effects** in `scenes.json` choices: `retaliation`, `turf_allies`, `turf_release`, `banner`.
- **Re-binding:** `InputRebinder` swaps keyboard/mouse events on the InputMap (gamepad untouched), keeps a
  snapshot of the defaults, saves to the `bindings` section of `settings.cfg`; `InputHints.custom` holds
  the new key names for the prompts.
- **Captions:** `AudioDirector.sound_heard(label, pos)` for the sounds in `CAPTIONS` within 45 m; `Main`
  turns it into `Hud.show_caption()` with a left/right arrow from the camera.
- **Autosave:** `GameSession.autosave()` after `mission_completed` and `day_changed`; `autosave_enabled`
  is for tests, `autosave_user` is the player's setting.
- **Crowd range:** `SimulationDirector.dormant_distance`; `Resident.set_dormant()` hides it and stops
  `_process`/`_physics_process`. Not dormant: crew, anyone mid-incident, on an errand or inside.
- **Screen effects:** two canvas shaders on the HUD (`hint_screen_texture`); they are only visible while
  there is rain or heat, so they cost nothing the rest of the time.
- **Playtest bot:** `tests/playbot.gd` (`--crew=`, `--choice=`). It cheats on district unlocks, crew
  nearness and stats, takes one dialogue choice throughout, and skips what needs another crew or
  branch. `tests/playbot.sh` runs four crew/branch combinations.

## Vehicle detail (2026-11-13)

- `VehicleDetail.dress()` runs at the end of `VehicleLibrary.build()`; positions are in the body's
  Tilt space (front +Z, left +X). `DIMS` holds each model's width, half length, sill, roof, windscreen
  corners and wheelbase (copied from `tools/blender/build_vehicles.py`; keep them in step).
- The Blender script now exports marker empties `<model>_steer`, `_dash` and `_wiper_N` instead of
  baking the wheel and wipers into the mesh; Godot builds the turning wheel and sweeping blades.
- Shared materials (`VehicleLibrary.drops_material()`, `dash_material()`) change alpha with `rain` and
  `night`; `Weather` sets `VehicleLibrary.rain`, `DayNight` sets `dust`, `wet`, `haze`.
- `VehicleLibrary._animate_detail()` is the per-frame part (steering ring, wipers, exhaust, dust, brake
  glow, skid marks); `hit()` adds dents and a cracked windscreen; `dress_parked()` is the parked-car
  variety (cover, bricks, flat tyre).
- Scooters have two wheels: `front` is set for the front half of the wheel list, not `k < 2`.
- `tools/godot/lineup.gd --cars [--only=<model> --dist=8]` renders the fleet or one vehicle.
