extends "../Goal.gd"


func get_class_name(): return "NeedLumberGoal"


func is_valid(agent) -> bool:
	return not agent.get_state("is_running") and not agent.get_state("is_hiding")


func priority(_agent) -> int:
	return 1


func get_desired_state(_agent) -> Dictionary:
	return { "collected_wood": true }
