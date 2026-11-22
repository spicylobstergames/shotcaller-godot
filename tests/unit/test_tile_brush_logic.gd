extends RefCounted

# =============================================================================
# Tile brush logic tests (tests/unit/test_tile_brush_logic.gd)
# =============================================================================
# Covers addons/map_editor/tile_brush_logic.gd — the editor-free core of the
# plugin's tile-painting mode: brush->layer resolution, editor-camera click
# math, per-tile paint blocks, the mirror twin math (shared with the ported
# mirror_tiles.gd), the walls cell-size guard, TileSet tile listing, and
# paint/erase/state-restore primitives. The interactive stroke/undo layer is
# editor-only and untestable headless.
# =============================================================================

const TileBrush = preload("res://addons/map_editor/tile_brush_logic.gd")
const Scaffold = preload("res://addons/map_editor/map_scaffold.gd")


func run(harness) -> void:
	_test_layer_for_brush(harness)
	_test_mirrored_cell(harness)
	_test_mirror_size_for(harness)
	_test_click_math(harness)
	_test_paint_blocks(harness)
	_test_block_cells(harness)
	_test_block_options(harness)
	_test_tile_icon(harness)
	_test_walls_guard(harness)
	_test_list_layer_tiles(harness)
	_test_paint_erase_restore(harness)


# ---------------------------------------------------------------------------
# Brush -> layer resolution
# ---------------------------------------------------------------------------

func _test_layer_for_brush(harness) -> void:
	var map: Node = Scaffold.new().build_map()

	harness.check_equal(TileBrush.layer_for_brush(map, "ground"), map.get_node("tiles/ground/Ground"),
			"the ground brush resolves to the contract ground layer")
	harness.check_equal(TileBrush.layer_for_brush(map, "walls"), map.get_node("tiles/walls/Walls"),
			"the walls brush resolves to the contract walls layer")
	harness.check_equal(TileBrush.layer_for_brush(map, "trees"), map.get_node("tiles/trees/Trees"),
			"the trees brush resolves to the contract trees layer")
	harness.check_equal(TileBrush.layer_for_brush(map, "water"), null,
			"an unknown brush resolves to null")
	harness.check_equal(TileBrush.layer_for_brush(null, "ground"), null,
			"a null map resolves to null")

	# A node that exists but is not a TileMapLayer must not pass.
	var bare := Node2D.new()
	var tiles := Node2D.new()
	tiles.name = "tiles"
	var ground := Node2D.new()
	ground.name = "ground"
	tiles.add_child(ground)
	bare.add_child(tiles)
	harness.check_equal(TileBrush.layer_for_brush(bare, "ground"), null,
			"a non-TileMapLayer node under the contract path resolves to null")

	map.free()
	bare.free()


# ---------------------------------------------------------------------------
# Mirror twin math (shared with the ported mirror_tiles.gd)
# ---------------------------------------------------------------------------

