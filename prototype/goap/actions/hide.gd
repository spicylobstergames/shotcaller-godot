extends "../Action.gd"

#class_name Hide

func get_class(): return "Hide"


func get_cost(blackboard) -> int:
		return 5

func get_preconditions() -> Dictionary:
	return {}


func get_effects() -> Dictionary:
	return {"is_threatened": false}
func exit(agent):
		agent.get_unit().visible = true
		agent.set_state("is_threatened", false)
		pass

func perform(agent, delta) -> bool:
		var is_scared = false
		for i in agent.get_unit().units_in_radius:
				if i.team != "neutral" and i.type != "building" and i.team != agent.get_unit().team:
						agent.set_state("is_safe", 0)
						is_scared = true
						break
		if not agent.get_unit().visible and not is_scared:
				agent.set_state("is_safe", agent.get_state("is_safe")+1)
		if(not agent.get_unit().visible and agent.get_state("is_safe") > 200):
				return true
		return false

func enter(agent):
		Behavior.move.point(agent.get_unit(), Vector2(458,570))
		agent.set_state("is_safe",0)

func on_arrive(agent):
		agent.get_unit().visible = false
		pass
