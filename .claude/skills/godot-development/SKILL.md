---
name: godot-development
description: Use when creating or modifying Godot 4 scenes, scripts, resources, input, navigation, or project settings.
---

# Godot development workflow

- Inspect project version and existing patterns first.
- Use Godot 4 APIs compatible with the installed version.
- Prefer typed GDScript, small scripts, reusable scenes, and Resources for data.
- Keep scripts and scenes modular.
- Use signals for decoupled communication.
- Validate with the installed Godot executable after changes.
- For visual features, launch the scene and inspect it; headless parsing is not enough.
- Never invent API calls. Check engine documentation or existing project code.
- Report exact commands and results.
