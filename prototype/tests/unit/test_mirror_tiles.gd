extends RefCounted

<<<<<<< HEAD
# ---------------------------------------------------------------------------
# Helper: compute mirrored local-pixel coords using the same formula as
# MirrorTiles._get_mirrored_coords (line 90-93 of mirror_tiles.gd).
#
# The mirror tool computes:
#     mirrored_local = (mirror_size - local) - tile_size
#
# Then converts back to tile-grid via local_to_map (floor-divide by tile_size).
# ---------------------------------------------------------------------------

func _mirror_local_pixel(local_x: int, local_y: int, mirror_w: float, mirror_h: float, tile_size: float) -> Vector2i:
	var mirrored_x = int((mirror_w - local_x) - tile_size)
	var mirrored_y = int((mirror_h - local_y) - tile_size)
	return Vector2i(int(mirrored_x / tile_size), int(mirrored_y / tile_size))


func _mirror_map_coords(map_x: int, map_y: int, map_w: float, map_h: float, tile_size: float) -> Vector2i:
	# map_to_local: each tile's top-left corner in pixels
	var local_x = map_x * tile_size
	var local_y = map_y * tile_size
	# Apply the mirror formula, then local_to_map (floor divide)
	return _mirror_local_pixel(local_x, local_y, map_w, map_h, tile_size)


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func run(harness) -> void:
	# -- involution tests --
	harness.check(
		_test_involution(),
		"Mirroring a coordinate twice returns the original coordinate."
	)

	harness.check(
		_test_involution_rectangular_maps(),
		"Involution holds for rectangular (non-square) map sizes."
	)

	# -- reversibility tests --
	harness.check(
		_test_reversibility(),
		"If mirror(A) == B then mirror(B) == A."
	)

	harness.check(
		_test_reversibility_rectangular(),
		"Reversibility holds for rectangular map sizes."
	)

	# -- multiple map sizes --
	harness.check(
		_test_even_map_sizes(),
		"Mirroring is correct for even-dimension map sizes."
	)

	harness.check(
		_test_odd_map_sizes(),
		"Mirroring is correct for odd-dimension map sizes."
	)

	harness.check(
		_test_non_divisible_tile_size(),
		"Mirroring works when tile size does not evenly divide map dimensions."
	)

	# -- cell diffing --
	harness.check(
		_test_cell_diff_addition(),
		"_get_changed_cells detects a newly added cell."
	)

	harness.check(
		_test_cell_diff_removal(),
		"_get_changed_cells detects an erased cell."
	)

	harness.check(
		_test_cell_diff_no_changes(),
		"_get_changed_cells returns empty when snapshots are identical."
	)

	harness.check(
		_test_cell_diff_partial(),
		"_get_changed_cells reports only the subset of cells that changed."
	)


# ---------------------------------------------------------------------------
# Involution
# ---------------------------------------------------------------------------

func _test_involution() -> bool:
	# 16x16 map, 64px tiles — all 256 cells
	var map_w = 16.0 * 64.0
	var map_h = 16.0 * 64.0
	for x in range(16):
		for y in range(16):
			var m1 = _mirror_map_coords(x, y, map_w, map_h, 64.0)
			var m2 = _mirror_map_coords(m1.x, m1.y, map_w, map_h, 64.0)
			if m2 != Vector2i(x, y):
				return false
	return true


# ---------------------------------------------------------------------------
# Involution on rectangular maps
# ---------------------------------------------------------------------------

func _test_involution_rectangular_maps() -> bool:
	var test_sizes = [
		{"w": 100.0 * 32.0, "h": 50.0 * 32.0, "tw": 100, "th": 50, "ts": 32.0},
		{"w": 160.0 * 64.0, "h": 80.0 * 64.0, "tw": 160, "th": 80, "ts": 64.0},
		{"w": 50.0 * 16.0, "h": 50.0 * 16.0, "tw": 50, "th": 50, "ts": 16.0},
	]
	for sz in test_sizes:
		for x in range(sz.tw):
			for y in range(sz.th):
				var m1 = _mirror_map_coords(x, y, sz.w, sz.h, sz.ts)
				var m2 = _mirror_map_coords(m1.x, m1.y, sz.w, sz.h, sz.ts)
				if m2 != Vector2i(x, y):
					return false
	return true


