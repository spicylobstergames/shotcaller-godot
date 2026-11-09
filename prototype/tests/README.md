# Testing Conventions

How to write tests for this project. Read this before adding test files.

## Running the suite

```
./prototype/tests/run_suite.sh          # full verification (unit + boot smoke + error budget)
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
(`tests/test_map/test.gd --smoke`) and asserts behavioral invariants (units
spawn, the simulation moves, nothing crashes). Extend it when adding systems
that should be verified end-to-end — keep assertions behavioral (what the game
does), not structural (what the scene tree contains).

## Bug protocol

1. Found a bug? Write the failing test that proves it.
2. Fix production so the test passes — or, if the fix is deferred, record the
   bug in `COVERAGE.md` "Known bugs" with a reference to the documenting test.
3. Never delete or weaken a test to make a failure go away.
