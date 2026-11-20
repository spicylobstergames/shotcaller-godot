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
const CampaignMap = preload("res://map/maps/campaign_map.tscn")


func run(harness) -> void:
	_test_plugin_scripts_parse(harness)
	_test_scaffold_passes_validation(harness)
	_test_scaffold_structure(harness)
	_test_write_and_reload_roundtrip(harness)
	_test_existing_maps_pass(harness)
	_test_error_detection(harness)
	_test_contract_gaps(harness)
	_test_warning_detection(harness)


# ---------------------------------------------------------------------------
# The plugin/dock layer itself parses (the dock is editor-only and otherwise
# untested headless; a native-class shadow here killed the plugin once while
# the scaffold/validator suites stayed green — import.log's SCRIPT ERROR
# check in run_suite.sh is the other backstop).
# ---------------------------------------------------------------------------

func _test_plugin_scripts_parse(harness) -> void:
	harness.check(load("res://addons/map_editor/map_editor_plugin.gd") != null,
			"map_editor_plugin.gd compiles (no native-class shadow)")
	harness.check(load("res://addons/map_editor/editor_dock.gd") != null,
			"editor_dock.gd compiles")


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
	harness.check(map.get_node("zoom_out_sprite") is Sprite2D, "scaffold ships the minimap zoom_out_sprite")
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
			# Instance internals must stay owned by their building instance —
			# flattening them into the map scene caused load-time name-clash
			# errors ("buildings/blue/castle/hud") on the first scaffold use.
			var castle: Node = reloaded.get_node("buildings/blue/castle")
			var hud: Node = castle.get_node_or_null("hud")
			harness.check(hud != null and hud.get_owner() == castle,
					"reloaded castle keeps its hud owned by the instance (no flattening)")
			# Genuine additions to an instance stay owned by the map scene,
			# mirroring the shipping maps' editable-instance overrides.
			var closest: Node = reloaded.get_node_or_null("buildings/blue/blacksmith/closest_tree")
			harness.check(closest != null and closest.get_owner() == reloaded,
					"reloaded closest_tree stays owned by the map scene (editable addition)")
			reloaded.free()
		else:
			harness.check(false, "reloaded scaffold scene could be loaded")
	DirAccess.remove_absolute(path)


# ---------------------------------------------------------------------------
# The validator accepts the shipping maps (including campaign_map, which
# legitimately ships blue-only — a missing team directory is a warning)
# ---------------------------------------------------------------------------

func _test_existing_maps_pass(harness) -> void:
	for entry in [["one_lane_map", OneLaneMap], ["three_lane_map", ThreeLaneMap],
			["campaign_map", CampaignMap]]:
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
# Regression tests for contract gaps found in adversarial review
# ---------------------------------------------------------------------------

func _test_contract_gaps(harness) -> void:
	var v := Validator.new()

	# spawns.gd hardcodes the "mid" lane for leader spawning (unless the map
	# has exactly top/mid/bot); without it, leader spawn crashes at runtime.
	var no_mid: Node = Scaffold.new().build_map()
	no_mid.get_node("lanes/mid").name = "top"
	harness.check(_has_problem(v.validate(no_mid), "error", "no lane named"),
			"map without a 'mid' lane is an error (spawns.gd leader crash)")
	no_mid.free()

	# Exactly three lanes with non top/mid/bot names would send three-lane
	# leader spawning to nonexistent lanes.
	var misnamed: Node = Scaffold.new().build_map()
	misnamed.get_node("lanes/mid").name = "a"
	for extra_lane_name in ["b", "c"]:
		var lane := Line2D.new()
		lane.name = extra_lane_name
		lane.points = PackedVector2Array([Vector2.ZERO, Vector2(10, 10)])
		misnamed.get_node("lanes").add_child(lane)
	harness.check(_has_problem(v.validate(misnamed), "warning", "not named top/mid/bot"),
			"three misnamed lanes warn (three-lane leader spawning assumes top/mid/bot)")
	misnamed.free()

	# setup_buildings treats every child of 'buildings' as a team directory.
	var stray: Node = Scaffold.new().build_map()
	var extra := Node2D.new()
	extra.name = "extra"
	stray.get_node("buildings").add_child(extra)
	harness.check(_has_problem(v.validate(stray), "error", "unexpected child"),
			"stray node under 'buildings' is an error (setup_buildings error spam)")
	stray.free()

	# Duplicate building names silently shadow each other via get_node. The
	# Node API cannot create them (add_child and the name setter both
	# auto-dedupe), so the fixture goes through the scene loader — the same
	# path a text-edited .tscn takes.
	var fixture_path := "user://map_editor_dupe_fixture.tscn"
	var fixture := FileAccess.open(fixture_path, FileAccess.WRITE)
	fixture.store_string(DUPE_FIXTURE_SCENE)
	fixture.close()
	var packed = load(fixture_path)
	if packed != null:
		var dupe_map: Node = (packed as PackedScene).instantiate()
		harness.check(_has_problem(v.validate(dupe_map), "warning", "duplicate"),
				"duplicate building names warn (get_node resolves only the first)")
		dupe_map.free()
	else:
		harness.check(false, "duplicate-name fixture loads")
	DirAccess.remove_absolute(fixture_path)

	# navigation.gd grids the WALLS layer's cells by base_map's tile_size;
	# a mismatching walls TileSet cell size blocks the wrong pathfinding
	# cells. (Ground/trees TileSets are visual and may differ — shipping
	# maps run an (8, 8) ground cell size against tile_size 64.)
	var bad_tile_size: Node = Scaffold.new().build_map()
	bad_tile_size.set("tile_size", 32)
	harness.check(_has_problem(v.validate(bad_tile_size), "error", "walls TileMapLayer cell size"),
			"walls TileSet cell size mismatching tile_size is an error")
	bad_tile_size.free()

	# base_map.gd's tile_size is untyped: a float value must still be checked,
	# not silently skipped.
	var float_tile_size: Node = Scaffold.new().build_map()
	float_tile_size.set("tile_size", 64.0)
	harness.check(not _has_problem(v.validate(float_tile_size), "error", "walls TileMapLayer cell size"),
			"float tile_size equal to walls cell size does not error")
	float_tile_size.free()

	# The minimap's zoomed-out view degrades silently without this sprite.
	var no_zoom: Node = Scaffold.new().build_map()
	no_zoom.get_node("zoom_out_sprite").free()
	harness.check(_has_problem(v.validate(no_zoom), "warning", "zoom_out_sprite"),
			"missing zoom_out_sprite is a warning")
	no_zoom.free()


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


# Minimal hand-authored-style map whose blue team has two nodes named "tower"
# — exercises the duplicate-name warning through the scene loader.
const DUPE_FIXTURE_SCENE := """[gd_scene format=3]

[ext_resource type="Script" path="res://map/maps/base_map.gd" id="1"]

[node name="map" type="Node2D"]
script = ExtResource("1")

[node name="fog" type="CanvasModulate" parent="."]

[node name="lanes" type="Node2D" parent="."]

[node name="mid" type="Line2D" parent="lanes"]
points = PackedVector2Array(0, 0, 10, 10)

[node name="buildings" type="Node2D" parent="."]

[node name="blue" type="Node2D" parent="buildings"]

[node name="tower" type="Node2D" parent="buildings/blue"]

[node name="tower" type="Node2D" parent="buildings/blue"]

[node name="red" type="Node2D" parent="buildings"]
"""


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
