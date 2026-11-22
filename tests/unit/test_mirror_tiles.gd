extends RefCounted

# =============================================================================
# Mirror tiles tests (tests/unit/test_mirror_tiles.gd)
# =============================================================================
# Covers map/tool/mirror_tiles.gd after the TileMapLayer port: the mirror
# coordinate math now lives in addons/map_editor/tile_brush_logic.gd
# (mirrored_cell) and the layer delegates to it, so the invariants tested
# here are the same as pre-port — involution, reversibility, even/odd map
# sizes — plus single-layer cell diffing and a production end-to-end sync.
# =============================================================================

const MirrorTilesScript = preload("res://map/tool/mirror_tiles.gd")
const TileBrushLogic = preload("res://addons/map_editor/tile_brush_logic.gd")


func run(harness) -> void:
	# --- Involution: mirroring a coordinate twice returns the original ---
	_test_involution_production(harness)

	# --- Reversibility: mirror(A) == B implies mirror(B) == A ---
	_test_reversibility_production(harness)

	# --- Even map sizes ---
	_test_even_map_sizes_production(harness)

	# --- Odd map sizes ---
	_test_odd_map_sizes_production(harness)

	# --- Cell diffing — addition ---
	_test_cell_addition_production(harness)

	# --- Cell diffing — removal ---
	_test_cell_removal_production(harness)

	# --- Cell diffing — no changes ---
	_test_no_changes_production(harness)

	# --- Cell diffing — partial changes ---
	_test_partial_changes_production(harness)

	# --- End-to-end: painting a cell syncs its mirrored twin ---
	_test_mirror_sync_end_to_end(harness)

	# --- set_mirrored_cell paints both twins at once ---
	_test_set_mirrored_cell(harness)


# ---------------------------------------------------------------------------
# Production-backed mirror coordinate tests
# ---------------------------------------------------------------------------

func _setup_mirror_layer(tile_size_val: int, map_w: int, map_h: int) -> TileMapLayer:
	var mt: TileMapLayer = MirrorTilesScript.new()
	var ts = TileSet.new()
	ts.tile_size = Vector2i(tile_size_val, tile_size_val)
	mt.tile_set = ts
	mt.map_size = Vector2(map_w * tile_size_val, map_h * tile_size_val)
	# The layer's transform is identity by default, so cell math behaves as
	# coords * tile_size (see TileBrushLogic.mirrored_cell).
	return mt


func _test_involution_production(harness) -> void:
	# 100x100 tiles, 32px — corners, edges, center, and 100 seeded-random
	# cells mirrored twice must return the original (deterministic sample,
	# not an exhaustive 10k-assertion sweep).
	var mt = _setup_mirror_layer(32, 100, 100)
	var rng = RandomNumberGenerator.new()
	rng.seed = 20240101
	var cells: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(99, 0), Vector2i(0, 99), Vector2i(99, 99),
		Vector2i(0, 50), Vector2i(99, 50), Vector2i(50, 0), Vector2i(50, 99),
		Vector2i(50, 50),
	]
	for i in range(100):
		cells.append(Vector2i(rng.randi_range(0, 99), rng.randi_range(0, 99)))
	var failures := 0
	for a in cells:
		var b = mt._mirrored_coords(a)
		var c = mt._mirrored_coords(b)
		if c != a:
			failures += 1
	harness.check_equal(failures, 0,
		"Involution: mirror(mirror(cell)) == cell for %d sampled cells (incl. corners/edges/center)." % cells.size())
	mt.free()


func _test_reversibility_production(harness) -> void:
	# 50x50 tiles, 32px — a full sweep of a small map: if mirror(A) == B then
	# mirror(B) == A. Small enough (2500) to exhaust while keeping the suite fast.
	var mt = _setup_mirror_layer(32, 50, 50)
	var failures := 0
	for x in range(50):
		for y in range(50):
			var a = Vector2i(x, y)
			var b = mt._mirrored_coords(a)
			var c = mt._mirrored_coords(b)
			if c != a:
				failures += 1
	harness.check_equal(failures, 0,
		"Reversibility: mirror(mirror(cell)) == cell for all 2500 cells of a 50x50 map.")
	mt.free()


func _test_even_map_sizes_production(harness) -> void:
	# 100x80 tiles, 64px — specific corners
	var mt = _setup_mirror_layer(64, 100, 80)
	var tl = mt._mirrored_coords(Vector2i(0, 0))
	harness.check_equal(tl, Vector2i(98, 78),
		"Even map: top-left (0,0) mirrors to (98,78) (the established formula).")
	var br = mt._mirrored_coords(Vector2i(98, 78))
	harness.check_equal(br, Vector2i(0, 0),
		"Even map: (98,78) mirrors back to top-left (0,0).")
	mt.free()


func _test_odd_map_sizes_production(harness) -> void:
	# 15x15 tiles, 64px — the production formula maps (7,7) to (6,6) and vice versa
	var mt = _setup_mirror_layer(64, 15, 15)
	var m1 = mt._mirrored_coords(Vector2i(7, 7))
	var m2 = mt._mirrored_coords(Vector2i(6, 6))
	harness.check_equal(m1, Vector2i(6, 6),
		"Odd map: cell (7,7) mirrors to (6,6).")
	harness.check_equal(m2, Vector2i(7, 7),
		"Odd map: cell (6,6) mirrors back to (7,7).")
	mt.free()


# ---------------------------------------------------------------------------
# Cell diffing (single layer — the port dropped the layer index dimension)
# ---------------------------------------------------------------------------

