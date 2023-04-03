extends "../Action.gd"


func get_class_name(): return "HelpFriend"


func get_cost(agent) -> int:
	return 1


func get_preconditions() -> Dictionary:
	return { "react_target": true }


func get_effects() -> Dictionary:
	return { "react_target": false }


func perform(agent, delta) -> bool:
	return false


func enter(agent):
	var position = agent.get_state("react_target").global_position
	Behavior.advance.point(agent.get_unit(), position)


