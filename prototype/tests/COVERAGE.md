# Test Coverage

**8 test classes**, **93 assertions**, **0 script errors** — all passing.

```
./prototype/tests/run_suite.sh
→ [1/2] TESTS_COMPLETE: passed=93 failed=0
→ [1/2] All 93 tests passed.
→ [2/2] SMOKE_RESULT: frames=300 units=127 leaders=1 moved=1 pathed_moved=1
→ SUITE GREEN: unit tests, boot smoke, zero script errors (golden replay deferred — see COVERAGE.md)
```

## Deferred coverage (GOAP suites + golden replay)

This suite is a **port of the CI-verified test suite onto the post-restructure
upstream main** (GOAP refactor: `Orders` removed, `ChooseTarget`/`ChooseTactics`
split, global `Navigation`, `wait_out` removed). The upstream restructure was
still in flight at port time (multiple breaking commits within days), so the
GOAP-coupled suites are **deferred, not deleted**: they live on the PR branch
(`spicylobstergames#231`) and the fork's `test-*` branches, and come back once
the GOAP API settles.

Deferred:

- `test_planner.gd`, `test_planner_real_actions.gd` — planner contract
- `test_agent_signals.gd`, `test_agent_target.gd`, `test_agent_tactic.gd` — agent wiring
- `test_action_lifecycles.gd`, `test_goal_interactions.gd`, `test_goap_integration.gd` — plan/goal lifecycle
- `test_movement.gd`, `test_navigation.gd`, `test_arrive_at_destination.gd` — movement/pathing
- `test_order_action.gd`, `test_orders_panel_signal.gd` — orders (Orders class was removed upstream)
- `test_attack_priorities.gd` — ChooseTarget priorities
- **Golden replay** — the recorded checkpoints pin pre-restructure behavior;
  they must be re-recorded (`--golden-update`) together with the deferred
  suites, not ported as-is.

Re-entry criteria: upstream main stops breaking the GOAP action/goal contract
across consecutive merges; then port one deferred suite at a time, re-pointing
each at the current API (`Goap.get_action`, per-agent goal wiring, `Unit.take_hit`),
and re-record the golden replay.

## The suite has two layers

### 1. Unit + integration suite (`res://tests/test_runner.tscn`, ~1s)

Fast, deterministic checks against production classes. Mocks are only ever
used for Godot nodes/autoloads — never for game logic.

### 2. Boot smoke test (`tests/smoke/smoke_runner.gd`, ~5s)

Boots the **real game** (`game.tscn`) headless via the existing debug harness
(`tests/debug_map.gd`), on the real three-lane map, runs 300 simulation ticks,
and asserts the game actually plays: units spawn, at least one unit moves,
nothing is freed mid-run. The debug scenario spawns the leader and test pawn
far apart on purpose, so the AI has to move (pursue or lane-walk) to engage.
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

The runner cannot *accidentally* produce a green result:
- `run_tests.gd` must emit `TESTS_COMPLETE: passed=N failed=0`, and `N` must
  equal `EXPECTED_UNIT_TESTS` **pinned in run_suite.sh** (a different file).
  A crashed, hung, or accidentally-bypassed runner fails loudly, as does
  accidental test-count drift.
- Both Godot invocations run under a per-step timeout — a hung runner fails
  instead of hanging CI.
- The boot smoke asserts behavior (units exist, something moves, nothing is
  freed mid-run), so a broken simulation fails even with zero assertion errors.

Honest limit: a *deliberate* forger can edit the reporter itself to print a
fake token — self-reporting cannot exclude that, only make it conscious
(the pin is in a second file, so drift/bypass is caught, not forgery).

## Test classes

