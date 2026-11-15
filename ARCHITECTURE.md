# Architecture

Shotcaller is a Godot 4.7 RTS/MOBA hybrid: two teams of units (leaders + pawns)
fight across lanes on a tile map, driven by a GOAP (Goal-Oriented Action
Planning) AI. This document is the map an AI agent (or human) needs before
changing anything. Read it fully before editing; the "do not touch" list at the
end marks the landmines.

> **Verified against `d527203`** (repo-root layout: `project.godot` at the top
> level, tests in `tests/`). Several companion docs still describe the deleted
> `prototype/` tree or an older GOAP API — see **Documentation drift** under
> "Known gaps" before trusting `AGENTS.md`, `docs/ai/*`, or `tests/COVERAGE.md`
> verbatim.

## Boot flow

`project.godot` main scene is `res://game.tscn` → `game.gd`:

1. `game._ready()` wires UI signals, resets WorldState flags, then either
   starts the debug harness (`tests/debug_map.gd`, when its `debug` flag is
   set) or shows the main menu.
2. `game.start()` initializes all WorldState collections (all_units,
   player_*/enemy_* arrays), creates the one-second timer, loads the map via
   `map_manager.load_current_map()`.
3. The map signals ready through the **minimap** (`ui/minimap.gd`): it
   snapshots the viewport, then calls `map_manager.map_loaded()` →
   `map_became_ready` → `game.map_loaded()`. In headless mode the snapshot is
   skipped (`DisplayServer.get_name() == "headless"` guard, `ui/minimap.gd:106`)
   — do not remove that guard, CI depends on it.
4. `game.map_loaded()` starts the one-second cycle and `spawns.start()`.

## Autoloads (project.godot `[autoload]`, order matters)

| Autoload | Script | Owns |
|----------|--------|------|
| `WorldState` | `goap/game_logic/world_state.gd` | Global key/value store (`get_state`/`set_state`), the `second_elapsed` signal, team rosters. **The cross-file contract layer** — see landmines. |
| `Collisions` | `collision/collisions.gd` | Quadtree + collision queries, and the per-tick movement/arrival driver. |
| `Skills` | `skills/passive_skills.gd` | Passive skill lookup (`Skills.leader` table from `skills/resources/leader_passives.tres`), `hit_modifiers` combat resolution. |
| `Modifiers` | `skills/modifiers.gd` | Per-unit modifier stacks (hp/speed/damage/...), level scaling, `get_value` reads. |
| `Goap` | `goap/goap_system/goap.gd` | Action/goal registries, the shared planner, the per-tick agent pump. |
| `CraftyCamera` | `controls/crafty_camera.tscn` (scene) | Camera control. |
| `Utils` | `utils/util.gd` | Misc helpers (building lookup, geometry). |
| `Navigation` | `pathfind/navigation.gd` | JPS path grid (`path_grid`/`path_finder`), path line drawing, `setup_pathfind()`. The old `Finder` autoload is gone. |

## GOAP (the AI core)

**GOAP decides; existing systems perform.** Movement, combat, animation, and
pathfinding are pre-existing systems; actions call into them rather than
reimplementing them.

### The decision loop

```
  Unit / WorldState
        |
        v
  Goap.physics_process(all_units, delta)   [game.gd:170, every physics tick]
        |
        |  per unit: only on its staggered turn (see cadence), and only while
        |  WorldState "is_game_active" is true; dead units are skipped
        v
  Agent.goap_process(delta)                [agent.gd:169]
        |
        |-- _get_best_goal()               highest-priority valid goal (strict >)
        |       goal != current? -> Goap.get_action_planner().get_plan(agent, goal)
        |                            -> _replace_plan(goal, plan)
        |       goal == current? -> _follow_plan(plan, delta)  action.perform()
        v
  Actions call existing systems: Move/Navigate, ChooseTarget/AttackEnemy,
  RangeAttack/MeleeAttack projectiles, OrderAction for player orders.
```

Key properties of this loop (all verified in `agent.gd`):

- **The agent replans only when the *goal identity* changes.** A stale plan is
  never revalidated against the world; if an action can no longer run and the
  goal stays selected, the agent keeps executing it.
