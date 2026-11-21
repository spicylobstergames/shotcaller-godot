# GOAP Architecture

> The verified, cross-system map is `../../ARCHITECTURE.md`; the open work
> items are in `../../IMPROVEMENT_PLAN.md`. This document is the long-form
> GOAP walkthrough. It has been corrected in place against the current code:
> where an older revision of this file disagreed with the code, the code wins.

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

The agent does not run every physics tick. `Goap.physics_process` skips dead
units and advances each agent every 7th tick (`frames_til_next_process`,
seeded `randi_range(0, 6)` at `_ready` to stagger units). Physics is 60 Hz, so
**each unit evaluates goals at ~8.6 Hz**. `project.godot`'s
`common/physics_fps=30` is the Godot 3 key name and is ignored by Godot 4
(`physics/common/physics_ticks_per_second` is the real setting).

## Key components

### Goap (goap.gd) — Global singleton

Autoload accessible globally via `Goap`. Initializes the planner and exposes:

- `get_action_planner()` — returns the shared planner instance
- `get_goal(name)` / `get_action(name)` — retrieve goals/actions from registries
- `physics_process(units, delta)` — called from `game.gd` each physics tick
  (60 Hz) to advance every unit's agent on its staggered turn

There are **no** `Goap.move` / `Goap.navigation` members. Movement is reached
through `Goap.get_action("Move")` / `Goap.get_action("Navigate")` and the
`Navigation` autoload.

### Agent (agent.gd) — Per-unit AI state machine

Each unit has one agent instance. Responsibilities:

1. **Goal management** — loads the exported `goals_list` at `_ready()` (the
   `WalkLane` goal is appended at spawn by `map/spawns.gd`), evaluates every
   goal on its turn, and selects the highest-priority valid one (`is_valid()`
   then `priority()`, strict `>` so earlier-registered goals win ties).
2. **Plan management** — asks the planner for a plan when the **goal
   identity** changes, follows the plan step by step. The plan is not
   revalidated mid-execution.
3. **State management** — maintains a local dictionary of state facts that the
   planner consumes. `set_state("target", …)` is special-cased: it routes to
   `ChooseTarget.set_target` and writes `unit.target`, not the dictionary.
4. **Action lifecycle** — `_replace_plan` emits `action_changed`, whose handler
   calls `enter()` on the current action; `_follow_plan` iterates
   `perform()` until it returns `true`, then calls `exit()` and advances (or
   clears the plan on the last step).
5. **Signal wiring** — connects to unit signals and translates them into state
   changes or action/goal callbacks (table below).
6. **Per-second work** — `WorldState.second_elapsed` → `on_every_second`,
   which dispatches optional `on_every_second` hooks to the current
   action/goal, then calls `unit.regenerate()` and
   `unit.apply_damage_over_time()`.

The agent pump is called from `game.gd`:

```gdscript
Goap.physics_process(WorldState.get_state("all_units"), delta)
```

### Planner (planner.gd) — Backward search

The planner uses backward search from the desired state:

1. The goal's `get_desired_state()` defines what facts must be true.
2. The planner removes facts already satisfied by the agent's state or by
   `WorldState` (agent state is checked first; `Object` values are coerced to
   `true`).
3. For remaining unsatisfied facts, it considers all actions whose effects
   match those facts.
4. Each candidate action's preconditions are added to the unsatisfied facts,
   and the search recurses.
5. Recursion continues until the desired state is empty (plan found), the
   depth limit (`MAX_PLAN_DEPTH = 64`) is reached, or no valid actions exist.
   Repeated unsatisfied states in a branch are pruned by a state signature.
6. Among all valid plans, the lowest **summed `get_cost()`** one is returned;
   ties keep the first-built plan (registry order).

#### Precondition merging — there is no contradiction check

The planner merges an action's preconditions into the branch's desired state by
dictionary assignment. If a precondition conflicts with a fact the branch
already requires, the new value **silently overwrites** the old one; the
branch is not rejected.

Verified consequence: for a goal requiring `{b: true, x: true}`, an action
`MakeX` (`{b: false} → {x: true}`) plus `MakeNotB` (`{} → {b: false}`) yields
the plan `["MakeNotB", "MakeX"]`, which leaves `b` false and therefore cannot
satisfy the goal. An older revision of this document claimed such branches were
rejected — they are not. Keep preconditions consistent with goals and ancestor
requirements by hand, and see `IMPROVEMENT_PLAN.md` Track C for the planned
rejection (prior art: branch `planner-precondition-safety`).

