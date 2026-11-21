# World-State Catalog

## How to read this catalog

Every string-keyed state fact used by the GOAP planner and the game is listed below. For each key:

| Field | Description |
|-------|-------------|
| **Scope** | Where the value lives: `agent` (per-unit local state), `world` (WorldState singleton), or `both` (shared by both). |
| **Type** | Expected type: `bool`, `int`, `String`, `Object`, `Array`, `Dictionary`, `Vector2`. |
| **Default** | What absence means when the key is not set. |
| **Producer** | Who sets or updates the value. |
| **Consumer** | Who reads the value (goals, actions, planner, other systems). |
| **Lifecycle** | When the key is cleared, reset, or invalidated. |

> **Drift warning:** this catalog was written against an older revision. Line
> numbers are approximate and several entries are stale (notably `has_path`,
> `target`, `stunned`, and the `ArriveAtDestination` producer list). Verify any
> entry against the current code before relying on it; `ARCHITECTURE.md` is the
> verified system map and `IMPROVEMENT_PLAN.md` Track D tracks the cleanup.

## Important: the `null` vs `false` rule

When the planner checks a fact, it reads `agent.get_state(key)`. If the key is **not set**, this returns `null`. In GDScript, `null != false`. Therefore:

- A precondition of `false` (e.g., `{"has_path": false}`) is **not** satisfied by an unset key.
- The fact must be **explicitly set** to `false` for the precondition to match.
- This matters for any precondition or desired state whose expected value is `false` (for example `has_path: false`, `enemy_dead: false`): the fact must be written explicitly. `ArriveAtDestination.is_valid()` hard-returns `false` and no longer maintains `has_path`; `Move`'s real precondition is `has_destiny: true`.

## State facts

### Agent-specific facts