- **`_replace_plan` always emits `plan_changed` and `action_changed`;
  `goal_changed` only when the goal actually changed.** `action_changed` is
  wired to `_on_action_changed`, which calls the new action's `enter()`.
- **Goal switching calls `goal.exit()` / `goal.enter()`** (the goal contract
  has both, even though the planner ignores them).

### Cadence (do not trust "30 Hz")

`project.godot` sets `common/physics_fps=30`, but that is the Godot 3 key
name — Godot 4 ignores it and uses `physics/common/physics_ticks_per_second`,
which defaults to **60**. `Engine.physics_ticks_per_second` reports 60 on this
tree. `Goap.physics_process` then throttles each unit:

```gdscript
if unit.agent and !unit.dead:
    if unit.agent.frames_til_next_process == 0:
        unit.agent.goap_process(delta)
        unit.agent.frames_til_next_process = 6   # process every 7th tick
    else:
        unit.agent.frames_til_next_process -= 1
```

`frames_til_next_process` is seeded `randi_range(0, 6)` per agent at `_ready`
to stagger units. Net effect: **each unit evaluates goals at ~8.6 Hz, not 30 Hz
or 60 Hz**, while the physics tick itself is 60 Hz. `docs/ai/*` and `AGENTS.md`
still say 30 Hz. The golden replay is recorded at 60 Hz (`--fixed-fps 60`).

### Agent (`goap/goap_system/agent.gd`)

One `Agent` node (`goap_agent`) is a child of every unit. Responsibilities:

1. **Goals** — loaded from the exported `goals_list` at `_ready()`; `WalkLane`
   is appended at spawn time by `map/spawns.gd:166` (`add_goal`). Each scene
   declares its own list (`unit/pawns/*.tscn`, `unit/leaders/*.tscn`,
   `unit/buildings/*.tscn`, `unit/neutrals/lumberjack.tscn`).
2. **Goal selection** — `_get_best_goal()` iterates the list, calls
   `is_valid(agent)`, and keeps the strict-highest `priority(agent)` (ties go
   to the earlier-registered goal; the incumbent's `priority()` is re-evaluated
   on every comparison).
3. **Plan following** — `_follow_plan` calls `action.perform(agent, delta)`;
   `true` advances to the next step (calling `exit()` first) or, on the last
   step, clears the plan via `_replace_plan(null, [])`.
4. **Local state** — `get_state` / `set_state` / `erase_state` / `clear_state`
   over `_state`. `reset()` (also called on `unit_reseted`) clears the dict but
   preserves `lane` and `tactic`, re-seeds `is_stunned=false`,
   `ready_to_fight` (when the unit attacks), and clears the plan.
5. **Signal glue** — see the wiring table below.
6. **Per-second work** — `WorldState.second_elapsed` → `on_every_second`,
   which dispatches optional `on_every_second` hooks to the current
   action/goal, then calls `unit.regenerate()` and
   `unit.apply_damage_over_time()`.

**`target` is a trap.** `set_state("target", value)` is intercepted and routed
to `ChooseTarget.set_target(agent, value)`, which writes **`unit.target`** —
never `_state["target"]`. No code calls `agent.get_state("target")` (verified);
read `unit.target` instead. The world-state catalog's `target` row implies an
agent-scope key; it is really unit state.

**Actual signal wiring in `Agent._ready()`** (names are contracts):

| Signal | Handler |
|--------|---------|
| `unit_reseted` | `reset` |
| `unit_idle_ended` | `on_idle_end` |
| `unit_stun_ended` | `on_stun_end` |
| `unit_attack_ended` | `on_attack_end` |
| `unit_attack_release` | `on_attack_release` → `RangeAttack.projectile_release` |
| `unit_attack_hitted` | `on_attack_hit` → `MeleeAttack.hit` |
| `unit_death_started` | `on_death_started` → `cancel_player_order` |
| `unit_died` | `on_died` → `RangeAttack.clear_stuck` |
| `unit_animation_ended` | `on_animation_end` |
| `unit_was_attacked` | `was_attacked` |
| `WorldState.second_elapsed` | `on_every_second` |