# ---------------------------------------------------------------------------
# Reversibility
# ---------------------------------------------------------------------------

func _test_reversibility() -> bool:
	var map_w = 16.0 * 64.0
	var map_h = 16.0 * 64.0
	for x in range(16):
		for y in range(16):
			var a = Vector2i(x, y)
			var b = _mirror_map_coords(x, y, map_w, map_h, 64.0)
			var b_back = _mirror_map_coords(b.x, b.y, map_w, map_h, 64.0)
			if b_back != a:
				return false
			# Also verify: if A mirrors to B, B mirrors to A (symmetric)
			var a_from_b = _mirror_map_coords(b.x, b.y, map_w, map_h, 64.0)
			if a_from_b != a:
				return false
	return true


# ---------------------------------------------------------------------------
# Reversibility on rectangular maps
# ---------------------------------------------------------------------------

func _test_reversibility_rectangular() -> bool:
	var map_w = 100.0 * 32.0
	var map_h = 50.0 * 32.0
	for x in range(100):
		for y in range(50):
			var a = Vector2i(x, y)
			var b = _mirror_map_coords(x, y, map_w, map_h, 32.0)
			if b == a:
				# Self-mirrored cell: still reversible
				continue
			var b_back = _mirror_map_coords(b.x, b.y, map_w, map_h, 32.0)
			if b_back != a:
				return false
	return true


# ---------------------------------------------------------------------------
# Even map sizes
# ---------------------------------------------------------------------------

func _test_even_map_sizes() -> bool:
	# 100x80 tiles, 64px — every cell should mirror correctly
	var map_w = 100.0 * 64.0
	var map_h = 80.0 * 64.0
	for x in range(100):
		for y in range(80):
			var m = _mirror_map_coords(x, y, map_w, map_h, 64.0)
			var m2 = _mirror_map_coords(m.x, m.y, map_w, map_h, 64.0)
			if m2 != Vector2i(x, y):
				return false
	# Check specific corners
	var tl = _mirror_map_coords(0, 0, map_w, map_h, 64.0)
	if tl != Vector2i(99, 79):
		return false
	var br = _mirror_map_coords(99, 79, map_w, map_h, 64.0)
	if br != Vector2i(0, 0):
		return false
	return true


# ---------------------------------------------------------------------------
# Odd map sizes
# ---------------------------------------------------------------------------

func _test_odd_map_sizes() -> bool:
	# 15x15 tiles, 64px — odd dimension should still work
	var map_w = 15.0 * 64.0
	var map_h = 15.0 * 64.0
	for x in range(15):
		for y in range(15):
			var m = _mirror_map_coords(x, y, map_w, map_h, 64.0)
			var m2 = _mirror_map_coords(m.x, m.y, map_w, map_h, 64.0)
			if m2 != Vector2i(x, y):
				return false
	# Center cell (7,7) should mirror to (7,7) — self-inverse on odd center
	var center = _mirror_map_coords(7, 7, map_w, map_h, 64.0)
	if center != Vector2i(7, 7):
		return false
	return true


# ---------------------------------------------------------------------------
# Non-divisible tile size
# ---------------------------------------------------------------------------

func _test_non_divisible_tile_size() -> bool:
	# Map 200x150 with 7px tiles — non-standard tile size
	var map_w = 200.0
	var map_h = 150.0
	var tile_size = 7.0
	var cols = int(map_w / tile_size)  # 28
	var rows = int(map_h / tile_size)  # 21
	for x in range(cols):
		for y in range(rows):
			var m = _mirror_map_coords(x, y, map_w, map_h, tile_size)
			var m2 = _mirror_map_coords(m.x, m.y, map_w, map_h, tile_size)
			if m2 != Vector2i(x, y):
				return false
	return true


