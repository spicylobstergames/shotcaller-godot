extends RefCounted

const MirrorTilesScript = preload("res://map/tool/mirror_tiles.gd")


func run(harness) -> void:
	# ---- Mirror coordinate tests — using production MirrorTiles methods ----

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


# ---------------------------------------------------------------------------
# Production-backed mirror coordinate tests
# ---------------------------------------------------------------------------

func _setup_mirror_map(tile_size_val: int, map_w: int, map_h: int) -> Node:
	var mt = MirrorTilesScript.new()
	# Create a TileSet with the desired tile size
	var ts = TileSet.new()
	ts.tile_size = Vector2i(tile_size_val, tile_size_val)
	mt.tile_set = ts
	mt.map_size = Vector2(map_w * tile_size_val, map_h * tile_size_val)
	# TileMap transform is identity by default, so map_to_local and local_to_map
	# behave as: map_to_local(coords) = coords * tile_size,
	#             local_to_map(local) = floor(local / tile_size)
	return mt


func _test_involution_production(harness) -> void:
	# 100x100 tiles, 32px — every cell mirrored twice returns original
	var mt = _setup_mirror_map(32, 100, 100)
	for x in range(100):
		for y in range(100):
			var a = Vector2i(x, y)
			var b = mt._get_mirrored_coords(a)
			var c = mt._get_mirrored_coords(b)
			harness.check(c == a, "Involution: mirror(mirror(%d,%d)) == (%d,%d)" % [x, y, x, y])
			if c != a:
				break  # fail fast on first mismatch


func _test_reversibility_production(harness) -> void:
	# 50x50 tiles, 32px — if mirror(A) == B then mirror(B) == A
	var mt = _setup_mirror_map(32, 50, 50)
	for x in range(50):
		for y in range(50):
			var a = Vector2i(x, y)
			var b = mt._get_mirrored_coords(a)
			var c = mt._get_mirrored_coords(b)
			harness.check(c == a, "Reversibility: mirror(mirror(%d,%d)) == (%d,%d)" % [x, y, x, y])


func _test_even_map_sizes_production(harness) -> void:
	# 100x80 tiles, 64px — specific corners
	var mt = _setup_mirror_map(64, 100, 80)
	var tl = mt._get_mirrored_coords(Vector2i(0, 0))
	harness.check_equal(tl, Vector2i(98, 78),
		"Even map: top-left (0,0) mirrors to bottom-right (99,79).")
	var br = mt._get_mirrored_coords(Vector2i(98, 78))
	harness.check_equal(br, Vector2i(0, 0),
		"Even map: bottom-right (99,79) mirrors to top-left (0,0).")


func _test_odd_map_sizes_production(harness) -> void:
	# 15x15 tiles, 64px — the production formula maps (7,7) to (6,6) and vice versa
	var mt = _setup_mirror_map(64, 15, 15)
	var m1 = mt._get_mirrored_coords(Vector2i(7, 7))
	var m2 = mt._get_mirrored_coords(Vector2i(6, 6))
	harness.check_equal(m1, Vector2i(6, 6),
		"Odd map: cell (7,7) mirrors to (6,6).")
	harness.check_equal(m2, Vector2i(7, 7),
		"Odd map: cell (6,6) mirrors back to (7,7).")


# ---------------------------------------------------------------------------
# Production-backed cell diffing tests
# ---------------------------------------------------------------------------

func _test_cell_addition_production(harness) -> void:
	# Simulate: old snapshot is empty, new snapshot has one cell.
	# _get_changed_cells should detect it as an addition.
	var mt = MirrorTilesScript.new()
	mt._cell_snapshot = {}  # empty previous snapshot
	var new_snap: Dictionary = {
		"0:3:5": {
			"layer": 0,
			"coords": Vector2i(3, 5),
			"present": true,
			"source_id": 1,
			"atlas_coords": Vector2i(0, 0),
			"alternative_tile": 0,
		},
	}
	var changed = mt._get_changed_cells(new_snap)
	harness.check("0:3:5" in changed,
		"Cell addition: new cell detected in changed cells.")
	harness.check(changed["0:3:5"].present == true,
		"Cell addition: present flag is true for added cell.")


