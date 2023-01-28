extends "../Goal.gd"


func get_class(): return "FollowPathGoal"


func is_valid(agent) -> bool:
	return WorldState.get_state("is_game_active")


func priority(agent) -> int:
	return 10 # higher if unit is further from lane


func get_desired_state(agent) -> Dictionary:
	return { "close_to_lane": true }
