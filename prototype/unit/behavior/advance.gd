extends Node
var game:Node


func _ready():
	game = get_tree().get_current_scene()



func start(unit, objective): # move_and_attack
	if not unit.stunned:
		unit.set_behavior("advance")
		unit.objective = objective
		game.unit.attack.set_target(unit, null)
		var enemies = unit.get_units_on_sight({"team": unit.oponent_team()})
		if not enemies: move(unit, objective) 
		else:
			var target = game.unit.orders.select_target(unit, enemies)
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
		start(unit, unit.objective)
