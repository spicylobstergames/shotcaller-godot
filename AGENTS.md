# AGENTS.md — Instructions for Coding Agents

## Project context

- **Engine:** Godot 4.7, GDScript
- **Project root:** repo root (`project.godot` lives at the top level)
- **Main scene:** `res://game.tscn` (set in `project.godot`)
- **GOAP system:** `goap/`
- **Tests:** `tests/` (headless runner: `res://tests/test_runner.tscn`)
- **Run the test suite:**
  ```bash
  ./tests/run_suite.sh /path/to/godot     # everything (~45s)
  # Godot binary resolution: argument > GODOT env var > "godot" on PATH.
  # If the default log dir ($PROJECT_DIR/../.test-logs) is not writable
  # (sandboxed/CI checkouts), set TEST_LOG_DIR to a writable path.
  ```
- **GitHub Actions workflow:** `.github/workflows/tests.yml` — runs the suite on PRs and main pushes.

## Verifying

- `run_suite.sh` runs the unit suite, a 300-tick boot smoke of the real game
  (on the three-lane map), the golden replay, and a script-error budget.
- **Zero `SCRIPT ERROR` lines is part of green.** Script errors can silently
  swallow assertions (a failing expression aborts the statement containing
  it) — a "passing" suite with script errors is lying.
- `run_suite.sh` pins the expected assertion count (`EXPECTED_UNIT_TESTS`).
  Adding tests → bump it. The suite failing with "ran N tests, expected M"
  is the reminder.
- New test files must be registered in `tests/run_tests.gd` AND
  have `run()` called in the registry list — both, or the count pin will
  catch it.
- A **golden replay** (`tests/golden/`) checkpoints the real game's state at
  frames 100/200/300 of a deterministic run. If it fails, either fix the
  regression or — if the behavior change is intended — re-record with
  `--golden-update` and say why in the commit (DECISIONS.md D12).
- Test conventions: `tests/README.md`. Coverage map, known bugs,
  and pinned quirks: `tests/COVERAGE.md`.

## Architecture overview

The AI subsystem is a GOAP (Goal-Oriented Action Planning) system layered on top of an existing unit/behavior system. **GOAP decides; existing systems perform.**

Key files:

| File | Role |
|------|------|
| `goap/goap_system/goap.gd` | Global autoload singleton — owns the planner and both registries, exposing `get_action()`/`get_goal()`/`get_action_planner()`. Its `physics_process()` pump (called from `game.gd`) runs each unit's agent on a staggered cadence (every 7th physics tick). There are no `move`/`navigation` members. |
| `goap/goap_system/agent.gd` | Per-unit AI state machine — holds goals, current plan, current action, local state dictionary, and signal wiring to the unit. |
| `goap/goap_system/planner.gd` | Backward-search planner — generates action plans and selects the lowest-cost (depth-capped at 64, per-branch visited-state memo). **It does NOT detect contradictions**: preconditions are merged by assignment, so a conflicting fact silently overwrites an earlier requirement. Keep preconditions consistent with goals/ancestors by hand. |
| `goap/goap_system/action_contract.gd` | Base class for all GOAP actions. Methods: `is_valid()`, `get_cost()`, `get_preconditions()`, `get_effects()`, `enter()`, `perform()`, `exit()`. |
| `goap/goap_system/goal_contract.gd` | Base class for all GOAP goals. Methods: `is_valid()`, `priority()`, `get_desired_state()`, plus `enter()`/`exit()` (called by the agent on goal change; the planner ignores them). |
| `goap/game_logic/action_registry.gd` | Creates and stores all action instances (shared, singletons). |
| `goap/game_logic/goal_registry.gd` | Stores all goal instances by name. |
| `goap/game_logic/world_state.gd` | Global autoload for world-wide state (teams, units lists, map, etc.). |

### The decision loop

```
  Unit / World State
       |
       v
  Agent.goap_process(delta)  [pumped by Goap.physics_process from
                              game.gd:_physics_process; each unit on its
                              own staggered turn, ~8.6 Hz]
       |
       v
  _get_best_goal()  — evaluates all goals, picks highest priority valid one
       |
       v
  Goap.get_action_planner().get_plan(agent, goal)  — backward search
       |
       v
  _follow_plan()  — iterates through plan actions via perform()
       |
       v
  Existing Unit Systems  [movement, combat, animation, pathfinding]
```

