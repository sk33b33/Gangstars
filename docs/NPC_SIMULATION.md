# NPC Simulation Specification

## Design target

The neighbourhood must visibly live. NPCs should move between homes and streets as a normal part of play, not just stand in place as decorative props.

## NPC state machine

Implement a finite-state machine with states similar to:

- `AT_HOME`
- `PREPARING_TO_LEAVE`
- `TRAVELLING`
- `AT_DESTINATION`
- `SOCIALIZING`
- `WORKING`
- `PATROLLING`
- `INVESTIGATING`
- `FLEEING`
- `RETURNING_HOME`
- `UNAVAILABLE`

Use explicit transition rules. Keep state changes testable and avoid a large collection of unrelated booleans.

## Schedule model

A schedule entry should describe:
- Start/end time or time window.
- Activity type.
- Destination ID.
- Priority.
- Optional conditions (weekday, mission state, faction state).

Example daily rhythm:
- Morning: home → shop/work destination.
- Midday: work or social destination.
- Afternoon: court, shop, or home.
- Evening: gathering spot or home.
- Night: home, safehouse, or patrol point for crew.

Do not require a fully accurate clock simulation in Phase 1. Start with a simple timer-driven schedule and add a day/night clock later.

## Movement loop

1. Behaviour controller selects a destination ID.
2. Destination registry resolves the ID to a world position.
3. NPC validates that the point is on/near the navigation mesh.
4. NavigationAgent3D calculates a path.
5. NPC moves via CharacterBody3D physics movement.
6. NPC updates animation based on velocity.
7. NPC detects arrival using the agent's target-reached logic and a small distance tolerance.
8. NPC performs an activity for a duration.
9. Controller selects the next destination.

## Recovery rules

- If no path exists, retry once after a short delay with a nearby valid point.
- If the destination is destroyed/disabled, select a fallback.
- If the NPC is stuck, detect low movement over a time window and re-path.
- Never retry pathfinding every frame.
- Do not let NPCs bunch at exactly one coordinate; add destination offsets/slots.
- Use avoidance carefully and profile it with the expected crowd size.

## Reactions

For nearby events, use simple perception:
- Detect event through an Area3D, signal, or event bus.
- Choose a reaction based on NPC role/personality and event severity.
- Move to a safe, curious, or assigned response point.
- Return to schedule after the event ends.

## Performance targets

- First slice: 3–5 active NPCs.
- Full starter district: 8–12 active NPCs, then scale toward 20–30 visible/active.
- Stagger non-critical thinking updates (for example, every 0.5–2 seconds with per-NPC offsets).
- Reduce update frequency with distance.
- Pool or reuse NPC scenes if profiling proves spawning overhead matters.
- Profile before optimizing. Avoid premature multithreading.

## Debug overlay

For each selected NPC show:
- ID and display name.
- Current state.
- Home ID.
- Current destination ID.
- Navigation path status.
- Last state transition.
- Simulation tier.
