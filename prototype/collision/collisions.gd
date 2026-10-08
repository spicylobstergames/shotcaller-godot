extends Node

# self = Collisions

const Quadtree = preload("res://collision/quadtree.gd")

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


func create_block(x, y, team):
	var block = block_template.instantiate()
	block.selectable = false
	block.moves = false
	block.attacks = false
	block.collide = true
	if team == "blue": block.get_node("light").visible = true
	block.global_position = Vector2(half_tile_size + x * tile_size, half_tile_size + y * tile_size)
	current_map.block_container.add_child(block)
	setup(block)
	WorldState.get_state("all_units").append(block)
	return block


func setup(unit):
	var select = unit.get_node_or_null("collisions/select")
	if select:
		unit.selection_position = select.position
		if select.shape:
			unit.selection_radius = select.shape.radius
	
	var block = unit.get_node_or_null("collisions/block")
	var block_node = unit.get_node_or_null("block")
	if block:
		unit.collision_position = block.position
		if block.shape:
			unit.collision_radius = block.shape.radius
	elif block_node is CollisionShape2D:
		if block_node:
			unit.collision_position = block_node.position
			if block_node.shape:
				unit.collision_radius = block_node.shape.radius
	
	var attack = unit.get_node_or_null("collisions/attack")
	if attack:
		unit.attack_hit_position = attack.position
		if attack.shape:
			unit.attack_hit_radius = attack.shape.radius

	if unit is CollisionObject2D:
		unit.collision_layer = 1 if unit.collide else 0
		unit.collision_mask = 1 if unit.collide else 0
		if unit is CharacterBody2D:
			unit.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	if unit.collide and unit is CollisionObject2D:
		var physical_shape = unit.get_node_or_null("physical_collision")
		if physical_shape == null and block_node is CollisionShape2D:
			physical_shape = block_node
		elif physical_shape == null:
			physical_shape = CollisionShape2D.new()
			physical_shape.name = "physical_collision"
			unit.add_child(physical_shape)
			var rectangle = RectangleShape2D.new()
			var diameter = max(unit.collision_radius * 2.0, 4.0)
			rectangle.size = Vector2(diameter, diameter)
			physical_shape.shape = rectangle
			physical_shape.position = unit.collision_position
		if unit.navigation_agent:
			unit.navigation_agent.radius = max(unit.collision_radius, 8.0)

	if unit.collide and not unit.moves and not unit.has_node("NavigationObstacle2D"):
		var obstacle = NavigationObstacle2D.new()
		obstacle.name = "NavigationObstacle2D"
		obstacle.avoidance_enabled = true
		obstacle.radius = max(unit.collision_radius, 8.0)
		unit.add_child(obstacle)



func physics_process(delta):
	quad.clear()
	
	# loop 1
	for unit1 in WorldState.get_state("all_units"):
		
		# add units to quad
		if unit1.collide and not unit1.dead:
			quad.add_body(unit1)
	
	
	# loop 2: checks for collisions
	
	for unit1 in WorldState.get_state("all_units"):
		
		# projectiles collision
		
		if unit1.projectiles.size():
			for projectile in unit1.projectiles:
				if is_instance_valid(projectile.node) and projectile.speed and projectile.stuck == false:
					var projectile_position = projectile.node.global_position + (projectile.speed * delta)
					# projectile out of range
					if projectile_position.distance_to(unit1.global_position + unit1.collision_position) > projectile.radius:
						Goap.attack.projectile_stuck(unit1, null, projectile)
					else:
						if projectile.target:
							if projectile.target.point_collision(projectile_position):
								Goap.attack.take_hit(unit1, projectile.target, projectile)
						else: # pierces
							var targets = Collisions.get_units_in_radius(projectile_position, 1) 
							for target in targets:
								if (Goap.attack.can_hit(unit1, target) and
										projectile.targets.find(target) < 0 and
										target.point_collision(projectile_position) ):
									Goap.attack.take_hit(unit1, target, projectile)
						# move projectile
						if not projectile.stuck: Goap.attack.projectile_step(delta, projectile)
		
		# Unit blocking is handled by CharacterBody2D collision response.
		
		unit1.next_event  = "" # default no event
		if not unit1.dead:
			if unit1.moves and unit1.state == "move":
				var offset = 0
				if not unit1.target and not unit1.agent.get_state("has_player_command"):
					offset = WorldState.get_state("map").half_tile_size
				if unit1.point_collision(unit1.current_destiny, offset):
					unit1.next_event = "arrive"
				else:
					unit1.next_event = "move"
		
		# move or arrive
		match unit1.next_event:
			"move": unit1.on_move(delta)
			"arrive": unit1.on_arrive()
