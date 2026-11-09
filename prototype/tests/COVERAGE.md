# Test Coverage

**20 test classes**, **175 assertions**, **0 script errors** — all passing.

```
./prototype/tests/run_suite.sh
→ [1/2] TESTS_COMPLETE: passed=175 failed=0
→ [1/2] All 175 tests passed.
→ [2/2] SMOKE_RESULT: frames=300 units=127 leaders=1 moved=3 pathed_moved=2
→ SUITE GREEN: unit tests passed, boot smoke passed, zero script errors
```

## The suite has two layers

### 1. Unit + integration suite (`res://tests/test_runner.tscn`, ~1s)

Fast, deterministic checks against production classes. Mocks are only ever
used for Godot nodes/autoloads — never for game logic.

### 2. Boot smoke test (`tests/smoke/smoke_runner.gd`, ~5s)

Boots the **real game** (`game.tscn`) headless via the existing debug harness,
runs 300 simulation ticks, and asserts the game actually plays:
units spawn, at least one unit moves, nothing is freed mid-run.
Run it directly with:

```
godot --headless --path prototype res://game.tscn -- --smoke --smoke-ticks=300
```

### The script-error budget

`run_suite.sh` fails on **any** `SCRIPT ERROR` line in either run's output —
even when all assertions pass. Script errors can silently swallow assertions
(a failing expression aborts the statement containing it), so a
"passing" suite with script errors is lying. The budget makes that impossible
to miss.

### Tamper-evidence

The runner cannot silently pass:
- `run_tests.gd` must emit `TESTS_COMPLETE: passed=N failed=0`, and `N` must
  equal `EXPECTED_UNIT_TESTS` **pinned in run_suite.sh** (a different file).
  A crashed, hung, or bypassed runner cannot fake green without editing both.
- Both Godot invocations run under a per-step timeout — a hung runner fails
  instead of hanging CI.
- The boot smoke asserts behavior (units exist, pathed units move), so a
  broken simulation fails even with zero assertion errors.

Verified by sabotage (each experiment run, then reverted):
| Sabotage | Caught by |
|----------|-----------|
| Fake success token, zero tests executed | Token/count pin in run_suite.sh |
| Parse error appended to a production .gd | Script-error budget + parse smoke |
| `MoveAction.calc_step` disabled (live movement path) | Smoke: "No unit moved" |
| Runtime script error injected in `Unit.gd._ready` | Script-error budget |

## Test classes

| Test File | Coverage Target | Kind |
|-----------|----------------|------|
| `test_script_parse.gd` | Every `.gd` file compiles | Smoke |
| `test_scene_instantiate.gd` | Every `.tscn` loads + instantiates | Smoke |
| `test_goap_integration.gd` | Real `Agent`: goal selection, signal wiring, plan lifecycle | Integration |
| `test_action_lifecycles.gd` | Plan execution via TestAgent (real `_replace_plan`/`_follow_plan` paths) | Unit |
| `test_goal_interactions.gd` | Goal contracts via real `Agent._get_best_goal()` | Unit |
| `test_modifiers.gd` | `skills/modifiers.gd` public methods | Unit |
| `test_passive_skills.gd` | `skills/passive_skills.gd` hit_modifiers, get_value | Unit |
| `test_spawns.gd` | `map/spawns.gd` camp_hire, cemetery, lane tactics | Unit |
| `test_mirror_tiles.gd` | `map/tool/mirror_tiles.gd` — real `_get_mirrored_coords`/`_get_changed_cells` | Unit |
| `test_planner.gd` | GOAP planner | Unit |
| `test_arrive_at_destination.gd` | Arrival goal lifecycle | Unit |
| `test_attack_priorities.gd` | ChooseTarget priorities | Unit |
| `test_agent_signals.gd` | Agent signal wiring | Unit |
| `test_agent_target.gd` | Target selection | Unit |
| `test_agent_tactic.gd` | Tactic speed bonuses | Unit |
| `test_collisions.gd` | Quadtree + geometry helpers | Unit |
| `test_movement.gd` | Physics movement step | Unit |
| `test_navigation.gd` | Pathfinding + navigation | Unit |
| `test_order_action.gd` | Order completion flow | Unit |
| `test_orders_panel_signal.gd` | Orders panel signals | Unit |

## Rules for new tests (see also tests/README.md)

1. Tests must **fail when production behavior breaks** — never assert what a
   mock does. Before merging a new test, break the production line it guards
   once and watch the test fail.
2. Every bug fix ships with a regression test.
3. The suite must stay green **with zero script errors**. Script errors fail
   CI even when assertions pass.

## Known bugs

None currently outstanding. (The camp_hire collective-check / per-leader
deduction mismatch was fixed this phase: affordability is pooled team gold and
the cost is split evenly across leaders, matching the lumberjack_hire
convention. Regression-tested in `test_spawns.gd`.)

## Known coverage limits

- `Unit.advance_with_navigation` is dormant in the default config
  (`Goap.use_native_pathfinding = false`); the smoke test exercises the live
  movement path (MoveAction) instead. If native pathfinding is enabled, add
  smoke coverage for it.
- The headless smoke boots a slightly divergent UI path: minimap skips its
  viewport snapshot (no frames are drawn headless). UI-only tail code is
  therefore not exercised headless.

## Remaining high-priority gaps

1. Golden-replay test: seed the RNG, run N frames, hash game state, compare
   against a stored snapshot (catches silent behavior changes).
2. GOAP `Agent.process()` orchestration test (goal selection → planner →
   action execution, via the real planner).
3. Combat resolution coverage (dodge/crit/counter paths in `hit_modifiers`).
4. Economy coverage beyond camp_hire (lumber, taxes).
5. Per-action simulation checks: each of the 19 registered actions can be
   planned and executed inside the boot smoke scenario.
6. Shared helper extraction (Phase 1): mock units, WorldState
   snapshot/restore, seeded RNG are still duplicated across test files.