### How integration works

GOAP actions do **not** reimplement movement or combat. Instead:

- **`MoveAction`** and **`NavigateAction`** drive the unit's movement system through `Goap.get_action("Move")` / `Goap.get_action("Navigate")` and the `Navigation` autoload. There is **no** `Goap.move` / `Goap.navigation` API.
- **`AttackEnemy`**, **`MeleeAttack`**, **`RangeAttack`** fire the unit's weapon/attack system.
- **`OrderAction`** processes player orders.
- The **agent** connects to unit signals (death, stun, idle, attack, animation) and translates them into state changes that the GOAP planner consumes. Movement arrival is **not** signal-dispatched: `Collisions` detects it in its single movement loop and calls `ArriveAtDestination.advance_path(unit)`, which latches the arrival facts (`arrived_at_destination`, `has_path`, `has_destiny`); actions drive their arrival effects from `perform()` by reading those facts. `MoveAction`/`NavigateAction` only *request* movement.

**Do not introduce a second implementation of unit movement or combat when an existing game system already provides it.** Reuse the established system through its intended interface.

### State facts

The planner uses string-keyed dictionaries for preconditions, effects, goals, and agent state. Spelling errors or incorrect assumptions silently break planning.

**Read `docs/ai/world-state.md`** before adding or modifying any state fact — it is the intended catalog of every key, its scope (agent vs. world), type, producer, consumer, and lifecycle. It **has drifted**, so verify any entry against the current code; `ARCHITECTURE.md` is the verified system map.

**Important rule:** A precondition of `false` is not satisfied by an unset state key. The agent state reads `null`, and `null != false` in GDScript. A fact must be explicitly set for it to be matched.

### State ownership rules

- **Agent-specific state** belongs in the agent's local dictionary (`agent.set_state(...)`).
- **World-wide state** belongs in the `WorldState` singleton.
- **Team-specific state** (player team, enemy team, team unit lists) belongs in `WorldState`.
- **Unit-specific mutable data** must never be stored in globally shared action objects. The action registry creates action instances once and shares them across all units.
- **Team-scoped mutable state in a shared action is the documented exception** — today only `Taxes` (`player_tax`/`enemy_tax`) does this. `ChooseTarget` no longer holds priority dictionaries (the priority system was removed) and is a normal plannable target-acquisition action.

## Architectural invariants

| Invariant | Why it matters |
|-----------|----------------|
| GOAP makes high-level decisions; existing unit systems perform the work. | Prevents duplicated movement and combat logic. |
| An action's preconditions and effects must agree with its runtime behavior. | Prevents plans that look valid but cannot execute. |
| Unit-specific data must not be shared between agents (unless documented). | Prevents cross-unit state leakage. |
| State facts have documented ownership and semantics (see `docs/ai/world-state.md`). | Reduces misspelled keys and incorrect assumptions. |
| Actions and goals must follow the agreed contracts. | Keeps the codebase consistent as more behaviors are added. |
| Planner and lifecycle changes require regression tests. | Protects existing behavior during architectural work. |
| Goal `is_valid()` should not mutate state. It is called for every goal of every unit on that unit's staggered turn (~8.6 Hz; physics is 60 Hz). Documented exceptions are stale-fact maintenance (`EnemyDefeated`, `FriendsSafe`, `NeedSafety`, `Recover`). | Prevents order-dependent behavior and hidden side effects. |

## Required behavior when editing AI

1. **Inspect existing actions and goals before adding a new one.** Read at least 2–3 similar implementations to understand the established pattern.
2. **Follow the established action or goal contract.** Every active GOAP action must extend `action_contract.gd`; every active GOAP goal must extend `goal_contract.gd`.
3. **Do not invent new world-state keys** without checking `docs/ai/world-state.md`.
4. **Do not add per-unit mutable state to globally shared action objects.**
5. **Do not change the planner or agent lifecycle** just to implement an ordinary new behavior.
6. **Do not refactor unrelated systems** without an explicit reason.
7. **Add or update tests** when changing planning rules, action lifecycle, or goal evaluation.

## Known exceptions