Not wired: **`unit_arrived` and `unit_move_ended`**. `Unit.on_arrive()` emits
`unit_arrived` (`unit/Unit.gd:369`) but nothing listens, so `Agent.on_arrive()`
— and every action's `on_arrive()` hook — is dead code in production. Arrival
is handled entirely by `Collisions` (next section). This is a live wiring bug,
not a design choice; see Known gaps #1.

`state_changed` is declared `(goal, action)` but emitted with a single
`"Goal Action"` string (`agent.gd:156`); Godot fills the missing arg with null,
so `hud.update_state(text)` receives the combined string. The signature lies.

### Planner (`goap/goap_system/planner.gd`)

Backward search from `goal.get_desired_state(agent)`:

1. For each node, keys of the node's desired state that already match agent
   state (`agent.get_state`, checked first) or WorldState
   (`WorldState.get_state`) are removed. `Object` values are coerced to `true`
   (presence = truthy).
2. If the remaining desired state is empty, the branch is a solution.
3. Otherwise it tries every action whose `get_effects()` value equals a needed
   fact; that action's `get_preconditions()` are merged into the branch's
   desired state; recursion continues.
4. Guard rails: `MAX_PLAN_DEPTH = 64` and a per-branch visited-state set keyed
   by a sorted `_state_signature` (`planner.gd:85-92, 130`).
5. The full solution tree is materialized and the **lowest summed
   `get_cost()`** plan wins (`_transform_tree_into_array` /
   `_get_cheapest_plan`). Ties keep the first-built plan (registry order).

