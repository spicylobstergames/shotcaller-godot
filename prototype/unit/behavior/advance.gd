extends Node

var game:Node


# self = Behavior.advance


func _ready():
	game = get_tree().get_current_scene()


func smart(unit, objective):
	point(unit, objective, true) # uses pathfinder


 # move_and_attack
func point(unit, objective, smart_move = false):
	var agent = unit.agent
	Behavior.attack.set_target(unit, null)
	if objective and Behavior.move.in_bounds(objective):
		unit.objective = objective
		if unit.attacks and not unit.agent.get_state("is_stunned"):
			var path = agent.get_state("current_path")
			if smart_move:
				path = Behavior.follow.find_path(unit.global_position, unit.objective)
				agent.set_state("current_path", path)
			var enemies = unit.get_units_in_sight({ "team": unit.opponent_team() })
			var at_objective = (unit.global_position.distance_to(unit.objective) < game.map.half_tile_size)
			var has_path = ( path and not path.empty() )
			if not enemies:
				if not at_objective: move(unit, unit.objective, smart_move) 
				elif has_path: Behavior.follow.path(unit, path)
			else:
				var target = Behavior.orders.select_target(unit, enemies)
				if not target:
					if not at_objective: move(unit, unit.objective, smart_move)
					elif has_path: Behavior.follow.path(unit, path)
				else:
					Behavior.attack.set_target(unit, target)
					var target_position = target.global_position + target.collision_position
					if Behavior.attack.in_range(unit, target):
						Behavior.attack.point(unit, target_position)
					else: move(unit, target_position, smart_move) 


func move(unit, objective, smart_move):
	if unit.moves and objective:
		if smart_move: Behavior.move.smart(unit, objective)
		else : Behavior.move.move(unit, objective)
	else: stop(unit)


func on_collision(unit):
	if unit.collide_target == unit.target:
		var target_position = unit.target.global_position + unit.target.collision_position
		Behavior.attack.point(unit, target_position)



func resume(unit):
	point(unit, null)


func end(unit):
	if unit.current_destiny != unit.objective:
		point(unit, null)
	else: stop(unit)


func react(target, attacker):
	point(target, attacker.global_position)


func ally_attacked(target, attacker):
	var allies = target.get_units_in_sight({ "team": target.team })
	for ally in allies: react(ally, attacker)


func stop(unit):
	Behavior.move.stop(unit)


