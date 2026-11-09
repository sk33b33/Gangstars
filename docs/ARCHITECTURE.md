# Technical Architecture

## Suggested project layout

```text
res://
  project.godot
  scenes/
    main/
    world/
    districts/
    houses/
    characters/
    npcs/
    props/
    ui/
  scripts/
    core/
    player/
    world/
    houses/
    navigation/
    npcs/
    factions/
    missions/
    progression/
    save/
    ui/
  data/
    houses/
    npcs/
    schedules/
    missions/
    districts/
  materials/
  models/
  audio/
  tests/
```

## Scene responsibilities

- `Main`: bootstraps the game and loads the active save/session.
- `World`: owns the district scene, global navigation context, lighting, and world-level services.
- `District`: owns district geometry, house instances, points of interest, and district navigation.
- `HousePlot`: reusable exterior, door/entrance, metadata, and optional interior spawn.
- `Player`: movement, camera, and interaction component.
- `NPC`: character body, navigation agent, animation state, and behaviour controller.
- `UI`: HUD, prompts, mission display, pause menu, and territory screen.

## Core data models

Use Resources or similarly typed data objects. Suggested models:

- `HouseData`: `id`, `display_name`, `district_id`, `plot_transform`, `entrance_marker`, `occupant_ids`, `ownership_state`, `interior_scene`.
- `NPCData`: `id`, `display_name`, `home_id`, `faction_id`, `schedule_id`, `personality_tags`, `role`.
- `ScheduleData`: ordered time/activity/destination entries.
- `DistrictData`: `id`, `display_name`, `house_ids`, `unlock_requirements`, `is_initially_unlocked`.
- `MissionData`: `id`, `title`, `description`, `prerequisites`, `objectives`, `rewards`.
- `FactionData`: `id`, `name`, `relationship_values`, `territory_ids`.

Use stable string IDs; do not rely on scene tree order or instance IDs for saves.

## Navigation design

- Use one or more NavigationRegion3D nodes per district, with geometry configured to avoid building interiors and inaccessible rooftops.
- Ensure the navigation mesh covers sidewalks, walkable yards, and destination pads.
- Give every house an explicit entrance marker and a nearby reachable navigation point.
- Use NavigationAgent3D for path queries and movement steering.
- Move the CharacterBody3D using velocity and physics ticks; do not set arbitrary transforms to simulate walking.
- Tune agent radius/height and navigation layers consistently.
- Add debug drawing for paths, target points, and unreachable destinations.
- For entering a building, walk to the door marker, play an entry/exit action, then switch to a lightweight interior scene or interior instance. Do not path through the building mesh.

## NPC simulation tiers

1. **Near/player-visible:** full navigation, avoidance, animation, reactions.
2. **District-active but distant:** lower-frequency schedule/state updates; movement may be simplified but must remain plausible.
3. **Far/off-screen:** abstract schedule progression and destination bookkeeping; on re-entry, spawn at a plausible valid location. Do not visibly teleport in front of the player.

## Dependency direction

- UI observes systems and sends player intent; it does not own gameplay rules.
- NPC behaviour requests navigation destinations; navigation does not decide NPC goals.
- Mission manager grants rewards through progression services.
- District manager owns district unlock state.
- Save system serializes stable data models, not live node graphs.

## Debugging support

Provide toggles or debug UI for:
- NPC ID/state/current destination.
- Navigation path and path status.
- House ID and occupancy.
- District lock state and unlock requirements.
- Current simulation tier and update interval.
