# Changelog

All notable development milestones should be recorded here.

## Unreleased

### The Mitchells Plain aunty look (2026-11-11)
- Most grown women residents (16 of 28 across the three suburbs) now dress in the classic
  Mitchells Plain aunty style:
  - **House dresses and maxis:** long, with an elasticated waist, in bright cotton prints
    (rose, blue, sunflower, teal, lilac) or a bright solid colour.
  - **Comfort footwear:** slippers or PVC sandals in pink, sky blue or black, white sneakers, or
    tan wedges.
  - **Hair and accessories:** a satin doek or pink curlers, bold gold hoops, and a handbag in
    the hand.
  - **Layers:** a cardigan, or an apron on the named cooks.
- Generated looks are deterministic per resident.
- Named aunties have hand-made outfits:
  - Aunty Mavis: lilac print, red doek, black cardigan.
  - Auntie Faiza: rose print, blue doek, hoops, handbag.
  - Rachel: sunflower print, curlers, apron.
  - Gail: teal print, white cardigan, apron.
- **Data:** `data/npcs/looks.json` takes `dress`, `print`, `shoe_color`, `cardigan_color` and
  `bag_color`; `dress: 0` opts someone out.
- **Models:** the Blender character gains Dress (weighted to the legs so it drapes over the knees
  when sitting), Acc_hoops, Acc_curlers, Acc_handbag and Acc_cardigan (with sleeves). Body,
  dress and cardigan get cylindrical cloth UVs for the prints. Prints are pxl textures
  (`print_*`). `lineup.gd --aunties` shows the look; the `--aunty` screenshot flag frames one in
  game.
- **Tests:** look derivation, variety, named outfits, and the model showing the right pieces. The
  traffic stop test tolerates slow queued cars.

### The hustle: smokkie, phone and clients (2026-11-10)
- **Aunty Mavis' smokkie** (shebeen) in Westridge, with a counter, chairs and
  a "smokkie night" crowd every evening (17:00–23:00). Mavis (`npc_mavis`) gives two missions
  (`data/missions/dealing.json`):
  - *The Smokkie*: serve 3 drinks at her counter, then report back.
  - *Bankies*: save 3 client contacts, then make 3 street deals.
- **Stock:** buy bankies (weed) and drinks from your crew's runner in the safehouse menu. Prices,
  timings and mood rules live in `data/dealing/dealing.json`.
- **Phone (P / D-pad up):** stock, contacts with mood faces, open orders, and incoming calls
  (answer or decline). Once *Bankies* starts, chatting to an interested neighbour saves them as a
  contact.
- **Calls and street deals:** clients ring with orders. Answering sends them to wait at their gate
  until a deadline; talk to them to hand over. If an officer with line of sight (18 m) or a police
  bakkie (25 m) sees it, it's a bust: stock lost, heat +2, client spooked.
- **Client moods:** fast and on-time deals cheer clients up; late, declined, missed and busted deals
  annoy them. Below 25 they buy from a rival crew instead (you get a message, and the phone
  shows who). The phone has a "win them back" button. Emoji-style faces (happy, ok, meh, angry,
  lost) float over clients within 16 m and show in the phone.
- **Missions:** new `stat` objective type (`{stat, value}`) for game counters (drinks sold,
  contacts, street deals).
- **Saving:** stock, clients, orders and stats are saved.
- Kept fictional and game-like: no real-world specifics.
- **New:** DealingState (pure logic, unit-tested), DealingController, Phone UI, shebeen landmark,
  mood/phone/item sprites, a ring sound.
- **Tests:** dealing unit and in-game tests. The traffic "stops for the player" test is now robust
  to queued cars.

### Crew names (2026-11-10)
- The fictional crews are renamed in a more Cape Flats style: Tortel Laaities, Spine Road Stylers,
  Dune Cruisers and Rock Royals (internal ids unchanged).
- Graffiti tags, mission text, dialogue and turf warnings follow the new names.
- Real gang names are deliberately not used.

### Join a crew (2026-11-10)
- **Choosing a crew:** a new game opens "Who do you run with?". You choose one of four
  **fictional** crews (`data/factions/crews.json`; made-up names, colours and bosses, not real
  gangs):

  | Crew | Home | Perk |
  |---|---|---|
  | Tortel Boys | Westridge | +R150 and +15% Westridge influence, once |
  | Vlakte Vipers (new: boss Slang, den by the Westridge park) | Westridge | heat builds 40% slower |
  | Duin Boys | Lentegeur | +25% mission cash |
  | Klipspringers | Rocklands | a shotgun as a second weapon (Tab / RB to switch) |