func _test_mirrored_cell(harness) -> void:
	# Established values from the old TileMap-based mirror_tiles.gd, kept
	# verbatim by the port: 32px cells on a 100x80 map.
	var cell_size := Vector2i(32, 32)
	var area := Vector2(100 * 32, 80 * 32)
	harness.check_equal(TileBrush.mirrored_cell(Vector2i(0, 0), cell_size, area), Vector2i(98, 78),
			"mirror(0,0) is (98,78) on a 100x80 map (established formula)")
	harness.check_equal(TileBrush.mirrored_cell(Vector2i(98, 78), cell_size, area), Vector2i(0, 0),
			"mirror(98,78) is (0,0) — the pair closes")

	# Involution + reversibility on a seeded sample and a full small sweep.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240101
	var failures := 0
	for i in 100:
		var a := Vector2i(rng.randi_range(0, 99), rng.randi_range(0, 79))
		if TileBrush.mirrored_cell(TileBrush.mirrored_cell(a, cell_size, area), cell_size, area) != a:
			failures += 1
	harness.check_equal(failures, 0,
			"involution holds for 100 seeded samples on a 100x80 map")

	var small := Vector2(50 * 32, 50 * 32)
	failures = 0
	for x in 50:
		for y in 50:
			var a := Vector2i(x, y)
			var b := TileBrush.mirrored_cell(a, cell_size, small)
			if TileBrush.mirrored_cell(b, cell_size, small) != a:
				failures += 1
	harness.check_equal(failures, 0,
			"reversibility holds for all 2500 cells of a 50x50 map")

	# Odd sizes keep the established (7,7) <-> (6,6) pairing.
	var odd := Vector2(15 * 64, 15 * 64)
	harness.check_equal(TileBrush.mirrored_cell(Vector2i(7, 7), Vector2i(64, 64), odd), Vector2i(6, 6),
			"odd map: (7,7) mirrors to (6,6)")

	# No mirror area / no cell size -> unchanged (callers skip the twin).
	harness.check_equal(TileBrush.mirrored_cell(Vector2i(3, 4), cell_size, Vector2.ZERO), Vector2i(3, 4),
			"a ZERO mirror area disables mirroring")
	harness.check_equal(TileBrush.mirrored_cell(Vector2i(3, 4), Vector2i.ZERO, area), Vector2i(3, 4),
			"a ZERO cell size disables mirroring")


# ---------------------------------------------------------------------------
# Mirror area resolution: layer export wins, then the owning BaseMap
# ---------------------------------------------------------------------------

func _test_mirror_size_for(harness) -> void:
	var map: Node = Scaffold.new().build_map()
	var walls: TileMapLayer = map.get_node("tiles/walls/Walls")

	# Plain TileMapLayer has no map_size property; with no owner there is
	# nothing to fall back to.
	harness.check_equal(TileBrush.mirror_size_for(walls), Vector2.ZERO,
			"no export and no owner -> no mirror area")

	# Owner fallback: the scaffolded map's size.
	walls.owner = map
	harness.check_equal(TileBrush.mirror_size_for(walls), map.size,
			"the owning BaseMap's size is the mirror area fallback")

	# The ported script's map_size export wins over the owner.
	var ported: TileMapLayer = (load("res://map/tool/mirror_tiles.gd") as GDScript).new()
	ported.map_size = Vector2(640, 640)
	ported.owner = map
	harness.check_equal(TileBrush.mirror_size_for(ported), Vector2(640, 640),
			"the layer's map_size export wins over the owner")

	map.free()
	ported.free()


# ---------------------------------------------------------------------------
# Click math: editor camera + layer transform -> cells
# ---------------------------------------------------------------------------

func _test_click_math(harness) -> void:
	# The 2D editor camera exactly as CanvasItemEditor builds it (see
	# test_lane_logic.gd): world (0,0) at viewport (1024,512), 0.5x zoom.
	var camera := Transform2D(Vector2(0.5, 0.0), Vector2(0.0, 0.5), Vector2(1024, 512))
	var layer := _layer_with_tileset(64)
	layer.position = Vector2(256, 128)

	var click_on_origin := camera * Vector2(256, 128)
	harness.check_equal(TileBrush.viewport_to_cell(layer, click_on_origin, camera), Vector2i(0, 0),
			"a click on the layer origin is cell (0,0) under a panned/zoomed camera")

	var click_next_cell := camera * (Vector2(256, 128) + Vector2(96, 0))
	harness.check_equal(TileBrush.viewport_to_cell(layer, click_next_cell, camera), Vector2i(1, 0),
			"a click 96px into the layer is cell (1,0) (floored onto the 64px grid)")

	# 8px ground cells: the same click math floors at 8px.
	var ground := _layer_with_tileset(8)
	ground.position = Vector2(256, 128)
	var ground_click := camera * (Vector2(256, 128) + Vector2(4, 4))
	harness.check_equal(TileBrush.viewport_to_cell(ground, ground_click, camera), Vector2i(0, 0),
			"8px cells floor independently: a click 4px into the layer is cell (0,0)")

	layer.free()
	ground.free()


