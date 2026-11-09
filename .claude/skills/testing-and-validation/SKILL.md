---
name: testing-and-validation
description: Use after any implementation change and when verifying project health, NPC movement, progression, or release readiness.
---

# Testing workflow

- Run a headless import/editor validation with the installed Godot binary.
- Run a headless project launch where supported.
- Launch the relevant scene for any visual or movement feature.
- Verify player collision, NPC navigation, house entrances, and destination reachability.
- Test failure paths: blocked route, missing destination, duplicate reward, locked district, corrupt/missing save.
- Record exact test steps and outcomes.
- Separate passed, failed, blocked, and not-tested items.
- Update `docs/CHANGELOG.md` and roadmap evidence.
