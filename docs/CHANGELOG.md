# Changelog

## More on Remy's van, and the wheels fixed (2026-11-18)
- Wheels: the rims were black (a metal material with nothing to reflect renders black), so the wheels read as plain black discs, and at full
  lock (0.5 rad, as on every car) the wide HiAce tyres pushed out through the arch. The rims are now light grey and visible, and the
  van's front wheels turn 0.3 rad at full lock (`VehicleLibrary.STEER_LOCK`, other cars keep 0.5). Check seen failing at 0.5.
- Details: a roof rack (two rails, four cross bars), indicator lamps at all four corners that blink on the side the van turns towards (every
  drivable car now passes its turn to the lamps), two wipers that sweep in rain with drops on the windscreen, dust and an exhaust puff
  (the van now has `VehicleDetail.DIMS`), and a "WESTRIDGE" sticker low on the rear window.
- Tests: front-wheel lock, two wipers, both indicator lamps and the windscreen.

## Remy's own van: a Toyota HiAce Commuter (2026-11-18)
- New model `assets/models/vehicles/hiace.glb`, built by `tools/blender/build_hiace.py` from the 2012 Toyota HiAce Commuter the owner
  supplied (`art/source/2012_Toyota_HiAce_Commuter.fbx`, kept out of the game import with a `.gdignore`). The source was 500 000 triangles
  with 30 photo textures, 1.25 times life size; the script scales it to a real 5.4 m, welds and decimates it to about 37 000 triangles,
  drops the roof luggage and replaces every texture with plain materials (paint takes the car's colour, glass, black trim, chrome, seats,
  headlights, tail lights). Four wheels spin and the front pair steers, there are number plates, and the driver (Remy) shows at the wheel
  on the right. The steering wheel, doors and mirrors are static parts of the body.
- Exclusive to Remy: `VehicleLibrary.EXCLUSIVE` gives the model only to the vehicle id `car_player`. It is in no traffic, parking or
  civilian list, so no other car on the road is a HiAce. `car_player` is now "Remy's HiAce", white, in the data (it was a blue hatchback).
- It stays clean (no weathering, rust, dents or road dust) and has a 5.4 m collision box.
- Tests: Remy's id gets the HiAce and no other drivable car does (seen failing with the exclusivity off); four wheels, a driver and under
  45 000 triangles; the collision box is 5.4 m.

