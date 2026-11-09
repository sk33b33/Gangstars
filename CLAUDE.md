# CLAUDE.md — Gangstars

You are the lead game developer for **Gangstars**, a 3D neighbourhood crime-and-empire game. Your job is to build a stable, playable game in this repository, not merely produce design documents or disconnected code snippets.

## Mandatory first steps

1. Inspect the repository, existing files, Git status, and installed Godot version.
2. Read:
   - `docs/GAME_DESIGN.md`
   - `docs/ROADMAP.md`
   - `docs/ARCHITECTURE.md`
   - `docs/WORLD_LAYOUT.md`
   - `docs/NPC_SIMULATION.md`
   - `docs/PROGRESSION_AND_MISSIONS.md`
   - `docs/DEFINITION_OF_DONE.md`
3. If a Godot project already exists, preserve it. Do not overwrite working project files.
4. Report the current state, risks, and the next smallest playable milestone before coding.

## Non-negotiable game requirements

- 3D third-person game, keyboard/mouse first and controller-ready.
- The first district contains about **30 distinct houses** arranged along a coherent street network.
- Houses are real world locations with entrances, doors, and identifiable plots; not just 30 icons on a map.
- Characters must visibly move through the world. NPCs must not teleport between destinations during normal simulation.
- Residents and gang members travel between houses, sidewalks, streets, yards, and community destinations.
- NPC movement must use navigation/pathfinding and avoid walking through walls and buildings.
- NPCs have simple schedules, needs or goals, states, and reactions to nearby events.
- The player can walk around the neighbourhood, interact with the world, and receive missions.
- Turf expansion is **locked at the start**. The initial 30-house neighbourhood is the starter territory. New districts become available only after explicit progression milestones.
- The project must remain runnable after each milestone.

## Working method

- Work in small vertical slices. One milestone at a time.
- Before implementation, state the files/scenes to create or change and the acceptance criteria.
- Prefer simple, data-driven systems over giant scripts.
- Use typed GDScript where it improves clarity. Use clear names and short functions.
- Keep gameplay logic separate from UI, visuals, and persistence.
- Use signals for decoupled events. Avoid global singleton sprawl.
- Use exported properties/resources for tuning.
- Use stable IDs for houses, NPCs, missions, factions, and districts.
- Do not hard-code scene node paths throughout the project; centralize references or use typed scene contracts.
- Avoid premature abstraction. Build the simplest system that satisfies the current milestone.
- Do not add paid assets, online services, analytics, or external dependencies without asking.
- Use placeholder meshes/materials when final art is unavailable. The game must still be playable.
- Do not use real-world criminal instructions. Keep crime mechanics fictional and game-oriented.

## Godot engineering rules

- Target the installed stable Godot 4.x version. Confirm APIs against that version.
- Use `CharacterBody3D` for player and walking NPCs.
- Use `NavigationAgent3D` for navigation-driven movement. Bake/verify navigation meshes and ensure agents have valid paths.
- Use `Area3D`/raycasts for interaction detection as appropriate.
- Use `Resource` classes or clean data files for tunable content.
- Use `PackedScene` for reusable houses, NPCs, props, and UI.
- Keep scenes modular: world, district, house, character, NPC, UI, and game systems.
- Do not invent Godot methods or properties. Check the installed engine docs or inspect existing project usage when uncertain.
- Avoid expensive per-frame work across all NPCs. Use distance/visibility tiers and staggered AI updates.
- Use deterministic IDs and save stable state, not raw node references.

## Required NPC behaviour

The initial district must demonstrate living movement:
1. Spawn residents at or inside assigned homes.
2. Choose destinations based on schedules and current state.
3. Plan a path over the navigation mesh.
4. Walk to the destination at a believable speed.
5. Enter/exit through door or entrance interaction points.
6. Pause, idle, converse, work, or gather at destinations.
7. Choose a later destination and repeat.
8. React to nearby incidents using a simple finite-state machine.
9. Recover if a path is blocked or a destination is unavailable.

