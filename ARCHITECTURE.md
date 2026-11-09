# Architecture

Shotcaller is a Godot 4 RTS/MOBA hybrid: two teams of units (leaders + pawns)
fight across lanes on a tile map, driven by GOAP (Goal-Oriented Action
Planning) AI. This document is the map an AI agent (or human) needs before
changing anything. Read it fully before editing; the "do not touch" list at
the end marks the landmines.

## Boot flow

`project.godot` main scene is `prototype/game.tscn` → `game.gd`:

1. `game._ready()` wires UI signals, resets WorldState flags, then either
   starts the debug harness (`tests/test_map/test.gd`, when its `debug` flag
   is set) or shows the main menu.
2. `game.start()` initializes all WorldState collections (all_units,
   player_*/enemy_* arrays), sets up timers, loads the map via
   `map_manager.load_current_map()`.
3. The map signals ready through the **minimap** (`ui/minimap.gd
   get_map_texture()` — it snapshots the viewport, then calls
   `map_manager.map_loaded()`). In headless mode the snapshot is skipped
   (`DisplayServer.get_name() == "headless"` guard) — do not remove that
   guard, CI depends on it.
4. `game.map_loaded()` starts the one-second cycle and `spawns.start()`.

## Autoloads (project.godot `[autoload]`, order matters)

| Autoload | Script | Owns |
|----------|--------|------|
| `WorldState` | `goap/game_logic/world_state.gd` | Global key/value store (`get_state`/`set_state`), timers, team rosters. **The cross-file contract layer** — see landmines. |
| `Collisions` | `collision/collisions.gd` | Quadtree + collision queries |
| `Finder` | `map/pathfind/jump_point_finder.gd` | Jump-point pathfinding |
| `Skills` | `skills/passive_skills.gd` | Passive skill lookup (`Skills.leader` table from `skills/resources/leader_passives.tres`), `hit_modifiers` combat resolution |
| `Modifiers` | `skills/modifiers.gd` | Per-unit modifier stacks (hp/speed/damage/...), level scaling |
| `Goap` | `goap/goap_system/goap.gd` | Action planner, action/goal registries, navigation |
| `CraftyCamera` | `controls/crafty_camera.tscn` | Camera control |
| `Utils` | `utils/util.gd` | Misc helpers |

## GOAP flow (the AI core)

```
Agent (goap/goap_system/agent.gd, child of every unit)
  process(delta) every frame:
    _get_best_goal()            — highest-priority valid goal (goal registry)
    goal changed?
      → Goap.get_action_planner().get_plan(agent, goal)   — planner.gd
        matches desired state against real actions' get_effects(),
        chains get_preconditions(), returns cheapest valid plan
      → _replace_plan(goal, plan) — emits goal_changed/plan_changed/action_changed
    _follow_plan(plan, delta)   — calls action.perform(); true → next step;
                                  last step → plan cleared
```

- **Actions** (`goap/game_logic/actions/`, 19 registered in
  `action_registry.gd`): each extends `action_contract.gd` —
  `is_valid(agent)`, `get_cost(agent)`, `get_preconditions()`,
  `get_effects()`, `enter/perform/exit`. Planning uses the first four;
  execution uses the rest.
- **Goals** (`goap/game_logic/goals/`, 8 registered in `goal_registry.gd`):
  `is_valid(agent)`, `priority(agent)`, `get_desired_state(agent)`.
- **Agent** is a Node child of each unit; `agent.get_unit()` returns the
  unit. Units emit signals (`unit_arrived`, `unit_attack_hitted`, ...) that
  the agent connects in `_ready()` — signal names are wiring contracts.
- `WorldState.get_state()` is consulted during *planning* (precondition
  matching reads both agent state and WorldState) — an unset key read through
  a typed `-> bool` return must use `get_state(key, false)`, not bare
  `get_state(key)` (null breaks the type; fixed twice already).

## Unit model

`unit/Unit.gd` (+ `Unit.tscn`) is every fighting entity; leaders/pawns/
neutrals/buildings are scenes under `unit/{leaders,pawns,neutrals,buildings}/`.
Units own: movement (navigation agent + `advance_with_navigation`, dormant
unless `Goap.use_native_pathfinding`), combat state, `current_modifiers`
(stacks consumed by `Modifiers.get_value`), and the signal surface above.
Leaders carry gold/exp and the per-leader passive skill dicts from
`leader_passives.tres` (keys: "arthur", "raja", ...).

## Economy conventions

Team purchases are **collective**: affordability checks pool gold across the
team's leaders, and costs are split evenly (`floor(cost / leaders)` — see
`spawns.gd camp_hire` / `lumberjack_hire`). Do not introduce per-leader
full-cost deduction; a regression test pins the split behavior.

## Map

`map/maps/` holds the tile-map scenes (`three_lane_map` is the battle map).
`map_manager.gd` instantiates the map, creates containers
(`unit_container`, `projectile_container`, `block_container`), sets up
buildings and lanes, and owns `spawns.gd` (spawn timers, cemetery recycling,
camp hiring). `map/tool/mirror_tiles.gd` is a @tool TileMap for the map
editor — its mirror math (`_get_mirrored_coords`) and diff
(`_get_changed_cells`) are regression-tested.

## Tests

`prototype/tests/` — read `tests/README.md` before adding tests, and
`tests/COVERAGE.md` for what is covered. One command verifies everything:
`./prototype/tests/run_suite.sh` (unit suite + boot smoke + script-error
budget). CI runs it on every push.

## Do not touch without understanding

- **WorldState keys are cross-file contracts.** `set_state` keys are read
  from many files with no schema. Before renaming/removing a key, grep it;
  when adding one, note the writer. Tests must restore keys they touch
  (`tests/helpers/world_state_snapshot.gd`).
- **`Modifiers.get_value` is called from everywhere** (movement speed, regen,
  damage). Its unit reads go through `unit.get(property)` with null checks —
  keep them; a bare property access breaks test doubles and optional props.
- **Unit signal names** are wired in `Agent._ready()` and emitted across
  `Unit.gd`, actions, and UI. Renames break silently.
- **The minimap headless guard** (see boot flow) — removing it breaks every
  headless run including CI.
- **`hit_modifiers`' early return**: a unit present in the leader table with
  an EMPTY skill dict returns null (pinned quirk — see
  `test_passive_skills.gd`). Production .tres data must keep non-empty dicts.
- **Typed returns on WorldState reads**: never `return WorldState.get_state(k)`
  from a `-> bool` function.
- **`Skills.leader` and `Goap` registries are singletons** — tests swap them
  (goal spy) and MUST restore before returning.