### Action contract (action_contract.gd)

Every active GOAP action extends this base class. Methods:

| Method | Responsibility |
|--------|----------------|
| `get_class_name()` | Returns the identifier used by the action registry to retrieve this action. It is not declared on the base; every action defines it. |
| `is_valid(agent) -> bool` | Determines whether the action is eligible for consideration. Default is `true`; actions opt out. Called during planning to filter candidates; execution does not re-check it on the current action. `ChooseTarget` is a normal plannable action (`unit.attacks and !unit.target`), not an always-invalid service object. |
| `get_cost(agent) -> int` | Returns the action's cost (default 1). Used by the planner to select the lowest-cost plan. Can be situational. |
| `get_preconditions() -> Dictionary` | Facts that must hold before the action can run. The planner uses these to determine ordering. It does **not** perform contradiction checking (see above). |
| `get_effects() -> Dictionary` | Facts expected to hold after successful completion. The planner uses these to determine which goal requirements the action satisfies. |
| `enter(agent)` | Called once when the action starts executing. |
| `perform(agent, delta) -> bool` | Called each tick during execution. Returns `true` when the action is complete (agent advances to the next plan step), `false` to continue. |
| `exit(agent)` | Called once when the action ends (completes normally or is interrupted). |

### Goal contract (goal_contract.gd)

Every active GOAP goal extends this base class. Methods:

| Method | Responsibility |
|--------|----------------|
| `get_class_name()` | Returns the identifier used by the goal registry. |
| `is_valid(agent) -> bool` | Determines whether the goal is currently eligible. Called on each unit's staggered turn (~8.6 Hz). Should be pure; the documented exceptions (`EnemyDefeated`, `FriendsSafe`, `NeedSafety`, `Recover`) reset stale success facts deliberately. |
| `priority(agent) -> int` | Returns the goal's priority. Higher values win. Can be dynamic. |
| `get_desired_state(agent) -> Dictionary` | Returns the facts the planner must achieve. These become the root requirements for backward search. |
| `enter(agent)` / `exit(agent)` | Called by the agent when the goal is selected/replaced. The planner ignores them (it only calls `get_desired_state`). |

### Registries

- **Action registry** (`action_registry.gd`) — creates 19 action instances as
  singletons (shared across all units). Each instance is added once and reused.
- **Goal registry** (`goal_registry.gd`) — creates 8 goal instances as
  singletons, stored by name in a dictionary.
- Per-unit goal availability is scene data: each unit scene sets `goals_list`
  on its `goap_agent` node, and `map/spawns.gd` appends `WalkLane` at spawn.

### WorldState (world_state.gd) — Global autoload

Autoload for world-wide state accessible globally via `WorldState`. Stores teams, unit lists, map data, game state, etc. Also emits the `second_elapsed` signal each game second, which the agent uses for regeneration and per-second action/goal callbacks.

## Integration boundaries

### Where does decision-making happen?

**Goal selection** happens in `agent._get_best_goal()` — it evaluates all goals, calls `is_valid()` and `priority()` for each, and returns the highest-priority valid one.

**Plan generation** happens in `planner.get_plan()` — it performs backward search from the goal's desired state and returns the lowest-cost plan.

Both are called from `agent.goap_process(delta)`, which runs on the unit's staggered turn (~8.6 Hz).

### Where does an action actually happen?

Actions interact with the existing game systems through their `enter()`, `perform()`, and `exit()` methods. For example:

- `MoveAction.enter()` calls `move(unit, unit.current_destiny)` to start the unit moving.
- `AttackEnemy.enter()` aims the unit's weapon/attack system at the target.
- `NavigateAction.enter()` sets up the path and hands the first waypoint to the movement driver.

Actions do **not** reimplement movement or combat — they call
`Goap.get_action("Move")` / `Goap.get_action("Navigate")`, the `Navigation`
autoload, or unit methods.

### How does the agent know an action has finished?

The action's `perform()` method returns `true` when complete. The agent then calls `exit()` and advances to the next plan step. If the action never returns `true` (e.g., the target disappears, the path is blocked), the agent continues executing that action until something changes the agent's goal (triggering replanning) or the action is internally interrupted.

`perform()` returns a bare boolean (`true` = complete, `false` = still running); there is no `FAILED` state and no mid-plan precondition revalidation. Those remain open items (see "Planned improvements").

### What can interrupt an action?

Several mechanisms:

