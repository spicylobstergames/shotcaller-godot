# GOAP Architecture

## Overview

Shotcaller uses a GOAP (Goal-Oriented Action Planning) system for AI unit behavior. The system makes high-level decisions (which goal to pursue, what plan to execute) while delegating low-level actions (movement, combat, animation) to existing game systems. This separation was deliberately introduced to solve the problem of integrating GOAP with pre-existing unit logic — the two systems coexist rather than one replacing the other.

## Lifecycle of a unit decision

```
       UNIT / WORLD STATE
                |
                v
          GOAP AGENT (agent.gd)
                |
                v
          Select Goal (_get_best_goal)
                |
                v
          GOAP PLANNER (planner.gd)
                |
                v
        Generate Action Plan (backward search)
                |
                v
       Action Execution Lifecycle
       (enter -> perform -> exit)
                |
                v
     Existing Unit / Game Systems
     (movement, combat, animation, pathfinding)
                |
                v
       Unit Events and State Updates
                |
                +------> GOAP AGENT (back to start)
```

## Key components

### Goap (goap.gd) — Global singleton

Autoload accessible globally via `Goap`. Initializes the planner and exposes:

- `get_action_planner()` — returns the planner instance
- `get_goal(name)` / `get_action(name)` — retrieve goals/actions from registries
- `move` / `navigation` — convenience references to MoveAction and NavigateAction (used by other actions)
- `physics_process(units, delta)` — called from `game.gd` each physics tick (30 Hz) to advance every unit's agent

### Agent (agent.gd) — Per-unit AI state machine

Each unit has one agent instance. Responsibilities:

1. **Goal management** — maintains a list of active goals, evaluates them every tick, selects the highest-priority valid one.
2. **Plan management** — asks the planner for a plan when the goal changes, follows the plan step by step.
3. **State management** — maintains a local dictionary of state facts that the planner consumes.
4. **Action lifecycle** — calls `enter()` on the current action, iterates `perform()` until it returns `true`, calls `exit()` before advancing.
5. **Signal wiring** — connects to unit signals (arrival, death, stun, attack end, etc.) and translates them into state changes or action/goal callbacks.

The agent pump is called from `game.gd`:
```gdscript
Goap.physics_process(WorldState.get_state("all_units"), delta)
```

This calls `agent.process(delta)` on every unit, which evaluates goals, plans as needed, and follows the current plan.

### Planner (planner.gd) — Backward search

The planner uses backward search from the desired state:

1. The goal's `get_desired_state()` defines what facts must be true.
2. The planner checks which facts are already satisfied (in agent state or WorldState) and removes them.
3. For remaining unsatisfied facts, it considers all actions whose effects match those facts.
4. Each candidate action's preconditions are added to the unsatisfied facts.
5. **If any precondition contradicts a fact that the branch already requires to stay satisfied, the branch is rejected.** (See "Contradiction checking" below.)
6. Recursion continues until the desired state is empty (plan found), the depth limit is reached, or no valid actions exist.
7. Among all valid plans, the lowest-cost one is returned.

#### Contradiction checking

The planner tracks facts that a branch already requires and that are currently satisfied (at the root goal or any ancestor). When an action's preconditions are added, the planner checks:

- Does the precondition contradict a fact that remains unsatisfied in the current branch? (e.g., branch requires `b: true`, action preconditions require `b: false`)
- Does the precondition contradict a fact that an ancestor already requires to stay satisfied? (e.g., root goal requires `has_weapon: true`, action preconditions require `has_weapon: false`)

If either condition is true, the branch is rejected. This prevents the planner from planning sequences that would make the goal impossible to achieve.

### Action contract (action_contract.gd)

Every active GOAP action extends this base class. Methods:

