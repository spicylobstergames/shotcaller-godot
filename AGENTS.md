# AGENTS.md — Instructions for Coding Agents

## Project context

- **Engine:** Godot 4.7, GDScript
- **Project root:** `prototype/` (relative to repo root)
- **Main scene:** `res://game.tscn` (set in `prototype/project.godot`)
- **GOAP system:** `prototype/goap/`
- **Tests:** `prototype/tests/` (headless runner: `res://tests/test_runner.tscn`)
- **Run the test suite:**
  ```bash
  godot --headless --path prototype res://tests/test_runner.tscn
  ```
- **GitHub Actions workflow:** `.github/workflows/godot-tests.yml` — runs the suite on PRs and main pushes.

## Architecture overview

The AI subsystem is a GOAP (Goal-Oriented Action Planning) system layered on top of an existing unit/behavior system. **GOAP decides; existing systems perform.**

Key files:

| File | Role |
|------|------|
| `prototype/goap/goap_system/goap.gd` | Global autoload singleton — exposes planner, action/goal access, movement, and navigation. Calls `physics_process()` on all units each physics tick. |
| `prototype/goap/goap_system/agent.gd` | Per-unit AI state machine — holds goals, current plan, current action, local state dictionary, and signal wiring to the unit. |
| `prototype/goap/goap_system/planner.gd` | Backward-search planner — generates action plans and selects the lowest-cost. Rejects branches whose preconditions contradict facts already satisfied in the current branch. |
| `prototype/goap/goap_system/action_contract.gd` | Base class for all GOAP actions. Methods: `is_valid()`, `get_cost()`, `get_preconditions()`, `get_effects()`, `enter()`, `perform()`, `exit()`. |
| `prototype/goap/goap_system/goal_contract.gd` | Base class for all GOAP goals. Methods: `is_valid()`, `priority()`, `get_desired_state()`. |
| `prototype/goap/game_logic/action_registry.gd` | Creates and stores all action instances (shared, singletons). |
| `prototype/goap/game_logic/goal_registry.gd` | Stores all goal instances by name. |
| `prototype/goap/game_logic/world_state.gd` | Global autoload for world-wide state (teams, units lists, map, etc.). |

### The decision loop

```
  Unit / World State
       |
       v
  Goap.Agent.process(delta)  [called from game.gd:physics_process]
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

- **`MoveAction`** and **`NavigateAction`** drive the unit's movement system through `Goap.move` and `Goap.navigation` helpers.
- **`AttackEnemy`**, **`MeleeAttack`**, **`RangeAttack`** fire the unit's weapon/attack system.
- **`OrderAction`** processes player orders.
- The **agent** connects to unit signals (arrival, death, stun, etc.) and translates them into state changes that the GOAP planner consumes.

**Do not introduce a second implementation of unit movement or combat when an existing game system already provides it.** Reuse the established system through its intended interface.

### State facts

The planner uses string-keyed dictionaries for preconditions, effects, goals, and agent state. Spelling errors or incorrect assumptions silently break planning.

**Read `docs/ai/world-state.md`** before adding or modifying any state fact. It is the authoritative catalog of every key, its scope (agent vs. world), type, producer, consumer, and lifecycle.

**Important rule:** A precondition of `false` is not satisfied by an unset state key. The agent state reads `null`, and `null != false` in GDScript. A fact must be explicitly set for it to be matched.

### State ownership rules

- **Agent-specific state** belongs in the agent's local dictionary (`agent.set_state(...)`).
- **World-wide state** belongs in the `WorldState` singleton.
- **Team-specific state** (player team, enemy team, team unit lists) belongs in `WorldState`.
- **Unit-specific mutable data** must never be stored in globally shared action objects. The action registry creates action instances once and shares them across all units.
- **ChooseTarget** is a documented exception — it holds team-level priority dictionaries intentionally. See below.

## Architectural invariants

| Invariant | Why it matters |
|-----------|----------------|
| GOAP makes high-level decisions; existing unit systems perform the work. | Prevents duplicated movement and combat logic. |
| An action's preconditions and effects must agree with its runtime behavior. | Prevents plans that look valid but cannot execute. |
| Unit-specific data must not be shared between agents (unless documented). | Prevents cross-unit state leakage. |
| State facts have documented ownership and semantics (see `docs/ai/world-state.md`). | Reduces misspelled keys and incorrect assumptions. |
| Actions and goals must follow the agreed contracts. | Keeps the codebase consistent as more behaviors are added. |
| Planner and lifecycle changes require regression tests. | Protects existing behavior during architectural work. |
| Goal `is_valid()` must not mutate state. It is called every physics tick (30 Hz) for every goal of every unit. | Prevents order-dependent behavior and hidden side effects. |

## Required behavior when editing AI

1. **Inspect existing actions and goals before adding a new one.** Read at least 2–3 similar implementations to understand the established pattern.
2. **Follow the established action or goal contract.** Every active GOAP action must extend `action_contract.gd`; every active GOAP goal must extend `goal_contract.gd`.
3. **Do not invent new world-state keys** without checking `docs/ai/world-state.md`.
4. **Do not add per-unit mutable state to globally shared action objects.**
5. **Do not change the planner or agent lifecycle** just to implement an ordinary new behavior.
6. **Do not refactor unrelated systems** without an explicit reason.
7. **Add or update tests** when changing planning rules, action lifecycle, or goal evaluation.

## Known exceptions

### ChooseTarget (action_registry entry)

`ChooseTarget` extends the action contract but always returns `false` from `is_valid()`. It is **not** planned as an action — it is a service object for target selection and lane/leader priority management. Its mutable priority dictionaries are shared intentionally at the team level.

### The process pump

`Goap.physics_process(all_units, delta)` is called explicitly from `game.gd` each physics tick (30 Hz). It is deliberately named without an underscore (`physics_process`, not `_physics_process`) to distinguish it from Godot virtual methods. Do not change this to `_process` or `_physics_process`.

### `has_path` and the `null` vs `false` trap

The `MoveAction` precondition requires `has_path: false`. This is only satisfied because goal `is_valid()` methods (specifically `WalkLane` and `ArriveAtDestination`) write `has_path` to the agent state every frame. If a goal fails to call `set_state("has_path", ...)`, the planner will see `null` and treat the precondition as unmet. The world-state catalog documents this dependency.

### Stale references

- `goal_contract.gd` line 16 references `goals/keep_fed.gd` (leftover from the GOAP tutorial this was based on). This file no longer exists.
- `move_action.smart` checks `get_state("stunned")` (line 165) while the canonical key is `"is_stunned"`. This guard is silently inactive.

## Completion requirements

Every AI development task must include verification:

- **New action or goal:** Add at least one test in `prototype/tests/unit/` that exercises the new behavior (planning, validity, lifecycle).
- **Modified planner or agent:** Run the full test suite (`godot --headless --path prototype res://tests/test_runner.tscn`) and report results.
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