# ---------------------------------------------------------------------------
# Paint blocks: one click covers a whole map tile of layer cells
# ---------------------------------------------------------------------------

func _test_paint_blocks(harness) -> void:
	var walls := _layer_with_tileset(64)
	harness.check_equal(TileBrush.paint_cells_for_local(walls, Vector2(70, 10), 64).size(), 1,
			"a 64px-cell layer paints exactly one cell per map tile")
	harness.check_equal(TileBrush.paint_cells_for_local(walls, Vector2(70, 10), 64), [Vector2i(1, 0)] as Array[Vector2i],
			"a click at local (70,10) paints cell (1,0)")

	var ground := _layer_with_tileset(8)
	var block := TileBrush.paint_cells_for_local(ground, Vector2(70, 10), 64)
	harness.check_equal(block.size(), 64,
			"an 8px-cell layer paints an 8x8 block per map tile")
	var xs := {}
	var ys := {}
	for cell in block:
		xs[cell.x] = true
		ys[cell.y] = true
	harness.check_equal(xs.keys().min(), 8,
			"the 8px block starts at cell x=8 for local x=70")
	harness.check_equal(xs.keys().max(), 15,
			"the 8px block ends at cell x=15 (covering the whole 64px tile)")

	var trees := _layer_with_tileset(24)
	var tree_block := TileBrush.paint_cells_for_local(trees, Vector2(10, 10), 64)
	harness.check_equal(tree_block.size(), 9,
			"a 24px-cell layer paints a 3x3 block per map tile")

	walls.free()
	ground.free()
	trees.free()


# ---------------------------------------------------------------------------
# Detail blocks: n x n cells anchored at the clicked cell
# ---------------------------------------------------------------------------

func _test_block_cells(harness) -> void:
	var block := TileBrush.block_cells(Vector2i(5, 7), 1)
	harness.check_equal(block, [Vector2i(5, 7)] as Array[Vector2i],
			"a 1-cell block is just the clicked cell")

	var pair := TileBrush.block_cells(Vector2i(5, 7), 2)
	harness.check_equal(pair.size(), 4,
			"a 2-cell block covers 4 cells")
	harness.check(Vector2i(6, 8) in pair,
			"the block extends down-right from the clicked cell")

	harness.check_equal(TileBrush.block_cells(Vector2i(3, 3), 0).size(), 1,
			"a non-positive block size clamps to a single cell")


func _test_block_options(harness) -> void:
	harness.check_equal(TileBrush.block_options_for(Vector2i(8, 8), 64), [1, 2, 4, 8] as Array[int],
			"8px ground cells offer 1/2/4/8-cell blocks (8 = full tile)")
	harness.check_equal(TileBrush.block_options_for(Vector2i(24, 24), 64), [1, 2, 3] as Array[int],
			"24px tree cells offer 1/2/3-cell blocks (3 = full tile)")
	harness.check_equal(TileBrush.block_options_for(Vector2i(64, 64), 64), [1] as Array[int],
			"64px walls offer only the single cell")
	harness.check_equal(TileBrush.block_options_for(Vector2i.ZERO, 64), [1] as Array[int],
			"a missing cell size offers only the single cell")


# ---------------------------------------------------------------------------
# Tile preview icons for the dock picker
# ---------------------------------------------------------------------------

