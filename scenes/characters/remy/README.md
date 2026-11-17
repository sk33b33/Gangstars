# Remy (Mixamo character)

A rigged Mixamo character with five animations, set up as a reusable model for the player and for NPCs.
**Remy is the game's player** (2026-11-17): `scenes/characters/player.tscn`'s `Model` node is now
`remy_player_model.tscn`. The game's `Player` script is unchanged (combat, interaction, camera, driving, touch, saves),
except for one `model.jump()` call. Remy also has his own stand-alone player (`remy_player.tscn`) and a test world:
open `scenes/dev/remy_playground.tscn`, press F6.

## Remy as the game's player

`RemyPlayerModel` (`scripts/characters/remy_player_model.gd`) answers the calls the old `CharacterModel` did, so nothing
else in the game changed: `set_weapon`, `draw_weapon`, `aiming`, `animate`, `muzzle_position`, `flinch`, `base_pose`,
`build`, `rotation.y` (the Player turns it so that +Z is where the character faces; the RemyModel inside is turned round).
- **Weapons** come from `WeaponLibrary` (pistol, shotgun): in the hands while drawn or aiming, then a pistol rides in a
  holster on the right hip (`HipAttachment/Holster`) and a shotgun is slung across the back (`BackAttachment/Sling`).
  The box pistol of the playground is hidden. Placement values are in `tools/godot/build_remy_model.gd`.
- **Crew colours** (`Player.wear_colours`) tint the top and bottoms and the skin tone tints the body. The cap and the old
  model's hair, face and trouser options do not exist on Remy.
- **Gaits** follow the Player's own speeds: its walk (3.4 m/s) is Remy's Run clip, a gentle push still plays Walk,
  its sprint (6.5 m/s) plays Sprint.
- **Knocked out** lays Remy on his back (a tween: there is no fall clip). **Hit flinch, kick, wave:** nothing plays yet
  (no clips).
- Aiming is the Player's own (RMB / LT / the AIM button); `Aim_Hold` raises the arms.

## Files

| What | Where |
|---|---|
| The uploaded model (never edited) | `assets/models/characters/Remy_Animations_Mobile.glb` |
| Its import settings (loops, materials) | `assets/models/characters/Remy_Animations_Mobile.glb.import` |
| Extracted textures (VRAM compressed) | `assets/models/characters/Remy_Animations_Mobile_Remy_*.png` (+ `.import`) |
| Editable materials | `assets/models/characters/remy/materials/*.tres` |
| Reusable model (skeleton, one AnimationTree, gun) | `scenes/characters/remy/remy_model.tscn`, `scripts/characters/remy_model.gd` |
| The AnimationTree | `scenes/characters/remy/remy_anim_tree.tres` |
| Third-person player (CharacterBody3D, capsule, SpringArm3D camera) | `scenes/characters/remy/remy_player.tscn`, `scripts/characters/remy_player.gd` |
| What an NPC wears | `scripts/characters/remy_outfit.gd` |
| Test world with touch controls and 5 demo NPCs | `scenes/dev/remy_playground.tscn` |
| Generators (re-run after changing them) | `tools/godot/build_remy_materials.gd`, `tools/godot/build_remy_model.gd` |

## Animations

| Clip | Length | Loops | Authored speed | Notes |
|---|---|---|---|---|
| `Walk` | 1.07 s | yes | 1.7 m/s (`AUTHORED_WALK`; your note said 1.6) | in place (root motion removed) |
| `Run` | 0.67 s | yes | 5.5 m/s (`AUTHORED_RUN`; your note said 5.4) | in place |
| `Sprint` | 0.57 s | yes | 6.0 m/s (`AUTHORED_SPRINT`; your note said 5.5) | in place; quicker steps than Run |
| `Jump` | 1.93 s | no | | crouch to 0.4 s, apex 0.8 s, feet down about 1.3 s |
| `Pistol_Aim` | 7.13 s | yes | | raises the gun by 0.5 s, holds until about 1 s, then lowers it |
| `Idle` | 10.0 s | yes | | breathing idle |
| `Fall_Down` | 2.3 s | | | knocked out; carries ~1 m of root motion, so `RemyModel` plays an in-place copy |
| `Stand_Up` | 1.7 s | | | getting up; also played in place |
| `Lying` | | yes | | **made at start-up: the last frame of Fall_Down, held** |
| `Aim_Hold` | | yes | | made at start-up: Pistol_Aim at 0.75 s held |

- The clip's play speed is `actual speed / authored speed`, so the feet do not skate (`RemyModel.play_speed`).
  The authored speeds are where the planted foot stood stillest when measured in the game (ground speed scanned
  for each clip played at normal speed: Walk best at 1.7, Run at 5.5, Sprint at 6.0). Tune `AUTHORED_*` in
  `remy_model.gd` if the feet still slide on your phone.
- Gaits are not blended linearly: mixing two clips with different strides makes the feet skate (65 to 80% of the speed
  when that was tried). Each clip stays alone at a matched play speed (Walk from a crawl up to about 2.5 m/s, 0.4 to
  1.8 times its speed), only the first 0.35 m/s (idle to walk) and a window of 0.6 m/s around 2.85 m/s (walk to run)
  are blended, and Run is used up to sprint speed.
- Measured foot slide (the planted toe's speed over the ground, in the game's own physics, 60 Hz): median 0.06 to 0.33 m/s
  for walking and running at 1.0, 1.7, 2.5, 4.0 and 5.5 m/s (mean 15 to 24% of the body's speed, including the toe
  rolling), and about 1 m/s for the sprint clip (16%).
