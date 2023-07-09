extends Node2D

# self = game.maps.blocks
const Quadtree = preload("res://collision/Quadtree.gd")

# COLLISION QUADTREES
var quad:Quadtree
var block_template:PackedScene = load("res://collision/blocks/block_template.tscn")
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
