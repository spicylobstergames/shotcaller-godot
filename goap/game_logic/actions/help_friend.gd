# =============================================================================
# GOAP-GUIDE: HelpFriend - action (goap/game_logic/actions/help_friend.gd)
# =============================================================================
# Purpose   : Move to the attacker of a nearby ally until the ally is safe.
# Plannable : yes - FriendsSafe({friends_safe: true}) -> HelpFriend.
# cost      : 1
# precond   : {"react_target": true}
# effects   : {"friends_safe": true}
# enter     : Navigate.move(unit, react_target.global_position).
# perform   : true once react_target is gone/dead or is no longer attacking a
#             friendly unit (re-checks every tick).
# exit      : Move.stop; clears react_target.
# Traps     : react_target is planted by FriendsSafe.enter, not here.
# =============================================================================

extends "res://goap/goap_system/action_contract.gd"


func get_class_name(): return "HelpFriend"


func get_cost(_agent) -> int:
	return 1


func get_preconditions() -> Dictionary:
	return { "react_target": true }


func get_effects() -> Dictionary:
	return {"friends_safe": true}


func perform(agent, _delta) -> bool:
	var target = agent.get_state("react_target")
	var safe = not is_instance_valid(target) or target.dead
	if not safe:
		safe = not _is_attacking_friend(agent, target)
	if safe:
		agent.set_state("friends_safe", true)
	return safe


func enter(agent):
	var target = agent.get_state("react_target")
	if is_instance_valid(target):
		Goap.get_action("Navigate").move(agent.get_unit(), target.global_position)


func exit(agent):
	var unit = agent.get_unit()
	if unit and not unit.dead:
		Goap.get_action("Move").stop(unit)
	agent.set_state("react_target", null)


func _is_attacking_friend(agent, target) -> bool:
	var unit = agent.get_unit()
	for ally in unit.get_units_in_sight({"team": unit.team}):
		if ally.agent.get_state("being_attacked") and ally.agent.get_state("attacker") == target:
			return true
	return false