# ---------------------------------------------------------------------------
# Cell diffing — addition detection
# ---------------------------------------------------------------------------

func _test_cell_addition(
	snapshot_before: Dictionary, snapshot_after: Dictionary, layer: int,
	coords: Vector2i, source_id: int, atlas: Vector2i, alt: int
) -> Dictionary:
	# Simulates MirrorTiles._get_changed_cells logic (lines 61-73).
	var changed: Dictionary = {}
	var key = "%d:%d:%d" % [layer, coords.x, coords.y]
	snapshot_after[key] = {
		"layer": layer,
		"coords": coords,
		"present": true,
		"source_id": source_id,
		"atlas_coords": atlas,
		"alternative_tile": alt,
	}
	for cell_key in snapshot_after:
		if not snapshot_before.has(cell_key) or snapshot_before[cell_key] != snapshot_after[cell_key]:
			changed[cell_key] = snapshot_after[cell_key]
	return changed


func _test_cell_diff_addition() -> bool:
	var old_snap: Dictionary = {}
	var new_snap: Dictionary = {}
	var coords = Vector2i(3, 5)
	var changed = _test_cell_addition(old_snap, new_snap, 0, coords, 1, Vector2i(0, 0), 0)
	var key = "0:%d:%d" % [coords.x, coords.y]
	return key in changed and changed[key].present == true


# ---------------------------------------------------------------------------
# Cell diffing — removal detection
# ---------------------------------------------------------------------------

func _test_cell_diff_removal() -> bool:
	var old_snap: Dictionary = {}
	var new_snap: Dictionary = {}
	var coords = Vector2i(3, 5)
	var key = "%d:%d:%d" % [0, coords.x, coords.y]
	old_snap[key] = {
		"layer": 0,
		"coords": coords,
		"present": true,
		"source_id": 1,
		"atlas_coords": Vector2i(0, 0),
		"alternative_tile": 0,
	}
	var changed: Dictionary = {}
	# Check removed: cell in old_snap but not in new_snap
	for cell_key in old_snap:
		if not new_snap.has(cell_key):
			changed[cell_key] = {
				"layer": old_snap[cell_key].layer,
				"coords": old_snap[cell_key].coords,
				"present": false,
			}
	var key = "0:%d:%d" % [coords.x, coords.y]
	return key in changed and changed[key].present == false


# ---------------------------------------------------------------------------
# Cell diffing — no changes
# ---------------------------------------------------------------------------

func _test_cell_diff_no_changes() -> bool:
	var snap: Dictionary = {
		"0:2:3": {"layer": 0, "coords": Vector2i(2, 3), "present": true,
			"source_id": 1, "atlas_coords": Vector2i(0, 0), "alternative_tile": 0},
		"0:4:5": {"layer": 0, "coords": Vector2i(4, 5), "present": true,
			"source_id": 1, "atlas_coords": Vector2i(1, 0), "alternative_tile": 0},
	}
	var changed: Dictionary = {}
	for cell_key in snap:
		if not snap.has(cell_key):  # self-comparison always has keys
			changed[cell_key] = snap[cell_key]
	return changed.is_empty()


# ---------------------------------------------------------------------------
# Cell diffing — partial changes
# ---------------------------------------------------------------------------

