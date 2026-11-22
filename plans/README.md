# plans/ — machine-readable work items

One file per open work item, intended to be handed to an implementing agent
one at a time. The prose rationale lives in `../IMPROVEMENT_PLAN.md`; these
files carry the machine-checkable fields.

## Schema (YAML front matter + markdown body)

```yaml
---
id: E1                     # stable id, matches the file name
title: ...                 # short imperative title
track: A|B|C|D|E|F|M       # IMPROVEMENT_PLAN track
status: open|blocked-on-decision|done
decision_required: false   # true => do not start without the owner's call
depends_on: [C1]           # ids that must land first
files: [...]               # expected touch set
verify: [...]              # commands that must pass
acceptance: [...]          # observable, testable outcomes
---
```

## Ground rules for the implementing agent

- One item per branch/commit; keep the diff to `files`.
- Run `verify` before claiming done; the full suite is the definition of done:
  `TEST_LOG_DIR="$PWD/.test-logs" ./tests/run_suite.sh <godot>`.
  Fast inner loop: `TEST_LOG_DIR="$PWD/.test-logs" ./tests/run_goap_lint.sh <godot>`.
- Comments/tests/docs only unless the item says otherwise; no drive-by refactors.
- Adding tests means bumping `EXPECTED_UNIT_TESTS` in `tests/run_suite.sh`
  and registering the file in `tests/run_tests.gd`.
- A behavior change that moves frame-by-frame state needs a golden re-record
  with the reason in the commit (`tests/record_golden.sh`, DECISIONS D6/D12).

## Status snapshot

| Item | Track | Status |
|------|-------|--------|
| C1, C2 | C | dropped 2026-11-21 (owner decision: no planner change; see IMPROVEMENT_PLAN.md Track C / DECISIONS D15) |
| D1–D3 | D | open |
| D4 | D | done 2026-11-14 |
| E1 | E | done 2026-11-14 |
| E2, E3 | E | open |
| E4 | E | done 2026-11-14 |
| F1 | F | done 2026-11-14 |
| F2 | F | open |
| M1 | M | done 2026-11-21 (coordinate fix 52792ac; user-verified in editor) |
| M2 | M | done 2026-11-21 (user-verified in editor) |
| M3 | M | implemented 2026-11-21 (TileMapLayer port done; awaiting user editor verification) |
| M4 | M | open 2026-11-22 (runtime/in-game map editor MVP; plan ready) |

Already landed (do not redo): Track A documentation truth pass; Track B
arrival-dispatch fix + ReturnLumber; state-key lint + contract lint +
GOAP-GUIDE banner test + fast GOAP lint (was D5); generated
`docs/ai/goap-index.md`; `goap-cheatsheet.md`; `planner.explain()`;
readable golden diffs; action/goal templates.
