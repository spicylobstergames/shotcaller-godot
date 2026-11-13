## Lightweight helper that implements the _get_mirrored_coords formula
## without requiring a TileMap instance.
##
## The formula: local_to_map(Vector2(
##     (mirror_size.x - cell_pos.x) - tile_size.x,
##     (mirror_size.y - cell_pos.y) - tile_size.y
## ))
## where cell_pos = map_to_local(coords).
##
## In TileMap, map_to_local(coords) returns coords * tile_size,
## and local_to_map(local_pos) returns local_pos / tile_size (floor).
## Substituting:
##   mirrored_x = floor(((map_size.x * tile_size.x) - (coords.x * tile_size.x) - tile_size.x) / tile_size.x)
##             = map_size.x - coords.x - 1
## Same for y.  MirrorMath encodes this directly.

extends RefCounted

var mirror_size: Vector2
var tile_size: Vector2


func _init(p_mirror_size: Vector2, p_tile_size: Vector2) -> void:
	mirror_size = p_mirror_size
	tile_size = p_tile_size


func mirrored_coords(coords: Vector2i) -> Vector2i:
	return Vector2i(
		mirror_size.x - coords.x - 1,
		mirror_size.y - coords.y - 1
	)
