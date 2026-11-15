---
paths:
  - "scripts/**/*.gd"
---

# Gameplay code rules

- Tunable gameplay values come from data files (`data/**`) or exported properties, not literals buried in logic.
  A named `const` at the top of the script is acceptable only for values no designer would tune.
- Use `delta` for everything time-dependent.
- Gameplay never reaches into UI code. It emits signals; `GameSession` / `Main` wire them to the HUD.
- Logic lives in plain classes (`RefCounted`) that can be unit-tested without a scene; nodes present it.
- State machines name their states (enum) and keep transitions in one place.
- Every new system has unit tests in `tests/run_tests.gd` and a design doc in `design/gdd/` it names in its header comment.
- No new autoload singletons for game state: pass dependencies in `setup(...)`.
- No per-frame allocations or tree queries across all NPCs: cache, stagger, or use distance tiers.
