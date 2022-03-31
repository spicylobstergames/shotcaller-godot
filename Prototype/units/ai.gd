extends Node

# Called when the node enters the scene tree for the first time.
#func _ready():
#	pass # Replace with function body.


func move_and_attack(unit, point):
	unit.objective = point
#	if unit.state != "attack":
#		var enemies = unit.get_units_on_sight()
#		if enemies: 
#			unit.target = enemies[0] # todo closest enemy
#			if unit.hits(unit.target):
#				unit.attack(unit.target.global_position)
#			else: unit.move(unit.target.global_position)
#		else: unit.move(point)