## More at the community halls (2026-11-18)
- Four new textures (pxl): `sign_civic`, `sign_sports_hall`, `sign_events`, `door_hall`.
- Civic centre (`RealHallDecor.draw_civic`): barred windows along its walls (it had none), a row of high windows in the raised hall, the
  "WESTRIDGE CIVIC CENTRE" sign over the entrance and steel double doors under it, an events board by the street ("BINGO FRI, SOCCER SAT,
  CHOIR SUN"), benches and bins either side of the canopy, five bollards, a bicycle rack, a water tank behind, a community vegetable garden
  of three raised beds, and two trees.
- Sports hall (`RealHallDecor.draw_sports_hall`): barred high windows, its own sign and doors, a basketball post, two floodlights,
  benches, a bin and a bicycle rack. The smaller sports blocks are unchanged.
- Tests: civic centre and sports hall each get their own set.

## More at the churches and mosque (2026-11-18)
- Six new textures (pxl): `window_stained`, `rose_window`, `door_church`, `window_arch`, `sign_church`, `sign_mosque`. One new Blender
  prop: `crescent_finial` (70 props in all).
- Churches (`RealWorshipDecor.draw_church`, the ones with a pitched roof): stained-glass windows between stone buttresses along the long
  walls, a pair of wooden doors up two steps at the front gable, a rose window in the gable (when the gable is tall enough), a notice board
  by the street ("ALL WELCOME, SUNDAYS 09:00"), flower beds, a bench, a bin, a palm and a tree.
- Mosque (`RealWorshipDecor.draw_mosque`): arched green-glass windows, a crescent on the dome and on the minaret, four loudspeakers under the
  minaret's balcony, a shoe rack and an ablution trough with taps beside the entrance, a notice board ("MASJID, FRIDAYS 13:00") and palms.
- Fix: `RealStreetDecor.face_quad` wound its triangles anticlockwise, but Godot's front face is clockwise, so a single-sided material showed
  its picture mirrored (the STOP sign hid it because its material draws both sides). It now winds clockwise, which also corrects the fuel
  price board, the clinic signpost and the bus and taxi stop signs. Regression check seen failing, then passing.
- Tests: church and mosque each get their parts; the rose window is left out of a low gable.

## More at the clinic and crèche (2026-11-18)
- Four new textures (pxl): `sign_clinic` (green cross, "WESTRIDGE CLINIC"), `sign_creche`, `sign_clinic_hours`, `bay_ambulance`.
- Clinic (`RealClinicDecor`): barred windows along the walls (there were none), the clinic sign above the entrance canopy, an opening-hours
  board beside the door, two waiting benches and a litter bin, three bollards, a yellow-boxed ambulance bay with AMBULANCE painted in it
  (reads correctly for an ambulance driving in), and a signpost with a two-sided clinic board by the road.
- Crèche (the kindergarten in the data): its own colourful "CRECHE / PRE-SCHOOL" sign instead, benches, a bin, bollards, two spring riders,
  a seesaw and a sandpit out front; no ambulance bay.
- There is no hospital in the Westridge data; only the clinic and the crèche got this.
- Tests: clinic and crèche each get their own set.

## More at the bus stops and taxi ranks (2026-11-18)
- Four new textures (pxl): `sign_taxi_rank`, `sign_timetable`, and the road words `bay_bus` and `bay_taxi`.
- Bus and taxi stops (`RealTransitDecor.draw_stop`): a yellow painted kerb along a 14 m bay, BUS or TAXI painted across the lane, a
  timetable (BUS 06:10, 07:25, 12:40) on the shelter's back wall, a litter bin beside it, and on one stop in three a hawker's crate stack
  and two plastic chairs.
- The small "bus station" building (`bus_station` in the data; there is one) is now a real landmark with a "TAXI RANK / TO TOWN" sign, a
  bench, a litter bin and three bollards (`RealTransitDecor.draw_station`).
- Tests: a taxi stop gets the kerb paint, road words, timetable and bin; the station gets the sign, bench and bollards.

## More at the petrol stations (2026-11-18)
- Two new textures (pxl): `sign_garage` ("DUIN GARAGE / SHOP OPEN 24H") and `sign_fuel_prices` (a price board, fictional "DUIN FUEL").
- Five new Blender props: `tyre_stack`, `oil_drums`, `air_machine`, `bollard`, `price_pylon` (69 props in all).
- Each station (`RealFuelDecor`): the garage sign over the kiosk, three bollards at its door, a litter bin, a price pylon with a two-sided
  price board by the road (when there is 3.5 m or more before the road), and, on a kiosk front 10 m wide or more, an air and water machine,
  a stack of tyres and oil drums.
- Tests: a station kiosk gets these; no pylon where there is no room before the road; no tyres or drums on a narrow front.

## More at the shops and spaza stores (2026-11-18)
- Four new Blender props: `drinks_fridge`, `chest_freezer`, `a_frame`, `gas_cage` (64 props in all).
- Shopping-centre and corner-shop frontages (`RealShopDecor.draw_shop`): the "WESTRIDGE CAFE" sign board on the parapet band, a drinks
  fridge, a chest freezer, sometimes a gas bottle cage, an A-frame board on the pavement, two or three plastic chairs and a crate stack.
- Spaza shops in a front room (`RealShopDecor.draw_spaza`): a striped awning over the hatch, a drinks fridge and a chest freezer either
  side, an A-frame board out front and sometimes a gas cage, besides the existing sign, crates and chair.
- Tests: a 14 m shop frontage and a spaza hatch get these, and none stands behind the wall.

## More on the streets and verges (2026-11-18)
- Two new Blender props: `fire_hydrant`, `post_box` (60 props in all).
- Streets: a red fire hydrant about every 110 m; wheelie bins put out at the kerb on ordinary streets; on collectors and main roads
  public litter bins and benches (looking at the houses); the odd post box; tufts of dry grass growing from the kerb. All clear of
  lamps, power poles and junction ends (`RealStreetDecor.street_furniture`).
- Tests: furniture appears on a 400 m street and collector, and none stands on the carriageway.

## More in the school grounds (2026-11-18)
- Three new Blender props: `netball_post`, `flagpole`, `bike_rack` (58 props in all).
- Each school ground: up to two netball courts (tar, white boundary and third lines, a post at each end), a flagpole with a flag, three
  bicycle racks, and six benches each with a litter bin. Every item is put on open ground found by trying random spots (clear of
  buildings, paths and the fence); one that finds no room is left out.
- Test: a 160 m school ground gets the court, posts, flagpole, racks, benches and bins.

## More in the playgrounds (2026-11-18)
- Three new Blender props: `seesaw`, `spring_rider`, `monkey_bars` (55 props in all).
- Each playground: a red rubber safety surface under the swings, slide and roundabout; a sandpit with a timber edge; a seesaw; monkey
  bars; three spring riders; two benches and a litter bin at the edge; shade trees, shrubs and flower beds round the outside.
  Anything that would fall outside the playground or on a path is left out.
- Test: a 40 m playground gets all of these.

## More in the public parks (2026-11-18)
- Six new Blender props: `park_bench`, `picnic_table`, `litter_bin`, `boulder`, `fallen_log`, `park_lamp` (52 props in all).
- Parks: a paved loop path (6 m radius, smaller in small parks) with four benches on its outside looking in, a litter bin beside each,
  four lamp posts between them, two picnic tables on a lawn patch inside it, and boulders and fallen logs scattered through the park.
  Trees and shrubs keep clear of the loop. A park too small or cluttered for the loop is left as before. The old box benches are gone.
- Tests: a 60 m park gets the path, benches, bins, lamps and tables, and no tree grows inside the loop.

## No board across a gable end (2026-11-18)
- Gable roofs had a horizontal fascia board along each gable end, which read as a gutter across the short side. Gable roofs now have
  fascia only on the two long eaves; hip roofs keep all four (`RealChunkBuilder.fascia_edges`). Test seen failing, then passing.

## Gutters follow the roof type (2026-11-18)
- Hip and pyramid-hip roofs are guttered all round, with the end gutters now meeting the side ones at the corners. Gable roofs have
  gutters only on their two long sides, none on the gable ends (`RealChunkBuilder.gutter_runs`).
- Fix: semi-detached houses had no gutters at all (they were passed as flat-roofed); they now follow the same rule.
- Test: the gutter layout check was seen failing with gutters on gable ends, then passing.

## Old specs and migration scripts deleted (2026-11-18)
- Removed `tools/specs/` (four old district specs) and `tools/world/` (the three migration scripts). Nothing in the game or tests read them.
  Docs that pointed at them now say so. The old districts themselves were already removed in 3e58e94.

## More detail in house gardens and yards (2026-11-18)
- Front gardens: a paved path from the gate to the door, lawn patches on the side away from the driveway, a wheelie bin beside the gate,
  a letterbox on the gate post, plastic chairs on some stoeps and tyre planters.
- Back yards: braai drums, dog kennels and leaning bicycles (new Blender props `braai_drum`, `kennel`, `bicycle`, `letterbox`), kept clear
  of walls, the tank and the washing line.
- Test: the real-world "all details" check covers the paths, lawns, bins, letterboxes, braai drums and chairs.

## Roller doors, solar geysers, dishes; SAPS colours (2026-11-18)
- Roller doors: a garage roller door (white ribbed shutter in a concrete frame, steel housing above, threshold) in place of one front
  window on about a third of the houses with a wide front, and on some side walls.
- Solar water heaters (`solar_geyser`, a new Blender prop): a collector panel with its tank on the north-facing slope of about a third of
  the pitched roofs, lying flush on the slope. Satellite dishes: a wall dish on one house in two (was one in four) and a dish at the eave
  of some roofs.
- SAPS: the POLICE lettering is off (it did not fit the body). Officers wear a light blue shirt (#a4c1e6) and navy blue trousers (#2c4c96),
  as in the reference photo.

## More detailed house walls and roofs (2026-11-18)
- Walls: three finishes by house (smooth plaster, rough-cast, face brick tinted brick red or brown), window surrounds (a lintel and a reveal
  each side), air bricks under some windows, a concrete stoep step at the front door, an electricity meter box beside it and sometimes a
  small awning, and downpipes on one or two corners.
- Roofs: rain gutters under the eaves, a ridge cap, now and then a brick chimney, uneven concrete tiles (lighter and darker ones), and
  roofs in different colours (four tints each for tiles and IBR sheeting).
- New pxl textures `wall_brick` and `wall_rough`; the details are built by `RealChunkBuilder._house_details` and `_window`.

## Mirrored tags, one STOP sign (2026-11-18)
- Gang tags (and the shop boards, murals and other pictures on walls) were mirrored: the wall panel helper's flip rule was the wrong way
  round for every wall. Fixed in `RealChunkBuilder._panel`, with a check that the panel's right-hand edge carries the right-hand part
  of the picture (seen failing first).
- A STOP sign is one octagon on top of its pole: red with STOP on both faces, each reading correctly from its own side (it was a red
  front plus a grey back plate, which looked like two signs). The pole ends at the octagon's lower edge.

## More trees, plants and flowers (2026-11-18)
- New plant models (`tools/blender/build_props.py`, each under 400 triangles): bush, flowering bushes (pink, yellow, white), flower
  beds (three colour mixes), grass tufts (dry and green), agave, a fan palm, a broad shade tree (`tree_c`) and a hedge piece.
- Street verges: every street and road with a pavement now has trees (palms on the bigger roads), shrubs, flower beds and grass at the
  back of the verge on both sides, clear of lamps, poles, junction ends and bus shelters.
- Parks: more and mixed trees (shade tree, palm) with shrubs, flower beds, grass and agave under them. Dunes: fynbos (dry and green
  grass, agave, shrubs). School grounds: shade trees across the grounds with shrubs and flower beds.
- Front yards: flower beds by the path and now and then a shrub, besides the aloes, bougainvillea and lemon trees.

## STOP sign pole no longer shows across the face (2026-11-18)
- The sign plate stood 3 cm in front of the pole's middle but the pole is 7 cm thick, so the pole poked through the plate and showed
  across the STOP (and the bus stop signs). Plates now stand 6 cm out (`SIGN_STANDOFF`), the pole behind them, ending below the top.
  The back of a STOP sign is a plain grey octagon.

## Street name blocks, STOP sign pole, floating names (2026-11-18)
- The corner slabs are now the long low concrete name block (1 m x 105 mm, 265 mm high with a 125 mm step in front and the name on the
  sloping face), white-painted with the street's name in black capitals. One block per street, lying along that street just behind its kerb
  at each junction corner, facing the road.
- A STOP sign's pole now stops inside the octagon (2.2 m; the sign runs 1.55 to 2.3 m) instead of poking out above it, and the sign has a
  plain grey back (it showed a mirrored red face from behind). Bus stop sign poles are 10 cm shorter than their signs too.
- The street names float over the roads again (besides the blocks).

## STOP written across the lane (2026-11-18)
- The STOP painted before a stop line is now written horizontally across the lane, letters side by side reading left to right as the
  driver sees them (2.4 m across, 1.8 m along, stretched along the road like real road paint), not stacked along the road.

## Westridge details, HUD and people (2026-11-17)
- **Houses with missing walls.** Each wall was faced away from the building's centre, which is wrong for L and U shapes: 2,437
  walls of 1,370 buildings (a quarter of them) faced inward and were not drawn from the street. `RealChunkBuilder.edge_out`
  works the outward side out from the outline's winding (also used for doors, windows, bands and murals).
- **Road signs.** A red octagonal STOP sign on a pole at each stop line, facing the driver. The STOP painted on the road was
  truncated and ran the wrong way: it now reads from the driver's seat (S nearest, P at the stop line). Speed humps are slanted
  white stripes on dark asphalt, mapped by metres so the slant keeps its angle. A new `face_quad` draws signs on a pole the right
  way round (the wall panel helper mirrored them).
- **Street name slabs.** A squat white-painted concrete slab at the pavement corner of each junction with the two street names
  ("EXCELSIOR ST / EXCELSIOR CL") on both faces; the floating name labels are gone. (I could not find a source describing the
  Mitchells Plain slabs: they follow the suburban South African corner block as I know it. Tell me what they look like and I will
  change them.)
- **HUD.** Removed the area and controls tab, the money/rep/crew tab and the mission tab. Day and time are top left with a
  translucent mini map under it (streets, you as a white arrow, gold dots for the mission and people who have one for you, blue for
  the SAPS). Money is an R5 coin with the total under the health. Hunger, thirst and the like show under the money only when they
  matter. The compass is at the very top. The phone has a new Status page: money, reputation, crew, needs and the mission.
- **Map menu.** Pinch with two fingers, drag with one, mouse wheel, and +, - and home buttons (1x to 12x).
- **People.** Men call out "Awe mybru!", "Aweza!" or "Ahoy!" when you walk up (not when afraid of or cold to you, not women). The
  SAPS wear a flat navy uniform with POLICE on the chest and the back (it follows the body), and are men (Leonard) and women (Kate):
  five of the ten officers are women now.
- **Remy's pistol.** The weapon mesh's origin is the middle of the gun, not the top of the grip like the placeholder the hand was
  tuned for: it is moved 4 cm so the grip sits in the palm.

## Houses no longer stand in the road (2026-11-17)
- The house outlines (Microsoft footprints) and the streets (OpenStreetMap) disagree by a metre or two, so 163 of 5,505 buildings
  had a corner on or within 0.5 m of a carriageway (up to 2.8 m onto a street, a roof and wall standing in the road).
  `tools/osm/clear_roads.py` (also run by `build_westridge.py`) moves those corners straight off the street; 58 chunk files changed.
- New check: no building corner stands on a carriageway (seen failing first: 77 corners on the old data).

## Residents wear the Mixamo bodies (2026-11-17)
- `NpcBodyModel` (extends `RemyPlayerModel`) answers the old `CharacterModel` calls; `NpcBodies` picks the body (police Leonard, crew
  James or Meegan, others by id and sex). Residents, the interiors' stand-ins and the vendors use it
  (`NpcBodies.enabled = false` restores the old model).
- Stand-ins until clips exist: talk turns towards the listener, sit is a hand-posed chair pose, wave is a timer, lean stands.
- Tests: the old model's checks run on `_legacy_model()`; new in-game checks for bodies, walking, turning, waving, sitting, weapons,
  knock-out and kids.

## Five more Mixamo bodies for NPCs (2026-11-17)
- James, Kate, Leonard, Louise and Meegan (uploaded as GLBs) are in `assets/models/characters/npc/`: lightened with
  `tools/blender/lighten_mixamo.py` (about 25,000 triangles each, Diffuse only), matte two-sided materials, and one model
  scene each (`scenes/characters/npc/`). `RemyModel` retargets Remy's clips onto them (idle, walk, run, sprint, jump, aim,
  fall, get-up). Residents do not wear them yet.

## Remy: matte, no see-through spots (2026-11-17)
- Materials: two-sided instead of back-face culled (gaps at sleeve, collar and trouser openings), and matte: the glb's Gloss maps
  were used as roughness and made skin and clothes shiny with white highlight specks, so each material now has one roughness
  and a low specular (`tools/godot/build_remy_materials.gd`).

## Remy falls and gets up (2026-11-17)
- The glb now has `Fall_Down` and `Stand_Up`. Knocked out plays the fall, lies on the spot and stands up when the player wakes
  (`RemyModel.fall_down() / stand_up() / is_down()`, new states FallDown, Lying, StandUp in the AnimationTree). Both clips are
  played in place: their ~1 m of root motion is taken out of the hips so the body stays under the player.

## Remy has a real Idle (2026-11-17)
- The updated `Remy_Animations_Mobile.glb` carries a 10 s breathing `Idle` (looping). It replaces the held Walk frame at the
  bottom of the gait blend, so standing still looks like standing still. Not in the glb yet: falling and standing up.

## Remy is the player (2026-11-17)
- The game's `Player` now shows Remy (`scenes/characters/player.tscn`: the `Model` node is `remy_player_model.tscn`).
  Combat, interaction, camera, driving, touch controls, saves and the tests use the same `Player` script (one new line:
  `model.jump()`).
- `RemyPlayerModel` gives Remy the old model's calls. The pistol and shotgun of `WeaponLibrary` are in the hands when drawn,
  a pistol rides on the right hip, a shotgun on the back. Crew colours tint his top and bottoms. Knocked out lays him on his back.
- Not there yet: hit flinch, kick and wave clips, the old model's cap, hair and face options, a real Idle.
- Remy's idle is Walk's first frame (a mid-stride pose) until a real Idle clip is added.

## Remy: a rigged Mixamo character, ready for the player and NPCs (2026-11-17)
- Imported `Remy_Animations_Mobile.glb` (uploaded to `assets/models/characters/`, never edited): loops set (Walk, Run,
  Sprint and Pistol_Aim loop, Jump once), hair and eyelashes on alpha scissor, textures VRAM compressed
  (ETC2/ASTC on for Android), editable materials (no metallic or strength-0 normal texture, back-face culling on closed meshes).
- `remy_model.tscn`: one skeleton, one AnimationTree (gait blend Idle/Walk/Run/Sprint with the clip speed tied to the
  ground speed, a 3-piece jump, upper-body aim blend), the model scaled to 1.8 m and turned to face -Z, a placeholder
  pistol on a BoneAttachment3D at `mixamorig_RightHand`, outfits (`RemyOutfit`) and part replacement for NPCs.
- `remy_player.tscn`: CharacterBody3D, 1.8 m capsule, SpringArm3D camera; camera-relative movement, sprint, jump, turning,
  aim facing the camera. Uses the project's input actions and TouchControls (now accepts any player node).
- `scenes/dev/remy_playground.tscn`: test world with 5 demo NPCs. The game's own Player is unchanged.
- **No Idle clip exists:** Walk's first frame is held as a temporary idle.
- 31 new checks (`tests/run.sh --remy-only`). Notes: `scenes/characters/remy/README.md`.

## Android controls: a way back and an editable layout (2026-11-17)
- **Back to game:** a big button always at the top of the menu (it no longer scrolls away), and the Android back key now
  works: it finishes the editor, closes the menu, or opens the menu while you play.
- **Edit touch controls** (Menu, touchscreens only): drag a button to move it; tap it once to select it and tap the small
  red x to remove it; **+ Add button** lists what is missing (removed buttons, and new SWAP, GAS and BRAKE); Reset to
  default; Done saves and returns to the menu. The MENU button can't be removed. The layout is saved and kept after a restart.
- Layouts are stored as fractions of the screen, so they fit other phones and a turned screen; damaged saved layouts are ignored.
- 33 new checks (`_test_touch_layout_units`, `_test_touch_editor_in_game`; `tests/run.sh --only=touch`).
- Screenshots `docs/screenshots/ui_*.png`. Design: `design/gdd/touch_controls.md`.

## Real Westridge: the leftovers (2026-11-17)
- **Dual-road grass was on the wrong side:** it grew on the verge side of each carriageway and left the gap between
  the two roads bare sand. It now covers the whole gap between the carriageways (a check that failed on the old code).
- **Cars slow for speed humps** (3 m/s over a hump, easing up beyond it).
- **Stallholders:** an older woman in an apron and doek behind each fruit stall and a man behind the snoek bakkie
  (which now parks on the verge, not the median). Press E to buy: apples, naartjies, bananas, braaied snoek, snoek rolls.
- **Phone profile:** on a touchscreen (or `-- --touch`) the game builds only 320 m round the player (16 of 121
  pieces), keeps navigation only round the safehouse and wherever they walk, carries 18 passers-by and 6 cars, builds in
  12 ms slices and lets far-off people sleep. Starts in about 7 s here. Test: `tests/run.sh --phone-only`.
- 12 new checks.

## Real Westridge: a fuller world (2026-11-16)
- **Streets:** speed humps on residential streets; stop lines and STOP where side streets meet bigger roads; zebra
  crossings by schools, shops, the clinic and the civic centre; grass medians on Spine, Morgenster, Eisleben and
  Wespoort; wooden power poles and sagging wires (the odd pair of sneakers on a wire); potholes, tar patches, oil,
  sand in the gutters, litter, drain grates and manholes; bus and taxi stops with shelters; trees along Park Avenue.
- **Homes:** brick driveways (the fence stops for them) with ~110 parked cars; ~500 wendy houses; washing lines,
  JoJo tanks and satellite dishes; front gardens (aloes, bougainvillea, lemon trees, pot plants); semi-detached
  pairs painted as two halves with a party wall and a second door; ~90 spaza shops.
- **Public places:** palisade fences with gates round every school; trees and benches in the parks; swings, slides
  and roundabouts in playgrounds; goals on pitches; murals and (made-up) crew tags; fruit stalls by the crossings and
  a snoek bakkie by the shopping centre.
- Solid details (wendy houses, tanks, cars, school fences, stalls) are planned from the map data, so people walk
  round them; no route crosses them and none blocks a family's way out (new checks).
- Planning a piece's details and building it are separate steps; each frame does steps until it has used 40 ms.
  Planning the next piece over: about 75 ms; building it: about 65 ms.
- Stalls, parked cars, wendy houses, tanks and school fences keep 3 m clear of the game's places (a fruit stall had
  landed on the Tortel crew's corner, so they could not gather or push; found by the full suite, new check).
- Two older driving/crowd checks were made independent of where earlier checks left the car or which resident is
  indoors.
- New textures: median grass, STOP, oil stain, a second mural, stall awning. 9 new checks.
- Screenshots `docs/screenshots/rw_full_*.png`.

## Real Westridge: authentic buildings, landmarks and pavements (2026-11-16)
- **Heat shimmer off** by default (Settings > Video > "Heat shimmer on hot days" turns it back on).
- **Buildings in their grounds:** 159 unnamed outlines inside school grounds, the shopping centre, sports grounds and
  parks are now classroom blocks, shops and pavilions instead of homes with doors, yards and residents
  (`tools/osm/classify_buildings.py`). Five game families who lived in school buildings moved to the nearest real
  house (two got new addresses: 19 Bering, 3 and 5 Dexter Close, 15 Angus Road).
- **Landmark shapes** (`RealLandmarks`): churches with steep gables, crosses and bell towers; the mosque with dome and
  minaret; the Civic Centre with its raised hall, entrance canopy and flagpole; clinic canopy; two-storey face-brick
  classroom blocks with rows of barred windows; shops with sign bands, roller shutters and verandas; fuel-station
  forecourt canopies with pump islands. Flat roofs are dark grey; car parks and the shopping centre are tarmac.
- **Pavements:** residential streets have sandy verges with grass tufts; main roads and collectors a paved footway.
- 4 new checks. Screenshots `docs/screenshots/rw_lm_*.png`.

## Real Westridge: fences and yard walls (2026-11-16)
- About 1,800 homes get a front yard (`RealYards`): precast concrete panel walls, steel palisade between plaster
  pillars, low plastered walls in the house's colour, or a low wall with palisade on top. A gate opening sits in line
  with the front door; side walls run back to the house. About one yard in eight is left open.
- Yards are worked out from the map data, so the 3D builder and the navigation agree: fences are solid, people walk
  out through the gate, nobody walks through a fence (a new check that fails when fences are left out of navigation).
- Fences never cross a building, a pavement, a footpath, a neighbour's doorstep or the way straight out of a
  neighbour's front door (a neighbour's side wall had shut the Ranger Close family in; caught by the full suite,
  now has its own check); the game's own houses keep their gate spot outside the fence and the yard dog inside.
