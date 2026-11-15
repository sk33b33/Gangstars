---
paths:
  - "data/**/*.json"
---

# Data file rules

- Valid JSON, lowercase_with_underscores file names, `snake_case` keys.
- Every file's schema is documented in the design doc of the system that reads it (`design/gdd/`) or in `docs/ARCHITECTURE.md`.
- Stable ids: never rename an id that a save file, mission or another data file refers to.
- No orphaned entries: every entry is read by code or referenced by another data file (tests check the catalogs).
- Optional fields have sensible defaults in the loader.
- Numbers that need explaining are explained in the design doc's "Tuning Knobs" table (safe range + what it affects).