func _test_tile_icon(harness) -> void:
	# A real CPU-side image: GradientTexture2D.get_image() is null under the
	# headless dummy renderer, but ImageTexture keeps its source image.
	# 64px so the icon path exercises the downscale.
	var ts := TileSet.new()
	ts.tile_size = Vector2i(64, 64)
	var source := TileSetAtlasSource.new()
	var image := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(0, 0, 64, 64), Color.RED)
	var texture := ImageTexture.create_from_image(image)
	source.texture = texture
	source.texture_region_size = Vector2i(64, 64)
	source.create_tile(Vector2i(0, 0))
	ts.add_source(source, 0)

	var icon := TileBrush.tile_icon(ts, 0, Vector2i(0, 0))
	harness.check(icon != null,
			"a readable tile yields a preview icon")
	if icon != null:
		harness.check(icon.get_width() == 96 and icon.get_height() == 96,
				"a 64px tile is upscaled 4x to a 96x96 icon (nearest-neighbor)")

	# An 8px ground cell must upscale too — it was invisible at native size.
	var ts_tiny := TileSet.new()
	ts_tiny.tile_size = Vector2i(8, 8)
	var tiny_source := TileSetAtlasSource.new()
	var tiny_image := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	tiny_image.fill_rect(Rect2i(0, 0, 8, 8), Color.BLUE)
	tiny_source.texture = ImageTexture.create_from_image(tiny_image)
	tiny_source.texture_region_size = Vector2i(8, 8)
	tiny_source.create_tile(Vector2i(0, 0))
	ts_tiny.add_source(tiny_source, 0)
	var tiny_icon := TileBrush.tile_icon(ts_tiny, 0, Vector2i(0, 0))
	harness.check(tiny_icon != null and tiny_icon.get_width() == 96,
			"an 8px ground cell upscales to the 96px icon box")

	harness.check_equal(TileBrush.tile_icon(ts, 5, Vector2i(0, 0)), null,
			"a missing source yields no icon")
	harness.check_equal(TileBrush.tile_icon(ts, 0, Vector2i(9, 9)), null,
			"a missing atlas tile yields no icon")
	harness.check_equal(TileBrush.tile_icon(null, 0, Vector2i(0, 0)), null,
			"a null TileSet yields no icon")


# ---------------------------------------------------------------------------
# Walls guard: navigation grids walls cells by tile_size
# ---------------------------------------------------------------------------

func _test_walls_guard(harness) -> void:
	var map: Node = Scaffold.new().build_map()

	var walls: TileMapLayer = map.get_node("tiles/walls/Walls")
	harness.check_equal(TileBrush.walls_guard_message(map, "walls", walls), "",
			"the scaffold's walls TileSet (64px) passes the guard")
	harness.check_equal(TileBrush.walls_guard_message(map, "ground", map.get_node("tiles/ground/Ground")), "",
			"non-walls brushes are never guarded (ground legitimately runs 8px cells)")

	var map_child := Node2D.new()
	map_child.name = "tiles"
	var fake_walls := Node2D.new()
	fake_walls.name = "walls"
	map_child.add_child(fake_walls)
	harness.check_equal(TileBrush.walls_guard_message(map_child, "walls", null), "",
			"a null layer is not guarded here (resolution reports it separately)")

	# A walls TileSet with the wrong cell size must be refused with a message:
	# swap the scaffold map's walls TileSet (BaseMap.tile_size = 64) for a
	# 32px one.
	var walls_tile_set: TileSet = walls.tile_set
	walls.tile_set = _tileset_with_tiles(32, 1)
	harness.check(TileBrush.walls_guard_message(map, "walls", walls) != "",
			"a walls TileSet whose cell size differs from tile_size is refused")
	walls.tile_set = walls_tile_set

	map.free()


# ---------------------------------------------------------------------------
# Tile listing: (source, atlas) pairs for the dock picker
# ---------------------------------------------------------------------------

func _test_list_layer_tiles(harness) -> void:
	var layer := _layer_with_tileset(64)  # source 0 with one tile at (0,0)
	var tiles := TileBrush.list_layer_tiles(layer)
	harness.check_equal(tiles.size(), 1,
			"a one-tile TileSet lists one (source, atlas) pair")
	harness.check_equal(tiles[0], {"source_id": 0, "atlas_coords": Vector2i(0, 0)},
			"the listed pair carries the source id and atlas coords")

	# A second source with its own tile extends the list — walls sources ARE
	# teams (0 = blue, else red), so the picker must offer sources.
	var second := TileSetAtlasSource.new()
	var texture := PlaceholderTexture2D.new()
	texture.size = Vector2i(64, 64)
	second.texture = texture
	second.create_tile(Vector2i(0, 0))
	second.create_tile(Vector2i(1, 0))
	layer.tile_set.add_source(second, 1)
	tiles = TileBrush.list_layer_tiles(layer)
	harness.check_equal(tiles.size(), 3,
			"tiles from every source are listed")
	harness.check(tiles.any(func(t): return t.source_id == 1 and t.atlas_coords == Vector2i(1, 0)),
			"the second source's (1,0) tile is listed with its source id")

	var bare := TileMapLayer.new()
	harness.check_equal(TileBrush.list_layer_tiles(bare).size(), 0,
			"a layer without a TileSet lists nothing")

	layer.free()
	bare.free()