func _test_cell_removal_production(harness) -> void:
	# Simulate: old snapshot had a cell, new snapshot doesn't.
	# _get_changed_cells should detect it as a removal.
	var mt = MirrorTilesScript.new()
	mt._cell_snapshot = {
		"0:3:5": {
			"layer": 0,
			"coords": Vector2i(3, 5),
			"present": true,
			"source_id": 1,
			"atlas_coords": Vector2i(0, 0),
			"alternative_tile": 0,
		},
	}
	var new_snap: Dictionary = {}
	var changed = mt._get_changed_cells(new_snap)
	harness.check("0:3:5" in changed,
		"Cell removal: removed cell detected in changed cells.")
	harness.check(changed["0:3:5"].present == false,
		"Cell removal: present flag is false for removed cell.")


func _test_no_changes_production(harness) -> void:
	# Identical snapshots: no changes.
	var mt = MirrorTilesScript.new()
	var snap: Dictionary = {
		"0:2:3": {
			"layer": 0, "coords": Vector2i(2, 3), "present": true,
			"source_id": 1, "atlas_coords": Vector2i(0, 0), "alternative_tile": 0,
		},
		"0:4:5": {
			"layer": 0, "coords": Vector2i(4, 5), "present": true,
			"source_id": 1, "atlas_coords": Vector2i(1, 0), "alternative_tile": 0,
		},
	}
	mt._cell_snapshot = snap
	var changed = mt._get_changed_cells(snap)
	harness.check(changed.is_empty(),
		"No changes: identical snapshots produce empty diff.")


func _test_partial_changes_production(harness) -> void:
	# Old: cells A(0,0), B(1,0), C(2,0)
	# New: B modified, A removed, D(3,0) added
	var mt = MirrorTilesScript.new()
	mt._cell_snapshot = {
		"0:0:0": {
			"layer": 0, "coords": Vector2i(0, 0), "present": true,
			"source_id": 1, "atlas_coords": Vector2i(0, 0), "alternative_tile": 0,
		},
		"0:1:0": {
			"layer": 0, "coords": Vector2i(1, 0), "present": true,
			"source_id": 1, "atlas_coords": Vector2i(0, 0), "alternative_tile": 0,
		},
		"0:2:0": {
			"layer": 0, "coords": Vector2i(2, 0), "present": true,
			"source_id": 1, "atlas_coords": Vector2i(0, 0), "alternative_tile": 0,
		},
	}
	var new_snap: Dictionary = {
		"0:1:0": {
			"layer": 0, "coords": Vector2i(1, 0), "present": true,
			"source_id": 5, "atlas_coords": Vector2i(0, 0), "alternative_tile": 0,
		},
		"0:2:0": {
			"layer": 0, "coords": Vector2i(2, 0), "present": true,
			"source_id": 1, "atlas_coords": Vector2i(0, 0), "alternative_tile": 0,
		},
		"0:3:0": {
			"layer": 0, "coords": Vector2i(3, 0), "present": true,
			"source_id": 2, "atlas_coords": Vector2i(1, 1), "alternative_tile": 0,
		},
	}
	var changed = mt._get_changed_cells(new_snap)
	harness.check_equal(changed.size(), 3,
		"Partial changes: exactly 3 cells changed (1 added, 1 modified, 1 removed).")
	harness.check("0:0:0" in changed, "Partial changes: removed cell (0,0) detected.")
	harness.check("0:1:0" in changed, "Partial changes: modified cell (1,0) detected.")
	harness.check("0:3:0" in changed, "Partial changes: added cell (3,0) detected.")
