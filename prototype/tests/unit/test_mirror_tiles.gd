extends RefCounted

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