**There is no contradiction check.** Preconditions are merged by dictionary
assignment, so a precondition overwrites a fact the same branch already
requires. Verified empirically: a goal requiring `{b: true, x: true}` with
`MakeX` (`{b: false} → {x: true}`) plus `MakeNotB` (`{} → {b: false}`) yields
the plan `["MakeNotB", "MakeX"]`, which cannot satisfy the goal's `b: true`.
`AGENTS.md` and `docs/ai/architecture.md`/`adding-behavior.md` claim the
planner rejects contradicting branches — it does not (see Known gaps #2).

The planner itself is a **shared singleton** created in `Goap._ready()` with
the registry's action list set once. Multiple planners per faction are a
noted future option but do not exist.

### Contracts and registries

- `goap/goap_system/action_contract.gd` — `is_valid()` (default **true**),
  `get_cost()` (1), `get_preconditions()`/`get_effects()` (`{}`), `enter()`,
  `perform() -> bool` (default `false`), `exit()`. `get_class_name()` is not
  declared on the base; every action defines it for registry lookup.
- `goap/goap_system/goal_contract.gd` — `is_valid()` (true), `priority()` (1),
  `get_desired_state()` (`{}`), `enter()`/`exit()`.
- **19 actions** in `goap/game_logic/action_registry.gd`, **8 goals** in
  `goap/game_logic/goal_registry.gd` (asserted by
  `tests/unit/test_planner_real_actions.gd`).

Planning-relevant vs. service actions:

| Plannable (real preconditions/effects) | Service / signal-driven (never selected) |
|----------------------------------------|------------------------------------------|
| `Move`, `Navigate`, `ChooseTarget`, `PursueEnemy`, `AttackEnemy`, `Retreat`, `WaitForRegeneration`, `Hide`, `HelpFriend`, `GetLumber`, `ReturnLumber` | `RangeAttack`, `MeleeAttack`, `Order`, `Taxes`, `Mine`, `Conquer`, `Pray`, `ChooseTactics` |

`ChooseTarget.is_valid()` is `unit.attacks and !unit.target` — it **is** planned
as a target-acquisition step (e.g. `[ChooseTarget, PursueEnemy, AttackEnemy]`),
so `AGENTS.md`'s "always returns false / not planned" exception is stale. Its
sibling `ChooseTactics` is dead: it extends `Node` (not the action contract),
hard-returns `is_valid() == false`, and is referenced by nothing but the
registry.

### Arrival is collision-driven, not goal-driven

`ArriveAtDestination.is_valid()` hard-returns `false` (activation logic is
commented out; pinned by `tests/unit/test_arrive_at_destination.gd`). It is
registered and present in most `goals_list`s, but it is a **library/service
goal**, not a selectable one. The real arrival machinery lives in the physics
loop:

```gdscript
# collision/collisions.gd:73-80
if unit1.moves and unit1.state == "move":
    if Goap.get_goal("ArriveAtDestination").is_at_destination(unit1):
        Goap.get_goal("ArriveAtDestination").on_arrive(unit1)   # UNIT arg, not agent
    else:
        Goap.get_action("Move").step(unit1, delta)
```

`ArriveAtDestination.on_arrive(unit)` either advances the path via
`Navigate.next(unit)` or, when the path is empty, sets
`has_path=false` / `arrived_at_destination=true` and stops the unit. Note the
argument inconsistency: `Recover.on_arrive(agent)` calls
`ArriveAtDestination.on_arrive(agent)` with the **agent**, while `Collisions`
passes the **unit** — that path is currently dead (see Known gaps #1).

### State facts

The planner matches string keys from four sources: agent `_state`, WorldState,
action preconditions/effects, and goal desired states. `docs/ai/world-state.md`
is the intended catalog, but it has drifted (see Known gaps #3).

- **`null != false`.** A precondition of `false` is not satisfied by an unset
  key; the fact must be explicitly set. Any function with a typed `-> bool`
  return must read `get_state(key, false)`, never bare `get_state(key)`.
- **`has_destiny`, not `has_path`, is Move's precondition.**
  `Move.get_preconditions()` is `{has_destiny: true, is_stunned: false}`
  (`move_action.gd:20`). `Navigate.follow_path` sets `has_destiny = true` and
  **never clears it** (`navigate_action.gd:180`), so after any route the
  planner can skip `Navigate` and emit a bare `[Move]`. `has_path` is still
  written (`follow_path`, `ArriveAtDestination`) but no precondition reads it.
- **Stale-fact resets are load-bearing.** `EnemyDefeated.is_valid` resets
  `enemy_dead` every frame and releases dead/out-of-sight targets;
  `FriendsSafe.is_valid` resets `friends_safe`; `NeedSafety.is_valid` writes
  `is_threatened`. These side effects in `is_valid()` are intentional
  workarounds for the "planner sees a stale success fact and plans nothing"
  class of bug — the fix pattern is always in
  `tests/unit/test_attack_lifecycle.gd`.
- `Move.perform()` is inverted-looking but intentional: it returns `false`
  only when `arrived_at_destination` is already true, otherwise `true`
  (a one-shot step). `WalkLane.enter` and the plan re-install loop are written
  around that behavior.

### Integration boundaries

- **Movement** goes through `Move` / `Navigate`; `Move.step` is the single
  stepping driver and is only called by `Collisions` for `state == "move"`
  units. There is **no** `Goap.move` / `Goap.navigation` convenience API
  (docs/ai/* claim there is); use `Goap.get_action("Move")` /
  `Goap.get_action("Navigate")` or the `Navigation` autoload.
- **Pathfinding** is the `Navigation` autoload: `setup_pathfind()` builds the
  JPS grid and marks building tiles unwalkable; `Navigate.move` returns
  `false` when no route exists (blocked-tile case), and callers fall back to
  a straight-line approach.
- **Combat** is `ChooseTarget` (`can_hit`, `in_range`, `select_target`) plus
  `AttackEnemy`, with `MeleeAttack.hit` and `RangeAttack.projectile_*` invoked
  from unit signals and the collisions loop.
- **Player orders** are `OrderAction.issue_player_order` (`move`, `advance`,
  `attack`, `lane`, `teleport`, `stand`), consumed by the `ObeyPlayer` goal.
  Tactics are player-set strings on agent state (`ui/buttons/tactics_button.gd`,
  `ui/panels/tactics_panel.gd`) consumed by `Recover.should_retreat` and
  `Modifiers`.
- **`Goap`'s public surface** is exactly `get_action_planner()`,
  `get_action()`, `get_goal()`, `physics_process()`, plus inherited
  `get_tree()`.

## Unit model

`unit/Unit.gd` (+ `Unit.tscn`) is every fighting entity; leaders/pawns/
neutrals/buildings are scenes under `unit/{leaders,pawns,neutrals,buildings}/`.
Units own: movement state (`state` ∈ `move`/`idle`/`attack`/`stun`/`death`,
`current_path`, `current_destiny`, `final_destiny`), combat state, hp/regen,
gold/exp, `current_modifiers` (stacks consumed by `Modifiers.get_value`), and
the signal surface above. Stun writes both `is_stunned` (canonical) and the
legacy `stunned` alias (`Unit.gd:483-499`); only `OrderAction` still reads the
alias, defensively. Leaders carry the per-leader passive skill dicts from
`leader_passives.tres`. The native-pathfinding switch
(`Goap.use_native_pathfinding` / `Unit.advance_with_navigation`) no longer
exists — there is one movement path.

## Economy conventions

Hire costs are **split evenly** across the team's leaders
(`floor(cost / leaders)`), but the two hire paths differ in a critical way:
`camp_hire` **pools team gold and refuses the hire when insufficient**,
while `lumberjack_hire` performs **NO affordability check at all** — it
unconditionally deducts its share (cost is hard-coded 1) and can drive
leaders negative. Do not assume a gold gate exists on a hire path; do not
introduce per-leader full-cost deduction. Both behaviors are pinned in
`tests/unit/test_spawns.gd` (camp_hire: refuse + split; lumberjack_hire:
no-gate deduction pinned as a documented quirk).

## Map

`map/maps/` holds the tile-map scenes (`three_lane_map` is the battle map).
`map_manager.gd` instantiates the map, creates containers
(`unit_container`, `projectile_container`, `block_container`), builds lanes,
and emits `map_became_ready`. `spawns.gd` (spawn timers, cemetery recycling,
camp hiring) is a SIBLING node driven by `game.gd` via `%spawn` — map_manager
does not own it; it also assigns `lane`, `tactic`, and the `WalkLane` goal.
`map/tool/mirror_tiles.gd` is a @tool TileMap for the map editor — its mirror
math (`_get_mirrored_coords`) and diff (`_get_changed_cells`) are
regression-tested.

## Tests

`tests/` — read `tests/README.md` before adding tests, and
`tests/COVERAGE.md` for what is covered (its summary counts are stale; trust
`run_suite.sh` and `run_tests.gd`). One command verifies everything:
`./tests/run_suite.sh [godot-binary]` (unit suite + 300-tick boot smoke of the
real game + golden replay + script-error budget). CI runs it on every push.
`run_suite.sh` pins `EXPECTED_UNIT_TESTS` (currently **306**); adding tests
requires bumping it. Test log output defaults to `$PROJECT_DIR/../.test-logs`;
override with `TEST_LOG_DIR` when that location is read-only.

## Architectural invariants

| Invariant | Why it matters |
|-----------|----------------|
| GOAP makes high-level decisions; existing unit systems perform the work. | Prevents duplicated movement and combat logic. |
| An action's preconditions and effects must agree with its runtime behavior. | Prevents plans that look valid but cannot execute. |
| Unit-specific data must not be shared between agents (team-scoped singletons like `ChooseTarget`/`Taxes` are the documented exception). | Prevents cross-unit state leakage. |
| State facts have documented ownership and semantics (`docs/ai/world-state.md`, with drift caveats). | Reduces misspelled keys and incorrect assumptions. |
| Actions and goals must follow the agreed contracts. | Keeps the codebase consistent as more behaviors are added. |
| Planner and lifecycle changes require regression tests. | Protects existing behavior during architectural work. |
| Goal `is_valid()` should not mutate state — the documented exceptions are stale-fact maintenance (`EnemyDefeated`, `FriendsSafe`, `NeedSafety`). | Prevents order-dependent behavior and hidden side effects. |
| `perform()` returning `true` means "advance the plan", not "the world now matches my effects". | Effects are planning claims; runtime cleanup is separate. |

## Do not touch without understanding

- **WorldState keys are cross-file contracts.** `set_state` keys are read
  from many files with no schema. Before renaming/removing a key, grep it;
  when adding one, note the writer. Tests must restore keys they touch
  (`tests/helpers/world_state_snapshot.gd`).
- **The pump is deliberately not a Godot virtual.** `Goap.physics_process(...)`
  is called explicitly from `game.gd`; it is named without an underscore on
  purpose. Keep the stagger and the `!unit.dead` guard.
- **`Modifiers.get_value` is called from everywhere** (movement speed, regen,
  damage). Its unit reads go through `unit.get(property)` with null checks —
  keep them; a bare property access breaks test doubles and optional props.
- **Unit signal names** are wired in `Agent._ready()` and emitted across
  `Unit.gd`, actions, and UI. Renames break silently. (`unit_arrived` is
  already unwired — see Known gaps #1.)
- **The minimap headless guard** (see boot flow) — removing it breaks every
  headless run including CI.
- **`hit_modifiers`' early return**: a unit present in the leader table with
  an EMPTY skill dict returns null (pinned quirk — see
  `test_passive_skills.gd`). Production .tres data must keep non-empty dicts.
- **Typed returns on state reads**: never `return WorldState.get_state(k)`
  from a `-> bool` function; use `get_state(k, false)`.
- **`Skills.leader` and `Goap` registries are singletons** — tests swap them
  (goal spy) and MUST restore before returning.
- **`agent.set_state("target", v)` is not a normal state write** — it mutates
  `unit.target` through `ChooseTarget.set_target` and triggers
  attack-count/modifier side effects. Do not "simplify" it without auditing
  every caller.
- **Arrival is collision-driven.** `ArriveAtDestination.is_valid()` is pinned
  false and `Collisions` calls `is_at_destination`/`on_arrive` directly. Do not
  re-enable the goal's activation without a golden re-record and new tests.

## Known gaps and improvement candidates

Verified on `d527203`. Each item lists evidence and a proposed direction; none
is fixed yet. Ordered by expected impact.

1. **Arrival dispatch is broken (dead `on_arrive` hooks).** `Unit.on_arrive()`
   emits `unit_arrived`, but no one connects it; `Agent.on_arrive()` has no
   caller. Consequently `Hide.on_arrive`, `GetLumber.on_arrive` (sets
   `has_wood`), `ReturnLumber.on_arrive`, `RetreatAction.on_arrive` (sets
   `arrived_at_retreat`), and `OrderAction.on_arrive` (conquer/pray) never fire
   in production. `tests/unit/test_arrive_at_destination.gd` and
   `test_action_lifecycles.gd` exercise arrival by calling goal/action methods
   directly, so the suite is green while the wiring is absent.
   *Direction:* connect `unit_arrived` → `Agent.on_arrive` (single connection;
   do **not** also connect `OrderAction.on_arrive` — the old double-connect bug
   in `docs/ai/architecture.md`), or call `Agent.on_arrive` from the collision
   branch. Add a boot-level regression that a lumberjack actually obtains
   `has_wood`, and a unit-level test that the signal reaches the action.
2. **The planner has no contradiction check, but the docs say it does.**
   `planner.gd:110-112` merges preconditions by assignment; empirically a goal
   `{b: true, x: true}` plans `["MakeNotB", "MakeX"]` (which falsifies `b`).
   `AGENTS.md`, `docs/ai/architecture.md`, and `docs/ai/adding-behavior.md`
   describe rejection of contradicting branches.
   *Direction:* either implement contradiction rejection (reject a branch when
   a new precondition conflicts with an existing unsatisfied requirement, and
   when it conflicts with an ancestor requirement) with dedicated
   `test_planner.gd` cases, or document the limitation and audit actions whose
   preconditions assume the check. Planner behavior changes → golden re-record
   with a stated reason (D6/D12).
3. **Documentation drift across every AI doc.** `AGENTS.md` claims 30 Hz,
   `ChooseTarget` is an always-false non-action, `Move` requires
   `has_path: false`, `Goap.move`/`Goap.navigation` exist, `goal_contract.gd`
   references `keep_fed.gd`, and `move_action.smart` checks `stunned` — none of
   which is true (`ChooseTarget` is planned; `Move` requires `has_destiny`;
   there is no `smart`; no `keep_fed` reference). `docs/ai/architecture.md`
   describes a `unit_arrived` double-connect and 30 Hz. `tests/COVERAGE.md`
   says 255 assertions / 20 classes; the suite reports 306 / 23.
   `tests/run_tests.gd`'s header says the GOAP suites are "DEFERRED" while all
   23 are registered. *Direction:* one documentation-truth pass, with each doc
   pointing at this file and `docs/ai/world-state.md` as the single source for
   state facts.
4. **Stale-fact lifecycle is ad hoc.** `has_destiny` is set by
   `Navigate.follow_path` and never cleared; `arrived_at_destination` is set
   in several places. This exact class has already caused multiple frozen-unit
   regressions (see `tests/COVERAGE.md` "Known bugs").
   *Direction:* define and document a per-plan/per-goal fact reset contract
   (who clears what, when), or track `has_destiny` on the unit path object
   rather than agent state.
5. **State keys are untyped string literals.** Misspellings break planning
   silently (the `stunned` alias, `collected_wood` vs `has_wood`,
   `after_arive` typo) and several keys are undocumented:
   `opponents_in_sight` (written per frame by `EnemyDefeated`, never read),
   `after_arive`, `resume_path`/`lane_resume_path` (writers/erasers only,
   readers commented out), `move`/`attack`/`idle`/`death` on agent state.
   *Direction:* state-key constants plus a completeness test that greps
   `set_state("...")` keys against the catalog.
6. **`ReturnLumber.enter` cannot work.** `return_lumber.gd:25` does
   `unit.current_destination = agent.set_state("deliver_position")` —
   `set_state` returns null, and `Unit` has no `current_destination`
   property; the action also never calls `Navigate`/`Move`, so it cannot
   reach the mill. Reachability is currently masked by gap #1.
   *Direction:* replace with `Navigate.move(unit, agent.get_state("deliver_position"))`
   and add a lumberjack integration test.
7. **Dead/duplicated plumbing.** `ChooseTactics` is unreferenced dead code
   (extends `Node`, always invalid). `opponents_in_sight` allocates an array
   per enemy-goal evaluation for no consumer. `state_changed` is emitted with
   one arg against a two-arg declaration. `WorldState.setup_timers()` creates
   and adds a new `Timer` on every `game.start()` while `clear_state()` does
   not stop the old ones.
   *Direction:* delete or implement `ChooseTactics`; drop or consume
   `opponents_in_sight`; make `state_changed` match its emission; make timer
   setup idempotent.
8. **Corpse and growth costs.** Dead units stay in `all_units` (the pump now
   skips them, but `WorldState.second_elapsed` → `Agent.on_every_second` still
   fires for every corpse, and `all_units` grows monotonically with wave
   spawns). `DECISIONS.md` D13 measured an fps collapse as the list grows.
   *Direction:* disconnect/guard per-second work for dead agents and/or
   revisit the `all_units` ownership question with a `--perf` before/after
   (D13 re-entry criteria).
9. **Planner cost/scale.** Every replan enumerates the full solution tree and
   only then picks the cheapest; `_get_best_goal` re-calls `priority()` on the
   incumbent each comparison. With ~127 units replanning at ~8.6 Hz this is the
   hottest AI path. *Direction:* measure first (`tests/perf_monitor.gd`),
   then consider branch-and-bound / cheapest-first search and caching
   `priority()` once per goal per evaluation.
10. **Order-cancellation test tests the mock.** `tests/unit/test_order_action.gd`
    asserts `player_order_cancelled`, a key set only by its own `TestAgent`
    double; production `Agent.cancel_player_order()` sets
    `player_order_complete`/`has_player_command`. *Direction:* assert the
    production keys (and drive the real `Agent` where cheap), per the
    tests/README "never test the mock" rule.
