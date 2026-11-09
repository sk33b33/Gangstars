---
name: npc-neighbourhood-simulation
description: Use when implementing NPC schedules, walking, navigation, house visits, street activity, reactions, or simulation performance.
---

# NPC neighbourhood simulation workflow

1. Read `docs/NPC_SIMULATION.md` and `docs/ARCHITECTURE.md`.
2. Define NPC data, state transitions, destination IDs, and schedule entries.
3. Ensure each destination resolves to a reachable navigation point.
4. Move NPC CharacterBody3D instances with NavigationAgent3D paths and physics movement.
5. Add arrival, activity duration, next destination, and path recovery.
6. Add a debug view for state, target, and navigation status.
7. Test house → street destination → house loops with multiple NPCs.
8. Test blocked paths, invalid destinations, and off-screen simulation.
9. Profile before increasing NPC count.

Critical: visible NPCs must walk; do not teleport them to fake a living neighbourhood.