func _cell(coords: Vector2i, source_id: int = 1, atlas: Vector2i = Vector2i(0, 0)) -> Dictionary:
	return {
		"coords": coords,
		"present": true,
		"source_id": source_id,
		"atlas_coords": atlas,
		"alternative_tile": 0,
	}


func _test_cell_addition_production(harness) -> void:
	# Old snapshot is empty, new snapshot has one cell -> detected as addition.
	var mt: TileMapLayer = MirrorTilesScript.new()
	mt._cell_snapshot = {}
	var new_snap: Dictionary = {"3:5": _cell(Vector2i(3, 5))}
	var changed = mt._get_changed_cells(new_snap)
	harness.check("3:5" in changed,
		"Cell addition: new cell detected in changed cells.")
	harness.check(changed["3:5"].present == true,
		"Cell addition: present flag is true for added cell.")
	mt.free()


func _test_cell_removal_production(harness) -> void:
	# Old snapshot had a cell, new snapshot doesn't -> detected as removal.
	var mt: TileMapLayer = MirrorTilesScript.new()
	mt._cell_snapshot = {"3:5": _cell(Vector2i(3, 5))}
	var changed = mt._get_changed_cells({})
	harness.check("3:5" in changed,
		"Cell removal: removed cell detected in changed cells.")
	harness.check(changed["3:5"].present == false,
		"Cell removal: present flag is false for removed cell.")
	mt.free()


func _test_no_changes_production(harness) -> void:
	# Identical snapshots: no changes.
	var mt: TileMapLayer = MirrorTilesScript.new()
	var snap: Dictionary = {
		"2:3": _cell(Vector2i(2, 3)),
		"4:5": _cell(Vector2i(4, 5), 1, Vector2i(1, 0)),
	}
	mt._cell_snapshot = snap
	harness.check(mt._get_changed_cells(snap).is_empty(),
		"No changes: identical snapshots produce empty diff.")
	mt.free()


func _test_partial_changes_production(harness) -> void:
	# Old: cells (0,0), (1,0), (2,0); new: (1,0) modified, (0,0) removed,
	# (3,0) added.
	var mt: TileMapLayer = MirrorTilesScript.new()
	mt._cell_snapshot = {
		"0:0": _cell(Vector2i(0, 0)),
		"1:0": _cell(Vector2i(1, 0)),
		"2:0": _cell(Vector2i(2, 0)),
	}
	var new_snap: Dictionary = {
		"1:0": _cell(Vector2i(1, 0), 5),
		"2:0": _cell(Vector2i(2, 0)),
		"3:0": _cell(Vector2i(3, 0), 2, Vector2i(1, 1)),
	}
	var changed = mt._get_changed_cells(new_snap)
	harness.check_equal(changed.size(), 3,
		"Partial changes: exactly 3 cells changed (1 added, 1 modified, 1 removed).")
	harness.check("0:0" in changed, "Partial changes: removed cell (0,0) detected.")
	harness.check("1:0" in changed, "Partial changes: modified cell (1,0) detected.")
	harness.check("3:0" in changed, "Partial changes: added cell (3,0) detected.")
	mt.free()


# ---------------------------------------------------------------------------
# End-to-end: the ported layer actually mirrors
# ---------------------------------------------------------------------------

func _layer_with_tile(tile_size_val: int) -> TileMapLayer:
	var mt: TileMapLayer = MirrorTilesScript.new()
	var ts = TileSet.new()
	ts.tile_size = Vector2i(tile_size_val, tile_size_val)
	var source = TileSetAtlasSource.new()
	var texture = PlaceholderTexture2D.new()
	texture.size = Vector2i(tile_size_val, tile_size_val)
	source.texture = texture
	source.create_tile(Vector2i(0, 0))
	ts.add_source(source, 0)
	mt.tile_set = ts
	return mt


func _test_mirror_sync_end_to_end(harness) -> void:
	var mt = _setup_mirror_layer(32, 20, 20)  # mirror area 640x640 px
	# Baseline snapshot as _ready would take it, then paint through the
	# built-in path (set_cell) and run the deferred sync manually.
	mt._cell_snapshot = mt._get_cell_snapshot()
	mt.set_cell(Vector2i(2, 3), 0, Vector2i(0, 0))
	mt._sync_mirrored_cells()

	var mirror_of = mt._mirrored_coords(Vector2i(2, 3))
	harness.check(mt.get_cell_source_id(mirror_of) == 0,
			"sync paints the mirrored twin of a painted cell")
	harness.check(mt.get_cell_atlas_coords(mirror_of) == Vector2i(0, 0),
			"sync copies the atlas coords to the twin")

	# Erasing syncs the erase: remove the original, sync, twin must go too.
	mt.erase_cell(Vector2i(2, 3))
	mt._sync_mirrored_cells()
	harness.check(mt.get_cell_source_id(mirror_of) == -1,
			"sync erases the mirrored twin of an erased cell")
	mt.free()


func _test_set_mirrored_cell(harness) -> void:
	var mt = _setup_mirror_layer(32, 20, 20)
	mt.set_mirrored_cell(Vector2i(4, 5), 0, Vector2i(0, 0))
	var twin = mt._mirrored_coords(Vector2i(4, 5))
	harness.check(mt.get_cell_source_id(Vector2i(4, 5)) == 0,
			"set_mirrored_cell paints the requested cell")
	harness.check(mt.get_cell_source_id(twin) == 0,
			"set_mirrored_cell paints its mirrored twin in the same call")
	mt.free()
