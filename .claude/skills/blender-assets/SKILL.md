---
name: blender-assets
description: Use when creating or changing 3D models for Gangstars (characters, clothing, hair, animations, yard and street props) with headless Blender scripts, or when a model looks wrong in game.
---

# blender-assets: 3D models as code

Gangstars' models are Python scripts run in headless Blender, like the pxl textures: edit the
script, rebuild the .glb, look at it in Godot, fix, repeat. Never hand-edit a .glb.

| Script | Output | Used by |
|---|---|---|
| `tools/blender/build_character.py` | `assets/models/characters/person.glb` | `CharacterModel` (every resident, crew, player) |
| `tools/blender/build_props.py` | `assets/models/props/props.glb` | `PropLibrary.place()` (plots, parks, courtyards) |
| `tools/blender/build_dog.py` | `assets/models/animals/dog.glb` | `DogModel` (street and yard dogs) |
| `tools/blender/build_vehicles.py` | `assets/models/vehicles/vehicles.glb` | `VehicleLibrary` (parked, traffic, drivable, police) |
| `tools/blender/build_weapons.py` | `assets/models/weapons/weapons.glb` | `WeaponLibrary` + `CharacterModel.set_weapon` |

## Setup (once per machine)
Blender 4.5 LTS: download `blender-4.5.x-linux-x64.tar.xz` from download.blender.org/release/Blender4.5/,
untar to `~/opt`, link `~/bin/blender`. For Forward+ screenshots without a GPU: `apt-get install mesa-vulkan-drivers`.

## Loop
1. Edit the script.
2. Build it: `blender -b --factory-startup --python tools/blender/build_character.py` (or `build_props.py`).
   Expect a `WROTE ...` line; any `Traceback` names the failing line.
3. Re-import: `godot --headless --path . --import`.
4. Look at it:
   - Characters: `xvfb-run -a godot --path . -s tools/godot/lineup.gd -- --out=res://tests/output/lineup.png [--close]`
     (6 looks: idle/talk/guard/walk/run, skirts, hair styles, body shapes). Then read the PNG.
   - Dogs: `lineup.gd -- --dogs`. Vehicles: `--cars`. Police and weapons: `--armed`. Named characters: `lineup.gd -- --named`.
   - Props/in game: the normal `--shot=...` flags (see docs/TECH_NOTES.md), e.g. `--cam=x,y,z,lx,ly,lz`.
5. Run `tests/run_tests.gd`; it checks bones, body-shape variety and prop placement.

## Conventions (break these and Godot breaks quietly)
- **Axes:** Blender Z-up, the model faces **-Y**. The glTF export makes that Godot +Z.
- **Origins:** props have their origin at the base centre (`join()` handles it). Apply transforms with
  `location=True` before any bmesh cut, or the cut runs in local space and deletes the mesh.
- **UVs:** every mesh needs a UV layer, even flat ones, or Godot logs "UVs are required to generate tangents".
- **Materials are slots, named by role.** Godot recolours by material name:
  - Character: skin, shirt, forearm (sleeve: shirt or skin), pants, shoes, hair, hat, skirt, eye_white, pupil, lips.
  - Props: `paint` is recolourable; `leaf*` surfaces get the wind-sway shader (`assets/shaders/foliage_wind.gdshader`).
- **Hems:** cut edge loops at colour boundaries (`add_hem_loops`) before painting faces, or the edges come out jagged.
- **Rigging:** the body uses automatic weights (it must be a closed mesh, which the Skin modifier gives).
  Head, face, hair and hats are rigid on the `head` bone (`bind_rigid`). The skirt uses hand-made height weights.
- **Animation:** pose with `set_rot` or `set_multi`, which take *armature-space* axes, so "X" always means
  swing forward or back. Bake every frame and push each action to its own NLA track. Godot loops them and
  `CharacterModel._pace()` scales playback to real speed. Walk is authored at 1.5 m/s, run at 4.5 m/s.
- **Bone names are an API:** `hips spine chest neck head upper_arm.L/R forearm.L/R hand.L/R thigh.L/R
  shin.L/R foot.L/R`. `CharacterModel.UPPER_BONES` and the tests use them.
- **Optional pieces** are separate objects (`Hair_*`, `Hat_cap`, `Skirt`, `Acc_*`) that Godot shows or hides by name.
  - Add a hair style: create `Hair_<style>` and add the name to `CharacterModel.HAIR_STYLES`.
  - Add an accessory: create `Acc_<name>` and add the name to `CharacterModel.ACCESSORIES`. Bind it
    with `bind_rigid(..., "head")` for head pieces or `bind_by_height` for torso pieces.
  - Give a named character a look in `data/npcs/looks.json`. Check it with `lineup.gd --named`.
  - Printed cloth (the aunty house dresses) uses real UVs from `cloth_uvs()` (cylindrical, seams
    fixed per face) and `PixelMaterials.fabric(print)`. Triplanar smears on thin cone strips, and
    primitives already carry a UV layer, so `cloth_uvs` removes it first. Check with `lineup.gd --aunties`.
- **Animations:**
  - Full-body poses (sit, lean) are Blend2 nodes before the upper-body gestures (talk, guard, wave)
    in `CharacterModel._build_tree`.
  - A new full-body pose needs a new mix node there, plus a `base_pose` value.
  - The sit pose assumes the character's origin is the middle of a 0.45 m seat. The lean pose assumes
    the origin is 0.3 m in front of a wall. `SpotRegistry` markers follow those conventions.

## Adding a prop
Write a `def my_prop(x): ...; return join(parts, "my_prop", (x, 0, 0))` in `build_props.py`, then add it
to the build list. In game, use `PropLibrary.place(parent, "my_prop", pos, rot_y, paint_colour)`.
Visual-only by default; add `Geo.collider(...)` only where no walking path runs.

## Style
Low-poly but rounded (smooth shading, ico-sphere clumps, a little vertex jitter on organic shapes).
Colours come from the Cape Flats palette in docs/ART_BRIEF.md. Prefer a few strong shapes over many
small ones; check from the game camera (about 6 m away), not just in close-up.
