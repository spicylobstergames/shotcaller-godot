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
		"command_target_enemy": null,
	}

func perform(agent, delta) -> bool:
	var unit = agent.get_unit()
	if unit.target == null or unit.target.dead or not unit.point_collision(unit.target.position, unit.vision):     
		agent.clear_commands()                   
		return true
	if not unit.stunned and (unit.state != "attack" or unit.state != "idle") and  Behavior.attack.in_range(unit, unit.target):# basically, is not already attacking (idle/attack) and is it in range
		Behavior.attack.point(unit, unit.target.position)

	return false
func exit(agent):
	var unit = agent.get_unit()
	agent.set_state("enemy_active", unit.get_units_on_sight({"team": unit.opponent_team()}).size() > 0)

func enter(agent):
	var unit = agent.get_unit()
	if agent.get_state("command_target_enemy") != null:
		unit.target = agent.get_state("command_target_enemy")
		move(unit, unit.target.position)
		return

	var enemies = unit.get_units_on_sight({"team": unit.opponent_team()})
	if(enemies.size() > 0):
		unit.target = unit.closest_unit(enemies)
		move(unit, unit.target.position)
	else :
		print('Enemy died? Race condition')
	

func move(unit, objective):
	if unit.moves and objective:
		Behavior.move.move(unit, objective)
	else: stop(unit)


func on_collision(unit):
	if unit.collide_target == unit.target:
		var target_position = unit.target.global_position + unit.target.collision_position
		Behavior.attack.point(unit, target_position)



func resume(unit):
	if(unit.target):
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
	Behavior.move.stop(unit)


func on_idle_end(unit):		
	if not unit.stunned and unit.target:
		if Behavior.attack.in_range(unit, unit.target):
			Behavior.attack.point(unit,unit.target.position)
		#elif unit.state != "moving":
		#	move(unit, unit.target.position)
					