- The builder reuses the front doors the data already found (it no longer works them out twice).
- 6 new checks. Screenshots `docs/screenshots/rw_fence_*.png`.

## Real Westridge: roads, walls and roofs (2026-11-16)
- **Roads:** concrete kerbs and gutter channels along every street with a pavement; sun-bleached asphalt
  (4 m texture with sealed cracks); yellow edge lines on main roads; warmer pavement slabs. Junctions close by
  layering (a side street's asphalt covers the other street's kerb), so any angle works.
- **Walls:** a darker painted plinth band at the foot of every building, concrete window sills, a parapet with a
  concrete cap on flat roofs.
- **Roofs:** houses whose outline is close to a rectangle (84%) get a pitched roof over their best-fitting rectangle,
  hip or gable (gable ends in the wall paint), with eaves, fascia boards and soffits. Odd shapes keep a flat roof.
- Screenshots: `docs/screenshots/rw_street_before.png`, `rw_street_after.png`, `rw_roofs_after.png`, `rw_main_road.png`.
- 4 new checks; building one 200 m piece takes about 40 ms (budget 400 ms).

## Old districts removed; real Westridge is the only world (2026-11-16)
- The game starts in the real Westridge. Lentegeur, Rocklands, Town Centre, Tafelsig and the old 30-house Westridge,
  their gates, traffic, ground and street builders, the "switch world" button and the old-world test branches are gone.
