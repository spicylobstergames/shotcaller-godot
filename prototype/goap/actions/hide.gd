extends "../Action.gd"


func get_class_name(): return "Hide"


const max_wait_seconds = 5


func get_cost(_agent) -> int:
	return 1


func get_preconditions() -> Dictionary:
	return {}


func get_effects() -> Dictionary:
	return { "is_threatened": false }


func enter(agent):
	Behavior.move.point(agent.get_unit(), agent.get_state("deliver_position"))
	agent.set_state("is_running", true)


func on_arrive(agent):
	agent.get_unit().hide()
	agent.set_state("is_running", false)
	agent.set_state("is_hiding", true)
	agent.set_state("hiding_counter", 0)


func on_every_second(agent):
	var is_threatened = agent.get_state("is_running")
	var unit = agent.get_unit()
	var enemies = unit.get_units_in_sight({ "team": unit.opponent_team() })
	for enemy in enemies:
		if enemy.attacks:
			is_threatened = true
			agent.set_state("hiding_counter", 0)
			break
	agent.set_state("hide_threatened", is_threatened)
	#counter
	if agent.get_state("is_hiding") and not agent.get_state("hide_threatened"):
		var c = agent.get_state("hiding_counter")
		agent.set_state("hiding_counter", c+1)


func perform(agent, _delta) -> bool:
	var hiding_counter = agent.get_state("hiding_counter")
	return hiding_counter and hiding_counter > max_wait_seconds


func exit(agent):
	agent.get_unit().show()
	agent.set_state("is_hiding", false)
	agent.set_state("is_threatened", false)
	agent.set_state("hiding_counter", 0)


