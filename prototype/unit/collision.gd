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
	if game.test.fog: game.map.fog.skip_start()
	
	# loop 1: add to quad
	for unit1 in game.all_units:
		if unit1.collide and not unit1.dead:
			game.map.blocks.quad.add_body(unit1)
		
		if game.test.fog: 
			if unit1.team == game.player_team: game.map.fog.clear_sigh_skip(unit1)
	
	
	# loop 2: checks for collisions
	
	for unit1 in game.all_units:
		
		# projectiles collision
		
		if unit1.projectiles.size():
			for projectile in unit1.projectiles:
				if is_instance_valid(projectile.node) and projectile.speed and projectile.stuck == false:
					projectile.lifetime -= delta
					var stuck = false
					if projectile.lifetime < 0:
						game.unit.attack.projectile_stuck(unit1, null, projectile)
						stuck = true
					else:
						if projectile.target:
							if game.utils.point_collision(projectile.target, projectile.node.global_position):
								game.unit.attack.take_hit(unit1, projectile.target, projectile)
								stuck = true
						else: # pierces
							var targets = game.map.blocks.get_units_in_radius(projectile.node.global_position, 1) 
							for target in targets:
								if (game.unit.attack.can_hit(unit1, target) and
										projectile.targets.find(target) < 0 and
										game.utils.point_collision(target, projectile.node.global_position) ):
									game.unit.attack.take_hit(unit1, target, projectile)
						# move projectile
						if not stuck: game.unit.attack.projectile_step(delta, projectile)
		
		# units collision
		
		unit1.next_event  = ""
		if not unit1.dead:
			# move arrival
			if unit1.moves and unit1.state == "move":
				if unit1.target or unit1.working:
					if game.utils.point_collision(unit1, unit1.current_destiny):
						unit1.next_event = "arrive"
				else: # larger collision destiny for auto movement
					if game.utils.point_collision(unit1, unit1.current_destiny, game.map.half_tile_size):
						unit1.next_event = "arrive"
			
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

