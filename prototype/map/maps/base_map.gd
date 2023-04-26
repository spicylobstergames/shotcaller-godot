extends Node2D

class_name base_map

var game:Node


# self = game.map

@onready var walls = get_node("tiles/walls")
@onready var trees = get_node("tiles/trees")
@onready var fog = get_node("fog")

@export var size := Vector2(1056, 1056)
var mid := Vector2(size.x/2, size.y/2)

@export var tile_size = 64
var half_tile_size = tile_size / 2

@export var neutrals = ["blacksmith", "camp"]

@export var fog_of_war:bool = true

@export var camera_limit = Vector2(225,225)
@export var zoom_limit:Vector2 = Vector2(0.5,1.76)

var unit_container:Node2D
var block_container:Node2D
var projectile_container:Node2D