- The five district data sets now describe turf sectors inside Westridge (Westridge, Harvester, Rocklands, Westridge Centre,
  Duneside); locked sectors are walkable but the player cannot hold turf there until they unlock.
- Every home has a real street name and number. Full suite after the removal: 1524/1524 passed.
- Obsolete generators removed (`generate_starter_data.py`, `generate_district.py`, `make_tafelsig.py`);
  `tools/world/relocate_to_real.py` and the rebuild scripts are kept as records of the migration only.

## Real Westridge, stage 2: people and traffic
- **Navigation** on the real streets (`RealNav`): a navigation mesh per 200 m piece with every building outline cut out,
  baked in the background near you; pieces join edge to edge, so walks cross the suburb and go round the real buildings.
- **Homes**: houses now have a front door on the wall facing their street, and windows.
- **Residents** (`RealPopulation`): the game's ordinary residents live in real houses, leave on a daily schedule, walk to
  real places (the nearest shop, park, the civic centre or a church, a neighbour) and walk home. Up to 48 near you (18 on a phone).
- **Traffic** (`RealRoadGraph`, `RealCar`, `RealTraffic`): cars drive the real street network on the left, turn at real
  junctions, obey one-way carriageways, and stop for cars, people and you. Up to 14 near you (6 on a phone).
- The map tool now cuts streets at their junctions and records one-way streets.
- 18 new checks (`tests/run.sh --real-only` runs the real-world checks alone: 46/46).
- Still preview only: no missions, crews, police or shops there yet; people may cross roads anywhere; no parked cars or fences.

## Real Westridge world, stage 1: real streets, real outlines, loading in pieces
- New direction (design/gdd/real_world.md): one accurate district, the whole of real Westridge (about 1.6 by 2.5 km),
  replaces the five small made-up districts. Done in four stages; the existing game keeps running until stage 3 moves it over.
- **Data** (`data/world/westridge/`, `tools/osm/build_westridge.py`): 323 named streets with their real lines, footpaths,
  parks, pitches, school grounds and 60 landmarks from OpenStreetMap; 5,505 building outlines from Microsoft
  GlobalMLBuildingFootprints (OpenStreetMap has only 65 public buildings there, none of the houses). True north; nothing turned.
