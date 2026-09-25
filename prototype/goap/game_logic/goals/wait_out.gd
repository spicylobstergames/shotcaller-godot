extends "res://goap/goap_system/goal_contract.gd"


func get_class_name(): return "WaitOut"


func is_valid(agent) -> bool:
	return !agent.get_state("is_threatened")


func priority(_agent) -> int:
	return 1


func get_desired_state(_agent) -> Dictionary:
	return { 
		"ready_to_fight": true
	}
