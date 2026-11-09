# Adding Behavior to GOAP

This document provides a practical recipe for adding new actions and goals to Shotcaller's GOAP system. It reflects the current implementation as of the latest merge.

## Adding a new action

### Step 1: Review existing actions

Before writing a new action, read 2–3 existing actions to understand the established pattern. Good reference examples:

- **`AttackEnemy`** (`goap/game_logic/actions/attack_enemy.gd`) — clear lifecycle with enter/perform/exit; uses `ChooseTarget` for range checking.
- **`MoveAction`** (`goap/game_logic/actions/move_action.gd`) — drives movement through `Goap.move`; manages path state.
- **`NavigateAction`** (`goap/game_logic/actions/navigate_action.gd`) — pathfinding-driven movement; sets up navigation paths.
- **`PursueEnemy`** (`goap/game_logic/actions/pursue_enemy.gd`) — moves toward an enemy target.
- **`OrderAction`** (`goap/game_logic/actions/order_action.gd`) — processes player orders.

### Step 2: Extend the action contract

Every active GOAP action must extend the action contract:

```gdscript
extends "res://goap/goap_system/action_contract.gd"
```

Do not extend `Node` or any other base class. The action registry and planner depend on the contract's method signatures.

### Step 3: Implement `get_class_name()`

This returns the identifier used by the action registry and `Goap.get_action()`:

```gdscript
func get_class_name() -> String:
    return "MyAction"
```

The string must be unique across all actions.

### Step 4: Implement `is_valid(agent) -> bool`

