# Test Coverage

**20 test classes**, **255 assertions**, **0 script errors** — all passing.

```
./tests/run_suite.sh
→ [1/3] TESTS_COMPLETE: passed=255 failed=0
→ [1/3] All 255 tests passed.
→ [2/3] SMOKE_RESULT: frames=300 units=127 leaders=1 moved=1 pathed_moved=1
→ [3/3] GOLDEN_OK: 3 checkpoints identical
→ SUITE GREEN: unit tests, boot smoke, golden replay, zero script errors
```

## Port status (post-restructure)

The full CI-verified suite has been ported onto upstream main after the GOAP
restructure (`Orders` panel removed, `ChooseTarget`/`ChooseTactics` split,
global `Navigation`, `wait_out` deleted, contract defaults flipped). Every
suite was re-pointed at the current API; two removed subsystems were
re-targeted to their successors; the golden replay was re-recorded. See
DECISIONS.md D12 for the port decisions and COVERAGE "Known bugs" for the
production regressions the port caught.

## The suite has three layers

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
godot --headless --path . res://game.tscn -- --smoke --smoke-ticks=300
```

### 3. Golden replay (tests/golden/)

A **deterministic checkpointed end-state check** of the real game — NOT a
per-frame replay. Seeded RNG (`seed(20240101)`) + `--fixed-fps 60` + skipping
`game.rng.randomize()` (`--golden`) make 300 simulation frames reproducible;
the runner serializes game state at frames 100/200/300 and compares against
the committed snapshot (`tests/golden/replay_300.txt`).

The committed snapshot was **re-recorded on the post-restructure base** — the
pre-restructure checkpoints pinned deleted behavior (DECISIONS.md D11/D12).
If it fails: fix the regression, or — if the behavior change is intended —
re-record with `--golden-update` and say why in the commit.

### The script-error budget

`run_suite.sh` fails on **any** `SCRIPT ERROR` line in any run's output —
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
- All Godot invocations run under a per-step timeout — a hung runner fails
  instead of hanging CI.
- The boot smoke asserts behavior (units exist, something moves, nothing is
  freed mid-run), and the golden replay pins the full game state, so a
  broken simulation fails even with zero assertion errors.

Honest limit: a *deliberate* forger can edit the reporter itself to print a
fake token — self-reporting cannot exclude that, only make it conscious
(the pin is in a second file, so drift/bypass is caught, not forgery).

## Test classes

| Test File | Coverage Target | Kind |
|-----------|----------------|------|
| `test_script_parse.gd` | Every `.gd` file compiles | Smoke |
| `test_scene_instantiate.gd` | Every `.tscn` loads + instantiates | Smoke |
| `test_helpers.gd` | Shared helpers are load-bearing (snapshot/mock-goal self-tests) | Unit |
| `test_planner.gd` | Planner mechanics (cost ordering, precondition chains, dead ends) via contract doubles | Unit |
| `test_planner_real_actions.gd` | Planner + real 19-action registry + real goals (contract drift) | Integration |
| `test_agent_signals.gd` | Real `Agent`: goal/plan/action signal wiring and lifecycle | Unit |
| `test_agent_target.gd` | ChooseTarget.set_target sync (unit target, hunting, attack-count reset, modifier cleanup) | Unit |
| `test_agent_tactic.gd` | Tactic speed bonuses + Recover.should_retreat thresholds | Unit |
| `test_action_lifecycles.gd` | Action lifecycle semantics through the REAL Agent (plan replacement, signal-driven entry, multi-tick completion) | Unit |
| `test_goal_interactions.gd` | Goal selection contract: tie-breaking, no-valid-goals, is_valid side effects, priority changes | Unit |
| `test_goap_integration.gd` | Real Agent + real planner path: goal selection → plan install → follow → completion | Integration |
| `test_modifiers.gd` | `skills/modifiers.gd` public methods (null-safe lookups) | Unit |
| `test_passive_skills.gd` | `hit_modifiers` combat resolution (dodge/stun/crit/cleave/pierce/bleed/agile/counter, deterministic via skill injection) + get_value | Unit |
| `test_spawns.gd` | `map/spawns.gd` camp_hire pooled-gold semantics, cemetery, lane tactics | Unit |
| `test_mirror_tiles.gd` | `map/tool/mirror_tiles.gd` — real `_get_mirrored_coords`/`_get_changed_cells` | Unit |
| `test_collisions.gd` | Quadtree + geometry helpers | Unit |
| `test_movement.gd` | MoveAction.step clamping, move() gates (moves/is_stunned), soft-repulsion blocking | Unit |
| `test_navigation.gd` | Jump-point pathfinder (routes, walls, sealed maps) + NavigateAction→Navigation dispatch | Unit |
| `test_arrive_at_destination.gd` | Arrival goal contract (PINNED: self-activation disabled; see Known bugs) | Unit |
| `test_order_action.gd` | OrderAction completion/cancellation semantics | Unit |
| `test_attack_priorities.gd` | ChooseTarget proximity targeting (can_hit filter, closest wins, range checks) | Unit |
| `test_attack_lifecycle.gd` | Post-kill replan (no empty-plan freeze), AttackEnemy dead-branch fact cleanup, ranged hit direction (victim, not shooter), corpse-target release, untargetable-enemy goal refusal, pursuit stepping, lane-route resume from nearest waypoint, stale walking-fact reset, FriendsSafe stale fact | Unit |
| `test_sight_radius.gd` | Sight is distance-filtered (no phantom targets beyond vision) | Unit |

*(golden replay — snapshot file, not a test class; see section above)*

## Rules for new tests (see also tests/README.md)

1. Tests must **fail when production behavior breaks** — never assert what a
   mock does. Before merging a new test, break the production line it guards
   once and watch the test fail.
2. Every bug fix ships with a regression test.
3. The suite must stay green **with zero script errors**. Script errors fail
   CI even when assertions pass.

## Known bugs

Production regressions found by the port and FIXED (each regression-tested):
- `action_contract.is_valid` default was flipped to `false` in the
  restructure, silently unplanning every action without an override — NINE
  production actions (melee_attack, range_attack, hide, taxes, mine, prayer,
  help_friend, return_lumber, conquer) were dead in the planner. Restored
  the documented default (`true`); ChooseTarget remains the documented
  always-false exception via its own override.
- `get_lumber.is_valid` returned null for an unset `is_game_active` key
  (typed `-> bool` null-return, the same bug class the old suite documented
  for `wait_out`); the script error aborted the planner's action loop
  mid-search and broke Recover/NeedSafety planning. Now
  `get_state(key, false)`.
- `spawns.gd camp_hire`: no affordability gate + full per-leader deduction →
  now pooled check + even split (lumberjack_hire convention); gold-less
  leader nodes are skipped instead of crashing.
- `passive_skills.gd`: null-safe leader-table lookups (missing entries
  crashed `get_value`/`hit_modifiers`) and the caller's `counter` flag is
  preserved — resetting it to `true` silently disabled stun/critical/
  cleave/pierce/bleed for `counter=false` callers, including the counter
  branch itself.
- `modifiers.gd get_value/get_velocity`: crashed on units without the
  queried property, unknown modifier names (warned), or a missing agent.
- `ui/minimap.gd`: headless runs stalled forever awaiting
  `RenderingServer.frame_post_draw` (no frames are drawn headless), blocking
  the map-ready chain before any unit spawned → headless mode short-circuits
  to `map_loaded`.
- **Stale-fact planning freeze** (found by live debugging, FIXED): a kill
  recorded by `AttackEnemy.perform` left `enemy_dead: true` in agent state
  with no cleanup on any reachable path (`ChooseTarget.set_target` only
  resets it when a NEW target is set, which can never be planned while the
  fact is stale). `planner._build_plans` treats agent state as already
  satisfied, so the goal's desired state was met with an EMPTY plan;
  `Agent.goap_process` only replans when the goal CHANGES, so the agent held
  `EnemyDefeated` with no actions forever — units stood idle mid-fight and
  buildings froze after their first kill. The dead branch also left
  `enemy_in_attack_range: true` stale, which alone degraded the next plan to
  a bare `[AttackEnemy]` with no target acquisition. Fixed at the documented
  lifecycle points: `EnemyDefeated.is_valid` resets `enemy_dead` every frame
  the goal is valid (as `docs/ai/world-state.md` always claimed), and
  `AttackEnemy`'s dead branches clear `enemy_in_attack_range`. Regression:
  `test_attack_lifecycle.gd` (drives a kill through the real `perform()`,
  then re-plans through the real agent + planner).
- **Inverted ranged hit** (found by live debugging, FIXED, inherited from
  upstream prototype code — oldest commit b0b19c6 already had it):
  `RangeAttack.projectile_loop` called `unit1.take_hit(projectile.target, ...)`
  on the SHOOTER (melee does `unit.target.take_hit(unit)`). Ranged units —
  including every attacking building — damaged themselves per shot and never
  killed the target, so `AttackEnemy` never reached its dead branch and
  buildings sat in `state=attack` until they died to their own shots; the
  misdirected `attacker` also made `projectile_stuck` erase from the
  victim's projectile list, leaking the shooter's in-flight entries forever.
  Fixed to `projectile.target.take_hit(unit1, projectile)` (and the pierce
  branch likewise). Regression: `test_attack_lifecycle.gd` (projectile hit
  direction).
- **Phantom sight** (found by live debugging, FIXED after the stale-fact
  freeze): `Quadtree._get_bodies_in_radius` has no per-body distance test in
  leaf cells — any quadrant the query circle merely overlaps contributes ALL
  of its bodies (sparse areas never split, so early-game cells span hundreds
  of pixels). `Unit.get_units_in_sight` treated the result as authoritative:
  live-measured sight lists contained enemies 300–500px away (vision 280)
  and 735px away (vision 140). After the stale-fact freeze was fixed, this
  became the remaining "stuck after killing" symptom — the killer
  immediately re-acquired a phantom target it could never reach and stood
  locked on it. Fixed at the sight layer: `get_units_in_sight` enforces the
  real vision radius; raw radius queries keep their coarse semantics (every
  other consumer — cleave, pierce, soft-repulsion — re-checks real distance
  on candidates). Regression: `test_sight_radius.gd`.
- **Corpse target hold** (found by live debugging, FIXED): `unit.target` was
  never released when the attack action did not run again after the kill —
  `goap_process` re-selects the goal BEFORE `AttackEnemy.perform` sees the
  corpse, so a goal switch or the target dying later left the reference
  held; the truthy `unit.target` then blocked `WalkLane.is_valid` and
  `ChooseTarget.is_valid` and the unit idled at `goal=null` forever.
  `EnemyDefeated.is_valid` now releases dead/invalid targets during its
  per-frame fact maintenance. Regression: `test_attack_lifecycle.gd`.
- **Untargetable-enemy goal hijack** (found by live debugging, FIXED):
  `EnemyDefeated.is_valid` counted any enemy-shaped unit in sight, but
  churches (`immune = true`) and other immune units can never be hit by
  `ChooseTarget.can_hit`. The priority-6 combat goal therefore permanently
  outranked WalkLane (priority 2) whenever an immune unit — a church on the
  lane — was within vision, and the agent churned plans that never selected
  a target: the unit stood frozen beside the church. The goal now requires
  an actually targetable enemy (`select_target != null`). Regression:
  `test_attack_lifecycle.gd`.
- **Lane route lost after combat** (found by live debugging, FIXED): combat
  navigation (`PursueEnemy` → `Navigate.move` → `follow_path`) overwrites
  `unit.current_path` with a tile path between arbitrary fight points, and
  `WalkLane.enter` kept whatever path was already there — so post-kill units
  "walked their lane" toward wherever the fight happened, or (with an
  unpolluted path) backtracked all the way to the lane's first waypoint
  before proceeding. `WalkLane.enter` now re-derives the route from the lane
  definition and cuts it to the NEAREST waypoint (the same resume semantics
  `MoveAction.teleport`'s `resume_lane` already used), so units return to
  their own lane and continue it forward. Regression:
  `test_attack_lifecycle.gd`.
- **WalkLane frozen on stale walking facts** (found by live debugging,
  FIXED): `has_destiny` is set by `follow_path` and never cleared, so after
  any pursuit or route segment the planner skips Navigate in WalkLane plans
  (`[Move]` alone); and `arrived_at_destination` — documented as "set to
  false when a new path is queued or the goal re-evaluates" — was set true
  by `on_arrive` with an emptied path and never reset. The post-combat
  WalkLane plan then had `Move.perform` return false forever: the unit froze
  at `goal=WalkLane action=Move` with a fresh path it never followed.
  `WalkLane.enter` now re-derives the route AND kicks `Navigate.enter`
  directly (resetting the stale arrived fact and popping the route into
  `current_destiny` + stepping), since the planner runs before goal.enter.
  Regression: `test_attack_lifecycle.gd`.
- **FriendsSafe stale fact** (same class, FIXED preventively): HelpFriend
  writes `friends_safe=true` on completion and only the goal's enter()
  cleared it — but the planner runs BEFORE enter, so the next "ally
  attacked" evaluation saw the desired state as already satisfied and
  planned nothing (unit frozen mid-fight). `FriendsSafe.is_valid` now resets
  the fact while the goal is valid. Regression: `test_attack_lifecycle.gd`.
- **Motionless pursuit** (found by live debugging, FIXED, inherited from
  upstream): pursuit plans (`[ChooseTarget, PursueEnemy, AttackEnemy]`)
  contain no Move action, and only `state == "move"` units are stepped by
  `Collisions` — `Navigate.follow_path` set `current_destiny` without
  setting the state, so a unit with a live target out of attack range stood
  still forever "pursuing" it (the golden replay's leader stood at its spawn
  point for 100 frames). `follow_path` now hands each waypoint to
  `Move.move`, the established stepping driver; waypoint progression still
  flows through the existing `ArriveAtDestination.on_arrive` →
  `Navigate.next` machinery. Regression: `test_attack_lifecycle.gd`.

DOCUMENTED QUIRKS (pinned, not fixed — a fix must flip the pinning test
deliberately):
- `arrive_at_destination.gd is_valid()` hard-returns `false` (activation
  logic commented out in the restructure). Arrival works only because
  `Collisions` calls `is_at_destination`/`on_arrive` directly. Pinned by
  `test_arrive_at_destination.gd`; flag for upstream — if the commented-out
  activation is restored, this test flips with it. Note: `recover.gd
  on_arrive` passes the AGENT into `on_arrive(unit)` — inconsistent with
  `collisions.gd`, which passes the unit.
- An empty skill dict in the `Skills.leader` table makes `hit_modifiers`
  return null — a latent caller crash. Pinned by
  `test_passive_skills.gd _test_empty_skill_dict_returns_null`
  (production .tres data never produces empty dicts).
- `lumberjack_hire` has no affordability gate — a 0-gold leader is driven
  negative. Pinned by
  `test_spawns.gd _test_lumberjack_hire_has_no_affordability_gate`.

## Known coverage limits

- The headless smoke boots a slightly divergent UI path: minimap skips its
  viewport snapshot (no frames are drawn headless). UI-only tail code is
  therefore not exercised headless.
- The orders/tactics panel's button UI is not unit-tested in isolation: the
  full build (`build_leaders` → tactics buttons) only works inside the live
  game scene. The integration path (map_loaded → setup_leaders →
  build_leaders → leaders_built) IS exercised by every boot-smoke run with
  zero script errors.
- `addons/` (including `addons/gui`) is excluded from the whole-project
  smoke tests: third-party code, not ours to gate.
- `spawns.gd` floor-split payment can leave a remainder unpaid (cost 3 across
  2 leaders deducts 2 total). Accepted deliberately — identical to the
  pre-existing `lumberjack_hire` convention; the pooled check still gates
  every hire.
- Sabotage verification (breaking a production line and watching the suite
  fail) was performed on the pre-port suite; the ported assertions carry the
  same structure but have not all been re-sabotaged individually.

## Remaining high-priority gaps

1. Per-action simulation checks: each registered action can be planned and
   executed inside the boot smoke scenario.
2. Economy coverage beyond camp_hire (lumber, taxes).
3. Re-sabotage the ported planner/agent assertions against the new base.
