extends RefCounted

# =============================================================================
# Runtime map store tests (tests/unit/test_map_store.gd)
# =============================================================================
# map/editor/map_store.gd is the only writer of runtime maps, so it is the one
# piece of the runtime editor that is fully testable headless: name
# sanitization, user:// listing (with a phantom-name guard: a listing must only
# ever name real files in the maps dir), save→load roundtrip through a .tscn,
# and the owner-preservation rule that keeps placed buildings as scene
# INSTANCES (the M1 bug was pack() flattening them).
#
# The fixture is always removed before and after, so a failed assertion cannot
# leave a stray map in user://maps (run_suite.sh redirects user:// into
# $PWD/.godot-data via GODOT_DATA_HOME).
# =============================================================================

const MapStore = preload("res://map/editor/map_store.gd")
const Scaffold = preload("res://addons/map_editor/map_scaffold.gd")
const Validator = preload("res://addons/map_editor/map_validator.gd")
const BuildingLogic = preload("res://addons/map_editor/building_logic.gd")
const TileBrush = preload("res://addons/map_editor/tile_brush_logic.gd")

const _TMP := "_tmp_store_test_map"
const _LANE_NAME := "_tmp_store_lane"
const _WALLS_CELL := Vector2i(3, 2)
const EDITOR_DIR := "res://map/editor"
const EDITOR_SCRIPTS: Array[String] = [
	"res://map/editor/map_editor.gd",
	"res://map/editor/editor_camera.gd",
	"res://map/editor/editor_ui.gd",
	"res://map/editor/lane_overlay.gd",
	"res://map/editor/map_store.gd",
]

# Editor-only APIs that must not appear in the runtime editor (M4 decision: the
# runtime scene rebuilds what the plugin gets from the editor; @tool scripts and
# EditorInterface calls would make the scene unusable in a running game).
const EDITOR_ONLY_TOKENS: Array[String] = [
	"EditorPlugin", "EditorInterface", "get_undo_redo()", "_forward_canvas_gui_input",
	"_handles(", "add_control_to_dock", "EditorDock", "@tool",
	"get_global_canvas_transform", "FileDialog",
]


func run(harness) -> void:
	_clean()
	_test_sanitize(harness)
	_test_paths(harness)
	_test_roundtrip(harness)
	_test_listing(harness)
	_test_assets(harness)
	_test_editor_free(harness)
	_clean()


# ---------------------------------------------------------------------------
# Names and paths
# ---------------------------------------------------------------------------

func _test_sanitize(harness) -> void:
	# Traversal attempts become plain basenames.
	harness.check_equal(MapStore.sanitize_name("../../evil"), "evil",
			"'../../evil' collapses to a basename")
	var safe := MapStore.sanitize_name("..\\..\\evil")
	harness.check(not safe.contains("/") and not safe.contains("\\") and not safe.contains(".."),
			"no separators or '..' survive sanitization (got '%s')" % safe)
	harness.check(not MapStore.sanitize_name("a/../../b").contains(".."),
			"separators cannot re-form a traversal step")
	harness.check_equal(MapStore.sanitize_name("my cool map"), "my_cool_map",
			"spaces become '_'")
	harness.check_equal(MapStore.sanitize_name(""), "map", "empty name becomes 'map'")
	harness.check_equal(MapStore.sanitize_name("   .  "), "map", "whitespace/dots-only becomes 'map'")
	harness.check_equal(MapStore.sanitize_name("  spaced  "), "spaced",
			"leading/trailing whitespace is trimmed")
	harness.check_equal(MapStore.sanitize_name("weird:*?\"<>|name"), "weirdname",
			"illegal filename characters are dropped")


func _test_paths(harness) -> void:
	MapStore.ensure_dir()
	harness.check(DirAccess.dir_exists_absolute(MapStore.MAP_DIR),
			"ensure_dir creates %s" % MapStore.MAP_DIR)
	harness.check(MapStore.path_for("one").begins_with("user://maps/"),
			"path_for stays under user://maps/")
	harness.check_equal(MapStore.path_for("one"), "user://maps/one.tscn",
			"path_for appends the map extension")
	harness.check_equal(MapStore.path_for("../evil"), "user://maps/evil.tscn",
			"a traversal name cannot escape MAP_DIR")
	harness.check(not MapStore.path_for("a/../b").contains(".."),
			"path_for output never contains '..'")