This method determines whether the action is eligible for consideration. It is called **both** during planning (to filter candidates) and implicitly during execution (the agent doesn't re-check `is_valid()` on the current action mid-execution).

**Planning eligibility** vs **execution eligibility:** `is_valid()` serves both purposes in the current implementation. For planning, it checks whether the action is a possible way to produce its effects. For execution, it checks whether the action can currently begin or continue. These concepts overlap but are not interchangeable.

```gdscript
func is_valid(agent) -> bool:
    var unit = agent.get_unit()
    return (
        unit.moves
        and not agent.get_state("is_stunned")
        and not agent.get_unit().dead
    )
```

### Step 5: Implement `get_cost(agent) -> int`

Return the action's cost. Used by the planner to select the lowest-cost plan among multiple valid options. Can be situational:

```gdscript
func get_cost(agent) -> int:
    # Default cost; override if cost depends on agent state.
    return 1
```

### Step 6: Implement `get_preconditions() -> Dictionary`

Describe facts that must hold **before** the action can run. The planner uses these to determine ordering and to perform contradiction checking.

**Critical rules:**
- Preconditions must agree with `is_valid()` — if `is_valid()` requires a fact to be true, the precondition should not require it to be false (or vice versa).
- Preconditions must not contradict facts that an ancestor in the planning tree already requires to stay satisfied. The planner will reject such branches.
- A precondition of `false` is not satisfied by an unset state key (`null != false` in GDScript).

```gdscript
func get_preconditions() -> Dictionary:
    return {"enemy_in_attack_range": true}
```

### Step 7: Implement `get_effects() -> Dictionary`

Describe facts expected to hold **after successful completion**. The planner uses these to determine which goal requirements the action satisfies.

**Effects must describe what is true after the action completes successfully**, not what the action hopes to achieve. If the action can fail or be interrupted, effects still describe only the success case.

```gdscript
func get_effects() -> Dictionary:
    return {"enemy_dead": true}
```

### Step 8: Implement `enter(agent)`

Called once when the action starts executing. Initiate any required operations:

```gdscript
func enter(agent):
    var unit = agent.get_unit()
    var target = agent.get_state("target")
    if target and is_instance_valid(target):
        # Aim weapon, start movement, etc.
        pass
```

### Step 9: Implement `perform(agent, delta) -> bool`

Called every tick during execution. Returns `true` when the action is complete (agent advances to the next plan step), `false` to continue:

```gdscript
func perform(agent, delta) -> bool:
    # Check completion condition
    return agent.get_state("some_completion_flag", false)
```

**Current limitation:** The return value is a bare boolean. `true` = complete, `false` = still running. There is no `FAILED` state. If something goes wrong (target disappears, path blocked), the action should either:
1. Handle the failure internally (e.g., set a state flag that causes `perform()` to return `true`).
2. Rely on the agent's goal change mechanism (another goal with higher priority triggers replanning).

This is a known limitation. See `docs/ai/architecture.md` for planned improvements.

### Step 10: Implement `exit(agent)`

Called once when the action ends (completes normally or is interrupted). Clean up:

```gdscript
func exit(agent):
    var unit = agent.get_unit()
    # Stop movement, release resources, etc.
    Goap.move.stop(unit)
```

### Step 11: Register the action

Add the preload and `.new()` call to `action_registry.gd`'s `_actions` array. The array order does not affect planning (the planner considers all actions regardless of order), but place new actions near similar ones for readability.

```gdscript
var _actions: Array = [
    # ... existing actions ...
    preload("res://goap/game_logic/actions/my_action.gd").new(),
    # ... more actions ...
]
```

## Adding a new goal

### Step 1: Review existing goals

Good reference examples:

- **`EnemyDefeated`** (`goap/game_logic/goals/enemy_defeated.gd`) — combat goal with dynamic validity (requires a valid target).
- **`WalkLane`** (`goap/game_logic/goals/walk_lane.gd`) — movement goal that sets up paths and lanes.
- **`ObeyPlayer`** (`goap/game_logic/goals/obey_player.gd`) — player order goal.
- **`NeedSafety`** (`goap/game_logic/goals/need_safety.gd`) — reactive goal based on threat detection.

### Step 2: Extend the goal contract

Every active GOAP goal must extend the goal contract:

```gdscript
extends "res://goap/goap_system/goal_contract.gd"
```

Do not extend `Node` or any other base class.

### Step 3: Implement `get_class_name()`

```gdscript
func get_class_name() -> String:
    return "MyGoal"
```

### Step 4: Implement `is_valid(agent) -> bool`

Determine whether the goal is currently eligible. This is called **every physics tick (30 Hz) for every goal of every unit**.

**Critical rule:** `is_valid()` must not mutate agent state. It should be a pure function that returns a boolean. Side effects in `is_valid()` create order-dependent behavior and make the system harder to reason about.

Current exceptions (goals that do mutate state in `is_valid()`): `EnemyDefeated`, `WalkLane`, `ArriveAtDestination`, `NeedSafety`, `FriendsSafe`, `Recover`. These should be refactored. See `docs/ai/architecture.md` for planned improvements.

```gdscript
func is_valid(agent) -> bool:
    var unit = agent.get_unit()
    return (
        not unit.dead
        and not agent.get_state("is_stunned")
        and not agent.get_state("is_retreating")
    )
```

### Step 5: Implement `priority(agent) -> int`

Return the goal's priority. Higher values win. Can be dynamic:

```gdscript
func priority(agent) -> int:
    # Static priority
    return 3
    # Or dynamic:
    # return max(1, 10 - agent.get_unit().current_hp)
```

### Step 6: Implement `get_desired_state(agent) -> Dictionary`

Return the facts the planner must achieve. These become the root requirements for backward search:

```gdscript
func get_desired_state(agent) -> Dictionary:
    return {"enemy_dead": true}
```

### Step 7: Register the goal

Add the preload and `.new()` call to `goal_registry.gd`'s `_goals` dictionary:

```gdscript
var _goals: Dictionary = {
    # ... existing goals ...
    "MyGoal": preload("res://goap/game_logic/goals/my_goal.gd").new(),
    # ... more goals ...
}
```

### Step 8: Add the goal to the agent

The agent loads goals from its `goals_list` export variable. To make the new goal available to an agent, add the goal name to the `goals_list` array in the unit's scene file (or wherever agents are instantiated).

## Action lifecycle reference

| Method | Called | Responsibility |
|--------|--------|----------------|
| `get_class_name()` | Registry lookup | Return the action's identifier. |
| `is_valid(agent) -> bool` | Planning (candidate filter), implicit during execution | Determine eligibility. |
| `get_cost(agent) -> int` | Planning (cost comparison) | Return cost. |
| `get_preconditions() -> Dictionary` | Planning (backward search) | Describe pre-action facts. |
| `get_effects() -> Dictionary` | Planning (backward search) | Describe post-action facts. |
| `enter(agent)` | When the action starts | Initiate operations. |
| `perform(agent, delta) -> bool` | Every tick during execution | Continue execution; return true when complete. |
| `exit(agent)` | When the action ends | Clean up. |

## Goal lifecycle reference

| Method | Called | Responsibility |
|--------|--------|----------------|
| `get_class_name()` | Registry lookup | Return the goal's identifier. |
| `is_valid(agent) -> bool` | Every tick (30 Hz) for every unit | Determine eligibility. Must be pure (no side effects). |
| `priority(agent) -> int` | Every tick when evaluating goals | Return priority (higher = more important). |
| `get_desired_state(agent) -> Dictionary` | Planning (goal evaluation) | Return desired facts for the planner. |

## What actions and goals must NOT do

### Actions must not

- **Store per-unit mutable state in the action object.** The action registry creates action instances once and shares them across all units. Per-unit data belongs in the agent's state dictionary or the unit itself.
- **Reimplement movement or combat** when an existing game system already provides it. Use `Goap.move`, `Goap.navigation`, `Goap.get_action(...)`, or unit methods.
- **Modify WorldState** except for explicitly game-state facts (kills, deaths, team changes).
- **Have preconditions that contradict `is_valid()`**. If `is_valid()` requires a fact to be true, the precondition should not require it to be false.
- **Have effects that describe what the action hopes to achieve** rather than what is true after completion. Effects are used by the planner to match goal requirements.

### Goals must not

- **Mutate agent state in `is_valid()`**. This creates order-dependent behavior. `is_valid()` is called 30 Hz for every goal of every unit.
- **Have `get_desired_state()` return an empty dictionary** unless the goal is truly a no-op (e.g., "wait" as a passive goal). An empty desired state causes the planner to return an empty plan.
- **Have priorities that are always equal to other active goals** without a tiebreaker. The agent picks the first goal with the highest priority.

### Both must not

- **Use state keys not documented in `docs/ai/world-state.md`**. New facts must be added to the catalog.
- **Modify the planner or agent lifecycle** unless there is a documented architectural reason.
- **Use stale state keys** (e.g., `stunned` instead of `is_stunned`).

## Reference example: a clean action

Here is `AttackEnemy` as a clean reference implementation:

```gdscript
extends "res://goap/goap_system/action_contract.gd"

func get_class_name():
    return "AttackEnemy"

func is_valid(agent) -> bool:
    var unit = agent.get_unit()
    return unit.attacks and Goap.get_action("ChooseTarget").can_hit(unit, unit.target)

func get_cost(_agent) -> int:
    return 1

func get_preconditions() -> Dictionary:
    return {"enemy_in_attack_range": true}

func get_effects() -> Dictionary:
    return {"enemy_dead": true}

func perform(agent, _delta) -> bool:
    var target = agent.get_unit().target
    if not is_instance_valid(target) or target.dead:
        agent.set_state("enemy_dead", true)
        return true
    var target_in_range = Goap.get_action("ChooseTarget").in_range(agent.get_unit(), target)
    agent.set_state("enemy_in_attack_range", target_in_range)
    return not target_in_range

func enter(agent):
    var unit = agent.get_unit()
    var target = unit.target
    if not is_instance_valid(target) or target.dead:
        agent.set_state("enemy_dead", true)
        return
    if Goap.get_action("ChooseTarget").is_valid_target(unit, target):
        point(unit, target.global_position + target.collision_position)
    else:
        unit.final_destiny = target.global_position
        Goap.navigation.move(unit, target.global_position, false)

func exit(agent):
    var unit = agent.get_unit()
    Goap.move.stop(unit)
```

### Why this is a good reference

- `is_valid()` checks `can_hit(unit, target)` which is consistent with the precondition `enemy_in_attack_range: true`.
- `perform()` sets `enemy_dead: true` when the target is invalid/dead — handling the "target disappeared" case internally by treating it as completion.
- `enter()` uses `ChooseTarget` (the service object) for validation rather than reimplementing range checks.
- `exit()` cleanly stops movement.
- No per-unit mutable state is stored in the action object.
- Effects (`enemy_dead: true`) match what `perform()` actually sets.

## Adding behavior: step-by-step checklist

1. [ ] Read 2-3 similar existing actions or goals.
2. [ ] Check `docs/ai/world-state.md` for required state facts.
3. [ ] Decide: is this an action, a goal, or both?
   - If it's a **goal**, it describes what the agent wants and provides desired facts for planning.
   - If it's an **action**, it describes how the agent achieves something.
   - A goal usually has 0 or more corresponding actions.
4. [ ] Write the script extending the appropriate contract.
5. [ ] Register in the appropriate registry (`action_registry.gd` or `goal_registry.gd`).
6. [ ] If it's a new goal, add it to the agent's `goals_list` in the relevant scene.
7. [ ] Add at least one test in `prototype/tests/unit/` that exercises the new behavior.
8. [ ] Run the full test suite.
9. [ ] Report which checks you ran, which passed, and anything you couldn't verify.