func _test_cell_diff_partial() -> bool:
	var old_snap: Dictionary = {
		"0:0:0": {"layer": 0, "coords": Vector2i(0, 0), "present": true,
			"source_id": 1, "atlas_coords": Vector2i(0, 0), "alternative_tile": 0},
		"0:1:0": {"layer": 0, "coords": Vector2i(1, 0), "present": true,
			"source_id": 1, "atlas_coords": Vector2i(0, 0), "alternative_tile": 0},
		"0:2:0": {"layer": 0, "coords": Vector2i(2, 0), "present": true,
			"source_id": 1, "atlas_coords": Vector2i(0, 0), "alternative_tile": 0},
	}
	var new_snap: Dictionary = old_snap.duplicate(true)
	# Modify cell (1,0)
	new_snap["0:1:0"]["source_id"] = 5
	# Remove cell (0,0)
	new_snap.erase("0:0:0")
	# Add cell (3,0)
	new_snap["0:3:0"] = {
		"layer": 0, "coords": Vector2i(3, 0), "present": true,
		"source_id": 2, "atlas_coords": Vector2i(1, 1), "alternative_tile": 0,
	}

	var changed: Dictionary = {}
	for cell_key in new_snap:
		if not old_snap.has(cell_key) or old_snap[cell_key] != new_snap[cell_key]:
			changed[cell_key] = new_snap[cell_key]
	# Also detect removals
	for cell_key in old_snap:
		if not new_snap.has(cell_key):
			changed[cell_key] = {
				"layer": old_snap[cell_key].layer,
				"coords": old_snap[cell_key].coords,
				"present": false,
			}

	# Should have 3 changed cells: (0,0) removed, (1,0) modified, (3,0) added
	return changed.size() == 3 and "0:0:0" in changed and "0:1:0" in changed and "0:3:0" in changed
=======
const MirrorMath = preload("res://tests/unit/mirror_math.gd")
const MirrorTilesScript = preload("res://map/tool/mirror_tiles.gd")


func run(harness) -> void:
	test_cell_key_format(harness)
	test_cell_key_uniqueness(harness)
	test_get_changed_cells_empty(harness)
	test_get_changed_cells_detects_additions(harness)
	test_get_changed_cells_detects_removals(harness)
	test_get_changed_cells_detects_modifications(harness)
	test_mirrored_coords_basic(harness)
	test_mirrored_coords_edge_cases(harness)
	test_mirrored_coords_non_aligned(harness)


# ---------------------------------------------------------------------------
# _cell_key()  —  pure string formatting
# ---------------------------------------------------------------------------

func test_cell_key_format(harness) -> void:
	var mt = MirrorTilesScript.new()
	harness.check_equal(mt._cell_key(0, Vector2i(0, 0)), "0:0:0", "_cell_key returns 'layer:x:y'")
	harness.check_equal(mt._cell_key(2, Vector2i(-1, 5)), "2:-1:5", "_cell_key handles negative coords")
	mt.free()


func test_cell_key_uniqueness(harness) -> void:
	var mt = MirrorTilesScript.new()
	var keys: Array[String] = [
		mt._cell_key(0, Vector2i(0, 0)),
		mt._cell_key(0, Vector2i(1, 0)),
		mt._cell_key(1, Vector2i(0, 0)),
		mt._cell_key(0, Vector2i(0, 1)),
	]
	var seen: Dictionary = {}
	for k in keys:
		harness.check(not seen.has(k), "Unique layer/coord combos produce distinct keys")
		seen[k] = true
	mt.free()


# ---------------------------------------------------------------------------
# _get_changed_cells()  —  pure snapshot-diff logic, no TileMap needed
# ---------------------------------------------------------------------------

func test_get_changed_cells_empty(harness) -> void:
	var mt = MirrorTilesScript.new()
	mt._cell_snapshot = {}
	var current := {}
	harness.check_equal(mt._get_changed_cells(current), {}, "_get_changed_cells returns {} when snapshots match")
	mt.free()


func test_get_changed_cells_detects_additions(harness) -> void:
	var mt = MirrorTilesScript.new()
	mt._cell_snapshot = {}
	var current = {
		"0:5:3": {
			"layer": 0,
			"coords": Vector2i(5, 3),
			"present": true,
			"source_id": 0,
			"atlas_coords": Vector2i(0, 0),
			"alternative_tile": 0,
		}
	}
	var changed = mt._get_changed_cells(current)
	harness.check(changed.has("0:5:3"), "_get_changed_cells flags a newly-added cell")
	harness.check(changed["0:5:3"].present, "Added cell is marked present=true")
	mt.free()