# ---------------------------------------------------------------------------
# Paint/erase/state-restore primitives with mirrored twins
# ---------------------------------------------------------------------------

func _test_paint_erase_restore(harness) -> void:
	# The ported mirror-script layer carries the map_size export the mirror
	# area resolves from (a plain TileMapLayer has no such property).
	var layer: TileMapLayer = (load("res://map/tool/mirror_tiles.gd") as GDScript).new()
	layer.tile_set = _tileset_with_tiles(64, 1)
	layer.map_size = Vector2(256, 256)  # 4x4 tiles: (0,0) <-> (2,2)

	TileBrush.paint_cells(layer, [Vector2i(0, 0)] as Array[Vector2i], 0, Vector2i(0, 0), 0)
	harness.check(layer.get_cell_source_id(Vector2i(0, 0)) == 0,
			"paint_cells paints the requested cell")
	harness.check(layer.get_cell_source_id(Vector2i(2, 2)) == 0,
			"paint_cells paints the mirrored twin (0,0 -> 2,2 on a 4x4 map)")

	TileBrush.erase_cells(layer, [Vector2i(0, 0)] as Array[Vector2i])
	harness.check(layer.get_cell_source_id(Vector2i(0, 0)) == -1,
			"erase_cells clears the requested cell")
	harness.check(layer.get_cell_source_id(Vector2i(2, 2)) == -1,
			"erase_cells clears the mirrored twin too")

	# State capture/restore is what stroke undo replays.
	TileBrush.paint_cells(layer, [Vector2i(1, 1)] as Array[Vector2i], 1, Vector2i(0, 0), 0)
	var state := TileBrush.get_cell_state(layer, Vector2i(1, 1))
	TileBrush.paint_cells(layer, [Vector2i(1, 1)] as Array[Vector2i], 0, Vector2i(0, 0), 0)
	harness.check(layer.get_cell_source_id(Vector2i(1, 1)) == 0,
			"a repaint over an existing cell takes the new source")
	TileBrush.restore_cell_state(layer, Vector2i(1, 1), state)
	harness.check(layer.get_cell_source_id(Vector2i(1, 1)) == 1,
			"restore_cell_state puts back the previous source (undo replay)")

	var empty_state := TileBrush.get_cell_state(layer, Vector2i(3, 3))
	TileBrush.paint_cells(layer, [Vector2i(3, 3)] as Array[Vector2i], 0, Vector2i(0, 0), 0)
	TileBrush.restore_cell_state(layer, Vector2i(3, 3), empty_state)
	harness.check(layer.get_cell_source_id(Vector2i(3, 3)) == -1,
			"restoring a captured empty state erases the cell again")

	layer.free()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# A TileMapLayer whose TileSet has source 0 with `tile_count` tiles at (0,0),
# (1,0), ...
func _layer_with_tileset(cell_px: int, tile_count: int = 1) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = _tileset_with_tiles(cell_px, tile_count)
	return layer


func _tileset_with_tiles(cell_px: int, tile_count: int) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(cell_px, cell_px)
	var source := TileSetAtlasSource.new()
	var texture := PlaceholderTexture2D.new()
	texture.size = Vector2i(cell_px, cell_px)
	source.texture = texture
	# The region size defaults to 16x16; real atlas sources declare their own,
	# and the icon math reads it — so tests must declare it too.
	source.texture_region_size = Vector2i(cell_px, cell_px)
	for i in tile_count:
		source.create_tile(Vector2i(i, 0))
	ts.add_source(source, 0)
	return ts
