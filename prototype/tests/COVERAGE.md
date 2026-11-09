# Test Coverage

**23 test classes**, **234 assertions**, **0 script errors** — all passing.

```
./prototype/tests/run_suite.sh
→ [1/3] TESTS_COMPLETE: passed=234 failed=0
→ [1/3] All 234 tests passed.
→ [2/3] SMOKE_RESULT: frames=300 units=127 leaders=1 moved=3 pathed_moved=2
→ [3/3] GOLDEN_OK: 132 state lines identical
→ SUITE GREEN: unit tests, boot smoke, golden replay, zero script errors
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

### Golden replay (tests/golden/)

The third suite layer: a **deterministic checkpointed end-state check** of
the real game — NOT a per-frame replay. Seeded RNG (`seed(20240101)`) +
`--fixed-fps 60` + skipping `game.rng.randomize()` (`--golden`) make 300
simulation frames reproducible; the runner serializes game state at frames
100/200/300 (checkpointed, so mid-run divergence is caught even if it
converges later) and compares against the committed snapshot
(`tests/golden/replay_300.txt`).

Robustness: generated node names (`@StaticBody2D@83`) are normalized
(counter dropped), positions compared with a 0.5 tolerance and other
numerics 1.0 — platform float drift must not read as a gameplay regression.
Caught by sabotage: halving movement speed passes all 234 assertions and the
smoke test but fails golden at checkpoint 1.

If a golden failure is an INTENDED behavior change: re-record with
`--golden-update` and state why in the commit (DECISIONS.md D6). Determinism
strategy: DECISIONS.md D5, D10. Platform note: snapshot recorded on Linux
x86_64; other platforms may need their own re-record.

### The script-error budget

`run_suite.sh` fails on **any** `SCRIPT ERROR` line in either run's output —
even when all assertions pass. Script errors can silently swallow assertions
(a failing expression aborts the statement containing it), so a
"passing" suite with script errors is lying. The budget makes that impossible
to miss.

### Tamper-evidence

The runner cannot *accidentally* produce a green result:
- `run_tests.gd` must emit `TESTS_COMPLETE: passed=N failed=0`, and `N` must
  equal `EXPECTED_UNIT_TESTS` **pinned in run_suite.sh** (a different file).
  A crashed, hung, or accidentally-bypassed runner fails loudly, as does
  accidental test-count drift.
- Both Godot invocations run under a per-step timeout — a hung runner fails
  instead of hanging CI.
- The boot smoke asserts behavior (units exist, pathed units move), so a
  broken simulation fails even with zero assertion errors.

Honest limit: a *deliberate* forger can edit the reporter itself to print a
fake token — self-reporting cannot exclude that, only make it conscious
(the pin is in a second file, so drift/bypass is caught, not forgery).

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
| *(golden replay — snapshot file, not a test class; see section below)* | 300-frame deterministic end-state checkpoints (`tests/golden/replay_300.txt`) | Golden |
| `test_scene_instantiate.gd` | Every `.tscn` loads + instantiates | Smoke |
| `test_goap_integration.gd` | Real `Agent`: goal selection, signal wiring, plan lifecycle | Integration |
| `test_planner_real_actions.gd` | Planner + real 19-action registry + real goals (contract drift) | Integration |

| `test_helpers.gd` | Shared helpers are load-bearing (snapshot/mock-goal self-tests) | Unit |
| `test_action_lifecycles.gd` | Plan execution via TestAgent (real `_replace_plan`/`_follow_plan` paths) | Unit |
| `test_goal_interactions.gd` | Goal contracts via real `Agent._get_best_goal()` | Unit |
| `test_modifiers.gd` | `skills/modifiers.gd` public methods | Unit |
| `test_passive_skills.gd` | `hit_modifiers` combat resolution (dodge/stun/crit/cleave/pierce/bleed/agile/counter, deterministic via skill injection) + get_value | Unit |
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

None currently outstanding. Fixed during test development (each regression-
tested):
- `spawns.gd camp_hire`: collective-check / per-leader-deduction mismatch →
  now pooled check + even split (lumberjack_hire convention).
- `spawns.gd camp_hire`: 2-arg `Node.get("gold", 0)` crash on Godot 4.
- `get_lumber.gd` / `wait_out.gd`: `is_valid() -> bool` returned null when
  `is_game_active` was never set — typed-bool violation; defaults to false.
- DOCUMENTED QUIRK (not fixed): an empty skill dict in the `Skills.leader`
  table makes `hit_modifiers` return null — a latent caller crash. Pinned by
  `test_passive_skills.gd _test_empty_skill_dict_returns_null` (production
  .tres data never produces empty dicts).
- DOCUMENTED QUIRK (not fixed): `lumberjack_hire` has no affordability gate —
  a 0-gold leader is driven negative. Pinned by
  `test_spawns.gd _test_lumberjack_hire_has_no_affordability_gate`; adding
  the missing gate is a deliberate design change that must flip this test.

## Known coverage limits

- `Unit.advance_with_navigation` is dormant in the default config
  (`Goap.use_native_pathfinding = false`); the smoke test exercises the live
  movement path (MoveAction) instead. If native pathfinding is enabled, add
  smoke coverage for it.
- The headless smoke boots a slightly divergent UI path: minimap skips its
  viewport snapshot (no frames are drawn headless). UI-only tail code is
  therefore not exercised headless.
- `addons/` (including `addons/gui`) is excluded from both whole-project
  smoke tests: third-party code, not ours to gate.
- `spawns.gd` floor-split payment can leave a remainder unpaid (cost 3 across
  2 leaders deducts 2 total). Accepted deliberately — identical to the
  pre-existing `lumberjack_hire` convention; the pooled check still gates
  every hire.

## Sabotage-verified (Phase 2)

Disabling dodge flagging, zeroing counter damage, breaking the bleed cap,
breaking WaitOut's effects key, and breaking MoveAction's effects key each
turn the suite RED with the exact intended assertion.

## Remaining high-priority gaps

1. GOAP `Agent.process()` orchestration test (goal selection → planner →
   action execution, via the real planner).
3. Combat resolution coverage (dodge/crit/counter paths in `hit_modifiers`).
4. Economy coverage beyond camp_hire (lumber, taxes).
5. Per-action simulation checks: each of the 19 registered actions can be
   planned and executed inside the boot smoke scenario.
6. Shared helper extraction (Phase 1): mock units, WorldState
   snapshot/restore, seeded RNG are still duplicated across test files.
