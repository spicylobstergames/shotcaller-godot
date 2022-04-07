extends Node2D
var game:Node


var block_template:PackedScene = load("res://units/block.tscn")


# COLLISION QUADTREES
const _QuadtreeGD = preload("quadtree.gd")
var quad


func _ready():
	game = get_tree().get_current_scene()



func setup_quadtree():
	var Quad = _QuadtreeGD.new()
	var bound = Rect2(Vector2.ZERO, Vector2(game.size,game.size))
	quad = Quad.create_quadtree(bound, 16, 16)


func get_units_in_radius(pos, rad):
	return quad.get_units_in_radius(pos, rad)


func create_block(x, y):
	var block = block_template.instance()
	block.selectable = false
	block.moves = false
	block.attacks = true
	block.collide = true
	block.global_position = Vector2(32 + x * 64, 32 + y * 64)
	game.map.blocks.add_child(block)
	game.unit.setup_collisions(block)
	game.all_units.append(block)
