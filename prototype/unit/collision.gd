extends Node
var game:Node


# self = game.collision


func _ready():
	game = get_tree().get_current_scene()


func setup(unit):
	if unit.has_node("collisions/select"):
		unit.selection_position = unit.get_node("collisions/select").position
		unit.selection_radius = unit.get_node("collisions/select").shape.radius
	
	if unit.has_node("collisions/block"):
		unit.collision_position = unit.get_node("collisions/block").position
		unit.collision_radius = unit.get_node("collisions/block").shape.radius
	
	if unit.has_node("collisions/attack"):
		unit.attack_hit_position = unit.get_node("collisions/attack").position
		unit.attack_hit_radius = unit.get_node("collisions/attack").shape.radius



func process(delta):
	game.map.blocks.quad.clear()
	
	# loop 1
	for unit1 in game.all_units:
		
		# add units to quad
		if unit1.collide and not unit1.dead:
			game.map.blocks.quad.add_body(unit1)
	
	
	# loop 2: checks for collisions
	
	for unit1 in game.all_units:
		
		# projectiles collision
		
		if unit1.projectiles.size():
			for projectile in unit1.projectiles:
				if is_instance_valid(projectile.node) and projectile.speed and projectile.stuck == false:
					var projectile_position = projectile.node.global_position + (projectile.speed * delta)
					# projectile out of range
					if projectile_position.distance_to(unit1.global_position + unit1.collision_position) > projectile.radius:
						game.unit.attack.projectile_stuck(unit1, null, projectile)
					else:
						if projectile.target:
							if game.utils.point_collision(projectile.target, projectile_position):
								game.unit.attack.take_hit(unit1, projectile.target, projectile)
						else: # pierces
							var targets = game.map.blocks.get_units_in_radius(projectile_position, 1) 
							for target in targets:
								if (game.unit.attack.can_hit(unit1, target) and
										projectile.targets.find(target) < 0 and
										game.utils.point_collision(target, projectile_position) ):
									game.unit.attack.take_hit(unit1, target, projectile)
						# move projectile
						if not projectile.stuck: game.unit.attack.projectile_step(delta, projectile)
		
		# units next event (move, arrive or collision)
		
		unit1.next_event  = ""
		if not unit1.dead:
			# units > destiny collision (arrive)
			if unit1.moves and unit1.state == "move":
				if unit1.target or unit1.working: # unit thas target point destiny
					if game.utils.point_collision(unit1, unit1.current_destiny):
						unit1.next_event = "arrive"
				else: # larger collision destiny for auto movement (avoids fighting over point)
					if game.utils.point_collision(unit1, unit1.current_destiny, game.map.half_tile_size):
						unit1.next_event = "arrive"
			
			# units1 > unit2 collision
			
			if (unit1.moves and unit1.collide and unit1.state == "move" and unit1.next_event != "arrive"):
				unit1.next_event = "move"
				for unit2 in game.utils.get_units_around(unit1, delta):
					if not unit2.dead and unit2.collide and unit1 != unit2:
						if game.utils.unit_collision(unit1, unit2, delta):
							unit1.next_event = "collision"
							unit1.collide_target = unit2
							break
		
		# move or collide or stop
		match unit1.next_event:
			"move": unit1.on_move(delta)
			"collision": unit1.on_collision(delta)
			"arrive": unit1.on_arrive()
		
		# save last positions
		unit1.last_position2 = unit1.last_position
		unit1.last_position = unit1.global_position

