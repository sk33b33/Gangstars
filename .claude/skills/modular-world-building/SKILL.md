---
name: modular-world-building
description: Use when building the starter district, house plots, streets, sidewalks, landmarks, navigation meshes, or locked expansion boundaries.
---

# Modular world-building workflow

1. Read `docs/WORLD_LAYOUT.md`.
2. Create a reusable house/plot scene and deterministic variation system.
3. Store the 30 starter house definitions as data with stable IDs.
4. Populate streets and house plots from that data.
5. Build continuous sidewalk/yard navigation and validate each entrance.
6. Add a small number of distinct landmarks and destination anchors.
7. Create visible but inaccessible expansion boundaries.
8. Run a reachability check from every occupied home to public destinations.

Do not build all interiors before the player and NPC movement loop is working.