- **Builder** (`RealChunkBuilder`): roads as ribbons that follow any bend and angle, pavements, footpaths, coloured areas,
  and a building with a roof on every outline; street signs and landmark labels.
- **Loading in pieces** (`RealWorld`): 121 pieces of 200 m, built nearest-first as you move and freed behind you. A desktop
  loads the whole suburb; a touchscreen loads 320 m around you. One piece builds in about 8 ms here.
- **Preview**: pause menu > "Real Westridge preview" (or run `scenes/real/real_westridge.tscn`). Walk-around only:
  no residents, traffic or missions there yet, and houses have no doors or windows yet.
- Full suite before this change: 1518/1518 (Westridge and Lentegeur block rebuilds verified).

## Lentegeur rebuilt on its real streets
- Lentegeur is now the real **Hyacinth Avenue** crescent off **Firethorn Road**, with **Marguerite Road** to the north
  (OpenStreetMap). The made-up Duin Road and Kers Street are gone; traffic drives the real circuit round the crescent.
- All 20 homes keep their families and ids; the six row houses from Duin Road now stand back to back inside the crescent;
  the soccer field, shops, courtyard, taxi rank and police post were re-placed.
- A rebuilt area now carries a `real.anchor` (one local point and its spot on the real map), used by the city map.
- Test fix: the "hold the corner" check no longer depends on whether a patrolling rival happens to be there
  (`PoliceDispatch.turf_provocation`).

## Westridge rebuilt on its real streets
- Westridge is now the real block around **Excelsior Street** (OpenStreetMap): Excelsior Street, Rhone Way,
  Coetzenburg Street and Constantia Street at their real spacing, with the real dead ends **Rhone Close** and
  **Excelsior Close**. The made-up names (AZ Berman Drive, Spine Road, Kwikkie Street, Tortel Lane) are gone from
  Westridge: addresses, missions, dialogue and signs use the real names (your safehouse is 13 Excelsior Street).
- The block is turned 22 degrees to fit the game's grid; the compass and the city map show true directions.
- All 30 houses keep their families and ids; two families moved to Excelsior Close; the park moved to make room for Rhone Close.
- Every area's block is 14 m deeper (56 to 70 m) so the roads between districts still line up.
- New tests: every Westridge street exists in the map data beside that block; no plot overlaps a road or another plot.
- Not real yet: the neighbouring districts, and the link roads to them (see `docs/WORLD_LAYOUT.md`).

## Survival layer (Zomboid-style), real map view, working rules
- **Needs:** food, water and rest run down with game time (sprinting makes you thirstier). Empty food/water stops healing and
  lowers health to a floor; exhausted means no sprinting. Eat and drink from the bag; sleep at the safehouse.
  Can be switched off in Settings ("Survival needs").
- **Bag and looting:** a 10 kg bag (I / D-pad right / BAG button), a 60 kg stash at the safehouse, 20 items
  (`data/survival/items.json`). Shops sell food, drink and bandages and buy junk. A crate beside each shop and a bin at
  each bus/taxi stop can be searched; raiding a crew den also gives loot. Spots refill after two game days.
- **Wounds:** a gunshot can leave a bleeding wound (slower, no regeneration, health drains to a floor). Bandage it; it heals
  with time or sleep.
- **Skills:** shooting, driving, fitness, hustle and scavenging level up with use and give small bonuses (bag > Skills).
- All tuning is in `data/survival/`; design in `design/gdd/survival.md`; saved in the `survival` section (old saves load fine).
- **Real map:** the turf map has a "Show all of Mitchells Plain" view: the real main roads, railway, stations and suburbs
  from OpenStreetMap inside the KnoxMap outline, with the game's districts placed at their real spots.
  Data: `data/world/` (built by `tools/osm/`). Local streets are stored for the suburb rebuilds.
- **Working rules** adapted from Claude Code Game Studios (MIT) in `.claude/rules/`; credits in `docs/THIRD_PARTY.md`.

## Top-down camera option
- New `camera_mode` action (V, R3, or the VIEW touch button; also Settings > "Top-down camera"): a high, angled Zomboid-style view. Look only turns the camera; shots go flat along the facing (or at the locked target). The choice is saved.
- `--top-down` argument for screenshots; 6 new tests.

## Fix: touch taps fired the weapon
- A touch also arrives as an emulated left-click, which is bound to "fire", so tapping AIM or LOCK shot automatically. On a touchscreen the mouse buttons are now removed from the fire/aim actions; the FIRE button sends "fire" itself.

## Touch: LOCK button and FIRE placement
- New LOCK button (touch only): raises the weapon and swings the camera onto the nearest armed stranger within 30 m; tap again to turn off. Residents are now in the `residents` group.
- FIRE moved above the move stick; HEY moved to a second column so it no longer covers the waypoint label.

## Touch controls (phones and tablets)
- New `TouchControls` layer: left stick moves/drives, right stick looks, TALK / RUN / JUMP / AIM / FIRE buttons, and MENU / PHONE / MAP / HEY / RADIO on the right edge. Shown automatically on a touchscreen (or with `--touch` on a PC); hidden while a menu has the input.
- Prompts, the help line and the tutorial name the on-screen buttons on touch; tapping a tutorial card skips the tips.
- First start on a touch device uses lighter video settings (no shadows/effects, 70% render scale).
- 6 new tests (stick, button, hide-in-menu, prompts).

All notable development milestones should be recorded here.

## Unreleased