- Gameplay speeds (exports on `RemyPlayer`): walk 1.7, run 4.0, sprint 6.0 m/s (Run then plays at 0.73 times its speed). A gentle stick push walks, a firm one
  runs, the sprint button sprints.
- The Jump clip is played in three pieces so it reacts at once: take-off (from 0.25 s), air (0.5 to 1.25 s, last frame
  held if the fall is longer), landing (1.25 to 1.65 s). The jump velocity is applied the same frame the button is pressed.

## The AnimationTree (one per character)

```
Blend2 "aim"  (filter: spine and everything above it)
  in    StateMachine "loco"
          Grounded = BlendTree( BlendSpace1D "gait": Idle 0, Walk 1, Run 2, Sprint 3  ->  TimeScale "speed" )
          JumpStart -> JumpAir -> JumpLand -> Grounded
  blend Aim_Hold
```

Aiming blends only the upper body, so the legs keep walking. Parameters set by `RemyModel.update_locomotion()`:
`parameters/loco/Grounded/gait/blend_position`, `.../speed/scale`, `parameters/aim/blend_amount`,
`parameters/loco/conditions/landed`.

## Bone names

Godot turns Mixamo's colon into an underscore: the bones are `mixamorig_Hips`, `mixamorig_RightHand` and so on
(not `mixamorig:RightHand`).

## Size

The glb is about twice life size (the Armature node is scaled 0.01 and the bones are 2x too big). The `Remy` child of
`remy_model.tscn` is scaled 0.5 and turned round, so the model is **1.8 m tall and faces -Z** like any Godot node.

## Aim and the gun

When aim is held (`aim` action, right mouse, LT, or the AIM button) the player turns to face the camera direction,
slows to `aim_speed`, the camera moves closer over the shoulder, and the arms blend to the aim pose.

The pistol is `RemyModel > RightHandAttachment (BoneAttachment3D, bone mixamorig_RightHand) > Pistol`.
The attachment sits beside the model and points at its skeleton (external skeleton), so the glb stays untouched.
`Pistol` is scaled 200 to cancel the armature's 0.01 and the model's 0.5: inside it **1 unit = 1 metre**.
Select `Pistol` in the editor and change its position and rotation until it sits right. Its starting values were
worked out in the aim pose (barrel forward, slide up, grip in the palm); its box slide and grip are placeholders.
Firing is not implemented in `RemyPlayer` yet.

## NPCs

Instance `remy_model.tscn` for each NPC: each gets its own skeleton and its own AnimationTree, and they share the
clips, the meshes and the materials. Call `update_locomotion(speed, sprinting, on_floor, delta)` each physics frame.

- Different clothes: make a `RemyOutfit` (texture and tint for Tops, Bottoms, Shoes, Hair, a skin tone, parts to hide)
  and call `model.apply_outfit(outfit)`. Only a part you change gets its own material copy.
- A different mesh, for example a **female body**: import the other Mixamo glb, take its MeshInstance3D nodes and call
  `model.replace_part("Tops", other_mesh_instance)` (mesh, skin and material come along). The skeleton must have the
  same bone names (Mixamo does) and the same scale (this glb is 2x: a new glb that is not will mis-skin). Female NPCs
  keep using the same animations.
- Far-away NPCs: `model.set_animation_enabled(false)`.

## Touch controls

The project's `TouchControls` (left stick, right stick to look, JUMP, RUN, AIM and more; layout editable in the menu)
drive the normal input actions, so they work with `RemyPlayer` unchanged. They only appear on a touchscreen
(or with `-- --touch` on a PC), so desktop play is unaffected. Keyboard (WASD, Shift, Space, right mouse) and gamepad
work through the same actions.

## Mobile cost (read this)

One Remy is **35,196 triangles** (Body 13,538, Hair 4,666, Shoes 6,494, Bottoms 4,510, Tops 4,362, Eyes 1,520, Eyelashes
106), **7 draw calls**, 6 materials with a 1024 x 1024 texture each, 67 bones, 109 animation tracks per clip. That is
heavy for a phone: ten visible NPCs would be 350,000 triangles and 70 draw calls. Already done: textures are VRAM
compressed, no metallic or normal texture is read, hair and eyelashes use alpha scissor, every material is two-sided (open sleeve, collar and trouser ends would show the background through back-face culling) and matte (the glb's Gloss maps made the clothes shiny, so there is one roughness per material and a low specular),
one AnimationTree per character. Still to do for crowds:
- the importer builds mesh LODs (`meshes/generate_lods`); raise `rendering/mesh_lod/lod_change/threshold_pixels` to use them sooner;
- a cheaper NPC version: reduce the Body mesh (most of it is hidden under clothes), merge Eyes and Eyelashes, 512 px textures;
- shadows off for NPCs, `set_animation_enabled(false)` beyond about 40 m, a limit on how many are animated at once.

## What is missing

- Strafe and backwards walking (aiming while moving sideways plays the forward walk), a turn-in-place, a falling-hard
  landing, hit clips, a firing recoil.
- A cheaper LOD model for crowds (above).
- Wiring Remy into the game's `Player`/`Resident` (decision pending).

## Knocked out (Fall_Down, Lying, Stand_Up)
`RemyModel.fall_down()` plays Fall_Down and then holds `Lying`; `stand_up()` plays Stand_Up and returns to the gaits (walking
off during the last 0.7 s cuts it short). `is_down()` says whether he is falling or lying. The glb's two clips drift about
a metre across the ground (root motion), so the library plays copies whose hips keep their start position on the ground
(the Mixamo hips track: local X and Y are the ground, Z the height). `RemyPlayerModel.base_pose = "down"` / `""` call them.
