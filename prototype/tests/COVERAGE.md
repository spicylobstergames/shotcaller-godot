# Test Coverage Analysis

## Current state

**18 test classes**, **231 individual assertions**, all passing. Running headless via `res://tests/test_runner.tscn`.
**96 GDScript files** in the project, 330+ public methods not directly tested.

## Test suite results

```
godot --headless --path prototype res://tests/test_runner.tscn
→ All 231 tests passed.
```

New test classes (6, added in this session):
| Test File | Coverage Target | Lines | Assertions | Status |
|-----------|----------------|-------|------------|--------|
| `test_modifiers.gd` | `skills/modifiers.gd` — all public methods | ~180 | ~35 | ✅ PASS |
| `test_passive_skills.gd` | `skills/passive_skills.gd` — hit_modifiers, get_value | ~185 | ~20 | ✅ PASS |
| `test_spawns.gd` | `map/spawns.gd` — costs, cemitery, lane tactics | ~195 | ~22 | ✅ PASS |
| `test_goal_interactions.gd` | Goal contracts — priority, validity, independence | ~175 | ~25 | ✅ PASS |
| `test_mirror_tiles.gd` | `map/tool/mirror_tiles.gd` — coordinate math, cell diff | ~160 | ~28 | ✅ PASS |
| `test_action_lifecycles.gd` | `RetreatAction` + plan following | ~220 | ~18 | ✅ PASS |

Existing test classes (12, unchanged):
| Test File | Coverage Target | Status |
|-----------|----------------|--------|
| `test_arrive_at_destination.gd` | Arrival goal lifecycle | ✅ PASS |
| `test_attack_priorities.gd` | ChooseTarget priorities | ✅ PASS |
| `test_agent_signals.gd` | Agent signal wiring | ✅ PASS |
| `test_agent_target.gd` | Target selection | ✅ PASS |
| `test_agent_tactic.gd` | Tactic speed bonuses | ✅ PASS |
| `test_collisions.gd` | Quadtree + geometry helpers | ✅ PASS |
| `test_movement.gd` | Physics movement step | ✅ PASS |
| `test_navigation.gd` | Pathfinding + navigation | ✅ PASS |
| `test_order_action.gd` | Order completion flow | ✅ PASS |
| `test_orders_panel_signal.gd` | Orders panel signals | ✅ PASS |
| `test_planner.gd` | GOAP planner | ✅ PASS |

## Coverage matrix

### GOAP Actions (19 registered)

| Action | Has Tests | Coverage |
|--------|-----------|----------|
| AttackEnemy | ✅ | Medium |
| ChooseTarget | ✅ | Medium |
| ConquerAction | ❌ | — |
| GetLumber | ❌ | — |
| HelpFriend | ❌ | — |
| Hide | ❌ | — |
| MeleeAttack | ❌ | — |
| MineAction | ❌ | — |
| MoveAction | ✅ | Low |
| NavigateAction | ✅ | Low |
| OrderAction | ✅ | Medium |
| PrayerAction | ❌ | — |
| PursueEnemy | ❌ | — |
| RangeAttack | ❌ | — |
| RetreatAction | ✅ | Low | enter/perform/exit/cost/effects |
| ReturnLumber | ❌ | — |
| TaxesAction | ❌ | — |
| WaitForRegeneration | ❌ | — |
| WaitOut | ❌ | — |

### GOAP Goals (8 registered)

| Goal | Has Tests | Coverage |
|------|-----------|----------|
| ArriveAtDestination | ✅ | Medium |
| EnemyDefeated | ❌ | — |
| FriendsSafe | ❌ | — |
| NeedLumber | ❌ | — |
| NeedSafety | ❌ | — |
| ObeyPlayer | ❌ | — |
| Recover | ✅ | Low |
| WalkLane | ❌ | — |

### Systems

| System | Coverage | Notes |
|--------|----------|-------|
| Spawns | Low | Costs, cemitery keys, lane tactics tested |
| MapManager | ❌ | No tests |
| Modifiers | **High** | All public methods tested |
| PassiveSkills | **High** | Combat math tested |
| Quadtree | Medium | 1 test in collisions |
| Pathfinder | ✅ | Covered in navigation |

### Map Editor

| Method | Tests | Coverage |
|--------|-------|----------|
| `_get_mirrored_coords()` | ✅ | Multiple map sizes, involution, reversibility |
| `_get_changed_cells()` | ✅ | Add/remove/same/empty |
| `_get_cell_snapshot()` | ❌ | Requires TileMap |
| `_sync_mirrored_cells()` | ❌ | Requires TileMap |

### Goal Interactions

| Aspect | Tests | Coverage |
|--------|-------|----------|
| Priority ordering | ✅ | Higher priority wins |
| Validity filtering | ✅ | Invalid goals excluded |
| State independence | ✅ | Checking one goal doesn't corrupt another |
| Desired state consistency | ✅ | Each goal returns correct state |
| Conditional validity | ✅ | Dependency-based gating |

### Action Lifecycle

| Aspect | Tests | Coverage |
|--------|-------|----------|
| RetreatAction enter/perform/exit | ✅ | Full lifecycle |
| RetreatAction effects/cost | ✅ | Correct values |
| Plan following | ✅ | Step advancement, completion |

## Remaining high-priority gaps

1. **Spawns** — `send_pawn()` full path (needs Godot node mock)
2. **MapManager** — `setup_buildings()` / `setup_lanes()` (needs TileMap)
3. **Remaining actions** — PursueEnemy, GetLumber, ReturnLumber, Hide, WaitOut, TaxesAction, PrayerAction, MineAction, ConquerAction
4. **Remaining goals** — EnemyDefeated, WalkLane, NeedSafety, ObeyPlayer, FriendsSafe, NeedLumber
5. **Integration tests** — bridge between unit tests and real Godot scenes

## Recommended next steps

1. **Pick a pilot feature** (e.g., Guard Building) — exercises new goal + 1-2 actions
2. **One branch, one feature** — investigate → written plan → implement → test → review
3. **Continue adding tests** for remaining uncovered systems
