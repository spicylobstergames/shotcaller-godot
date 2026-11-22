extends RefCounted

# =============================================================================
# Tile brush logic (addons/map_editor/tile_brush_logic.gd)
# =============================================================================
# Pure, editor-free helpers for the plugin's tile-painting mode — the sibling
# of lane_logic.gd / building_logic.gd. Everything that decides WHICH layer a
# brush targets, WHICH cell(s) a click covers, and WHERE its mirrored twin
# lives lives here so it runs in the headless unit suite
# (tests/unit/test_tile_brush_logic.gd); the plugin only forwards editor
# input/output to these functions.
#
# Contract being honored (map_validator.gd / base_map.gd / pathfind/
# navigation.gd):
#   - the three required TileMapLayers are tiles/ground/Ground,
#     tiles/walls/Walls, tiles/trees/Trees;
#   - the WALLS TileSet cell size must equal base_map's tile_size (navigation
#     grids walls cells by tile_size) — the validator fails otherwise, so the
#     brush refuses instead of painting a broken map;
#   - a walls cell's SOURCE ID picks its team (0 = blue, else red) — that is
#     why the dock's tile picker lists (source, atlas) pairs, not just atlas
#     coords.
#
# Brush strokes paint one base_map TILE (tile_size px, default 64) worth of
# layer cells per click: ground runs 8px cells (8x8 cells per click), trees
# 24px (3x3), walls 64px (1x1). Cell math floors positions onto the layer's
# grid — the same convention TileMapLayer uses to place cells.
# =============================================================================

const BRUSHES := {
	"ground": "tiles/ground/Ground",
	"walls": "tiles/walls/Walls",
	"trees": "tiles/trees/Trees",
}


# The TileMapLayer a brush paints on, or null (missing node or wrong type —
# the dock/plugin logs instead of crashing).
static func layer_for_brush(map_root: Node, brush: String) -> TileMapLayer:
	if map_root == null or not BRUSHES.has(brush):
		return null
	var layer = map_root.get_node_or_null(BRUSHES[brush])
	if layer is TileMapLayer:
		return layer
	return null


# Editor-camera click -> layer-local position. camera_xform is the edited
# node's Viewport.get_global_canvas_transform() — the 2D editor's pan/zoom in
# Godot 4.7 (see lane_logic.gd: the plain canvas_transform is identity in the
# editor, and get_global_transform_with_canvas never sees the camera).
static func viewport_to_local(layer: TileMapLayer, viewport_pos: Vector2, camera_xform: Transform2D) -> Vector2:
	return (camera_xform * layer.get_global_transform()).affine_inverse() * viewport_pos


# Layer-local position -> the layer cell under it.
static func viewport_to_cell(layer: TileMapLayer, viewport_pos: Vector2, camera_xform: Transform2D) -> Vector2i:
	return local_to_cell(layer, viewport_to_local(layer, viewport_pos, camera_xform))


static func local_to_cell(layer: TileMapLayer, local_pos: Vector2) -> Vector2i:
	var cell_size := cell_size_of(layer)
	if cell_size == Vector2i.ZERO:
		return Vector2i.ZERO
	return Vector2i((local_pos / Vector2(cell_size)).floor())


# The layer's TileSet cell size, or ZERO when it has no TileSet (callers
# guard).
static func cell_size_of(layer: TileMapLayer) -> Vector2i:
	if layer == null or layer.tile_set == null:
		return Vector2i.ZERO
	return layer.tile_set.tile_size