### Arrival is a GOAP state transition, not a signal

`ArriveAtDestination.is_valid()` hard-returns `false` (activation is disabled;
pinned by `tests/unit/test_arrive_at_destination.gd`). It is a service/library
goal, not a selectable one. The real arrival machinery is in
`collision/collisions.gd`: when a `move` unit reaches `current_destiny`,
`Collisions` calls `ArriveAtDestination.advance_path(unit)` — on a waypoint it
advances the path; on the FINAL arrival it latches `has_path=false`,
`has_destiny=false`, `arrived_at_destination=true` and stops the unit. Actions
drive their arrival effects from `perform()` by reading those facts. There is
**no** `unit_arrived` wiring and **no** per-action `on_arrive` hook (removed in
the PR #239 feedback rework; pinned by `tests/unit/test_arrival_dispatch.gd`).
Do not re-enable the goal's activation and do not reintroduce signal-based
arrival dispatch.

### The process pump

`Goap.physics_process(all_units, delta)` is called explicitly from `game.gd`
each physics tick, which is **60 Hz**: `project.godot` sets
`common/physics_fps=30`, but that is the Godot 3 key name and is ignored
(Godot 4 reads `physics/common/physics_ticks_per_second`). The pump skips dead
units and runs each agent every 7th tick (`frames_til_next_process`, seeded
with `randi_range(0, 6)` to stagger units), so **per-unit goal evaluation is
~8.6 Hz, not 30 Hz**. The method is deliberately named without an underscore
(`physics_process`, not `_physics_process`) to distinguish it from Godot
virtual methods. Do not change this to `_process` or `_physics_process`.

### `has_destiny` lifecycle

`Move.get_preconditions()` is `{has_destiny: true, is_stunned: false}`.
`has_destiny` is set by `Navigate.follow_path` when a route is queued and is
cleared by `Move.stop` and by the final arrival
(`ArriveAtDestination.advance_path`), so the planner orders `Navigate` before
`Move` deterministically. `has_path` is still written by
`Navigate`/`ArriveAtDestination` but no precondition reads it.
`arrived_at_destination` is reset by `Move.move`/`Navigate.follow_path` on any
newly issued movement and latched by the final arrival — plan actions must
observe THEIR OWN arrival, never a stale one. A precondition of `false` is not
satisfied by an unset key (`null != false`), so a fact must be explicitly set
to `false` to match.

### `agent.set_state("target", v)` is special-cased

It does not write the agent state dictionary; it calls
`ChooseTarget.set_target(agent, v)`, which writes `unit.target` and resets
attack count/modifiers. Read `unit.target`, never `agent.get_state("target")`.

### ChooseTarget

`ChooseTarget` is a normal plannable action (`is_valid()` =
`unit.attacks and !unit.target`) used for target acquisition, e.g.
`[ChooseTarget, PursueEnemy, AttackEnemy]`. It is **not** a documented
always-invalid service object — that was the pre-restructure behavior.

### Dead code (removed)

`ChooseTactics` (a `Node`-extending stub that was never valid) was deleted in
Track E1; do not reintroduce it or use old copies as a template.

## Completion requirements

Every AI development task must include verification:

- **New action or goal:** Add at least one test in `tests/unit/` that exercises the new behavior (planning, validity, lifecycle).
- **Modified planner or agent:** Run the full test suite (`godot --headless --path . res://tests/test_runner.tscn`) and report results.
- **Modified goal priority:** Test that the correct competing goal is selected.
- **Modified planner precondition:** Test both a valid plan and an invalid one.

Report which checks you ran, which passed, and anything you couldn't verify.

## Development workflow

### Investigate before editing

A task should begin with identifying existing implementations and explaining how the requested behavior fits. For example:

> Investigate how Shotcaller's current goals, planner, and actions interact with unit movement and combat. Identify the existing behavior that should be reused. Explain which files you expect to modify, which state facts are involved, and how the behavior will be tested. Do not edit code yet.

### Small, verifiable tasks

Make one focused change per task. Specify observable acceptance criteria. Keep unrelated architecture changes out. Each task should be on its own branch with a clean diff.

### After the change

1. Run the test suite and report results.
2. Explain the implementation and identify which tests cover it.
3. Report anything you couldn't verify.