# ---------------------------------------------------------------------------
# Save / load roundtrip with edits, ownership preserved
# ---------------------------------------------------------------------------

func _test_roundtrip(harness) -> void:
	var map: Node2D = Scaffold.new().build_map()
	var problems: Array = Validator.new().validate(map)
	harness.check(_errors(problems).is_empty(),
			"scaffold validates with 0 errors (%s)" % _describe(problems))

	var blue: Node = map.get_node("buildings/blue")
	var lanes: Node = map.get_node("lanes")

	var lane := Line2D.new()
	lane.name = _LANE_NAME
	lane.add_point(Vector2(64, 128))
	lane.add_point(Vector2(192, 128))
	lanes.add_child(lane)

	# A church is team-owned (BuildingLogic.TEAM_OWNED_NAMES): team blue, and it
	# is an INSTANCED scene, which is what the ownership rule is about.
	var church: Node = (load("res://unit/buildings/church.tscn") as PackedScene).instantiate()
	church.name = BuildingLogic.next_building_name(blue, "church")
	BuildingLogic.apply_building_meta(church, "church", "blue", "mid")
	blue.add_child(church)

	var walls: TileMapLayer = TileBrush.layer_for_brush(map, "walls")
	var tiles: Array[Dictionary] = TileBrush.list_layer_tiles(walls)
	harness.check(not tiles.is_empty(), "the walls layer offers paintable tiles")
	var source_id := -1
	var atlas := Vector2i(-1, -1)
	if not tiles.is_empty():
		source_id = tiles[0].source_id
		atlas = tiles[0].atlas_coords
		walls.set_cell(_WALLS_CELL, source_id, atlas, 0)

	harness.check_equal(MapStore.save_map(map, _TMP), OK, "save_map writes the map")
	harness.check(FileAccess.file_exists(MapStore.path_for(_TMP)),
			"the saved file exists at %s" % MapStore.path_for(_TMP))
	map.free()

	var reloaded: Node = MapStore.load_map(_TMP)
	harness.check(reloaded is BaseMap, "load_map returns a BaseMap")
	if reloaded == null:
		return

	var reloaded_lane = reloaded.get_node_or_null("lanes/" + _LANE_NAME)
	harness.check(reloaded_lane is Line2D, "the added lane survives the roundtrip")
	if reloaded_lane is Line2D:
		harness.check_equal((reloaded_lane as Line2D).get_point_count(), 2,
				"the lane keeps both points")

	var reloaded_church = reloaded.get_node_or_null("buildings/blue/church")
	harness.check(reloaded_church != null, "the placed church survives the roundtrip")
	if reloaded_church != null:
		harness.check_equal(reloaded_church.get("team"), "blue", "the church keeps team = blue")
		harness.check(reloaded_church.get_owner() == reloaded, "the church is owned by the reloaded map")
		var hud = reloaded_church.get_node_or_null("hud")
		harness.check(hud != null and hud.get_owner() == reloaded_church,
				"the church's hud stays owned by the church (instanced, not flattened)")

	# Authored children of an instanced building stay owned by the map root.
	var blacksmith = reloaded.get_node_or_null("buildings/blue/blacksmith")
	var closest_tree = blacksmith.get_node_or_null("closest_tree") if blacksmith != null else null
	harness.check(closest_tree != null and closest_tree.get_owner() == reloaded,
			"buildings/blue/blacksmith/closest_tree is owned by the reloaded map")

	var reloaded_walls = reloaded.get_node_or_null("tiles/walls/Walls")
	harness.check(reloaded_walls is TileMapLayer, "the reloaded map has tiles/walls/Walls")
	if reloaded_walls is TileMapLayer:
		var layer := reloaded_walls as TileMapLayer
		harness.check_equal(layer.get_cell_source_id(_WALLS_CELL), source_id,
				"the painted walls cell keeps its source id")
		harness.check_equal(layer.get_cell_atlas_coords(_WALLS_CELL), atlas,
				"the painted walls cell keeps its atlas coords")

	var after: Array = Validator.new().validate(reloaded)
	harness.check(_errors(after).is_empty(),
			"the reloaded edited map still validates (%s)" % _describe(after))
	reloaded.free()


