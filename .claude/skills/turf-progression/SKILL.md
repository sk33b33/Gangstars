---
name: turf-progression
description: Use when implementing territory influence, district ownership, unlock conditions, map UI, or expansion content.
---

# Turf progression workflow

1. Read `docs/PROGRESSION_AND_MISSIONS.md`.
2. Model district state and unlock requirements as data.
3. Keep the district manager as the authority for unlock decisions.
4. Make the initial 30-house district available from the start.
5. Keep neighbouring districts locked until all requirements are met.
6. Show the player clear unlock requirements and feedback.
7. Persist unlocked district IDs and test reload behaviour.
8. Add new district content only after the starter district is stable.
