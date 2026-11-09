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

## Known limitations

- Characters are low-poly placeholders with a walk bob; no rigged animation yet.
- All NPCs are on the "near" simulation tier; distance tiers come in Phase 3.
- In software-rendered containers the game runs at about 8 FPS; this is not representative of real GPUs.