# ---------------------------------------------------------------------------
# Listing and deletion
# ---------------------------------------------------------------------------

func _test_listing(harness) -> void:
	var maps := MapStore.list_maps()
	harness.check(_TMP in maps, "list_maps contains the saved map (%s)" % ", ".join(maps))
	# Phantom-name detector (the PR #242 CI flake): a DirAccess on the user://
	# scheme can silently latch onto the process CWD and enumerate the PROJECT
	# ROOT instead of user://maps — its only root-level .tscn is game.tscn, so
	# the old unchecked listing presented "game" as the map list. Every listed
	# name must therefore exist as a real file in the (absolute) maps dir.
	var phantom := ""
	for map_name in maps:
		var map_file := ProjectSettings.globalize_path(MapStore.MAP_DIR) \
				+ "/" + map_name + MapStore.MAP_EXT
		if not FileAccess.file_exists(map_file):
			phantom = map_name
			break
	harness.check(phantom == "",
			"every listed map exists as a file in the maps dir (phantom: %s; listed: %s)" % [
					phantom, ", ".join(maps)])
	var sorted := maps.duplicate()
	sorted.sort()
	harness.check_equal(maps, sorted, "list_maps returns sorted basenames")
	harness.check(not maps.has(MapStore.MAP_EXT.trim_prefix(".")), "list_maps lists basenames, not filenames")
	harness.check_equal(MapStore.delete_map(_TMP), OK, "delete_map removes the map")
	harness.check(not _TMP in MapStore.list_maps(), "list_maps no longer contains it")
	harness.check_equal(MapStore.delete_map("_no_such_map_xyz"), ERR_FILE_NOT_FOUND,
			"deleting an unknown map reports it instead of failing silently")


# ---------------------------------------------------------------------------
# Runtime editor assets
# ---------------------------------------------------------------------------

func _test_assets(harness) -> void:
	for path in EDITOR_SCRIPTS:
		var script := load(path) as GDScript
		harness.check(script != null and script.can_instantiate(), "%s loads and instantiates" % path)

	var packed := load("%s/map_editor.tscn" % EDITOR_DIR) as PackedScene
	harness.check(packed != null, "map/editor/map_editor.tscn loads")
	if packed == null:
		return
	var editor := packed.instantiate()
	harness.check(editor is Node2D, "the editor scene roots at a Node2D")
	if editor == null:
		return
	var holder := editor.get_node_or_null("MapHolder")
	var overlay := editor.get_node_or_null("LaneOverlay")
	var ui := editor.get_node_or_null("UILayer/EditorUI")
	var camera := editor.get_node_or_null("EditorCamera")
	harness.check(holder is Node2D and overlay is Node2D and ui is Control and camera is Camera2D,
			"scene is MapEditor + EditorCamera/MapHolder/LaneOverlay/UILayer/EditorUI")
	# MapHolder and LaneOverlay are siblings (the overlay must draw above the
	# map, and it must never end up inside the saved map).
	harness.check(holder != null and overlay != null and holder.get_parent() == overlay.get_parent(),
			"MapHolder and LaneOverlay are siblings")
	harness.check(holder != null and ui != null and ui.get_parent() != holder,
			"the UI lives in a CanvasLayer, not under MapHolder")
	editor.free()


# ---------------------------------------------------------------------------
# The M4 contract: the runtime editor must not use editor-only APIs
# ---------------------------------------------------------------------------

