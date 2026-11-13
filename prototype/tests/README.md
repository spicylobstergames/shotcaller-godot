# Testing Conventions

How to write tests for this project. Read this before adding test files.

## Layout

- `run_tests.gd` — explicit registry of every unit/integration test class.
  Registering a file here AND calling `.run(self)` are both required.
- `run_suite.sh` — CI entry point: unit suite + boot smoke + golden replay
  + script-error budget in one command.
- `smoke/smoke_runner.gd` — boots the REAL game headless and asserts it
  plays (units spawn, the simulation moves). Enabled via `-- --smoke` on
  game.tscn; the debug harness (`tests/debug_map.gd`) spawns the scenario.
- `helpers/` — shared doubles (see below).
- `unit/` — the test classes.

## Running the suite

```
./prototype/tests/run_suite.sh          # full verification (unit + boot smoke + golden + error budget)
```

Direct runs:

```
godot --headless --path prototype res://tests/test_runner.tscn          # unit suite
godot --headless --path prototype res://game.tscn -- --smoke            # boot smoke
```

A change is only done when `run_suite.sh` exits 0. **Zero script errors is
part of green** — script errors can silently swallow assertions, so a suite
that "passes" with script errors is lying.

## The golden rule

**Tests must fail when production behavior breaks.** Before merging a new
test, temporarily break the production line it guards, run the test, watch it
fail, revert. If the test still passes, it is testing a mock — rewrite it.

- Instantiate **production classes** (`load("res://goap/...")`) and exercise
  their real methods.
- Mocks are allowed **only** for Godot nodes/autoloads the production class
  touches (`WorldState`, scene-tree parents, TileMaps) — never for game logic.
- Never duplicate production code in a test (no re-implementing formulas,
  plan-following logic, or mirror math). That was tried; it hides bugs.
- Never keep a second copy of the project to test against.

## Shared helpers (`tests/helpers/`)

| Helper | Purpose |
|--------|---------|
| `fs_scan.gd` | Whole-project file scanning for the smoke tests |
| `world_state_snapshot.gd` | Capture/restore WorldState keys — **mandatory** for any test registered in `run_tests.gd` that touches WorldState (they share one process; leaked state makes the suite order-dependent). Exempt: `tests/debug_map.gd` (the dev/smoke harness owns its process). |
| `mock_goal.gd` | Canonical GOAP mock goal: extends the real GoalContract, tracks is_valid/priority call counts |

Mock policy:
- Shared helpers exist for doubles that mirror autoload/contract shapes
  (goals, WorldState). Use them; extend them for extra behavior rather than
  redefining a local copy.
- Per-test minimal doubles (a TestUnit with three properties) are fine when
  they are genuinely test-specific — do not force them into a shared
  "god mock".
- GDScript gotcha: `extends` accepts only a literal path string, a
  class_name, or a native type — never `preload(...)` or a const. Use
  `extends "res://tests/helpers/mock_goal.gd"`. And a file with no
  class_name (like goal_contract.gd) cannot be extended by bare name —
  extend by path.

## Testing Agent signals

`Agent.goal_changed` fires only when the goal actually changes
(`_replace_plan`); `plan_changed` and `action_changed` always fire. A spy
test expecting `goal_changed` on every plan replacement is a false negative
by design.

## Test file shape

- One file per production concern, in `prototype/tests/unit/`.
- The file exposes `run(harness)`; `harness.check(cond, msg)` and
  `harness.check_equal(actual, expected, msg)` record assertions.
- Register the class in `prototype/tests/run_tests.gd` (explicit registration
  keeps the run order predictable).
- Test doubles are `RefCounted` — do **not** call `.free()` on them.

## Determinism

- Never rely on unseeded randomness: the game uses `randf()` for dodge/crit.
  Seed an `RandomNumberGenerator` explicitly (`rng.seed = <fixed>`) in tests.
- Loops that wait on game behavior must be **bounded** (tick guards). A
  regression should fail a test, never hang the suite.

## Boot smoke test

`tests/smoke/smoke_runner.gd` boots the real game through the debug harness
(`tests/debug_map.gd --smoke`, on the real three-lane map) and asserts
behavioral invariants (units spawn, the simulation moves, nothing crashes).
Extend it when adding systems that should be verified end-to-end — keep
assertions behavioral (what the game does), not structural (what the scene
tree contains).

## Bug protocol

1. Found a bug? Write the failing test that proves it.
2. Fix production so the test passes — or, if the fix is deferred, record the
   bug in `COVERAGE.md` "Known bugs" with a reference to the documenting test.
3. Never delete or weaken a test to make a failure go away.