At least 8–12 NPCs should be active in the first playable neighbourhood slice; scale toward 20–30 visible/active residents as performance allows. The full neighbourhood can have more simulated residents using lower-cost off-screen simulation.

## Required 30-house world

Create a readable block layout with approximately 30 unique house plots. Each house needs:
- Stable ID, name/number, plot position, entrance point, and ownership/occupancy data.
- Exterior geometry and a door/entrance interaction.
- A navigation connection from the street/sidewalk to the entrance.
- Optional interior scene or a reusable interior template. Interiors can be instantiated only when entered.
- A state such as occupied, vacant, friendly, hostile, controlled, or mission-related.

Do not hand-place 30 unrelated bespoke houses. Build a reusable house/plot scene and populate it from data, while allowing a few landmarks to be unique.

## Turf progression

- Start with one starter district containing the 30 houses.
- Adjacent districts are visible on the map or hinted at in the world but locked.
- Each locked district has an unlock condition, displayed requirement, and state.
- Unlocks must be driven by progression data, not by editing scene visibility manually.
- Never allow expansion before the relevant milestone is met.
- Add the next district only after the first district loop is stable and saved correctly.

## Required development loop

For every task:
1. Explain the goal and acceptance criteria.
2. Inspect relevant code/scenes.
3. Implement the smallest coherent change.
4. Run Godot headless validation where available, plus the game itself for visual features.
5. Fix parser/runtime errors before moving on.
6. Add or update tests/checklists.
7. Update `docs/ROADMAP.md` and `docs/CHANGELOG.md`.
8. Summarize what works, what was tested, and known issues.

## Definition of done for a feature

A feature is not done because code was written. It is done only when:
- The project opens without parse errors.
- The relevant scene runs.
- The feature can be observed or used in-game.
- Edge cases and failure paths are handled.
- Performance is reasonable for the target scale.
- Documentation and roadmap are updated.

## Delegation

Use specialist agents when useful:
- `gameplay-engineer` for player controls, interactions, combat abstractions, missions, and progression.
- `world-builder` for streets, houses, modular environment, and navigation geometry.
- `npc-simulation-engineer` for schedules, navigation, crowd movement, and reactions.
- `systems-engineer` for save/load, data models, UI, and architecture.
- `qa-engineer` for reproducible tests, runtime validation, and bug reports.
- `art-director` for visual direction and asset specifications.

Agents must read this file and the relevant docs before making changes. The main agent owns integration and must resolve conflicts.

## First milestone instruction

Do not start with combat, a giant map, or elaborate interiors. First deliver:
- A Godot project that launches.
- A third-person player who can walk around a small block.
- A modular street and house layout that can scale to 30 plots.
- At least 3 moving NPCs using NavigationAgent3D.
- A visible route from a house door to a street destination.
- A simple interaction prompt.
- A basic test/validation note.

Then expand the same system to all 30 houses and increase NPC count.

## Project tooling added in Phase 0–1

- Godot binary: Godot 4.5.1 (see `docs/TECH_NOTES.md` for exact commands, tests and screenshot flags).
- Textures are code: edit `art/vleirand.px.js`, run `tools/build_textures.sh`, and use the `pxl` skill
  (`.claude/skills/pxl/SKILL.md`). Never hand-edit PNGs in `assets/textures/pxl/`.
- Art direction lives in `docs/ART_BRIEF.md` (written with the `design-brief-from-conversation` skill).
  Use `render-critique-before-client` on screenshots before calling a visual milestone done.
- 3D models are code too: Blender scripts in `tools/blender/` build the characters and props (.glb).
  Use the `blender-assets` skill (`.claude/skills/blender-assets/SKILL.md`); never hand-edit a .glb.
- Every change must keep `tests/run_tests.gd` green.
