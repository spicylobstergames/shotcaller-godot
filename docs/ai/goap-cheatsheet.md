# GOAP Cheat Sheet

One-page orientation for the AI. Generated detail: `goap-index.md`. System
map: `../../ARCHITECTURE.md`. Fact catalog: `world-state.md`. Open work:
`../../IMPROVEMENT_PLAN.md`.

## The loop

```
unit.state + WorldState -> Agent._get_best_goal()   (priority, first wins ties)
                        -> Planner.get_plan(agent, goal)   (backward search)
                        -> Agent._follow_plan(): action.perform() until true
                        -> actions call Move/Navigate/combat systems
```

- `Goap.physics_process` runs each unit's agent **every 7th physics tick**
  (60 Hz physics → ~8.6 Hz per unit), and skips dead units.
- **The agent replans only when the goal changes.** No mid-plan revalidation,
  no failure state: `perform()` returns `true`/`false` only.
- Planning runs **before** `goal.enter()`; treat `enter()` as seeing a dirty
  agent.

## Goals

| Goal | Pri | Valid when | Desired fact | Plan |
|------|-----|-----------|--------------|------|
| `ObeyPlayer` | 100 | leader, controllable, non-empty `player_order` | `player_order_complete` | `Order` |
| `Recover` | 10 | `should_retreat` (tactic + hp) | `ready_to_fight` | `Retreat` → `WaitForRegeneration` |
| `NeedSafety` | 10 | enemy in sight (lumberjack only) | `is_threatened: false` | `Hide` |
| `EnemyDefeated` | 6 | a *targetable* enemy is in sight | `enemy_dead` | `ChooseTarget` → `PursueEnemy` → `AttackEnemy` |
| `FriendsSafe` | 5 | an ally in sight is being attacked | `friends_safe` | `HelpFriend` |
| `WalkLane` | 2 | lane set, no target/order/retreat, not channeling | `lane_route_finished` | `Navigate` → `Move` |
| `NeedLumber` | 1 | not hiding/running | `collected_wood` | `GetLumber` → `ReturnLumber` |
| `ArriveAtDestination` | – | never (`is_valid()` is false) | `arrived_at_destination` | service: called by `Collisions` |

Which goals a unit evaluates is **scene data** (`goals_list` on its
`goap_agent` node); `map/spawns.gd` appends `WalkLane` at spawn.

## Actions

| Action | Plannable | Preconditions → effects |
|--------|-----------|-------------------------|
| `AttackEnemy` | yes | `enemy_in_attack_range` → `enemy_dead`, `friends_safe` |
| `ChooseTarget` | yes | `is_stunned: false` → `has_attack_target` |
| `GetLumber` | yes | – → `has_wood` |
| `HelpFriend` | yes | `react_target` → `friends_safe` |
| `Hide` | yes | – → `is_threatened: false` |
| `Move` | yes | `has_destiny`, `is_stunned: false` → `arrived_at_destination`, `lane_route_finished` |
| `Navigate` | yes | `is_stunned: false` → `has_destiny` |
| `Order` | yes | – → `player_order_complete` |
| `PursueEnemy` | yes | `is_stunned: false`, `ready_to_fight`, `has_attack_target` → `enemy_in_attack_range` |
| `Retreat` | yes | – → `arrived_at_retreat` |
| `ReturnLumber` | yes | `has_wood` → `collected_wood` |
| `WaitForRegeneration` | yes | `arrived_at_retreat` → `ready_to_fight` |
| `Conquer` `MeleeAttack` `Mine` `Pray` `RangeAttack` `Taxes` | no | service / signal-driven (`Goap.get_action(...)`) |

## Facts you will touch most

- **Movement:** `has_destiny` (set by `Navigate`, never cleared), `has_path`,
  `arrived_at_destination`, `lane`, `lane_route_finished`, `is_stunned`.
- **Combat:** `target` (lives on `unit.target`), `has_attack_target`,
  `enemy_in_attack_range`, `enemy_dead`, `friends_safe`, `react_target`,
  `ready_to_fight`.
- **Recovery/safety:** `is_retreating`, `arrived_at_retreat`, `is_threatened`,
  `is_hiding`, `hiding_counter`.
- **Orders:** `player_order`, `player_order_complete`, `has_player_command`,
  `player_order_id`, `after_arive`.
- **World:** `is_game_active`, `player_team`/`enemy_team`, `all_units`,
  `player_units`/`enemy_units`, `lanes`, `map`.

## Vocabulary

| Term | Meaning here |
|------|--------------|
| **Goal** | A want, with `priority()` and a `get_desired_state()` fact map. |
| **Action** | A step, with `is_valid()`, `get_cost()`, `get_preconditions()`, `get_effects()`, `enter/perform/exit`. |
| **Fact** | A string-keyed value in agent state or `WorldState`. |
| **Plan** | An ordered action list the planner returns for a goal. |
| **Precondition** | A fact that must hold *before* an action runs. |
| **Effect** | A fact the planner may treat as true *after* the action succeeds. |
| **Service action** | Extends the action contract but is never planned; called directly or from a signal. |
| **Stale fact** | A success fact left `true` after the world changed; makes the planner return an empty plan. |
| **GOAP-GUIDE** | The per-file contract banner; `grep -rl GOAP-GUIDE goap/`. |

## Traps (read before editing)

1. **`null != false`.** A `false` precondition is only satisfied by an
   explicitly set key; typed `-> bool` readers must pass a default.
2. **Stale success facts freeze units.** `EnemyDefeated`/`FriendsSafe` reset
   `enemy_dead`/`friends_safe` in `is_valid()` for exactly this reason; an
   empty plan means "desired state already satisfied" as often as "impossible".
3. **`has_destiny` is never cleared**, so the planner can satisfy `Move`
   without `Navigate`.
4. **No replan on world change.** Only a goal change replans.
5. **Arrival is collision-driven.** `Collisions` calls
   `ArriveAtDestination.on_arrive(unit)` then `unit.on_arrive()` (which emits
   `unit_arrived`, wired once to `Agent.on_arrive`).
6. **The planner does not detect contradictions.** Preconditions overwrite by
   assignment; keep them consistent with goals/ancestors by hand (Track C).
7. **`Move.perform()` is a one-shot**: `true` unless already arrived. Plans are
   re-installed each tick on purpose.
8. **No per-unit state on shared action singletons.** `Taxes` is the
   documented team-scoped exception.
9. **`agent.set_state("target", v)` writes `unit.target`**, not the agent's
   dictionary.
10. **`after_arive`** is a misspelled but load-bearing key (Track D).

## Commands

```bash
# Fast GOAP gate (parse + planner + state-key/contract lint, seconds)
TEST_LOG_DIR="$PWD/.test-logs" ./tests/run_goap_lint.sh /path/to/godot

# Definition of done (unit suite + boot smoke + golden replay + error budget)
TEST_LOG_DIR="$PWD/.test-logs" ./tests/run_suite.sh /path/to/godot

# Regenerate the index after touching a banner
./tools/gen_goap_index.sh /path/to/godot
```

Adding an action or goal: `docs/ai/adding-behavior.md`, then
`./tools/gen_goap_index.sh` and the full suite (bump `EXPECTED_UNIT_TESTS`).