- **Effects of your crew:**
  - You wear its colour, and every crew's members wear their own.
  - Crew-mates are allies: they wave and back you up in fights.
  - Rival crews warn you off their own turf, and fight if you stay within 6 m for 5 s or point a
    gun at them.
  - Your crew's home suburb is cheaper to unlock (60% of the reputation, one crew member fewer).
  - You still always start in Westridge.
- **Crew missions:** 8 in total, two per crew (`data/missions/crews.json`, `prerequisites.member_of`).
  The main story's intros adapt to your crew (`intro_by_crew`).
- **Saving:** the save stores your crew. Older saves keep your current crew, or ask if you have
  none.
- **New:** CrewCatalog, CrewPicker and a crew_den landmark.
- **Fix:** CharacterModel rebuilds no longer keep references to freed parts.

### Set in Mitchells Plain (2026-11-10)
- **Renamed suburbs:**
  - The starter district is now **Westridge**.
  - The east district (flats, container shops, soccer field) is **Lentegeur**.
  - The west district (stone cottages, old quarry) is **Rocklands**.
- **Renamed roads:** the two through-roads are **AZ Berman Drive** and **Spine Road**. Residential
  streets keep made-up names.
- **Scope of the rename:** everything player-facing (addresses, missions, dialogue, signs, turf
  map, banners, generator specs) uses the new names.
- **Unchanged:** internal ids (`starter`, `district_east`, `district_west`) and file names, so
  existing saves still load.
- **Future turf:** the rest of Mitchells Plain (Tafelsig, Beacon Valley, Portlands, Eastridge,
  Strandfontein, Town Centre) is on the turf map as planned turf, with requirements. It is a new
  "planned" state that can't be unlocked until the area is built.
- **Lentegeur's ground** is pale Cape Flats sand instead of red dunes. The Rocklands hall sign
  reads "ROCKLANDS / CHURCH HALL".
- **Real places, fictional crews:** gangs and characters stay fictional, and suburb descriptions
  are neutral.

### Police, weapons and arcade combat; new vehicles (2026-11-10)
- **Vehicles:** Blender-built (`tools/blender/build_vehicles.py`): hatch, sedan, bakkie, minibus
  taxi and a police double cab, replacing the box cars everywhere (`VehicleLibrary`).
- **SAPS-inspired police, matched to reference photos:**
  - Uniform: light-blue shirts, blue-grey body armour with white POLICE lettering, navy caps
    with a gold star badge, black duty belts with holsters.
  - Bakkies: white with a yellow-edged blue band, POLICE lettering, a chrome bull bar and a blue
    light bar.
  - The crest is made up; the official emblem is not used.
- **Police on duty:**
  - Mobile police posts in each district.
  - 10 officers on foot beats in pairs: Vleirand has a day and a night shift. Patrols now end
    when the shift ends.
  - A bakkie on each district's traffic loop.
- **Weapons:** a pistol and a pump shotgun (`build_weapons.py`). Gangsters and police carry them
  holstered or slung, and draw and aim (new aim, hit and down animations).
- **Arcade combat (no blood, nobody dies):**
  - **Shooting:** aim with RMB / LT (over-the-shoulder camera, crosshair), shoot with LMB / RT.
    `CombatSystem` fires hitscan shots with tracers and muzzle flash.
  - **Health:** `Health` knocks people down at zero; they get up after 20 s and go home.
  - **Gunfire:** a new incident. Bystanders, kids included, run; police come from up to about
    70 m.
  - **Fights:** gangsters shot at fight back (keeping distance, strafing, line of sight). Rival
    crew-mates join in and your crew backs you up.
  - **Police response (`PoliceDispatch`):** heat goes from 0 to 5 stars. Heat 1 gets a "Stop!
    Police!"; at heat 2+ officers who see you fight, and bakkies flash their lights and sound
    their sirens. Police also take on gangsters shooting nearby. Heat cools while unseen.
  - **Knocked out:** you wake at the safehouse, pay a R100 fine, and your heat is cleared.
  - **Sounds:** new gunshot and siren sounds.

### Ambient life: kids' kick-about and neighbourhood dogs (2026-11-09)
- **Kids** (`data/npcs/kids.json`, role `kid`):
  - 13 kids live in the three districts as real residents with homes and schedules. They walk to
    their pitch on the navigation mesh, play for a while, go home for supper, and stay in when it
    rains.
  - They are child-sized (height 0.6, slimmer, bigger heads) and wave at the player.
- **Kick-about (`KickAbout`):**
  - One game per pitch: the Vleirand court, the Rooiduin soccer field, and a new sandy lot in
    Kalkbos with tyre goals (`kalk_kickabout`).
  - The nearest kid chases the scripted ball and kicks it (new `kick` animation), passing to a
    friend or shooting at an end goal. The others jog into space. The ball rolls, slows, bounces
    off the edges, and rolls back out after a goal; shouts of "GOAL!!" and "Pass, pass!".
  - Kids at play skip crowd avoidance: in a tight group it returned zero velocity. They keep their
    physics, so they still never teleport.
