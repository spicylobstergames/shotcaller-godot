# AGENTS.md

Conventions for AI agents (and humans) working in this repository. Read
`ARCHITECTURE.md` first for the system map.

## Before you change anything

1. `./prototype/tests/run_suite.sh` must exit 0 before AND after your change.
   If it's red before you start, fix or report that first — do not build on
   a broken base.
2. Read the file you're editing fully. Grep for its consumers (signal names,
   WorldState keys, and `Skills.leader` entries are cross-file contracts).

## The one rule

**Every change is verified by tests that fail when production breaks.**
- Bug fix → regression test first (write the failing test, then fix).
- New behavior → test against the production class, not a copy of it.
- Never weaken, skip, or delete a test to make a failure go away — fix the
  code or, if the test pinned wrong behavior, change the test deliberately
  and say why in the commit message.
- Never duplicate production code inside a test (no re-implemented formulas,
  plan logic, or mirror math). Mocks may only replace Godot nodes/autoloads,
  never game logic. Shared doubles live in `tests/helpers/`.

## Verifying

```
./prototype/tests/run_suite.sh                    # everything (~30s)
# Takes an optional godot-binary argument; without one it defaults to a
# hard-coded local path (see GODOT= in the script). CI passes "$(which godot)".
godot --headless --path prototype res://tests/test_runner.tscn    # unit only
godot --headless --path prototype res://game.tscn -- --smoke      # boot smoke
```

- **Zero `SCRIPT ERROR` lines is part of green.** Script errors can silently
  swallow assertions (a failing expression aborts the statement containing
  it) — a "passing" suite with script errors is lying.
- `run_suite.sh` pins the expected assertion count
  (`EXPECTED_UNIT_TESTS`). Adding tests → bump it. The suite failing with
  "ran N tests, expected M" is the reminder.
- New test files must be registered in `prototype/tests/run_tests.gd`.
  Registering a file but forgetting to call `run()` in the registry list has
  happened twice — after registering, confirm the pinned count changes.

## Workflow

- One feature or fix per branch; small commits; run the suite per commit.
- If you find a bug you won't fix now: write the pinning test, record it in
  `prototype/tests/COVERAGE.md` under "Known bugs", and move on. Don't leave
  silent breakage behind.
- Determinism: tests must not depend on unseeded RNG, timing, or test order.
  Loops that wait on game behavior get tick guards. Any test touching
  WorldState uses `tests/helpers/world_state_snapshot.gd`.
- Godot 4.7.2 quirks that have bitten here: `Node.get()` takes ONE argument
  (no default); `extends` needs a literal path or class_name, never
  `preload(...)`; inner classes can't be declared inside functions; a
  `-> bool` function returning `WorldState.get_state(key)` breaks when the
  key is absent — use `get_state(key, false)`.
