extends Node2D
var game:Node

# self = game.maps.blocks


# COLLISION QUADTREES

var quad
var block_template:PackedScene = load("res://map/blocks/block_template.tscn")


func _ready():
	game = get_tree().get_current_scene()



func setup_quadtree():
	var bound = Rect2(Vector2.ZERO, Vector2(game.map.size.x,game.map.size.y))
	quad = Quadtree.create_quadtree(bound, 16, 16)


func get_units_in_radius(pos, rad):
	var quad_units = quad.get_units_in_radius(pos, rad)
	var in_radius_units = []
	for unit1 in quad_units:
		var pos1 = unit1.global_position
		if pos.distance_to(pos1) <= rad: in_radius_units.append(unit1)
	return in_radius_units


func create_block(x, y):
	var block = block_template.instance()
	var size = game.map.tile_size
	var half = game.map.half_tile_size
	block.selectable = false
	block.moves = false
	block.attacks = false
	block.collide = true
	block.global_position = Vector2(half + x * size, half + y * size)
	game.map.block_container.add_child(block)
	game.collision.setup(block)
	game.all_units.append(block)
