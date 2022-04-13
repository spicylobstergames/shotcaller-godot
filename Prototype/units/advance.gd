extends Node
var game:Node


func _ready():
	game = get_tree().get_current_scene()



func start(unit, objective): # move_and_attack
	unit.set_behavior("advance")
	unit.objective = objective
	var enemies = unit.get_units_on_sight({"team": unit.oponent_team()})
	if not enemies: 
		if unit.moves: game.unit.move.move(unit, objective) 
		else: stop(unit)
	else:
		unit.target = closest_unit(unit, enemies)
		if not game.unit.attack.in_range(unit, unit.target):
			if unit.moves: game.unit.move.move(unit, unit.target.global_position)
			else: stop(unit)
		else: game.unit.attack.start(unit, unit.target.global_position)


func closest_unit(unit, enemies):
	var sorted = game.utils.sort_by_distance(unit, enemies)
	return sorted[0].unit


func on_collision(unit):
	if unit.behavior == "advance" and unit.collide_target == unit.target:
		 game.unit.attack.start(unit, unit.target.global_position)


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
		unit.current_destiny = Vector2.ZERO
		unit.objective = Vector2.ZERO
		unit.current_step = Vector2.ZERO
		unit.set_behavior("stop")
		unit.set_state("idle")
	
func on_idle_end(unit):
	if unit.behavior == "advance" or unit.behavior == "stop":
		start(unit, unit.objective)