# The block of layer cells covering the map tile (map_tile_px, default 64)
# containing local_pos. A click paints whole map tiles so 8px ground cells
# fill a 64px square (8x8 cells) and 24px tree cells a 3x3 block, while
# 64px walls stay 1x1.
static func paint_cells_for_local(layer: TileMapLayer, local_pos: Vector2, map_tile_px: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var cell_size := cell_size_of(layer)
	if cell_size == Vector2i.ZERO or map_tile_px <= 0:
		return cells
	var step := Vector2(cell_size)
	var block_origin := (local_pos / float(map_tile_px)).floor() * float(map_tile_px)
	var block_end := block_origin + Vector2(map_tile_px, map_tile_px)
	var first: Vector2i = Vector2i((block_origin / step).floor())
	var last: Vector2i = Vector2i(((block_end - step * 0.001) / step).floor())
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			cells.append(Vector2i(x, y))
	return cells


# An n x n block of cells anchored at origin (detail painting: the dock's
# block-size choice). n <= 1 yields just the origin cell.
static func block_cells(origin: Vector2i, n: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var size := maxi(n, 1)
	for x in size:
		for y in size:
			cells.append(origin + Vector2i(x, y))
	return cells


# Sensible block-size choices in cells for a layer with the given cell size:
# powers of two up to the map tile, always ending with the full-tile size.
# 8px ground -> [1, 2, 4, 8]; 24px trees -> [1, 2, 3]; 64px walls -> [1].
static func block_options_for(cell_size: Vector2i, map_tile_px: int) -> Array[int]:
	var options: Array[int] = [1]
	if cell_size.x <= 0 or cell_size.y <= 0 or map_tile_px <= 0:
		return options
	var max_n := int(ceil(float(map_tile_px) / float(mini(cell_size.x, cell_size.y))))
	var n := 1
	while n < max_n:
		n *= 2
		if n < max_n:
			options.append(n)
	if max_n > 1:
		options.append(max_n)
	return options


# A preview icon for a tile: the atlas region scaled (aspect kept, nearest-
# neighbor so pixel art stays crisp) to fit icon_px — UP or DOWN, since an
# 8px ground cell is invisible at native size. The dock uses 96 (4x the old
# 24px) for easy reading. null when the tile can't be read.
static func tile_icon(tile_set: TileSet, source_id: int, atlas_coords: Vector2i, icon_px: int = 96) -> Texture2D:
	if tile_set == null:
		return null
	var source = tile_set.get_source(source_id)
	if not (source is TileSetAtlasSource) or source.texture == null:
		return null
	if not source.has_tile(atlas_coords):
		return null
	var image: Image = source.texture.get_image()
	if image == null:
		return null
	if image.is_compressed():
		if image.decompress() != OK:
			return null
	var region: Rect2i = source.get_tile_texture_region(atlas_coords)
	if region.size.x <= 0 or region.size.y <= 0:
		return null
	var sub: Image = image.get_region(region)
	var scale := minf(float(icon_px) / region.size.x, float(icon_px) / region.size.y)
	sub.resize(maxi(1, int(region.size.x * scale)), maxi(1, int(region.size.y * scale)), Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(sub)


# The mirrored twin of a cell: 180° rotation of the cell's center around the
# mirror area's center (the established formula from the old TileMap-based
# mirror_tiles.gd, kept verbatim as cell math: mirror_px - center - cell,
# floored onto the cell grid). Returns coords unchanged when there is no
# mirror area (mirror_size_px ZERO) — callers skip the twin write then.
static func mirrored_cell(coords: Vector2i, cell_size: Vector2i, mirror_size_px: Vector2) -> Vector2i:
	if mirror_size_px == Vector2.ZERO or cell_size == Vector2i.ZERO:
		return coords
	var step := Vector2(cell_size)
	var center := Vector2(coords) * step + step / 2.0
	return Vector2i(((mirror_size_px - center - step) / step).floor())


# The mirror area in pixels for a layer: the ported mirror_tiles.gd's
# map_size export wins, else the owning BaseMap's size, else ZERO (no mirror).
static func mirror_size_for(layer: TileMapLayer) -> Vector2:
	var export_size = layer.get("map_size")
	if export_size is Vector2 and export_size != Vector2.ZERO:
		return export_size
	var map := layer.get_owner() as BaseMap
	if map != null:
		return map.size
	return Vector2.ZERO


# The walls guard, as a message ("" = fine): navigation.gd grids walls cells
# by base_map's tile_size, so painting walls on a TileSet with a different
# cell size would block the wrong pathfinding cells (the validator fails the
# map for exactly this). Only walls are checked — ground (8px) and trees
# (24px) TileSets legitimately differ.
static func walls_guard_message(map_root: Node, brush: String, layer: TileMapLayer) -> String:
	if brush != "walls" or layer == null:
		return ""
	var tile_size = map_root.get("tile_size")
	if layer.tile_set == null or not (tile_size is int or tile_size is float) or tile_size <= 0:
		return ""
	var expected := Vector2i(int(tile_size), int(tile_size))
	if layer.tile_set.tile_size != expected:
		return ("REFUSED: the walls TileSet cell size %s does not match tile_size %d — "
				+ "painted walls would block the wrong pathfinding cells.") % [layer.tile_set.tile_size, tile_size]
	return ""


# Every paintable (source_id, atlas_coords) of the layer's TileSet — the
# dock's tile picker. Walls sources ARE teams (0 = blue, else red), so the
# picker must offer sources, not just atlas coords.
static func list_layer_tiles(layer: TileMapLayer) -> Array[Dictionary]:
	var tiles: Array[Dictionary] = []
	if layer == null or layer.tile_set == null:
		return tiles
	for i in layer.tile_set.get_source_count():
		var source_id: int = layer.tile_set.get_source_id(i)
		var source = layer.tile_set.get_source(source_id)
		if source is TileSetAtlasSource:
			for t in source.get_tiles_count():
				tiles.append({"source_id": source_id, "atlas_coords": source.get_tile_id(t)})
	return tiles


# A cell's full paint state, for stroke undo (restore_cell_state).
static func get_cell_state(layer: TileMapLayer, coords: Vector2i) -> Dictionary:
	return {
		"present": layer.get_cell_source_id(coords) != -1,
		"source_id": layer.get_cell_source_id(coords),
		"atlas_coords": layer.get_cell_atlas_coords(coords),
		"alternative_tile": layer.get_cell_alternative_tile(coords),
	}


static func restore_cell_state(layer: TileMapLayer, coords: Vector2i, state: Dictionary) -> void:
	if state.get("present", false):
		layer.set_cell(coords, state.get("source_id", -1), state.get("atlas_coords", Vector2i(-1, -1)),
				state.get("alternative_tile", 0))
	else:
		layer.erase_cell(coords)


# Paint/erase cells AND their mirrored twins (explicit mirroring — the plugin
# does not rely on the changed-snapshot mirror while it paints; if the layer
# also carries the ported mirror_tiles.gd, its deferred sync becomes a no-op
# because the twins are already in place).
static func paint_cells(layer: TileMapLayer, cells: Array[Vector2i], source_id: int,
		atlas_coords: Vector2i, alternative_tile: int) -> void:
	var cell_size := cell_size_of(layer)
	var mirror_size := mirror_size_for(layer)
	for coords in cells:
		layer.set_cell(coords, source_id, atlas_coords, alternative_tile)
		var mirrored := mirrored_cell(coords, cell_size, mirror_size)
		if mirrored != coords:
			layer.set_cell(mirrored, source_id, atlas_coords, alternative_tile)


static func erase_cells(layer: TileMapLayer, cells: Array[Vector2i]) -> void:
	var cell_size := cell_size_of(layer)
	var mirror_size := mirror_size_for(layer)
	for coords in cells:
		layer.erase_cell(coords)
		var mirrored := mirrored_cell(coords, cell_size, mirror_size)
		if mirrored != coords:
			layer.erase_cell(mirrored)
