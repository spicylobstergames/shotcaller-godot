extends Node

var game:Node


# self = Behavior.advance


func _ready():
	game = get_tree().get_current_scene()


func smart(unit, final_destiny):
	point(unit, final_destiny, true) # uses pathfinder


 # move_and_attack
func point(unit, final_destiny, smart_move = false):
	Behavior.attack.set_target(unit, null)
	if final_destiny and Behavior.move.in_bounds(final_destiny):
		unit.final_destiny = final_destiny
		if unit.attacks and not unit.agent.get_state("is_stunned"):
			var path = unit.current_path
			if smart_move:
				path = Behavior.path.find(unit.global_position, unit.final_destiny)
				if path: unit.current_path = path
			var enemies = unit.get_units_in_sight({ "team": unit.opponent_team() })
			var at_final_destination = (unit.global_position.distance_to(unit.final_destiny) < game.map.half_tile_size)
			var has_path = ( path and not path.is_empty() )
			if enemies.size() == 0:
				if not at_final_destination: move(unit, unit.final_destiny, smart_move) 
				elif has_path: Behavior.path.start(unit,path)
			else:
				var target = Behavior.orders.select_target(unit, enemies)
				if not target:
					if not at_final_destination: move(unit, unit.final_destiny, smart_move)
					elif has_path: Behavior.path.start(unit,path)
				else:
					Behavior.attack.set_target(unit, target)
					var target_position = target.global_position + target.collision_position
					if Behavior.attack.in_range(unit, target):
						Behavior.attack.point(unit, target_position)
					else: move(unit, target_position, smart_move) 


func move(unit, final_destiny, smart_move):
	if unit.moves and final_destiny:
		if smart_move: Behavior.move.smart(unit, final_destiny)
		else : Behavior.move.move(unit, final_destiny)
	else: stop(unit)


func on_collision(unit):
	if unit.collide_target == unit.target:
		var target_position = unit.target.global_position + unit.target.collision_position
		Behavior.attack.point(unit, target_position)



func resume(unit):
	point(unit, null)


func react(target, attacker):
	point(target, attacker.global_position)


func ally_attacked(target, attacker):
	var allies = target.get_units_in_sight({ "team": target.team })
	for ally in allies: react(ally, attacker)


func stop(unit):
	Behavior.move.stop(unit)


