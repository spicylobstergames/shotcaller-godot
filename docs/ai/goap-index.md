# GOAP Index (generated)

Generated from the `GOAP-GUIDE` banners at the top of every GOAP script.
Do not edit by hand — run `./tools/gen_goap_index.sh` after changing a banner.
`tests/unit/test_goap_index.gd` fails when this file is stale.

Companion docs: `ARCHITECTURE.md` (system map), `goap-cheatsheet.md`
(one-page summary), `world-state.md` (fact catalog). Fields shown as
`-` are not stated in that script's banner (usually a service action).

## Goals (8)

| Goal | Priority | Desired state | File |
|------|----------|---------------|------|
| ArriveAtDestination | 3 (unused while is_valid() is false) | {"arrived_at_destination": true} | `goap/game_logic/goals/arrive_at_destination.gd` |
| EnemyDefeated | 6 | {"enemy_dead": true} | `goap/game_logic/goals/enemy_defeated.gd` |
| FriendsSafe | 5 | {"friends_safe": true} | `goap/game_logic/goals/friends_safe.gd` |
| NeedLumber | 1 (lowest; WalkLane at 2 outranks it, but a lumberjack has an empty lane so WalkLane is invalid for it) | {"collected_wood": true} | `goap/game_logic/goals/need_lumber.gd` |
| NeedSafety | 10 (ties with Recover; on a tie the earlier-registered goal wins) | {"is_threatened": false}   (produced by Hide) | `goap/game_logic/goals/need_safety.gd` |
| ObeyPlayer | 100 | {"player_order_complete": true}   (produced by Order) | `goap/game_logic/goals/obey_player.gd` |
| Recover | 10 | {"ready_to_fight": true} | `goap/game_logic/goals/recover.gd` |
| WalkLane | 2 (above NeedLumber, below combat/safety goals) | {"lane_route_finished": true} | `goap/game_logic/goals/walk_lane.gd` |

## Actions (18)

| Action | Plannable | Preconditions | Effects | File |
|--------|-----------|---------------|---------|------|
| AttackEnemy | yes - EnemyDefeated ({enemy_dead: true}) -> AttackEnemy. | {"enemy_in_attack_range": true} | {"enemy_dead": true, "friends_safe": true} | `goap/game_logic/actions/attack_enemy.gd` |
| ChooseTarget | yes - PursueEnemy needs has_attack_target. | {"is_stunned": false} | {"has_attack_target": true} | `goap/game_logic/actions/choose_target.gd` |
| Conquer | no - service object reached via Goap.get_action("Conquer"). | - | - | `goap/game_logic/actions/conquer_action.gd` |
| GetLumber | yes - NeedLumber({collected_wood: true}) -> GetLumber -> ReturnLumber. | {} | {"has_wood": true} | `goap/game_logic/actions/get_lumber.gd` |
| HelpFriend | yes - FriendsSafe({friends_safe: true}) -> HelpFriend. | {"react_target": true} | {"friends_safe": true} | `goap/game_logic/actions/help_friend.gd` |
| Hide | yes - NeedSafety({is_threatened: false}) -> Hide. | {} | {"is_threatened": false} | `goap/game_logic/actions/hide.gd` |
| MeleeAttack | no - service object. It overrides no effects, so the planner can never match it. Reached via Agent.on_attack_hit. | - | - | `goap/game_logic/actions/melee_attack.gd` |
| Mine | no - service object driven by order buttons. | - | - | `goap/game_logic/actions/mine_action.gd` |
| Move | yes - the movement step of most plans. | {"has_destiny": true, "is_stunned": false} | {"arrived_at_destination": true, "lane_route_finished": true} | `goap/game_logic/actions/move_action.gd` |
| Navigate | yes - with Move. | {"is_stunned": false} | {"has_destiny": true} | `goap/game_logic/actions/navigate_action.gd` |
| Order | yes - ObeyPlayer({player_order_complete: true}) -> Order. | {} (default) | {"player_order_complete": true} | `goap/game_logic/actions/order_action.gd` |
| Pray | no - service object reached via Goap.get_action("Pray"). | - | - | `goap/game_logic/actions/prayer_action.gd` |
| PursueEnemy | yes - bridges has_attack_target -> enemy_in_attack_range. | {"is_stunned": false, "ready_to_fight": true, "has_attack_target": true} | {"enemy_in_attack_range": true} | `goap/game_logic/actions/pursue_enemy.gd` |
| RangeAttack | no - signal-driven service. unit_attack_release -> Agent.on_attack_release; Collisions calls projectile_loop for every unit each physics tick. | - | - | `goap/game_logic/actions/range_attack.gd` |
| Retreat | yes - Recover({ready_to_fight: true}) -> Retreat -> WaitForRegeneration. | {} (default) | {"arrived_at_retreat": true} | `goap/game_logic/actions/retreat_action.gd` |
| ReturnLumber | yes - NeedLumber plan: GetLumber -> ReturnLumber. | {"has_wood": true} | {"collected_wood": true} | `goap/game_logic/actions/return_lumber.gd` |
| Taxes | no - service object, set from the UI. | - | - | `goap/game_logic/actions/taxes_action.gd` |
| WaitForRegeneration | yes - the second step of the Recover plan. | {"arrived_at_retreat": true} | {"ready_to_fight": true} | `goap/game_logic/actions/wait_for_regeneration.gd` |
