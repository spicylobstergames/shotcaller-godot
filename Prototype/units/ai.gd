extends Node
var game:Node


func _ready():
	game = get_tree().get_current_scene()

# Called when the node enters the scene tree for the first time.
#func _ready():
#	pass # Replace with function body.


func move_and_attack(unit, objective):
	unit.behavior = "move_and_attack"
	unit.objective = objective
	if unit.state != "attack":
		var enemies = unit.get_units_on_sight()
		enemies = game.sort_by_distance(unit, enemies)
		if enemies: 
			unit.target = enemies[0].unit
			if game.unit.attack.in_range(unit, unit.target):
				game.unit.attack.start(unit, unit.target.global_position)
			else: game.unit.move.start(unit, unit.target.global_position)
		else: game.unit.move.start(unit, objective)


func on_move_end(unit):
	if unit.behavior == "move_and_attack":
		move_and_attack(unit, unit.objective)


func on_collision(unit):
	if unit.behavior != "move_and_attack":
		unit.wait()


func on_arrive(unit):
	if unit.behavior == "move_and_attack":
		print("arrive")
		if unit.current_destiny != unit.objective:
			move_and_attack(unit, unit.objective)
		else: unit.behavior = ""
