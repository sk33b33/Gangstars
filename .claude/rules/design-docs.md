---
paths:
  - "design/gdd/**"
---

# Design document rules

A system's design doc has eight sections: Overview, Player Fantasy, Detailed Rules, Formulas, Edge Cases,
Dependencies, Tuning Knobs, Acceptance Criteria.

- Formulas define their variables, give expected ranges and a worked example.
- Edge cases say exactly what happens, never "handled gracefully".
- Dependencies are listed in both directions.
- Tuning knobs give a safe range and what they affect, and name the data file that holds them.
- Acceptance criteria are testable: each maps to a check in `tests/run_tests.gd`.
