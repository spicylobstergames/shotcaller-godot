extends Node2D
var game:Node

# self = game.map.blocks


# COLLISION QUADTREES
const _QuadtreeGD = preload("quadtree.gd")
var quad


var block_template:PackedScene = load("res://map/blocks/block_template.tscn")


func _ready():
	game = get_tree().get_current_scene()



func setup_quadtree():
	var Quad = _QuadtreeGD.new()
	var bound = Rect2(Vector2.ZERO, Vector2(game.map.size,game.map.size))
	quad = Quad.create_quadtree(bound, 16, 16)


func get_units_in_radius(pos, rad):
	return quad.get_units_in_radius(pos, rad)


func create_block(x, y):
	var block = block_template.instance()
	var size = game.map.tile_size
	var half = game.map.half_tile_size
	block.selectable = false
	block.moves = false
	block.attacks = true
	block.collide = true
	block.global_position = Vector2(half + x * size, half + y * size)
	game.map.blocks.add_child(block)
	game.collision.setup(block)
	game.all_units.append(block)
