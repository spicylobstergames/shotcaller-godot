extends GoapAction

class_name AttackEnemy

func get_class(): return "AttackEnemy"


func is_valid(blackboard) -> bool:
	return blackboard.has("enemy_active") and blackboard["enemy_active"]

#presently a magic number... maybe use distance in the future
func get_cost(blackboard) -> int:
	return 3


func get_preconditions() -> Dictionary:
	return {}


func get_effects() -> Dictionary:
	return {
		"enemy_active": false,
	}

func perform(agent, delta) -> bool:
	if agent.get_unit().target == null or agent.get_unit().target.dead:
		agent.set_state("enemy_active", agent.get_unit().get_units_on_sight({"team": agent.get_unit().oponent_team()}).size() > 0)
		return true
	if not agent.get_unit().stunned:
		if Behavior.attack.in_range(agent.get_unit(),agent.get_unit().target) and agent.get_unit().state != "attack":
			Behavior.move.stand(agent.get_unit())
			agent.get_unit().set_state("attack")
		#elif agent.get_unit().state != "moving":
		#	move(agent.get_unit(), agent.get_unit().target.position, true)
		pass
	return false

func enter(agent):
	var enemies = agent.get_unit().get_units_on_sight({"team": agent.get_unit().oponent_team()})
	if(enemies.size() > 0):
		agent.get_unit().target = agent.get_unit().closest_unit(enemies)
	else :
		print('wat')
	move(agent.get_unit(), agent.get_unit().target.position)

func move(unit, objective):
	if unit.moves and objective:
		Behavior.move.move(unit, objective)
	else: stop(unit)


func on_collision(unit):
	if unit.behavior == "advance" and unit.collide_target == unit.target:
		var target_position = unit.target.global_position + unit.target.collision_position
		Behavior.attack.point(unit, target_position)



func resume(unit):
	move(unit, unit.target.position)


func end(unit):
	return
	#if unit.current_destiny != unit.objective:
	#	point(unit, null)
	#else: 
	#	stop(unit)


func react(target, attacker):
	pass
	#point(target, attacker.global_position)


func ally_attacked(target, attacker):
	var allies = target.get_units_on_sight({"team": target.team})
	for ally in allies: react(ally, attacker)


func stop(unit):
	if unit.behavior == "advance":
		unit.set_behavior("stop")
		Behavior.move.stop(unit)


func on_idle_end(unit):
	pass
	#point(unit, unit.global_position)


func smart(unit, objective):
	pass
#	point(unit, objective, true)
					