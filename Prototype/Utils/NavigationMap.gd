extends Navigation2D


var astar: AStar2D = AStar2D.new()

#onready var tilemap: TileMap = $TileMap



#func _ready() -> void:
#	setup_astar()
	

#func setup_astar() -> void:
#	for c in tilemap.get_used_cells():
#		var pos = tilemap.map_to_world(c)
#		astar.add_point(abs(pos.x + pos.y * (c.x + c.y)), c, 1)
