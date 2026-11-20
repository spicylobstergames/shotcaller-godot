extends RefCounted

# =============================================================================
# Map editor tests (tests/unit/test_map_editor.gd)
# =============================================================================
# Covers the addons/map_editor/ plugin logic, which is editor-free RefCounted
# code specifically so it can be tested here:
#   - map_scaffold.gd: builds a contract-satisfying map scene tree
#   - map_validator.gd: checks a map against the runtime contract that
#     map_manager.gd / spawns.gd read by node path (map/README.md)
#
# The validator must accept the shipping maps (one-lane, three-lane) with zero
# errors, accept the scaffold with zero errors (including a save/load
# roundtrip through ResourceSaver), and catch each contract break it claims
# to catch.
# =============================================================================

const Scaffold = preload("res://addons/map_editor/map_scaffold.gd")
const Validator = preload("res://addons/map_editor/map_validator.gd")
const OneLaneMap = preload("res://map/maps/one_lane_map.tscn")
const ThreeLaneMap = preload("res://map/maps/three_lane_map.tscn")


func run(harness) -> void:
	_test_scaffold_passes_validation(harness)
	_test_scaffold_structure(harness)
	_test_write_and_reload_roundtrip(harness)
	_test_existing_maps_pass(harness)
	_test_error_detection(harness)
	_test_warning_detection(harness)


# ---------------------------------------------------------------------------
# Scaffold output is contract-clean
# ---------------------------------------------------------------------------

func _test_scaffold_passes_validation(harness) -> void:
	var map: Node = Scaffold.new().build_map()
	var problems: Array = Validator.new().validate(map)
	harness.check_equal(_errors(problems).size(), 0,
			"scaffold validates with zero errors%s" % _describe(problems))
	map.free()


func _test_scaffold_structure(harness) -> void:
	var map: Node = Scaffold.new().build_map()
	var v := Validator.new()

	# Root script + fog + tile layers with real TileSets, nothing pre-painted.
	harness.check(map is BaseMap, "scaffold root script is BaseMap")
	harness.check(map.get_node("fog") is CanvasModulate, "scaffold fog is CanvasModulate")
	harness.check(map.get_node("tiles/ground/Ground").tile_set != null, "scaffold Ground layer has a tile_set")
	harness.check(map.get_node("tiles/walls/Walls").tile_set != null, "scaffold Walls layer has a tile_set")
	harness.check(map.get_node("tiles/trees/Trees").tile_set != null, "scaffold Trees layer has a tile_set")
	harness.check(map.get_node("tiles/ground/Ground").get_used_cells().is_empty(),
			"scaffold Ground layer starts empty (user paints from scratch)")

	# Lanes: exactly the default mid lane, with its walk path.
	var lanes: Node = map.get_node("lanes")
	harness.check_equal(lanes.get_child_count(), 1, "scaffold has exactly one lane")
	var mid: Node = lanes.get_node_or_null("mid")
	harness.check(mid != null, "scaffold lane is named 'mid'")
	if mid != null:
		harness.check_equal(mid.get_point_count(), Scaffold.default_lane_points().size(),
				"scaffold mid lane carries its default walk path")

	# Buildings: red team is tagged red, blue relies on the Unit default,
	# every building's subtype names a real lane, neutrals are present, and
	# blacksmiths carry the closest_tree marker lumberjack hiring reads.
	harness.check_equal(map.get_node("buildings/red/castle").get("team"), "red",
			"scaffold red castle team is 'red'")
	harness.check_equal(map.get_node("buildings/blue/castle").get("team"), "blue",
			"scaffold blue castle team is 'blue'")

	var lane_names := {"mid": true}
	var structure_mismatches := 0
	var neutral_mismatches := 0
	for team_node_path in ["buildings/blue", "buildings/red"]:
		for building in map.get_node(team_node_path).get_children():
			var subtype = building.get("subtype")
			if building.name in ["castle", "barrack", "tower"]:
				# Team structures carry their lane assignment as subtype.
				if not lane_names.has(subtype):
					structure_mismatches += 1
			elif subtype != "backwood":
				# Neutrals carry the special conquerable-building subtype.
				neutral_mismatches += 1
	harness.check_equal(structure_mismatches, 0,
			"every scaffold structure subtype names a lane")
	harness.check_equal(neutral_mismatches, 0,
			"every scaffold neutral building uses the 'backwood' subtype")

	var missing_neutrals := 0
	var missing_closest_tree := 0
	for team in ["blue", "red"]:
		var team_node: Node = map.get_node("buildings/" + team)
		for neutral in ["blacksmith", "camp"]:
			if team_node.get_node_or_null(neutral) == null:
				missing_neutrals += 1
		var blacksmith: Node = team_node.get_node_or_null("blacksmith")
		if blacksmith != null and blacksmith.get_node_or_null("closest_tree") == null:
			missing_closest_tree += 1
	harness.check_equal(missing_neutrals, 0, "scaffold ships blacksmith + camp for both teams")
	harness.check_equal(missing_closest_tree, 0, "scaffold blacksmiths carry closest_tree markers")

	map.free()


