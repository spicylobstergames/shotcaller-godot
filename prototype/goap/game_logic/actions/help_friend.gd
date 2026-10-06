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
		Goap.navigation.point(agent.get_unit(), target.global_position)


func exit(agent):
	var unit = agent.get_unit()
	if unit and not unit.dead:
		Goap.move.stop(unit)
	agent.set_state("react_target", null)


func _is_attacking_friend(agent, target) -> bool:
	var unit = agent.get_unit()
	for ally in unit.get_units_in_sight({"team": unit.team}):
		if ally.agent.get_state("being_attacked") and ally.agent.get_state("attacker") == target:
			return true
	return false