#### `target`
- **Scope:** unit (`agent.set_state("target", …)` is intercepted and routed to `ChooseTarget.set_target`, which writes `unit.target`; the agent's own dictionary never holds it)
- **Type:** Object (Node) or null
- **Default:** null (no target)
- **Producer:** `ChooseTarget.set_target()` via `agent.set_state("target", …)`; `AttackEnemy.point()`; `NavigateAction.point()`; `OrderAction`
- **Consumer:** `EnemyDefeated` (validity, desired state), `AttackEnemy` (is_valid), `NavigateAction.point()`, `WalkLane.is_valid()`, `ChooseTarget.is_valid()`
- **Lifecycle:** Set on goal selection or order; cleared on death, retreat, or when no valid target exists. Clears attack count and attack speed modifiers and sets `hunting`/`has_attack_target`.

#### `has_attack_target`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Consumer:** `PursueEnemy` (precondition)
- **Lifecycle:** Set to `target != null` whenever `target` changes.

#### `hunting`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Consumer:** `Modifiers` (attack speed bonus)
- **Lifecycle:** Set to `target != null and unit.moves` when target is set; cleared when target is cleared or unit stops moving.

#### `has_path`
- **Scope:** agent
- **Type:** bool
- **Default:** false (but see `null` vs `false` rule above)
- **Producer:** `NavigateAction.follow_path()` (sets true), `ArriveAtDestination.advance_path()` (sets false on the final arrival).
- **Consumer:** Nothing in the planner — no `get_preconditions()` reads `has_path`, and `Move.is_valid()` is `unit.moves`. It survives as bookkeeping for movement/UI.
- **Lifecycle:** Set true when a path is queued; set false when the route's final waypoint is consumed.

#### `has_destiny`
- **Scope:** agent
- **Type:** bool
- **Default:** false (but see `null` vs `false` rule above)
- **Producer:** `NavigateAction.follow_path()` (sets true); **cleared by** `MoveAction.stop()` and by the final arrival (`ArriveAtDestination.advance_path()`).
- **Consumer:** `MoveAction.get_preconditions()` (`has_destiny: true`)
- **Lifecycle:** Set when a route is queued; cleared when movement stops or the route is consumed — so the planner orders `Navigate` before `Move` deterministically instead of skipping `Navigate` on a stale fact.

#### `arrived_at_destination`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `ArriveAtDestination.advance_path()` (latches true on the FINAL arrival, i.e. when the path is empty); **reset to false** by `MoveAction.move()` and `NavigateAction.follow_path()` on any newly issued movement.
- **Consumer:** The arrival effects of plan actions (`GetLumber`, `Hide`, `ReturnLumber`, `Retreat`, `Order._dispatch_arrival`), `ArriveAtDestination` (desired state).
- **Lifecycle:** The final-arrival latch: actions must observe THEIR OWN arrival, never a stale one — any new movement revokes it, and the next collision-driven arrival re-latches it.

#### `enemy_dead`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `EnemyDefeated.is_valid()` (line 28-29), `AttackEnemy.enter()` (line 39), `AttackEnemy.perform()` (line 28)
- **Consumer:** `EnemyDefeated` (desired state), `AttackEnemy` (precondition — via `enemy_dead: true`)
- **Lifecycle:** Set to `true` when the target's HP drops to zero; set to `false` every frame by `EnemyDefeated.is_valid()`.

#### `enemy_in_attack_range`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `AttackEnemy.perform()` (line 31), `PursueEnemy.enter()` (line 17), `PursueEnemy.perform()` (line 28)
- **Consumer:** `AttackEnemy` (precondition)
- **Lifecycle:** Set based on `ChooseTarget.in_range(unit, target)`.

#### `has_player_command`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `OrderAction.enter()` (line 33), `ConquerAction` (line 47), `PrayerAction` (line 31)
- **Consumer:** `WalkLane.is_valid()` (line 15), `ArriveAtDestination.is_at_destination()` (line 33)
- **Lifecycle:** Set when a player order is given; cleared when the order completes or is cancelled.

#### `player_order`
- **Scope:** agent
- **Type:** Dictionary (e.g., `{"type": "move", "target": ...}`)
- **Default:** empty dict
- **Producer:** `OrderAction.enter()`
- **Consumer:** `ObeyPlayer.is_valid()` (reads type), `OrderAction` (reads type)
- **Lifecycle:** Set when a player order is given; cleared when the order completes or the unit dies.

#### `player_order_complete`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `OrderAction.perform()` (line 69), `MoveAction.teleport()` (line 203)
- **Consumer:** `ObeyPlayer` (desired state)
- **Lifecycle:** Set to `true` when the order is fulfilled; set to `false` in `cancel_player_order()`.

#### `player_order_attack_ended`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `Agent.on_attack_end()` (line 255), `Agent.cancel_player_order()` (line 274)
- **Consumer:** `OrderAction` (checks in perform)
- **Lifecycle:** Set when a player attack order completes; reset on cancel.

#### `player_order_id`
- **Scope:** agent
- **Type:** int
- **Default:** 0
- **Producer:** `OrderAction.enter()` (increments)
- **Consumer:** `OrderAction` (checks order identity), `MoveAction.teleport()` (checks order identity)
- **Lifecycle:** Incremented each time a new order is given. Used to detect stale teleports.

#### `is_stunned`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `Unit.stun()` / `Unit.unstun()` (sets `is_stunned`; also sets `stunned` as a stale alias)
- **Consumer:** `MoveAction.is_valid()` / `point()` / `move()` / `resume()` / `smart()`, `NavigateAction.is_valid()` / `point()`, `AttackEnemy.point()`, `ConquerAction`, `PrayerAction`, `OrderAction` (checks stun state)
- **Lifecycle:** Set to `true` when stunned; set to `false` when the stun timer expires.

#### `stunned` (stale alias)
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `Unit.stun()` / `Unit.unstun()` (sets both `stunned` and `is_stunned`)
- **Consumer:** `OrderAction` reads it defensively alongside `is_stunned` (`order_action.gd:102,138`). Nothing else reads it; **consider removing the alias** (Track D).
- **Lifecycle:** Same as `is_stunned`. **Consider removing this alias.**

#### `is_retreating`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `RetreatAction.enter()` (line 26), `Recover.is_valid()` (line 17), `WaitForRegeneration.perform()`, `WaitOut.perform()`
- **Consumer:** `WalkLane.is_valid()` (line 16), `MoveAction.end()` (line 146), `Modifiers` (attack speed penalty)
- **Lifecycle:** Set when retreat begins; cleared when the unit reaches retreat position or when `MoveAction.end()` is called.

#### `arrived_at_retreat`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `RetreatAction.perform()` (latched from `arrived_at_destination` on the final arrival)
- **Consumer:** `RetreatAction.perform()`, `Recover` (desired state)
- **Lifecycle:** Set when the unit reaches its retreat position (final arrival); reset by `Recover.enter()`.

#### `cutting`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `GetLumber.perform()` (latched when the cut channel starts on the final arrival), cleared by `GetLumber.exit()`
- **Consumer:** `GetLumber.perform()` (one cut session per latch)
- **Lifecycle:** True while the lumberjack's cut channel is running; cleared by `exit()` (goal switch) or `reset()`.

#### `cutting_id`
- **Scope:** agent
- **Type:** int (session token)
- **Default:** 0
- **Producer:** `GetLumber.perform()` (increments per cut session) and `GetLumber.exit()` (increments to INVALIDATE the current session)
- **Consumer:** `GetLumber._cut()` via `_session_is_current()` (the channel-await continuation pays `has_wood` only if its OWN session id is still current)
- **Lifecycle:** Monotonic per agent; `exit()` bumps it so an abandoned continuation is a no-op even when NO new session starts before the shared `channeling_timer` fires (exit-without-re-entry). A re-entry bumps it again for the fresh session.

#### `is_channeling`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `MoveAction.teleport()`, `ConquerAction`, `MineAction`, `PrayerAction`
- **Consumer:** `ConquerAction`, `PrayerAction`, `MoveAction.teleport()`, `WalkLane.is_valid()` (line 17)
- **Lifecycle:** Set when a channeling action starts (teleport, conquer, mine, pray); cleared when the channel completes or is interrupted.

#### `being_attacked`
- **Scope:** agent
- **Type:** int (timer, decremented per frame)
- **Default:** 0 (not being attacked)
- **Producer:** `Agent.was_attacked()` (line 279)
- **Consumer:** `Agent.on_animation_end()` (decrements)
- **Lifecycle:** Set to `attacked_timer` (2) when the unit is attacked; decremented each frame in `on_animation_end()`.

#### `attacker`
- **Scope:** agent
- **Type:** Object (Node) or null
- **Default:** null
- **Producer:** `Agent.was_attacked()` (line 280)
- **Consumer:** `FriendsSafe.is_valid()` (checks allies being attacked by same attacker)
- **Lifecycle:** Set when the unit is attacked; cleared when `being_attacked` reaches 0.

#### `tactic`
- **Scope:** agent
- **Type:** String (e.g., `"default"`, `"attack"`, `"defend"`, `"retreat"`, `"hide"`)
- **Default:** `"default"`
- **Producer:** `Agent._ready()` (line 25), player UI (tactic buttons in `order_button.gd`)
- **Consumer:** `Recover.is_valid()` (line 36 — tactic-based goal selection)
- **Lifecycle:** Set once at unit spawn; changed by player via UI.

#### `lane`
- **Scope:** agent
- **Type:** String (lane name)
- **Default:** none
- **Producer:** `Agent.reset()` (line 106 — preserves on reset), `NavigateAction.change_lane()`, `MapManager` (on building spawn), `MapSpawns.spawn_leader()`
- **Consumer:** `WalkLane`, `RetreatAction`, `ChooseTarget`, `OrderButton` (tactic buttons), `MapSpawns`
- **Lifecycle:** Set when a leader is spawned or changes lane; preserved across resets.

#### `lane_route`
- **Scope:** agent
- **Type:** String (lane name)
- **Default:** none
- **Producer:** `WalkLane.is_valid()` (line 22)
- **Consumer:** `WalkLane.is_valid()` (line 21 — checks if route matches current lane)
- **Lifecycle:** Set when the goal re-evaluates and the lane changes; cleared when the route finishes.

#### `lane_route_finished`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `WalkLane.is_valid()` (erases), `WalkLane.enter()`, `WalkLane.change_lane()` (resets false)
- **Consumer:** `WalkLane.is_valid()` (line 25)
- **Lifecycle:** Erased when lane changes; set to `true` when the lane path is fully traversed.

#### `is_hiding`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `Hide.perform()` (line 30, 40)
- **Consumer:** `NeedLumber.is_valid()` (line 10)
- **Lifecycle:** Set to `true` when the unit stops moving; cleared when it resumes or is threatened.

#### `is_running`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `Hide.perform()` (line 33)
- **Consumer:** (internal to Hide action)
- **Lifecycle:** Set when the unit runs from cover; cleared when it hides.

#### `hide_threatened`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `Hide.perform()` (line 29)
- **Consumer:** (internal to Hide action)
- **Lifecycle:** Set when the hiding unit is threatened by an attacker.

#### `hiding_counter`
- **Scope:** agent
- **Type:** int
- **Default:** 0
- **Producer:** `Hide.perform()` (line 26, 28)
- **Consumer:** `Hide.perform()` (line 31 — checks counter against unit.wait_time)
- **Lifecycle:** Reset when hiding; incremented each tick while hiding.

#### `is_threatened`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `NeedSafety.is_valid()` (lines 13, 20), `Hide.perform()` (line 34)
- **Consumer:** `NeedSafety` (desired state)
- **Lifecycle:** Set when enemies are detected; cleared when threat is gone.

#### `ready_to_fight`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `Recover.is_valid()` (line 19), `WaitForRegeneration.perform()`, `WaitOut.perform()`
- **Consumer:** `Recover` (desired state)
- **Lifecycle:** Set to `true` when the unit has recovered (retreated, regen'd, or waited out); set to `false` when retreating begins.

#### `friends_safe`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `FriendsSafe.is_valid()` (line 11)
- **Consumer:** `FriendsSafe` (desired state)
- **Lifecycle:** Set to `false` when an ally is being attacked; set to `true` when the action completes.

#### `react_target`
- **Scope:** agent
- **Type:** Object (Node) or null
- **Default:** null
- **Producer:** `FriendsSafe.is_valid()` (line 10), `HelpFriend.perform()` (line 14)
- **Consumer:** `HelpFriend` (precondition, perform)
- **Lifecycle:** Set when a friendly is attacked; cleared after the response action completes.

#### `has_wood`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `GetLumber._cut()` (after the cut timer, only while `cutting` is latched; `perform()` only reads it)
- **Consumer:** `ReturnLumber` (precondition)
- **Lifecycle:** Set to `true` when lumber is collected; set to `false` when delivered.

#### `collected_wood`
- **Scope:** agent (goal desired state)
- **Type:** bool
- **Default:** false
- **Producer:** `ReturnLumber.get_effects()` (planning claim; `perform()` sets `returning_wood` and clears `has_wood` on the final arrival)
- **Consumer:** `NeedLumber.get_desired_state()`
- **Lifecycle:** A planning goal fact, not a runtime flag; `ReturnLumber`'s completion is what satisfies it.

#### `returning_wood`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `ReturnLumber.perform()` (latched on the final arrival)
- **Consumer:** `ReturnLumber` (perform check), `ReturnLumber.exit()` (clears)
- **Lifecycle:** Set ONCE when the unit completes the final arrival at `deliver_position` (the delivery: clears `has_wood`, heals buildings); cleared by `exit()`.

#### `closest_tree`
- **Scope:** agent
- **Type:** Vector2
- **Default:** none
- **Producer:** `MapSpawns.spawn_lumberjack()`
- **Consumer:** `GetLumber.perform()`
- **Lifecycle:** Set once when the lumberjack is spawned; never cleared.

#### `deliver_position`
- **Scope:** agent
- **Type:** Vector2
- **Default:** none
- **Producer:** `MapSpawns.spawn_lumberjack()`
- **Consumer:** `GetLumber.perform()`, `ReturnLumber.perform()`
- **Lifecycle:** Set once when the lumberjack is spawned; never cleared.

#### `lumberjack`
- **Scope:** agent
- **Type:** Object (Node) or null
- **Default:** null
- **Producer:** `MapSpawns.spawn_lumberjack()` (sets on lumbermill)
- **Consumer:** `OrderButton.dismiss_lumberjack()`
- **Lifecycle:** Set when a lumberjack is hired; cleared when dismissed.

#### `lumbermill`
- **Scope:** agent
- **Type:** Object (Node) or null
- **Default:** null
- **Producer:** `MapSpawns.spawn_lumberjack()`
- **Consumer:** `OrderButton.dismiss_lumberjack()`
- **Lifecycle:** Set on lumbermill building; cleared when the lumberjack is dismissed.

#### `target_priority`
- **Scope:** agent
- **Type:** Array (of Strings: `"pawn"`, `"leader"`, `"building"`)
- **Default:** `["pawn", "leader", "building"]`
- **Producer:** `ChooseTarget.set_unit_priority()` (line 65)
- **Consumer:** `ChooseTarget.select_target()` (line 135)
- **Lifecycle:** Set when `ChooseTarget.prioritize_unit()` is called; preserved across resets.

#### `death`
- **Scope:** agent
- **Type:** bool (stale — the unit's `dead` flag is used instead)
- **Default:** false
- **Producer:** `Unit.die()` (calls `set_state("death")`)
- **Consumer:** (not actively used; `Unit.dead` is checked instead)
- **Lifecycle:** Set on death. **Consider removing — use `Unit.dead` directly.**

#### `idle`, `attack`, `move`
- **Scope:** agent
- **Type:** bool
- **Default:** false
- **Producer:** `Unit.set_state()`, `MoveAction.move()` (sets `move`), `MoveAction.stop()` (sets `idle`), `AttackEnemy.point()` (sets `attack`)
- **Consumer:** (internal unit state machine, not consumed by GOAP)
- **Lifecycle:** Set/cleared as the unit transitions between movement states.

### Undocumented, dead, or duplicate keys (Track D)

- `opponents_in_sight` — written every frame by `EnemyDefeated.is_valid()`
  (`enemy_defeated.gd:38`), never read. Allocates a full sight list per enemy
  goal evaluation for no consumer.
- `after_arive` (typo for `after_arrive`) — set by `OrderAction`,
  `Conquer`, and `Pray`; read by `OrderAction._dispatch_arrival` (on the final arrival).
- `resume_path` / `lane_resume_path` — written/erased by `WalkLane` and
  `MoveAction.teleport`, but their readers in `NavigateAction` are commented
  out.
- `death` — set by `Unit.die()`; superseded by `Unit.dead`.
- `move` / `attack` / `idle` — unit animation state set through
  `Unit.set_state()`; not consumed by the planner.
- `arrived_at_retreat` was listed twice in this catalog; the
  `RetreatAction` entry above is the canonical one.

### WorldState facts

#### `player_team`, `enemy_team`
- **Scope:** world
- **Type:** String (`"blue"`, `"red"`)
- **Default:** none
- **Producer:** Menu screens (`main_menu.gd`, `new_game_menu.gd`), `ConquerAction` (line 67)
- **Consumer:** Everywhere — team checks, enemy lists, building lists, tax logic.
- **Lifecycle:** Set at game start; `player_team` may change when a building is conquered.

#### `game_started`, `game_ended`, `is_game_active`
- **Scope:** world
- **Type:** bool
- **Default:** `game_started: false`, `game_ended: false`, `is_game_active: false`
- **Producer:** `game.gd` (start/end logic)
- **Consumer:** `game.gd` (state checks), `WaitOut.is_valid()`, various UI controls
- **Lifecycle:** Set to `true` when the game begins; `game_ended: true` when the game ends; `is_game_active` toggled by pause/resume.

#### `game_mode`
- **Scope:** world
- **Type:** String (`"campaign"`, `"match"`)
- **Default:** none
- **Producer:** Menu screens
- **Consumer:** `DialogPanel` (campaign logic)
- **Lifecycle:** Set at game start.

#### `time`
- **Scope:** world
- **Type:** int (game time in seconds)
- **Default:** 0
- **Producer:** `game.gd` (increments each tick)
- **Consumer:** `game.gd` (HUD display)
- **Lifecycle:** Reset at game start; incremented each tick.

#### `player_kills`, `enemy_kills`, `player_deaths`, `enemy_deaths`
- **Scope:** world
- **Type:** int
- **Default:** 0
- **Producer:** `EnemyDefeated.take_hit()` (lines 94-100)
- **Consumer:** `game.gd` (HUD display)
- **Lifecycle:** Reset at game start; incremented on unit death.

#### `all_units`, `all_buildings`, `all_leaders`
- **Scope:** world
- **Type:** Array[Node]
- **Default:** empty arrays
- **Producer:** `game.gd` (line 288-312 — populates on game start), `MapManager` (appends buildings), `MapSpawns` (appends units)
- **Consumer:** Everywhere — collision checks, targeting, AI logic, UI rendering
- **Lifecycle:** Cleared at game start; populated during game initialization; individual entries added/removed as units/buildings spawn/die.

#### `player_units`, `enemy_units`, `neutral_units`
- **Scope:** world
- **Type:** Array[Node]
- **Default:** empty arrays
- **Producer:** `MapSpawns` (appends during spawn)
- **Consumer:** `ChooseTarget` (target selection), `game.gd` (spawning)
- **Lifecycle:** Populated during spawn; not actively cleaned up on death.

#### `player_buildings`, `enemy_buildings`, `neutral_buildings`
- **Scope:** world
- **Type:** Array[Node]
- **Default:** empty arrays
- **Producer:** `game.gd` (line 288), `MapManager` (appends)
- **Consumer:** `ConquerAction`, `ReturnLumber`, `NavigateAction` (pathfinding), `Utils` (building search)
- **Lifecycle:** Populated at game start; individual entries may be added/removed as buildings change teams or are destroyed.

#### `player_leaders`, `enemy_leaders`
- **Scope:** world
- **Type:** Array[Node]
- **Default:** empty arrays
- **Producer:** `MapSpawns.spawn_leader()` (appends), `game.gd` (clears at start)
- **Consumer:** `ChooseTarget` (leader priorities), `ConquerAction`, `MineAction`, `TaxesAction`, `Utils`, `Skills`
- **Lifecycle:** Populated during game start; entries added when leaders spawn.

#### `player_leaders_names`, `enemy_leaders_names`
- **Scope:** world
- **Type:** Array[String]
- **Default:** empty arrays
- **Producer:** Menu screens, `tests/test_map/test.gd`
- **Consumer:** `game.gd` (leader selection during spawn)
- **Lifecycle:** Set at game start; not changed during play.

#### `player_extra_unit`, `enemy_extra_unit`
- **Scope:** world
- **Type:** String (`"infantry"`, `"archer"`, `"mounted"`)
- **Default:** `"infantry"`
- **Producer:** `game.gd` (line 335-336 — initial default), `ConquerAction` (line 89)
- **Consumer:** `MapSpawns.spawn_leader()`
- **Lifecycle:** Set at game start; changed when a building is conquered.

#### `map`, `lanes`, `map_size`, `map_mid`, `map_camera_limit`, `zoom_limit`
- **Scope:** world
- **Type:** `map: Node`, `lanes: Dictionary[String, Array[Vector2]]`, `Vector2`, `float`
- **Default:** none
- **Producer:** `MapManager` (initializes all map-related state)
- **Consumer:** Everywhere — pathfinding, movement, UI, camera
- **Lifecycle:** Set at game start; `map` never changes; `lanes` may be updated if map changes.

#### `selected_unit`, `selected_leader`
- **Scope:** world
- **Type:** Object (Node) or null
- **Default:** null
- **Producer:** `controls/selection.gd`
- **Consumer:** `UI`, `Stats`, `OrderButton`, `SkillButton`, `ItemButton`, `ItemInventories`, `ItemShop`, `Unit.gd` (teleport check)
- **Lifecycle:** Set when a unit is clicked; cleared when clicking elsewhere or dismiss order.

#### `selectable_units`
- **Scope:** world
- **Type:** Array[Node]
- **Default:** empty array
- **Producer:** `controls/selection.gd`
- **Consumer:** `controls/selection.gd` (click detection)
- **Lifecycle:** Populated when selecting units.

#### `over_minimap`, `show_fps`, `hide_leaders_hud`
- **Scope:** world
- **Type:** bool
- **Default:** `over_minimap: false`, `show_fps: true`, `hide_leaders_hud: false`
- **Producer:** `game.gd` (over_minimap), `game.gd` (show_fps, hide_leaders_hud — via F-keys)
- **Consumer:** `crafty_camera.gd` (over_minimap, zoom_limit), `UI` (show_fps), `hud/unit_hud.gd` (hide_leaders_hud)
- **Lifecycle:** Toggled by F-keys or minimap interaction.

## State dependency map

Some facts have implicit dependencies — one system's behavior depends on another system writing a fact that the planner doesn't directly check.

| Dependency | Description | Risk |
|------------|-------------|------|
| `has_destiny` is route-scoped | `Navigate.follow_path` sets it; `Move.stop` and the final arrival clear it; `Move.get_preconditions()` requires it. | Cleared deterministically since the arrival rework — plans order `Navigate > Move`; do not remove the clears or the stale-`true` freeze returns. |
| `hunting` depends on `target` being set | `Modifiers` checks `hunting` for attack speed bonuses. | If `target` is set without `hunting`, attack speed bonus is lost. |
| `is_stunned` vs `stunned` alias | `MoveAction.smart()` checks the stale `stunned` alias; all other code uses `is_stunned`. | `smart()`'s stun guard is silently inactive. |
| `target` side effects | `_set_target()` clears `attack_count`, removes `agile` modifier, sets `hunting`. These are side effects that any code setting `target` inherits. | Setting `target` without understanding these side effects causes unintended behavior. |
| `EnemyDefeated.is_valid()` scans every frame | On every goal evaluation, `EnemyDefeated.is_valid()` calls `get_units_in_sight()`, `select_target()`, and writes `opponents_in_sight`. | Performance cost on each staggered evaluation (~8.6 Hz per unit). |
| `ChooseTarget` is a shared singleton | `ChooseTarget` holds mutable team-level priority dictionaries but is a globally shared action instance. | Safe because it's team-scoped, but needs documentation to prevent future misuse. |
