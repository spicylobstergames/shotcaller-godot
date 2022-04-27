extends Node
var game:Node

# self = game.unit.advance

func _ready():
	game = get_tree().get_current_scene()


func start(unit, objective): # move_and_attack
	game.unit.attack.set_target(unit, null)
	unit.objective = objective
	if (unit.attacks and game.unit.move.in_bounds(objective) and
			not unit.retreating and not unit.stunned and not unit.channeling):
		unit.set_behavior("advance")
		
		var enemies = unit.get_units_on_sight({"team": unit.oponent_team()})
		var at_objective = (unit.global_position.distance_to(unit.objective) < game.map.half_tile_size)
		var no_path = (unit.current_path.size() == 0)
		if not enemies and not at_objective: move(unit, objective) 
		if not enemies and at_objective and no_path: stop(unit)
		if enemies:
			var target = game.unit.orders.select_target(unit, enemies)
			if not target and not at_objective: move(unit, objective)
			if not target and at_objective and no_path: stop(unit)
			if target:
				game.unit.attack.set_target(unit, target)
				var target_position = target.global_position + target.collision_position
				if not game.unit.attack.in_range(unit, target):
					move(unit, target_position) 
				else: 
					game.unit.attack.start(unit, target_position)


func move(unit, objective):
	if unit.moves and objective:
		game.unit.move.move(unit, objective)
	else: stop(unit)


func on_collision(unit):
	if unit.behavior == "advance" and unit.collide_target == unit.target:
		var target_position = unit.target.global_position + unit.target.collision_position
		game.unit.attack.start(unit, target_position)


func resume(unit):
	if unit.behavior == "advance":
		start(unit, unit.objective)


func end(unit):
	if unit.behavior == "advance":
		if unit.current_destiny != unit.objective:
			start(unit, unit.objective)
		else: stop(unit)


func react(target, attacker):
	if target.behavior == "stop" or target.behavior == "advance":
		start(target, attacker.global_position)


func ally_attacked(target, attacker):
	var allies = target.get_units_on_sight({"team": target.team})
	for ally in allies: react(ally, attacker)


func stop(unit):
	if unit.behavior == "advance":
		unit.set_behavior("stop")
		
		game.unit.move.stop(unit)


func on_idle_end(unit):
	if unit.behavior == "advance" or unit.behavior == "stop":
		if unit.attacks: start(unit, unit.global_position)