func _test_editor_free(harness) -> void:
	# Comments carry the contract in prose ("not an EditorPlugin", "no @tool"),
	# so the scan looks at code only. A quoted string still counts — a runtime
	# script may not build an editor API name out of pieces.
	var offenders: PackedStringArray = []
	for path in EDITOR_SCRIPTS:
		var code := _strip_comments(FileAccess.get_file_as_string(path))
		for token in EDITOR_ONLY_TOKENS:
			if token in code:
				offenders.append("%s uses %s" % [path, token])
	harness.check(offenders.is_empty(), "no editor-only APIs in %s: %s" % [EDITOR_DIR, ", ".join(offenders)])

	# The guard itself: comments are dropped, quoted strings are not.
	var sample := 'var a := 1  # EditorInterface\nvar b := "EditorPlugin"\nvar c := "# not a comment"\nvar d := 2  # EditorDock\nvar e := """\nEditorUndoRedoManager\n"""\n'
	var stripped := _strip_comments(sample)
	harness.check(not stripped.contains("EditorInterface"),
			"_strip_comments drops a comment mention of an editor API")
	harness.check(stripped.contains("EditorPlugin"),
			"_strip_comments keeps double-quoted literals (the scan cannot be bypassed by quoting)")
	harness.check(stripped.contains("# not a comment"),
			"_strip_comments ignores '#' inside a string")
	harness.check(stripped.contains("EditorUndoRedoManager"),
			"_strip_comments keeps triple-quoted literals")
	harness.check(not stripped.contains("EditorDock"),
			"_strip_comments drops comments after a quoted line too")

	# The scene is part of the contract as well: a @tool or plugin script
	# attached to it would make the runtime editor unusable in a running game.
	var scene_source := FileAccess.get_file_as_string("%s/map_editor.tscn" % EDITOR_DIR)
	harness.check(not scene_source.contains("EditorPlugin") and not scene_source.contains("EditorDock"),
			"map_editor.tscn attaches no editor-only nodes")
	var foreign: PackedStringArray = []
	for line in scene_source.split("\n"):
		if not line.begins_with("[ext_resource"):
			continue
		var path := _ext_resource_path(line)
		if path != "" and not path.begins_with(EDITOR_DIR + "/"):
			foreign.append(path)
	harness.check(foreign.is_empty(),
			"every map_editor.tscn script comes from %s/: %s" % [EDITOR_DIR, ", ".join(foreign)])


# The path="…" value of a .tscn [ext_resource] header line.
static func _ext_resource_path(line: String) -> String:
	var start := line.find("path=\"")
	if start < 0:
		return ""
	var value_start := start + 6
	var value_end := line.find("\"", value_start)
	if value_end < value_start:
		return ""
	return line.substr(value_start, value_end - value_start)


# Line comments only, with enough lexical care to be trustworthy: '#' inside a
# quoted or triple-quoted string is not a comment, and '\"' does not close the
# string. Both GDScript quote styles count.
static func _strip_comments(source: String) -> String:
	var out := ""
	var n := source.length()
	var i := 0
	while i < n:
		var c: String = source[i]
		if c == "#":
			while i < n and source[i] != "\n":
				i += 1
			continue  # the newline itself is copied by the next iteration
		if c == "\"" or c == "'":
			var triple := i + 2 < n and source[i + 1] == c and source[i + 2] == c
			if triple:
				out += c + c + c
				i += 3
				while i < n:
					if source[i] == c and i + 2 < n and source[i + 1] == c and source[i + 2] == c:
						out += c + c + c
						i += 3
						break
					out += source[i]
					i += 1
				continue
			out += c
			i += 1
			var escaped := false
			while i < n:
				var q: String = source[i]
				out += q
				i += 1
				if escaped:
					escaped = false
				elif q == "\\":
					escaped = true
				elif q == c:
					break
			continue
		out += c
		i += 1
	return out


# ---------------------------------------------------------------------------

func _clean() -> void:
	# Only the fixture name. Deleting the sanitized test names too would wipe
	# real maps when the suite runs without GODOT_DATA_HOME ("map" is the
	# store's fallback save name).
	MapStore.delete_map(_TMP)


func _errors(problems: Array) -> Array:
	var errors: Array = []
	for problem in problems:
		if problem.get("level", "") == "error":
			errors.append(problem.get("message", ""))
	return errors


func _describe(problems: Array) -> String:
	var lines: PackedStringArray = []
	for problem in problems:
		lines.append("%s: %s" % [problem.get("level", "?"), problem.get("message", "")])
	return "; ".join(lines)
