extends "../Action.gd"


func get_class(): return "HelpFriend"


func is_valid(agent) -> bool:
	return WorldState.get_state("is_game_active")


func get_cost(agent) -> int:
	# cost of pursue should be higher than attacking
	return 25


func get_preconditions() -> Dictionary:
	return { "react_target": true }


func get_effects() -> Dictionary:
	return { "react_target": false }


func perform(agent, delta) -> bool:
	return false


func enter(agent):
	ally_attacked(agent, null)


func ally_attacked(target, attacker):
	var allies = target.get_units_in_sight({ "team": target.team })
	for ally in allies:
		if ally.state != "attack":
			ally.agent.set_state("react_target", attacker)