func test_get_changed_cells_detects_removals(harness) -> void:
	var mt = MirrorTilesScript.new()
	mt._cell_snapshot = {
		"0:5:3": {
			"layer": 0,
			"coords": Vector2i(5, 3),
			"present": true,
			"source_id": 0,
			"atlas_coords": Vector2i(0, 0),
			"alternative_tile": 0,
		}
	}
	var current: Dictionary = {}
	var changed = mt._get_changed_cells(current)
	harness.check(changed.has("0:5:3"), "_get_changed_cells flags a removed cell")
	harness.check(not changed["0:5:3"].present, "Removed cell is marked present=false")
	mt.free()


func test_get_changed_cells_detects_modifications(harness) -> void:
	var mt = MirrorTilesScript.new()
	mt._cell_snapshot = {
		"0:5:3": {
			"layer": 0,
			"coords": Vector2i(5, 3),
			"present": true,
			"source_id": 1,
			"atlas_coords": Vector2i(0, 0),
			"alternative_tile": 0,
		}
	}
	var current = {
		"0:5:3": {
			"layer": 0,
			"coords": Vector2i(5, 3),
			"present": true,
			"source_id": 2,  # changed source_id
			"atlas_coords": Vector2i(0, 0),
			"alternative_tile": 0,
		}
	}
	var changed = mt._get_changed_cells(current)
	harness.check(changed.has("0:5:3"), "_get_changed_cells flags a modified cell")
	harness.check_equal(changed["0:5:3"].source_id, 2, "Modified cell reflects new snapshot values")
	mt.free()


# ---------------------------------------------------------------------------
# _get_mirrored_coords()  —  call the production method via MirrorMath helper
# ---------------------------------------------------------------------------

func test_mirrored_coords_basic(harness) -> void:
	# 4x4 map, 16x16 tiles.  Cell (0,0) → mirrored at (3,3).
	var math = MirrorMath.new(Vector2(4, 4), Vector2(16, 16))
	harness.check_equal(
		math.mirrored_coords(Vector2i(0, 0)), Vector2i(3, 3),
		"_get_mirrored_coords mirrors (0,0) → (3,3) on 4x4"
	)
	harness.check_equal(
		math.mirrored_coords(Vector2i(3, 3)), Vector2i(0, 0),
		"_get_mirrored_coords mirrors (3,3) → (0,0) on 4x4"
	)
	math.free()


func test_mirrored_coords_edge_cases(harness) -> void:
	# 6x6 map, 32x32 tiles.  Cell (1,2) → (4,3).
	var math = MirrorMath.new(Vector2(6, 6), Vector2(32, 32))
	harness.check_equal(
		math.mirrored_coords(Vector2i(1, 2)), Vector2i(4, 3),
		"_get_mirrored_coords handles (1,2) → (4,3)"
	)
	# Midpoint: cell (2,2) mirrors to (3,3).
	harness.check_equal(
		math.mirrored_coords(Vector2i(2, 2)), Vector2i(3, 3),
		"_get_mirrored_coords midpoint maps correctly"
	)
	math.free()


func test_mirrored_coords_non_aligned(harness) -> void:
	# 10x10 map, 16x16 tiles.  Cell (0,0) → (9,9).
	var math = MirrorMath.new(Vector2(10, 10), Vector2(16, 16))
	harness.check_equal(
		math.mirrored_coords(Vector2i(0, 0)), Vector2i(9, 9),
		"_get_mirrored_coords (0,0) → (9,9) on 10x10"
	)
	# Cell (9,9) → (0,0).
	harness.check_equal(
		math.mirrored_coords(Vector2i(9, 9)), Vector2i(0, 0),
		"_get_mirrored_coords (9,9) → (0,0) on 10x10"
	)
	math.free()
>>>>>>> main
