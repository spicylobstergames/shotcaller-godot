@tool
extends TileMap

@export var map_size = Vector2(2112,2112)


func set_cell (layer:int, coords:Vector2i, source_id:int=-1, atlas_coords=Vector2i(-1, -1),  alternative_tile:int=0 ) -> void:
#(x: int, y: int, tile: int, flip_x = false, flip_y = false, transpose = false, autotile_coord = Vector2.ZERO) -> void:
	var is_flip = true
	var cell_pos = map_to_local(Vector2(x, y))
	var mirrored_cell_point = local_to_map(Vector2( (map_size.x - cell_pos.x) - cell_size.x, (map_size.x - (cell_pos.y)) - cell_size.x))
		
	super.set_cell(x, y, tile, false, false, transpose, autotile_coord)
	
	if map_to_local(mirrored_cell_point) >= Vector2(y, y) and tile != -1:
		is_flip = tile_set.tile_get_tile_mode(tile) == TileSet.AUTO_TILE

	super.set_cell(
		mirrored_cell_point.x,
		mirrored_cell_point.y,
		tile,
		is_flip,
		is_flip,
		transpose,
		get_cell_autotile_coord(x, y))
