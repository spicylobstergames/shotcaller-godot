# Test Coverage

**20 test classes**, **171 assertions**, **0 script errors** — all passing.

```
./prototype/tests/run_suite.sh
→ [1/2] All 171 tests passed.
→ [2/2] SMOKE_RESULT: ticks=300 units=127 leaders=1 moved=3
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

## Known bugs (documented by tests, not yet fixed)

- `spawns.gd camp_hire()`: the affordability check sums gold across all team
  leaders (collective), but the deduction charges the full cost to *each*
  leader (individual) — two leaders with 2 gold each pass a 3-gold check and
  both end at −1. See `test_spawns.gd _test_camp_hire_gold_deduction_semantics`.

## Remaining high-priority gaps

1. Golden-replay test: seed the RNG, run N ticks, hash game state, compare
   against a stored snapshot (catches silent behavior changes).
2. GOAP `Agent.process()` orchestration test (goal selection → planner →
   action execution, via the real planner).
3. Combat resolution coverage (dodge/crit/counter paths in `hit_modifiers`).
4. Economy coverage beyond camp_hire (lumber, taxes).
5. Per-action simulation checks: each of the 19 registered actions can be
   planned and executed inside the boot smoke scenario.
