extends Node

# self = Collisions

const Quadtree = preload("res://collision/Quadtree.gd")

# COLLISION QUADTREES
var quad:Quadtree
var block_template:PackedScene = preload("res://collision/blocks/block_template.tscn")
var tile_size := 64
var half_tile_size := tile_size / 2
var current_map : Node2D



func create_quadtree(bounds, splitThreshold, splitLimit, currentSplit = 0):
	return Quadtree.new(self, bounds, splitThreshold, splitLimit, currentSplit)


func setup_quadtree(map):
	current_map = map
	tile_size = map.tile_size
	half_tile_size = map.half_tile_size
	var bound = Rect2(Vector2.ZERO, Vector2(map.size.x, map.size.y))
	quad = create_quadtree(bound, 16, 16)


func get_units_in_radius(pos, rad):
	var quad_units = quad.get_units_in_radius(pos, rad)
	var in_radius_units = []
	for unit1 in quad_units:
		var pos1 = unit1.global_position
		if pos.distance_to(pos1) <= rad: in_radius_units.append(unit1)
	return in_radius_units


func create_block(x, y):
	var block = block_template.instantiate()
	block.selectable = false
	block.moves = false
	block.attacks = false
	block.collide = true
	block.global_position = Vector2(half_tile_size + x * tile_size, half_tile_size + y * tile_size)
	current_map.block_container.add_child(block)
	Collisions.setup(block)
	WorldState.get_state("all_units").append(block)


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
	Collisions.quad.clear()
	
	# loop 1
	for unit1 in WorldState.get_state("all_units"):
		
		# add units to quad
		if unit1.collide and not unit1.dead:
			Collisions.quad.add_body(unit1)
	
	
	# loop 2: checks for collisions
	
	for unit1 in WorldState.get_state("all_units"):
		
		# projectiles collision
		
		if unit1.projectiles.size():
			for projectile in unit1.projectiles:
				if is_instance_valid(projectile.node) and projectile.speed and projectile.stuck == false:
					var projectile_position = projectile.node.global_position + (projectile.speed * delta)
					# projectile out of range
					if projectile_position.distance_to(unit1.global_position + unit1.collision_position) > projectile.radius:
						Behavior.attack.projectile_stuck(unit1, null, projectile)
					else:
						if projectile.target:
							if projectile.target.point_collision(projectile_position):
								Behavior.attack.take_hit(unit1, projectile.target, projectile)
						else: # pierces
							var targets = Collisions.get_units_in_radius(projectile_position, 1) 
							for target in targets:
								if (Behavior.attack.can_hit(unit1, target) and
										projectile.targets.find(target) < 0 and
										target.point_collision(projectile_position) ):
									Behavior.attack.take_hit(unit1, target, projectile)
						# move projectile
						if not projectile.stuck: Behavior.attack.projectile_step(delta, projectile)
		
		# units next event (move, arrive or collision)
		
		unit1.next_event  = "" # default no event
		if not unit1.dead:
			# units > destiny collision (arrive)
			if unit1.moves and unit1.state == "move":
				# offset creates larger collision destiny to avoid fighting over point
				var offset = 0
				if not unit1.target and not unit1.agent.get_state("has_player_command"):
					offset = WorldState.get_state("map").half_tile_size
				if unit1.point_collision(unit1.current_destiny, offset):
					unit1.next_event = "arrive"
			# units1 > unit2 collision
			
			if (unit1.moves and unit1.state == "move" and unit1.next_event != "arrive"):
				unit1.next_event = "move"
				if unit1.collide:
					for unit2 in unit1.get_units_in_quad(delta):
						if not unit2.dead and unit2.collide and unit1 != unit2:
							if unit1.check_collision(unit2, delta):
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