### Tutorial and the gold waypoint (2026-11-13)
- **Gold waypoint:** a soft gold beam and a spinning diamond mark where the current mission needs you
  (the person to talk to, the place to visit, the door to knock on, the nearest corner you don't hold).
  With no mission running it points at whoever has the next one to give. On screen a label shows
  "◆ Boeta Daniels  42 m"; when the target is off screen an arrow at the screen edge points the
  way. It fades when you get close. Switch it off in the pause menu.
- **Tutorial:** seven short tips for a new game (move, look, sprint, talk to someone, the turf map,
  the phone, whistle), one at a time, each ticking over when you do it. Tab (D-pad left on a pad)
  skips them. They show once per save, never block anything, follow your key bindings and your device
  (keyboard or pad). The pause menu can turn tips off or replay them.
- **Tests:** marker targets for each objective type, the marker on and off, the tutorial stepping
  through, skipping, not repeating, and switching off.

### Vehicles: a worn, personalised, lived-in fleet (2026-11-13)
- **Wear by age** (`scripts/vehicles/vehicle_detail.gd`): paint fades and loses colour with age, rust
  at the wheel arches, dents in the doors, a mismatched replacement door, bumper stickers. The police
  are the newest, the skorokoro the oldest.
- **The minibus taxi:** roof sign, yellow side stripe, a number ("No. 42"), a slogan across the rear
  window ("ALLES SAL REG KOM"), bags or a tied-down mattress on the roof, a conductor leaning out of
  the sliding door. Ranks now have two parked taxis waiting for a full load.
- **Rain and night on the cars:** wipers that sweep in rain, drops on the windscreen, a dash that
  glows amber at night, brake lights that glow on the road behind in the dark or on wet ground.
- **Motion effects:** exhaust puffs when pulling away (old engines smoke more), dust behind fast cars
  on dusty days, skid marks that fade after about half a minute, headlight beams that show in dust
  and rain (volumetric fog energy).
- **Visible driving:** the steering wheel turns with the steering. Hits dent the car; hard hits
  crack the windscreen (the player's car).
- **New vehicles:** a commuter bus (route board), a refuse truck, a scooter with a rider; a bakkie
  carries a canopy or a tied-down load. They drive in the traffic loops (27 vehicles now).
- **Parked cars aren't identical:** some under a cover, some on bricks without wheels, some with a
  flat tyre.
- **Cheaper far away:** every small detail has a visibility range, and cars more than 100 m away
  update their detail every fourth frame.
- **Not done:** bicycles and delivery tricycles (they need rider animation), a damage model that
  actually bends the mesh, and a library of paint jobs beyond the age-fade.
- **Tests:** wipers, drops, dash glow, exhaust, brake glow, volumetric beams, skid marks, dents and
  cracks, taxi extras, the new models and a scooter's wheels, parked-car variety.

### Missions, daily life, accessibility, weather, music, tooling (2026-11-12)
- **New missions** (`data/missions/life.json`):
  - *Where's Piet?* (Auntie Faiza): ask around, check the court and the Lentegeur field.
  - *Quiet Eyes* (Boeta): a new **follow** objective. Marlon walks to the cafe; stay within range
    but not on top of him, or you lose him.
  - *Candles* (Aunty Gadija): buy candles in Lentegeur, bring them during load-shedding.
- **An ending:** *The Long View* (after *Kings of the Plain*, Tafelsig open, ten corners). Boeta asks
  what the Plain becomes: **rule it**, **share it** (every crew becomes your ally) or **walk away**
  (your corners go back to nobody). The game carries on afterwards (`game_finished` flag).
- **People react to you** (`ReputationVoice`): greetings by reputation, personal relationship and
  police heat (wary, known, respected, legend, friendly, cold, "Police are looking for you!"). Some
  turn away instead of waving. Lines mix in Kaaps ("Hoezit", "ja nee", "my bra"); they should be read
  through by someone from the Plain.
- **Your corners show:** your crew's flag flies on every corner you hold and comes down when you lose it.
- **Daily life events:** Friday prayers at the Town Centre mosque, Sunday service at the Rocklands
  hall, the school run at the Westridge bus stop, market day at the Promenade, and a *Tweede Nuwe
  Jaar* parade at the park with a made-up ghoema drum and brass loop (no costumes yet).
- **Places:** Westridge Gardens (roses along the beds, fynbos, a sign) in the park; a fish den in Tafelsig.
- **Accessibility:** re-bindable keys (pause menu; swaps on a clash; prompts follow; saved), sound
  captions with a direction arrow ("◀ [Gunshot]"), speech-bubble switch.
- **Autosave** after each mission and each new day (switchable; never while knocked out).
- **Weather you feel:** rain rings on the ground, drops running down the screen in heavy rain, paper
  and plastic tumbling in the wind, a heat shimmer over the horizon on a clear still midday.
- **People:** three school uniforms, football kits, church clothes.
- **Radio:** two more stations, Kasi Beats (log-drum groove) and Cape Ghoema FM.
- **Performance:** *Crowd simulation range* (Settings > Video): far-off residents sleep (frozen,
  hidden, no thinking) and wake exactly where they were. Default is everyone, all the time.
- **Playtest bot** (`tests/playbot.sh`): boots the game and plays every mission, once per crew and
  story branch; it found no stuck mission (34 finished in the first run; the rest need another crew
  or branch).
- **Tests:** rebinding, settings save, captions, autosave, reputation voice, the follow objective,
  endings, flags, events and the parade, weather effects, dormant crowd.
- **Not done:** a library, a railway line with trains, washing lines that sway, Klopse costumes, and
  true district streaming (everything is still built at once).

### The look of the Plain: skyline, ground, houses, people, light (2026-11-12)
Researched first: `docs/MITCHELLS_PLAIN_REFERENCE.md` (what is confirmed by sources and what is general
knowledge, plus how each finding shows up in the game).
- **Table Mountain on the horizon** (`scripts/world/skyline.gd`): a far-off, pale-blue plateau to
  the north-west, seen *side on* as it is from the Flats (not the postcard profile), with Devil's
  Peak and Lion's Head at the ends. Also the jagged Hottentots-Holland range to the east, the low
  Peninsula ridge to the west and False Bay to the south. It follows the camera like a skybox,
  ignores fog, turns violet at dusk, goes dark at night, hides in dust haze, and in a south-easter
  the "tablecloth" of cloud spills over the plateau.
- **Ground** (`ground_detail.gd`): worn earth and grass patches, wind ripples, sand drifting over
  pavement edges, weeds at the foot of walls, dune-grass tufts. No colliders.
- **Houses:** owners' additions on the plain council houses: front hedges with roses, satellite
  dishes, lean-to rooms, corrugated-iron back-yard rooms and painted Wendy houses; a community
  mural on some flats. Visual only.
- **A mosque** in the Town Centre (white prayer hall, green band, dome, minaret): a fictional building
  with no name or lettering. The research found mosques at Westridge, Rocklands and the Town Centre;
  the others can follow when there is a lot for them.
- **People:** headscarves (hijab) on some women, school bags on uniformed kids, a body roll and
  bounce while walking, soft blob shadows.
- **Light:** warm lamplight spills from windows and doors onto the yards at night; on desktop,
  screen-space reflections (wet roads, car paint) and thin volumetric haze that shows sunset
  shafts and thickens in dust.
- **HUD:** one glass-panel style, a compass (look north-west for Table Mountain) and a night
  vignette.
- **Tests:** skyline, tablecloth, camera-following horizon, ground detail, window glow, compass,
  headscarves, bags, sway, blob shadows.

### Tafelsig, grudges and a calmer HUD (2026-11-12)
- **Tafelsig, the fifth area** (east of Town Centre, "out towards the dunes"): 20 houses (flats
  on the main roads, row-house courts on Court Lane), 25 residents, a sand court, a courtyard, a
  taxi rank, a spaza and a tuck shop, sandy ground, its own traffic and two corners.
  - Locked until *Market Day* is done, with 200 reputation, 3 crew members and 40% Town Centre
    influence. Two gates from Town Centre; no longer listed as "planned".
  - The Laaities' cousins hold it (Tortel Laaities crew members).
  - Missions: *Over the Dunes* (Aunty Gadija), *Court Time* (Ricardo, hold the court),
    *Before the Wind Turns* (Ouma Hester).
  - Built with `tools/make_tafelsig.py` and `tools/generate_district.py`.
- **Story consequences:** hard choices leave a grudge. A story choice can now carry
  `retaliation: {crew, minutes}`; when it comes due the crew moves on one of your corners (once
  there is one). Allies leave no grudge. Going to war, walking out of Marlon's sit-down and
  standing alone against the Dune Cruisers all do this. New follow-ups:
  - *Payback*: hold a corner against a push (new `pushes_held` stat);
  - *Marlon's Favour*: after the split, pact with the Laaities or decline;
  - *The Dune Debt*: after standing alone, make peace with Spider or feud.
- **Weather:** puddles collect in potholes and gutters and show when the ground is wet; dust
  haze is thicker (denser fog, tan sky) and more visible on windy days.
- **HUD and menus:** the controls line fades after 40 s (a keyboard/pad switch brings it back);
  long menus (the safehouse) scroll instead of running off screen; turf map zone names are no
  longer clipped ("ROCKLANDS · LOCKED").
- **Tests:** `tests/run.sh` wrapper (see TECH_NOTES for why), `--units-only`, Tafelsig and
  consequence tests, puddles; 149 simulated NPCs now cost about 8 ms per physics frame headless,
  so that budget is 10 ms (12 ms after the look pass: the same code measured 7.9 to 10.1 ms between runs, so the check has noise).

### More detail: streets, houses, characters, vehicles, light (2026-11-12)
- **Streets:** litter on pavements and in gutters, potholes and tar patches, storm drains at
  the kerb, manholes, pole bins every 40 m, speed humps on side streets and a transformer box
  per street (`scripts/world/street_detail.gd`). Visual only, batched, never blocks walking.
  Cafés and container shops get a "Bread / Milk / Airtime" A-frame board and crates.
- **Houses:** gutters and downpipes, window sills, an electricity meter box, cracks and rust
  stains, stoep canopies on some single-storey houses, TV aerials and solar geysers.
- **Characters:** school uniforms (white shirt, grey trousers, maroon tie) for most kids,
  work overalls for some men, Sunday best (shirt, cardigan, tie) for some older men. People
  waiting check their phones (new phone pose), and shoppers carry a bag home.
- **Vehicles:**
  - the minibus taxi is hollow now: a glass cabin with pillars, four rows of seats and 4–9
    passengers;
  - new **combi** (two-tone, white roof) and **bakery panel van** (a made-up "Ouma's Bakery"
    sign on both sides) join the everyday cars;
  - 5 more cars in traffic (19 in all).
- **Lighting and atmosphere:**
  - golden hour: a deep orange low sun, a violet sky overhead at sunset and a pinker dawn;
  - windy days lift a tan Cape Flats dust haze;
  - cloud shadows drift over the streets on cloudy days;
  - the ground goes dark and glossy in the rain and stays wet for a while after;
  - every streetlight paints a warm pool of light on the ground at night.
- **Tests:** street detail (count, no colliders), outfits, phone and shopping bag, taxi
  passengers and glass, combi and panel van, bakery sign, 19 cars, wet ground, puddles
  linger, cloud shadows, dust haze, golden hour, lamp ground glow.

### Sound and music (2026-11-11)
- **Music, made in code:** three made-up radio stations, each a seamless 4-bar loop synthesized
  at runtime (no audio files):
  - *Plain FM*: a kwaito/house groove.
  - *Spine Road Jazz*: walking bass and mellow keys.
  - *Gospel 101*: organ and claps.
- **Car radio:** it plays while you drive. **R / D-pad down** cycles the stations and off.
- **A Music bus:** with its own "Music & radio" volume slider in the pause menu.
- **The smokkies play music** on smokkie nights (17:00–23:00) at Mavis', Doreen's and Ma
  Lena's, and all around you when you're inside one.
- **Street life:** minibus taxis hoot at the Lentegeur and Town Centre ranks, stallholders call
  out at the market, and the Rocklands hall bell rings at 08:00, 12:00 and 18:00.
- **Voices:** when people greet or chat, you hear a made-up gibberish voice. It's pitched per
  person, lighter for women, and only heard close by.
- **Tests:** Music bus, the three station loops, radio on while driving / cycles to off / stops
  when you get out, smokkie music at night, the sound spots, voices.
- **Also:** Slang's stays at the park and den are shorter (25 minutes), so he moves about more.

### The story: choices that shape the Plain (2026-11-11)
- **Dialogue with choices:** a new `dialogue` mission objective opens a story scene (speaker,
  lines, two choices) when you talk to that person (`data/story/scenes.json`). A choice
  applies its effects:
  - cash, reputation, crew influence, relationships and suburb influence;
  - story flags;
  - turf: handing corners over, or making a crew your ally (allies never push on your
    corners).

  Choices are saved.
- **The main storyline** (`data/missions/story.json`), six missions:
  1. *Word on the Street* (Boeta): the Tortel Laaities want a sit-down. Talk, or send a message?
  2. *The Sit-Down* (Marlon Carelse, Tortel Laaities): split Westridge's corners, or walk away.
     Or *Send a Message* (Boeta): hold their corner at night with your crew.
  3. *East of the Gate* (Spider, Lentegeur): ally with the Dune Cruisers, or stand alone.
  4. *The Market Cut* (Uncle Faried, Town Centre): protect the stalls for free, or take a
     month-end cut (R500, less respect).
  5. *Kings of the Plain* (Boeta): hold six corners across Mitchells Plain. The intro
     remembers how you got there.
- **Missions:**
  - New prerequisites: `flags` (choices made) and `any_missions` (either branch done).
  - Intros can vary by flag (`intro_by_flag`).
  - A `corners` stat counts the corners you hold.
- **Tests:** scenes load; Boeta's scene opens with choices; a choice sets the flag and finishes
  the objective; the branch that opens; turf hand-overs and allies; flag-aware intros; choices
  saved. Sturdier "officer sees the deal" check. 34 missions.

### Town Centre (2026-11-11)
- **Town Centre is built:** the fourth area, east past Lentegeur (x 264–384), through the same
  data pipeline (`tools/specs/town_centre.json` → houses and residents;
  `data/districts/town_centre.json`).
  - **The Promenade mall:** a big shopfront with coloured fascias, a canopy, columns and the
    PROMENADE sign, plus a car park.
  - **The market:** two rows of stalls with striped canopies and crates of produce.
  - **The big taxi rank, a spaza,** and Promenade Road and Market Lane between AZ Berman Drive and
    Spine Road.
  - Ten blocks of flats with 21 residents. Named locals: Uncle Faried (market stall), Shanaaz
    (mall), Bra Gary (taxi marshal). A Spine Road Stylers house sits on the Promenade.
  - Its own traffic (a taxi and two cars) and dogs.
- **Unlocking:** two gates on Lentegeur's east side (areas can now name their own neighbours).
  Requirements: Dune Truce, 150 reputation, 3 crew members, 60% Lentegeur influence. It's no
  longer listed as "planned".
- **Missions:**
  - *The Promenade* (Uncle Faried): walk the mall and the rank.
  - *Market Day* (Shanaaz): hold the market with your crew.
- **Turf:** two new corners, the market (Stylers) and the big taxi rank (nobody's).
- **Tests:** the area, houses, residents, landmarks, gates, locked state, missions, corners, and
  a walking path from Lentegeur to the market once open. Counts updated (4 areas, 14 cars, 28
  missions).

### Varied interiors: bedrooms, house styles, dens to raid, police posts (2026-11-11)
- **Every home has a bedroom** (bed, wardrobe, rug, lamp) through a doorway next to the lounge
  and kitchen. The safehouse bed is in there now.
- **Styles by house type:**
  - Rocklands cottages: whitewash and floorboards.
  - Double-storeys: a staircase up the wall (upstairs isn't open).
  - Lentegeur flats and row houses: their own touches.
- **Rival crew places:**
  - A rival crew's house (hostile), or a crew den, opens when nobody's home.
  - Inside are their couch, TV, crates, their tag on the wall and the **stash**.
  - Raiding it gives R150–300 and 3 bankies, +3 reputation, and weakens their corners in that
    suburb. Once a day per place.
  - Your own crew's den is yours to hang out in.
- **Police posts:**
  - Walk in to a charge office counter with a desk officer, benches and a holding cell.
  - Pay R80 a heat star to clear your heat.
  - You can't walk in with 2+ stars.
- **Tests:** bedroom, rival place open when empty, raid (and only once a day), police post
  refusing you at high heat, paying fines clears heat.

### A deeper hustle (2026-11-11)
- **More smokkies:** Doreen's smokkie in Lentegeur (12:00–24:00) and Ma Lena's tavern in
  Rocklands (12:00–23:00). Both are houses that used to be empty, with a sign over the door and
  a host. The door takes you straight in to a bar you can serve at, with the host behind it and
  regulars on evening smokkie nights. Venues live in `data/dealing/dealing.json`.
- **Prices move:**
  - +10% per heat star (risk), clamped to x0.75–x1.5.
  - Cheaper where rival crews hold the suburb's corners, dearer where you do.
  - The phone shows today's street prices where you stand and each order's price.
- **Runners:**
  - Hire up to two at the safehouse stash (R200 each).
  - On the phone, "Send your runner" takes an answered order for you: 30 minutes, a 20% cut.
  - The safe chance drops with heat and rival corners; a caught runner loses the stock (no heat
    on you).
- **Restock is a pick-up:** ordering stock from the safehouse leaves a crate at a drop (a
  Westridge corner you hold, else your safehouse gate). It's ready after 20 minutes and gone if
  left for 4 hours. The phone lists your drops.
- **Saving:** runners and drops are saved.
- **Tests:** units for prices, runners (cut, caught) and drops (ready, collect, expire). In game:
  the three smokkies, Doreen's door and bar, closing hours, price changes with heat and rival
  turf, the drop crate and collecting it, hiring a runner.

### Turf wars (2026-11-11)
- **Corners:** 10 street corners across the three suburbs (`data/factions/corners.json`):
  - Westridge: the Corner, the park, the sand court, the cafe corner.
  - Lentegeur: the taxi rank, the soccer field, the courtyard.
  - Rocklands: the quarry lookout, the village square, the bus stop.

  Each is held by a crew, or by nobody, with a control level from 0 to 100.
- **Taking a corner:** stand on it with no owner crew standing there (they come at you on their
  turf, so fight them off first). Crew-mates along make it faster. Nobody's corner builds up;
  a rival's drains. Taking one pays R100, +4 reputation and +10 influence in that suburb.
- **Rival pushes:**
  - Once you have 10 reputation, every 6–10 played hours a rival crew from that suburb moves
    on one of your corners: three members walk over and post up. You get a banner and a ring
    tone.
  - Get there: they square up when you come close. If they aren't standing there when you
    arrive, or the push runs out (2 hours), you hold it (+3 reputation).
  - Ignore it and the corner flips to them: −10 influence, and your clients in that suburb
    get unhappy.
- **Tags:** rivals spray their tag (a new Spine Road Stylers tag too) on a wall at corners they
  hold or push on, or on the ground in open spots. Paint over it to weaken their hold, or to
  firm up your own.
- **Turf map:** each corner is a ring in the holder's colour, filled to its control level, with a
  red ring when it's being pushed. The side panel lists every corner.
- **Saving:** corner owners and control are saved.
- **Robustness:** time skips and clock jumps count for at most 30 minutes towards the next push.
- **Tests:** TurfState units (take, blocked by owners, crew bonus, pushes lost/held/timed
  out, paint over, save) and in game (tags at rival corners, painting over, taking a corner,
  a push taking it, holding by showing up, save, map). Automatic pushes are off during the
  other tests.

### House interiors (2026-11-11)
- **Going inside:**
  - **Your safehouse:** the door takes you straight in. Inside are a couch and TV, a kitchen, a
    bed, a wardrobe, a map of the area, and the **stash** (the safehouse menu: upgrades,
    restocking, rest).
  - **Aunty Mavis' smokkie (10:00–23:00):**
    - a bar counter you can serve at, shelves of bottles and beer crates;
    - a pool table, a jukebox, posters and coloured lights;
    - Mavis behind her bar, and regulars at the tables on smokkie nights.
  - **Neighbours' houses:** knock, and if someone's home (and it isn't hostile) they say
    "Come in, come in". The door then says *Go inside* for 20 game minutes, so press E again.
    Whoever is home sits on the couch or stands in the kitchen, and you can talk to them as
    outside (missions, relationships and contacts all work).
- **The rooms:**
  - Built from code only when you go in, under their own plot, and freed when you come out.
    Each has lino or wooden floors, painted walls, skirting, windows with burglar bars and print
    curtains that follow the daylight, and a hanging lamp.
  - A home is a lounge (TV, couch, coffee table, rug, family photo, "Home Sweet Home") plus a
    kitchen (counter, sink, stove, fridge with magnets, calendar) and a dining table or
    armchair.
  - Walls and furniture are solid.
- **Gameplay:**
  - Police can't see you indoors, so heat cools off.
  - Saving indoors puts you at the front door when you load.
  - The room is dropped if you're moved out some other way (knocked out, load).
- **New:**
  - InteriorBuilder (layouts) and InteriorSystem (enter/leave, fade, people inside, welcomes).
  - 17 Blender furniture props: couch, armchair, coffee table, TV unit, kitchen counter, stove,
    fridge, bed, wardrobe, dining table, bar counter, bottle shelf, jukebox, pool table, crates,
    stash crate, ceiling lamp.
  - 13 pxl textures: lino, floorboards, rug, family photo, mountain picture, Home Sweet Home,
    clock, calendar, COLD ONES and VLEI FC posters, area map, inside window.
  - `--interior=<id>` screenshot flag.
- **Tests:**
  - Safehouse in and out, furnished, floor and walls, saving indoors, the stash menu.
  - Knock, then come in, people inside, talking to them.
  - Smokkie hours, Mavis, police can't see you, the room dropped, no way into hostile houses.
  - Flaky checks made robust: the car-push check only counts while a car is close, the rival
    aim test tries up to three rivals, and the gangster shot gets more tries.

### Modeling pass: heads, hands, hair, life; vehicle interiors and the skorokoro (2026-11-11)
- **Heads:** sculpted in code from one skull mesh:
  - a jaw tapering to the chin, cheekbones, eye sockets, a brow ridge and a fuller back;
  - a shaped nose (bridge to tip) with nostril wings, eyes set in their sockets;
  - hairlines that sit above the forehead and lower at the nape.
- **Hands:** four fingers and a thumb on each hand.
- **Hair:** new fade, cornrows, braids, curls and bun styles. Generated residents with short or
  long hair now spread across them; hand-made looks keep their hair.
- **Life:**
  - Blinking, and a mouth that moves while someone talks.
  - Two idle variants: weight on one leg, and hands on hips.
  - Older people stoop and walk 15% slower; some young men are lanky teens.
- **Vehicles:**
  - See-through glass, with a dashboard, a right-hand-drive steering wheel and seats with
    headrests inside.
  - Drivers in traffic, sometimes passengers, and two officers in police bakkies. The player
    shows at the wheel while driving.
  - Body details: door handles, wipers, grille slats, side repeaters, an exhaust, a sedan
    aerial, mud flaps and a bakkie tow bar.
  - Taxi and canopy windows are dark tinted.
- **The skorokoro:** a tired old boxy sedan in the civilian mix. It has a door from another car,
  a primer patch, rust on the sills and arches, a dented flank, chrome bumpers and a sagging rear
  bumper.
- **Wear:** about a third of the cars are dusty, with road grime fading up from the sills.
- **Performance:** small parts (fingers, lids, face paint, occupants, wheels) are not drawn from
  far away. Draw calls are 2,813 against 2,800 before.
- **Traffic:** a car stuck for 10 s behind a resident who stays in the lane eases past them
  (avoidance pushes walkers aside). The player and other cars are never ignored.
- **Tests:** occupants, see-through glass, the skorokoro, the player at the wheel, blinking,
  talking mouths, hair variety, stooping. The "keep driving" check now catches stuck cars
  without failing busy streets (> 30 m in 25 s).

### Detail pass: faces, clothes and vehicles (2026-11-11)
- **Painted faces:** a thin face-paint shell with pixel-art overlays tinted by skin tone:
  - eyelids and lashes;
  - lips (the old block mouth is gone);
  - wrinkles, bags and smile lines for older people;
  - stubble for some men.
  Picked by figure and age; `face` in looks.json overrides.
- **Materials:**
  - Skin: softer highlights, with subsurface scattering on Forward+.
  - Cloth: matte with a faint sheen.
  - Caps: cloth too.
- **Clothes:**
  - Trousers can be denim twill, tracksuit pants with white side stripes, or plain.
  - Hoodies have a hood, kangaroo pocket and drawstrings.
  - Shoes have white soles (dark for older people and police).
  - Crew caps carry a made-up crew logo, and so does the player's cap once you join.
- **Vehicles:**
  - Separate wheels with five-spoke rims spin with speed, and the front pair steers.
  - The body dips under braking and rolls in turns.
  - Paint is glossy with a clear coat, windscreens reflect the sky, and arch liners are dark.
  - Brake lights come on when braking and tail lights glow at night.
  - Amber indicators blink before turns.
  - Moving cars get headlight beams at night.
  - Made-up Cape number plates ("CA 123-456").
- **Pipeline notes:** Blender empties mark axles and plates. Names avoid "wheel", because Godot's
  importer turns those into VehicleWheel3D. Leg UVs wrap each leg once, with the seam inside.
  Arm UVs follow the slanted arm.
- **Tests:** faces, trouser variety, hoodies, cap logos, wheels spin and steer, brake lights,
  indicators, plates, night beams.

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
