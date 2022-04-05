extends Node
var game:Node


func _ready():
	game = get_tree().get_current_scene()


func move_and_attack(unit, objective):
	if unit.moves:
		if not unit.attacks: game.unit.move.start(unit, objective)
		else:
			unit.set_behavior("move_and_attack")
			unit.objective = objective
			var t = "blue"
			if unit.team == t: t = "red"
			var enemies = unit.get_units_on_sight({"team": t})
			if not enemies: game.unit.move.start(unit, objective) 
			else:
				unit.target = closest_unit(unit, enemies)
				if not game.unit.attack.in_range(unit, unit.target):
					game.unit.move.start(unit, unit.target.global_position)
				else: game.unit.attack.start(unit, unit.target.global_position)


func closest_unit(unit, enemies):
	var sorted = game.sort_by_distance(unit, enemies)
	return sorted[0].unit


func on_collision(unit):
	if unit.behavior == "move_and_attack" and unit.collide_target == unit.target:
		 game.unit.attack.start(unit, unit.target.global_position)


func resume(unit):
	if unit.behavior == "move_and_attack":
		move_and_attack(unit, unit.objective)


func end(unit):
	if unit.behavior == "move_and_attack":
		if unit.current_destiny != unit.objective:
			move_and_attack(unit, unit.objective)
		else: unit.set_behavior("stand")

