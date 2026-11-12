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


func get_units_in_radius(pos: Vector2, rad: float) -> Array:
	return quad.get_units_in_radius(pos, rad)


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
	
	var block_node = unit.get_node_or_null("block")
	if block_node:
		unit.collision_position = block_node.position
		if block_node.shape:
			unit.collision_radius = block_node.shape.radius
	
	var attack = unit.get_node_or_null("collisions/attack")
	if attack:
		unit.attack_hit_position = attack.position
		if attack.shape:
			unit.attack_hit_radius = attack.shape.radius


func physics_process(delta):
	quad.clear()
	
	var all_units = WorldState.get_state("all_units")
	for unit1 in all_units:
		if unit1.collide and not unit1.dead:
			quad.add_body(unit1)
	
	for unit1 in all_units:
		if unit1.projectiles.size():
			Goap.get_action("RangeAttack").projectile_loop(unit1, delta)
		if not unit1.dead:
			if unit1.moves and unit1.state == "move":
				if Goap.get_goal("ArriveAtDestination").is_at_destination(unit1):
					Goap.get_goal("ArriveAtDestination").on_arrive(unit1)
				else:
					Goap.get_action("Move").step(unit1, delta)
