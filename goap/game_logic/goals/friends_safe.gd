extends "res://goap/goap_system/goal_contract.gd"


func get_class_name() -> String:
	return "FriendsSafe"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var ready_to_fight = agent.get_state("ready_to_fight", true)
	var friend_attacker = ally_attacked(unit)
	if !ready_to_fight or !unit.attacks or !friend_attacker:
		return false
	# Same stale-fact trap as EnemyDefeated/enemy_dead: HelpFriend writes
	# friends_safe=true when it completes and only the goal's enter() clears
	# it — but the planner runs BEFORE enter, so the next "ally attacked"
	# goal evaluation saw the desired state as already satisfied and planned
	# nothing. Reset while the goal is valid, before planning.
	agent.set_state("friends_safe", false)
	return true


func enter(agent):
	var attacker = ally_attacked(agent.get_unit())
	agent.set_state("react_target", attacker)
	agent.set_state("friends_safe", false)


func priority(_agent) -> int:
	return 5


func get_desired_state(_agent) -> Dictionary:
	return {"friends_safe": true}


func ally_attacked(unit):
	for ally in unit.get_units_in_sight({"team": unit.team}):
		if ally.agent.get_state("being_attacked"):
			return ally.agent.get_state("attacker")
	return null