- **Dogs** (`DogPack`, `StreetDog`):
  - A new rigged dog built in Blender (`tools/blender/build_dog.py` → `dog.glb`) with idle (tail
    wag), walk, trot, lie and bark animations and seven coat colours.
  - **Yard dogs:** 14 in total. They live in a house's front yard and never leave it, nap in the
    sun, and run to the fence and bark when you walk past.
  - **Street dogs:** 10 in total. They wander the pavements near their patch on the navigation
    mesh and nap. Some bark at you from a few metres; friendly ones trot along beside you for a
    bit.
  - New synthesized bark sound.
  - Dogs further than 60 m from the player freeze.
  - Placement is per-district data (`"dogs": {"street": n, "yard": n}`), deterministic per house.
  - Dogs are purely cosmetic: they don't collide with people or cars.

### Sitting, leaning, waving and named-character looks (2026-11-09)
- **New animations** (in `build_character.py`):
  - **sit:** on a 0.45 m seat, hands on thighs.
  - **lean:** back to a wall, one foot up, hands in pockets.
  - **wave:** a one-shot greeting with the right arm.
  Sit and lean replace the standing body. Talk, guard and wave layer on the upper body, so people
  chat while seated and wave while walking.
- **Spots (`SpotRegistry`):**
  - Benches (one seat per 0.9 m), stoep chairs, the corner wall, bus-shelter poles and container
    shop walls all register sit or lean spots.
  - A resident who arrives to wait, relax, chat, visit, play or shop may claim the nearest free
    spot within 7 m. They walk to it, then step into it with a scripted, physics-free move at
    0.9 m/s, so it is never a teleport.
  - Any new order makes them stand up and step out first. A spot is never claimed twice.
  - Stoep chairs now face the street.
- **Waving:** friendly residents and crew wave when the player walks up (2-minute cooldown each),
  and sometimes when a chat starts. Rival crews don't wave.
- **Unique looks:**
  - `data/npcs/looks.json` overrides the generated resident data per character.
  - New accessories: glasses, sunglasses, beard, moustache, clerical collar, chain, apron
    (recolourable). New hair: afro, ponytail.
  - All 13 named characters are now distinct, for example: Pastor Josephs (black, collar, grey
    beard, glasses), Uncle Solly (white barber smock, moustache, glasses), Auntie Gail (blue apron),
    Spider (chain and shades), Klip (bald, shades, moustache), Kaylin (afro).
  - `tools/godot/lineup.gd --named` renders them.

### Visual upgrade: Forward+ lighting, rigged characters, Blender props (2026-11-09)
- **Lighting (desktop):**
  - The project now runs Godot's Forward+ renderer, with filmic tonemapping, ambient occlusion,
    bounced light (SSIL), bloom on streetlights and lit windows, and softer, longer shadows
    (`RenderQuality`).
  - Web builds keep the Compatibility renderer through the `rendering_method.web` override, and
    keep the old look.
  - New setting: "Lighting effects".
- **Characters:**
  - Every person is now a skinned, rigged model built from code in headless Blender
    (`tools/blender/build_character.py` → `person.glb`).
  - The body is smooth, with clothing material slots for skin, shirt, sleeves, trousers and shoes,
    so residents keep their data colours.
  - A face: eyes, pupils, brows, nose, mouth and ears.
  - Hair pieces (short, long, doek, beanie), a cap and an optional skirt.
  - "Figure" and "Heavy" body shapes, derived from each resident's id unless the data sets them.
  - Animations: idle, walk, run, talk and arms-folded guard. An AnimationTree blends walk and run
    by speed and scales playback so feet don't slide. Talk and guard gestures layer onto the upper
    body, and the head turns towards whoever the character is looking at.
  - `CharacterModel` kept its API, so AI, missions and the player needed no changes.
  - Preview with `tools/godot/lineup.gd`.
- **Props:**
  - `tools/blender/build_props.py` → `props.glb`, placed with `PropLibrary`. The set: wheelie
    bins, two trees with wind-swaying crowns (`foliage_wind.gdshader`), aloes, satellite dishes on
    a wall bracket, washing lines with laundry, painted tyre planters, JoJo water tanks, plastic
    chairs on the stoep, gas bottles and crates.
  - Yards keep their data-driven dressing. The new extras are derived per house id, so no data was
    regenerated. Park and courtyard trees use the new trees too.
- **New project skill:** `.claude/skills/blender-assets` (models as code: loop, conventions,
  adding props).
- **Render critique:** the objective beacon filled the screen when the player stood next to it. It
  is now thinner and fades out within 6–28 m.

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