func _test_write_and_reload_roundtrip(harness) -> void:
	var path := "user://map_editor_roundtrip.tscn"
	var err: int = Scaffold.new().write_map(path)
	harness.check_equal(err, OK, "write_map saves the scaffold to disk")
	if err == OK:
		var packed = load(path)
		if packed != null:
			var reloaded: Node = (packed as PackedScene).instantiate()
			var problems: Array = Validator.new().validate(reloaded)
			harness.check_equal(_errors(problems).size(), 0,
					"reloaded scaffold still validates with zero errors%s" % _describe(problems))
			reloaded.free()
		else:
			harness.check(false, "reloaded scaffold scene could be loaded")
	DirAccess.remove_absolute(path)


# ---------------------------------------------------------------------------
# The validator accepts the shipping maps
# ---------------------------------------------------------------------------

func _test_existing_maps_pass(harness) -> void:
	for entry in [["one_lane_map", OneLaneMap], ["three_lane_map", ThreeLaneMap]]:
		var map: Node = (entry[1] as PackedScene).instantiate()
		var problems: Array = Validator.new().validate(map)
		harness.check_equal(_errors(problems).size(), 0,
				"%s validates with zero errors%s" % [entry[0], _describe(problems)])
		if not problems.is_empty():
			print("  [%s] warnings: %s" % [entry[0], _describe(problems)])
		map.free()


# ---------------------------------------------------------------------------
# Each error check catches its contract break
# ---------------------------------------------------------------------------

func _test_error_detection(harness) -> void:
	var map: Node = Scaffold.new().build_map()
	var v := Validator.new()

	# Missing fog node — map_manager.map_loaded() dereferences map.fog.
	map.get_node("fog").free()
	harness.check(_has_problem(v.validate(map), "error", "fog"), "missing fog node is an error")

	# Missing red castle — the win condition.
	map.get_node("buildings/red/castle").free()
	harness.check(_has_problem(v.validate(map), "error", "castle"), "missing red castle is an error")

	# Lane with a single point — no walkable path.
	var mid: Line2D = map.get_node("lanes/mid")
	mid.points = PackedVector2Array([Vector2.ZERO])
	harness.check(_has_problem(v.validate(map), "error", "points"), "single-point lane is an error")

	# Subtype naming no lane — WalkLane cannot plan against it.
	map.get_node("buildings/blue/tower").set("subtype", "nope")
	harness.check(_has_problem(v.validate(map), "error", "subtype"), "unknown-lane building subtype is an error")

	# Team-colored structure with the wrong team — corrupts WorldState
	# player/enemy building lists in map_manager.setup_buildings().
	map.get_node("buildings/red/barrack").set("team", "blue")
	harness.check(_has_problem(v.validate(map), "error", "team"), "mis-teamed barrack is an error")

	# Missing lanes node — spawns.gd and WalkLane read lanes/<name>.
	map.get_node("lanes").free()
	harness.check(_has_problem(v.validate(map), "error", "lanes"), "missing lanes node is an error")

	# TileMapLayer without a TileSet.
	map.get_node("tiles/ground/Ground").tile_set = null
	harness.check(_has_problem(v.validate(map), "error", "tile_set"), "TileMapLayer without tile_set is an error")

	map.free()


# ---------------------------------------------------------------------------
# Optional features degrade to warnings
# ---------------------------------------------------------------------------

func _test_warning_detection(harness) -> void:
	var map: Node = Scaffold.new().build_map()
	var v := Validator.new()

	map.get_node("buildings/blue/blacksmith").free()
	harness.check(_has_problem(v.validate(map), "warning", "blacksmith"),
			"missing blue blacksmith is a warning (shop degrades)")

	map.get_node("buildings/red/camp").free()
	harness.check(_has_problem(v.validate(map), "warning", "camp"),
			"missing red camp is a warning (camp hiring degrades)")

	map.get_node("buildings/red/blacksmith/closest_tree").free()
	harness.check(_has_problem(v.validate(map), "warning", "closest_tree"),
			"blacksmith without closest_tree is a warning (lumberjack hiring degrades)")

	map.free()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _errors(problems: Array) -> Array:
	return problems.filter(func(p): return p.level == "error")


func _has_problem(problems: Array, level: String, needle: String) -> bool:
	for problem in problems:
		if problem.level == level and problem.message.contains(needle):
			return true
	return false


func _describe(problems: Array) -> String:
	if problems.is_empty():
		return ""
	var parts := []
	for problem in problems:
		parts.append("[%s] %s" % [problem.level, problem.message])
	return " — " + "; ".join(PackedStringArray(parts))
