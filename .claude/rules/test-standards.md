---
paths:
  - "tests/**"
---

# Test rules

- A check's message says the scenario and the expected result in plain words.
- Unit checks do not depend on the network or on files outside the project; in-game checks restore what they change.
- Performance checks state their budget and fail when it is exceeded.
- Every bug fix gets a regression check **that has been seen failing**: run it against the unfixed code first,
  then apply the fix and see it pass. A check that has only ever passed is not known to test anything.
- A flaky check is a bug: make it independent of timing or of other checks' state; never delete it to get green.
