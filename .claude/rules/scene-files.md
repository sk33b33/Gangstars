---
paths:
  - "**/*.tscn"
  - "**/*.tres"
---

# Scene and resource file rules (Godot)

- Never change the `format=` header, reuse an `id`, or invent a `uid://` value; leave `uid=` off a new reference
  and let `godot --headless --path . --import` assign it.
- Never edit or delete a `.uid` file; move it with its script.
- After a hand edit, run the import and load the scene once to confirm it opens without errors.
