# Definition of Done and QA Checklist

A feature is complete only when it is integrated, runnable, observable, and documented.

## Every implementation task

- [ ] Scope and acceptance criteria stated before coding.
- [ ] Existing project inspected; no unrelated files overwritten.
- [ ] Scenes/scripts use the established architecture.
- [ ] No parser errors or runtime errors in the relevant flow.
- [ ] Relevant scene launched and manually observed where visual behaviour matters.
- [ ] Tests or reproducible manual checks added.
- [ ] Performance risks considered at target NPC/house count.
- [ ] Roadmap and changelog updated.

## Player

- [ ] Movement and camera feel responsive.
- [ ] Player cannot fall through ground or pass through solid buildings.
- [ ] Interaction prompt appears only for valid nearby targets.
- [ ] Input actions are centralized and remappable.

## Houses and district

- [ ] Approximately 30 distinct house plot IDs exist.
- [ ] Each house has a visible entrance and approach point.
- [ ] Each occupied home maps to a valid resident.
- [ ] District navigation is connected and debug-visualizable.
- [ ] Locked district boundaries prevent premature entry.

## NPCs

- [ ] NPCs move between houses and street destinations.
- [ ] No normal routine teleporting.
- [ ] NPCs do not walk through walls.
- [ ] NPCs recover from blocked paths and disabled destinations.
- [ ] NPC states and destinations are inspectable.
- [ ] Simulation scales without one expensive AI update per NPC per frame.

## Progression and saves

- [ ] Mission rewards cannot be granted twice.
- [ ] Locked districts remain locked until requirements are met.
- [ ] Unlocks persist after save/load.
- [ ] Missing or invalid save data falls back safely.

## Suggested validation commands

Use the installed Godot executable; command-line flags can vary by version/platform.

```bash
godot --headless --path . --editor --quit
godot --headless --path . --quit
```

If the executable is named `godot4`, use that instead. A clean headless import/launch is useful but does not replace manual visual testing.