| Test File | Coverage Target | Kind |
|-----------|----------------|------|
| `test_script_parse.gd` | Every `.gd` file compiles | Smoke |
| `test_scene_instantiate.gd` | Every `.tscn` loads + instantiates | Smoke |
| `test_helpers.gd` | Shared helpers are load-bearing (snapshot/mock-goal self-tests) | Unit |
| `test_modifiers.gd` | `skills/modifiers.gd` public methods (null-safe lookups) | Unit |
| `test_passive_skills.gd` | `hit_modifiers` combat resolution (dodge/stun/crit/cleave/pierce/bleed/agile/counter, deterministic via skill injection) + get_value | Unit |
| `test_spawns.gd` | `map/spawns.gd` camp_hire pooled-gold semantics, cemetery, lane tactics | Unit |
| `test_mirror_tiles.gd` | `map/tool/mirror_tiles.gd` — real `_get_mirrored_coords`/`_get_changed_cells` | Unit |
| `test_collisions.gd` | Quadtree + geometry helpers | Unit |

## Rules for new tests (see also tests/README.md)

1. Tests must **fail when production behavior breaks** — never assert what a
   mock does. Before merging a new test, break the production line it guards
   once and watch the test fail.
2. Every bug fix ships with a regression test.
3. The suite must stay green **with zero script errors**. Script errors fail
   CI even when assertions pass.

## Known bugs

Fixed in this port (each regression-tested):
- `spawns.gd camp_hire`: no affordability gate + full per-leader deduction →
  now pooled check + even split (lumberjack_hire convention); gold-less leader
  nodes are skipped instead of crashing.
- `passive_skills.gd`: missing/null leader-table entries crashed `get_value`
  and `hit_modifiers` → now null-safe (`leader.get(name, {})`).
- `passive_skills.gd hit_modifiers`: the rebuilt modifiers dict reset
  `counter` to `true`, silently disabling stun/critical/cleave/pierce/bleed
  for callers passing `counter=false` (including the counter branch itself) →
  the caller's flag is now preserved.
- `modifiers.gd get_value/get_velocity`: crashed on units without the queried
  property, unknown modifier names, or a missing agent → null-safe with a
  warning on unknown names.
- `ui/minimap.gd`: headless runs stalled forever awaiting
  `RenderingServer.frame_post_draw` (no frames are drawn headless), blocking
  the map-ready chain before any unit spawned → headless mode short-circuits
  to `map_loaded`. Upstream #231 needed this too.

Deferred with the GOAP suites (recorded on the PR branch, obsolete upstream):
- `get_lumber.gd` / `wait_out.gd` null-return bug: `wait_out.gd` was deleted
  in the restructure; re-check `get_lumber.gd` (or its successor) when the
  GOAP suites return.

DOCUMENTED QUIRKS (not fixed, pinned by tests so a fix flips them
deliberately):
- An empty skill dict in the `Skills.leader` table makes `hit_modifiers`
  return null — a latent caller crash.
  Pinned by `test_passive_skills.gd _test_empty_skill_dict_returns_null`
  (production .tres data never produces empty dicts).
- `lumberjack_hire` has no affordability gate — a 0-gold leader is driven
  negative. Pinned by
  `test_spawns.gd _test_lumberjack_hire_has_no_affordability_gate`; adding
  the missing gate is a deliberate design change that must flip this test.

## Known coverage limits

- The headless smoke boots a slightly divergent UI path: minimap skips its
  viewport snapshot (no frames are drawn headless). UI-only tail code is
  therefore not exercised headless.
- `addons/` (including `addons/gui`) is excluded from both whole-project
  smoke tests: third-party code, not ours to gate.
- `spawns.gd` floor-split payment can leave a remainder unpaid (cost 3 across
  2 leaders deducts 2 total). Accepted deliberately — identical to the
  pre-existing `lumberjack_hire` convention; the pooled check still gates
  every hire.
- Lane-path movement (WalkLane) is not asserted by the boot smoke: units that
  see an enemy go straight to PursueEnemy/AttackEnemy and may never hold a
  lane path. That coverage belongs to the deferred GOAP movement suite.
- Sabotage verification (breaking a production line and watching the suite
  fail) was performed on the pre-port suite; the ported assertions carry the
  same structure but have not all been re-sabotaged individually.

## Remaining high-priority gaps

1. **Re-introduce the deferred GOAP suites** (see top of this file) once
   upstream's GOAP API settles.
2. Re-record the golden replay on the settled base.
3. Economy coverage beyond camp_hire (lumber, taxes).
4. Per-action simulation checks: each registered action can be planned and
   executed inside the boot smoke scenario.