| Method | Responsibility |
|--------|----------------|
| `get_class_name()` | Returns the identifier used by the action registry to retrieve this action. |
| `is_valid(agent) -> bool` | Determines whether the action is eligible for consideration. Called both during planning (to filter candidates) and implicitly during execution (the agent doesn't re-check `is_valid()` on the current action mid-execution). |
| `get_cost(agent) -> int` | Returns the action's cost. Used by the planner to select the lowest-cost plan among multiple valid options. Can be situational (depends on agent state). |
| `get_preconditions() -> Dictionary` | Describes facts that must hold before the action can run. The planner uses these to determine ordering and to perform contradiction checking. |
| `get_effects() -> Dictionary` | Describes facts expected to hold after successful completion. The planner uses these to determine which goal requirements the action satisfies. |
| `enter(agent)` | Called once when the action starts executing. |
| `perform(agent, delta) -> bool` | Called every tick during execution. Returns `true` when the action is complete (agent advances to the next plan step), `false` to continue. |
| `exit(agent)` | Called once when the action ends (completes normally or is interrupted). |

### Goal contract (goal_contract.gd)

Every active GOAP goal extends this base class. Methods:

| Method | Responsibility |
|--------|----------------|
| `get_class_name()` | Returns the identifier used by the goal registry. |
| `is_valid(agent) -> bool` | Determines whether the goal is currently eligible. Called every physics tick (30 Hz) for every goal of every unit. Must not mutate state. |
| `priority(agent) -> int` | Returns the goal's priority. Higher values win. Can be dynamic (based on agent state). |
| `get_desired_state(agent) -> Dictionary` | Returns the facts the planner must achieve. These become the root requirements for backward search. |

### Registries

- **Action registry** (`action_registry.gd`) — creates all action instances as singletons (shared across all units). Each instance is added once and reused.
- **Goal registry** (`goal_registry.gd`) — creates all goal instances as singletons, stored by name in a dictionary.

### WorldState (world_state.gd) — Global autoload

Autoload for world-wide state accessible globally via `WorldState`. Stores teams, unit lists, map data, game state, etc. Also emits the `second_elapsed` signal each game second, which the agent uses for regeneration and per-second action/goal callbacks.

## Integration boundaries

### Where does decision-making happen?

**Goal selection** happens in `agent._get_best_goal()` — it evaluates all goals, calls `is_valid()` and `priority()` for each, and returns the highest-priority valid one.

**Plan generation** happens in `planner.get_plan()` — it performs backward search from the goal's desired state and returns the lowest-cost plan.

Both are called from `agent.process(delta)`, which is called every physics tick by `Goap.physics_process()`.

### Where does an action actually happen?

Actions interact with the existing game systems through their `enter()`, `perform()`, and `exit()` methods. For example:

- `MoveAction.enter()` calls `move(unit, destiny)` to start the unit moving toward its destination.
- `AttackEnemy.enter()` calls `point(unit, target_position)` to aim the weapon.
- `NavigateAction.enter()` sets up the path and starts navigation.

Actions do **not** reimplement movement or combat — they call into the established systems through `Goap.move`, `Goap.navigation`, `Goap.get_action("...")`, and unit methods.

### How does the agent know an action has finished?

The action's `perform()` method returns `true` when complete. The agent then calls `exit()` and advances to the next plan step. If the action never returns `true` (e.g., the target disappears, the path is blocked), the agent continues executing that action until something changes the agent's goal (triggering replanning) or the action is manually interrupted.

**Current limitation:** `perform()` returns a bare boolean (`true` = complete, `false` = still running). There is no `FAILED` state. This makes it difficult to distinguish "still progressing" from "failed and needs replanning." See "Planned improvements" below.

### What can interrupt an action?

Several mechanisms:

1. **Goal change** — if `_get_best_goal()` returns a different goal than the current one, the agent exits the current action, replaces the plan, and starts a new one.
2. **Death** — `on_death_started()` cancels the player order and clears the plan.
3. **Player orders** — `OrderAction` can interrupt autonomous behavior.
4. **Stun** — `on_stun_end()` attempts to resume the current action/goal.
5. **Replanning** — when the current plan is fully executed, the agent re-evaluates goals and generates a new plan.

**Gap:** The agent does not validate the current plan against the world state on every tick. If a precondition is no longer satisfied (e.g., the target disappears mid-plan), the agent may continue executing a stale plan until the current action completes or the goal changes. See "Planned improvements."

### When does the agent replan?

Only when the goal changes:

```gdscript
func process(delta):
    var goal = _get_best_goal()
    if goal != _current_goal:
        var plan: Array = []
        if goal:
            plan = Goap.get_action_planner().get_plan(self, goal)
        _replace_plan(goal, plan)
    else:
        _follow_plan(_current_plan, delta)
```

The agent does **not** replan when:

- The current plan's preconditions become unmet mid-execution.
- The current action fails.
- The world state changes in a way that invalidates the plan.

This is a known limitation. See "Planned improvements."

## Signal wiring

The agent connects to unit signals in `_ready()`:

| Signal | Connection | Notes |
|--------|-----------|-------|
| `unit_reseted` | `reset()` | Clears the plan and state. |
| `unit_arrived` | `on_arrive()` | Advances the plan. Also connects to `OrderAction.on_arrive`. |
| `unit_idle_ended` | Delegates to current action/goal. |
| `unit_stun_ended` | Delegates `resume()` to current action/goal. |
| `unit_move_ended` | Delegates to current action/goal. |
| `unit_attack_ended` | Delegates to current action/goal; also resumes movement if no target. |
| `unit_attack_release` | `RangeAttack.projectile_release` | Fires projectiles. |
| `unit_attack_hitted` | `MeleeAttack.hit` | Registers melee hits. |
| `unit_death_started` | `cancel_player_order()` | Cancels orders. |
| `unit_died` | `RangeAttack.clear_stuck` | Clears stuck projectiles. |
| `unit_animation_end` | Delegates to current action/goal. |
| `unit_was_attacked` | `was_attacked()` | Sets attacker state and delegates. |
| `second_elapsed` (WorldState) | `on_every_second()` | Regen, per-second action/goal callbacks, DoT damage. |

**Known issue:** `unit_arrived` is connected **twice** (once to `on_arrive`, once to `OrderAction.on_arrive`). This causes `on_arrive` to fire twice for a single arrival event.

## State flow

```
  [Unit / WorldState]
       |
       v
  [Agent local state dictionary]  <-- set_state / get_state
       |
       v
  [Planner desired state matching]
       |
       v
  [Action preconditions / effects]
       |
       v
  [Action enter/perform/exit]
       |
       v
  [Unit signal callbacks]  <-- update agent state from unit events
```

The agent's local state dictionary is the bridge between the planner and the game systems. Actions and goals read from and write to this dictionary.

## Planned improvements

### Action result enum

Replace the boolean `perform()` return value with an explicit enum:

```gdscript
enum ActionResult { RUNNING, SUCCEEDED, FAILED }
```

This gives the agent and debugging tools a clear distinction between "still executing," "successfully completed," and "failed and needs a new plan."

### Plan revalidation

Add logic to `process()` or `_follow_plan()` that rechecks plan validity on each tick, or at minimum when key state facts change. If a precondition is no longer satisfied, the agent should replan rather than continuing a stale plan.

### Goal `is_valid()` side effects

Several goals currently mutate state in `is_valid()` — specifically `EnemyDefeated` (re-selects target every frame), `WalkLane` (builds path geometry), and `ArriveAtDestination` (rewrites `has_path`). Since `is_valid()` is called 30 Hz for every goal of every unit, this creates a hot path with implicit side effects.

The fix: introduce a `refresh(agent)` method for state observation/refresh, and make `is_valid()` a pure function that only returns a boolean.

### ChooseTarget as a proper singleton

`ChooseTarget` holds mutable priority dictionaries that are team-scoped. These should either be moved to WorldState or explicitly documented as intentionally shared. Currently undocumented.

### State-key constants

Replace string literal state keys with constants to prevent typos:

```gdscript
const STATE_HAS_PATH = "has_path"
const STATE_ENEMY_DEAD = "enemy_dead"
```

This would be enforced once the world-state catalog is complete.

### Stale references

- `goal_contract.gd` line 16 references `goals/keep_fed.gd` (leftover from the tutorial). Delete the comment or add a FIXME.
- `move_action.smart` checks `get_state("stunned")` (line 165) while the canonical key is `"is_stunned"`. This guard is silently inactive.