1. **Goal change** — if `_get_best_goal()` returns a different goal than the current one, the agent exits the current action, replaces the plan, and starts a new one.
2. **Death** — `on_death_started()` cancels the player order and clears the plan.
3. **Player orders** — `OrderAction` can interrupt autonomous behavior.
4. **Stun** — `on_stun_end()` attempts to resume the current action/goal.
5. **Plan completion** — when the last action completes, the agent clears the plan and re-evaluates goals on the next turn.

Arrival is not an interruption and not a signal; it is a GOAP state
transition. `Collisions` detects a moving unit reaching `current_destiny` and
calls `ArriveAtDestination.advance_path(unit)`: on a waypoint it advances the
path; on the FINAL arrival it latches `has_path=false`, `has_destiny=false`,
`arrived_at_destination=true` and stops the unit. Plan actions drive their
arrival effects from `perform()` by reading `arrived_at_destination` behind
per-action latches (`GetLumber` cutting, `Hide` is_hiding, `ReturnLumber`
delivery, `Retreat` arrived_at_retreat, `Order` conquer/pray dispatch).
`ArriveAtDestination.is_valid()` hard-returns `false`: the goal is a
service/library goal, not a selectable one.

### When does the agent replan?

Only when the goal changes:

```gdscript
func goap_process(delta):
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

This is a known limitation (Track C in `IMPROVEMENT_PLAN.md`).

## Signal wiring

The agent connects to unit signals in `_ready()`:

| Signal | Connection | Notes |
|--------|-----------|-------|
| `unit_reseted` | `reset()` | Clears the plan and state (preserving `lane`/`tactic`). |
| `unit_idle_ended` | `on_idle_end()` | Delegates to the current action/goal, then handles unit wait. |
| `unit_stun_ended` | `on_stun_end()` | Delegates `resume()` to the current action/goal. |
| `unit_attack_ended` | `on_attack_end()` | Delegates to the current action/goal. |
| `unit_attack_release` | `RangeAttack.projectile_release` | Fires projectiles. |
| `unit_attack_hitted` | `MeleeAttack.hit` | Registers melee hits. |
| `unit_death_started` | `on_death_started()` | Cancels player orders. |
| `unit_died` | `on_died()` | Clears stuck projectiles. |
| `unit_animation_ended` | `on_animation_end()` | Decrements `being_attacked`; delegates to the current action/goal. |
| `unit_was_attacked` | `was_attacked()` | Sets `being_attacked`/`attacker`; delegates. |
| `second_elapsed` (WorldState) | `on_every_second()` | Regen, per-second action/goal callbacks, DoT damage. |

Signals that exist but are **not** connected to the agent: `unit_arrived`
(arrival is a GOAP state transition — see above — and used to be wired to the
removed `Agent.on_arrive` dispatch), `unit_move_ended`, `unit_stuned`,
`unit_started_channeling`, `unit_healed`, `unit_leveled_up`.
`state_changed` carries a single combined `"Goal Action"` debug string, and
`hud.update_state(text)` receives it as its one argument.

**Execution history.** Each agent keeps a bounded (64-entry) log of
goal/plan/action transitions (including explicit `completed:` events) plus movement/arrival/service sub-events
(`Agent.record_event` / `get_history()` / `history_summary()`). It is
diagnostics only — nothing in planning reads it — and `tests/freeze_report.gd`
prints the tail for stuck units. Expected plan sequences per goal are listed
in `../../ARCHITECTURE.md` ("Arrival is a GOAP state transition").

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

The agent's local state dictionary is the bridge between the planner and the
game systems. `unit.target` is the exception: it lives on the unit, reached
through the special-cased `set_state("target", …)`. State facts, their owners,
and their lifecycle are catalogued in `world-state.md`.

## Planned improvements

The prioritized, implementation-ready list now lives in
`../../IMPROVEMENT_PLAN.md`. In brief:

- **Track C — planner precondition conflicts.** The planner does not detect
  contradictory preconditions (see above); either implement rejection or
  document the limitation explicitly.
- **Track D — state-fact hygiene.** Replace string keys with constants,
  document the reset contract for facts such as `has_destiny` and
  `arrived_at_retreat`, and remove dead keys.
- **Track E — performance and cleanup.** Guard corpse per-second work and
  measure planner cost. (The dead `ChooseTactics` action was deleted — E1.)
- **Track F — test hardening.** Replace mock-only assertions and re-sabotage
  the ported planner/agent tests.

Action results: `perform()` still returns a bare boolean, so failures are
handled by setting a state flag that makes `perform()` return `true`, or by
letting a higher-priority goal trigger replanning.
