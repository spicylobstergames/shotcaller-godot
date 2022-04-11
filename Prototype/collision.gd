extends Node
var game:Node


func _ready():
	game = get_tree().get_current_scene()


func process(delta):
	game.map.blocks.quad.clear()
	for unit1 in game.all_units:
		if unit1.collide: game.map.blocks.quad.add_body(unit1)
	
	
	# loop 2: checks for collisions
	for unit1 in game.all_units:
		unit1.next_event  = ""
		
		# move arrival
		if unit1.moves and unit1.state == "move":
			if game.utils.point_collision(unit1, unit1.current_destiny):
				
				unit1.next_event = "arrive"
		

		# projectiles collision
		if unit1.projectiles.size():
			for projectile in unit1.projectiles:
				if is_instance_valid(projectile.node) and projectile.speed:
					projectile.lifetime -= delta
					if projectile.lifetime > 0:
						projectile.node.global_position += projectile.speed * delta
						if unit1.target:
							if game.utils.point_collision(unit1.target, projectile.node.global_position):
								game.unit.attack.take_hit(unit1, unit1.target, projectile)
					else: 
						game.unit.attack.projectile_stuck(unit1, null, projectile)
		
		# units collision
		if (unit1.moves and unit1.collide and unit1.state == "move" 
				and unit1.next_event != "arrive"):
			unit1.next_event = "move"
			for unit2 in game.utils.get_units_around(unit1, delta):
				if unit2.collide and unit1 != unit2:
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
