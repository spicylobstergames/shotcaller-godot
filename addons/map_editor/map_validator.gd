extends RefCounted

# =============================================================================
# Map contract validator (addons/map_editor/map_validator.gd)
# =============================================================================
# Checks a map scene against the runtime contract that map_manager.gd and
# spawns.gd read by node path (see map/README.md and map/maps/base_map.gd).
#
# This file is deliberately editor-free (RefCounted, no EditorInterface) so it
# runs in the headless unit suite: tests/unit/test_map_editor.gd.
#
# validate(map) -> Array of {"level": "error"|"warning", "message": String}.
#   error   = the map will break or misbehave at runtime.
#   warning = optional feature absent (shop blacksmith, camp hiring, ...).
# The validator never mutates the map.
# =============================================================================

const _BASE_MAP_SCRIPT_PATH := "res://map/maps/base_map.gd"

# Team-colored structures: their `team` must match the directory they sit in.
const _TEAM_STRUCTURE_NAMES := ["castle", "barrack", "tower"]

# The team directories map_manager.setup_buildings iterates.
const _TEAM_DIRECTORIES := ["blue", "red"]

# The three TileMapLayers base_map.gd reads in @onready; navigation.gd also
# reads `map.walls` for jump-point pathfinding.
const _REQUIRED_TILE_LAYERS := [
	"tiles/ground/Ground",
	"tiles/walls/Walls",
	"tiles/trees/Trees",
]


func validate(map: Node) -> Array:
	var problems: Array = []
	_check_root(map, problems)
	_check_tiles(map, problems)
	var lane_names := _check_lanes(map, problems)
	_check_buildings(map, lane_names, problems)
	return problems


# ---------------------------------------------------------------------------
# Root script, fog, exports
# ---------------------------------------------------------------------------

func _check_root(map: Node, problems: Array) -> void:
	var script = map.get_script()
	if script == null:
		_fail(problems, "map root has no script attached (expected one extending %s)" % _BASE_MAP_SCRIPT_PATH)
	elif not _script_is_base_map(script):
		_fail(problems, "map root script %s does not extend %s" % [script.resource_path, _BASE_MAP_SCRIPT_PATH])

	var fog = map.get_node_or_null("fog")
	if fog == null:
		_fail(problems, "missing required node 'fog' (CanvasModulate; map_manager.gd toggles its visibility)")
	elif not fog is CanvasModulate:
		_fail(problems, "'fog' must be a CanvasModulate (got %s)" % fog.get_class())

	var size = map.get("size")
	# A BaseMap-rooted scene always has a valid exported default; this only
	# fires when a map explicitly overrides size with a non-positive value.
	if size is Vector2 and (size.x <= 0 or size.y <= 0):
		_warn(problems, "map 'size' must be a positive Vector2 (got %s); WorldState map_size is published from it" % size)

	# ui/minimap.gd reads this with get_node_or_null to snapshot the zoomed-out
	# view; both shipping maps carry it, so absence degrades the minimap.
	if map.get_node_or_null("zoom_out_sprite") == null:
		_warn(problems, "no 'zoom_out_sprite' Sprite2D (minimap's zoomed-out view falls back silently)")


func _script_is_base_map(script) -> bool:
	var s = script
	while s != null:
		if s.resource_path == _BASE_MAP_SCRIPT_PATH:
			return true
		s = s.get_base_script()
	return false


# ---------------------------------------------------------------------------
# Tile layers
# ---------------------------------------------------------------------------

func _check_tiles(map: Node, problems: Array) -> void:
	for path in _REQUIRED_TILE_LAYERS:
		var layer = map.get_node_or_null(path)
		if layer == null:
			_fail(problems, "missing required TileMapLayer '%s' (base_map.gd reads it in @onready)" % path)
			continue
		if not layer is TileMapLayer:
			_fail(problems, "'%s' must be a TileMapLayer (got %s)" % [path, layer.get_class()])
			continue
		if layer.tile_set == null:
			_fail(problems, "TileMapLayer '%s' has no tile_set assigned" % path)

	# navigation.gd feeds the WALLS layer's used-cell coordinates directly into
	# a pathfinding grid built from base_map's `tile_size`, so a walls TileSet
	# with a different cell size makes painted walls block the wrong cells.
	# (The ground/trees TileSets are visual and may legitimately differ — the
	# shipping maps run an (8, 8) ground cell size against tile_size 64.)
	var walls: TileMapLayer = map.get_node_or_null("tiles/walls/Walls")
	var tile_size = map.get("tile_size")
	# base_map.gd declares tile_size untyped, so the inspector can hand us a
	# float; accept any numeric value.
	if walls != null and walls is TileMapLayer and walls.tile_set != null \
			and (tile_size is int or tile_size is float) and tile_size > 0:
		var cell_size: Vector2i = walls.tile_set.tile_size
		if cell_size.x != tile_size or cell_size.y != tile_size:
			_fail(problems, "walls TileMapLayer cell size %s does not match 'tile_size' %d — painted walls would block the wrong pathfinding cells (navigation.gd grids walls cells by tile_size)" % [cell_size, tile_size])


# ---------------------------------------------------------------------------
# Lanes
# ---------------------------------------------------------------------------

# Returns the set of lane names so the building check can verify that every
# building's `subtype` points at a real lane (WalkLane plans against it).
func _check_lanes(map: Node, problems: Array) -> Dictionary:
	var lane_names := {}
	var lanes_node = map.get_node_or_null("lanes")
	if lanes_node == null:
		_fail(problems, "missing required 'lanes' node (spawns.gd and WalkLane read lanes/<name>)")
		return lane_names

	var found_line := false
	for lane in lanes_node.get_children():
		if not lane is Line2D:
			continue
		found_line = true
		lane_names[lane.name] = true
		if lane.get_point_count() < 2:
			_fail(problems, "lane '%s' needs at least 2 points (unit walk path)" % lane.name)

	if not found_line:
		_fail(problems, "'lanes' contains no Line2D lanes (spawns.gd iterates them to spawn pawns)")

	# spawns.gd spawns LEADERS on the hardcoded "mid" lane unless the map has
	# exactly three lanes (then top/mid/bot by counter). Without a "mid" lane
	# leader spawning crashes (get_lane_path returns [] -> pop_front() null).
	if not lane_names.has("mid"):
		_fail(problems, "no lane named 'mid' (spawns.gd hardcodes it for leader spawning)")

	# Three lanes with other names would send leaders to nonexistent
	# top/mid/bot lanes.
	if lane_names.size() == 3 and not (lane_names.has("top") and lane_names.has("mid") and lane_names.has("bot")):
		_warn(problems, "map has exactly three lanes but they are not named top/mid/bot (three-lane leader spawning assumes those names)")

	return lane_names


# ---------------------------------------------------------------------------
# Buildings
# ---------------------------------------------------------------------------

func _check_buildings(map: Node, lane_names: Dictionary, problems: Array) -> void:
	var buildings_node = map.get_node_or_null("buildings")
	if buildings_node == null:
		_fail(problems, "missing required 'buildings' node (map_manager.setup_buildings reads buildings/<team>/<building>)")
		return

	for child in buildings_node.get_children():
		# setup_buildings treats EVERY child of 'buildings' as a team and
		# iterates its children as buildings; a stray node here means error
		# spam (reset_unit/agent/... on a non-building).
		if not child.name in _TEAM_DIRECTORIES:
			_fail(problems, "unexpected child '%s' under 'buildings' (expected only %s team directories)" % [
				child.name, " and ".join(PackedStringArray(_TEAM_DIRECTORIES)),
			])
			continue
		_check_team(child, child.name, lane_names, problems)

	for team in _TEAM_DIRECTORIES:
		if buildings_node.get_node_or_null(team) == null:
			# Runtime tolerates a missing team (campaign_map legitimately ships
			# blue-only), but a battle map without one can't be won/lost.
			_warn(problems, "missing 'buildings/%s' node (fine for a campaign-style map; a battle map needs it)" % team)


func _check_team(team_node: Node, team: String, lane_names: Dictionary, problems: Array) -> void:
	var names := {}
	for building in team_node.get_children():
		names[building.name] = true

	# map_manager.gd resolves buildings/<team>/<building> with get_node, which
	# returns the FIRST match — duplicates below silently shadow each other.
	if names.size() != team_node.get_child_count():
		_warn(problems, "buildings/%s has duplicate building names (get_node resolves only the first)" % team)

	if not names.has("castle"):
		_fail(problems, "buildings/%s is missing its castle (the win condition)" % team)
	for structure in ["barrack", "tower"]:
		if not names.has(structure):
			_warn(problems, "buildings/%s has no %s" % [team, structure])
	if not names.has("blacksmith"):
		_warn(problems, "buildings/%s has no blacksmith (the shop looks for buildings/%s/blacksmith)" % [team, team])
	if not names.has("camp"):
		_warn(problems, "buildings/%s has no camp (camp hiring)" % team)

	for building in team_node.get_children():
		_check_building(building, team, lane_names, problems)


func _check_building(building: Node, team: String, lane_names: Dictionary, problems: Array) -> void:
	# Team structures' subtype IS their lane assignment (map_manager copies it
	# into agent state; WalkLane plans against it), so it must name a lane.
	# Neutral buildings use the special "backwood" subtype instead (Taxes/
	# Conquer behavior in Unit.gd/tactics_panel.gd) — a lane name is also
	# accepted for them.
	var subtype = building.get("subtype")
	if building.name in _TEAM_STRUCTURE_NAMES:
		if subtype == null or not lane_names.has(subtype):
			_fail(problems, "building 'buildings/%s/%s' subtype '%s' does not match any lane (%s)" % [
				team, building.name, subtype, ", ".join(PackedStringArray(lane_names.keys())),
			])
	elif subtype != "backwood" and (subtype == null or not lane_names.has(subtype)):
		_fail(problems, "building 'buildings/%s/%s' has subtype '%s' (expected 'backwood' or a lane name: %s)" % [
			team, building.name, subtype, ", ".join(PackedStringArray(lane_names.keys())),
		])

	var bteam = building.get("team")
	if bteam == null:
		bteam = ""
	if building.name in _TEAM_STRUCTURE_NAMES:
		if bteam != team:
			_fail(problems, "building 'buildings/%s/%s' has team '%s' but must be '%s'" % [team, building.name, bteam, team])
	elif bteam != team and bteam != "neutral":
		_fail(problems, "building 'buildings/%s/%s' has unknown team '%s' (expected '%s' or 'neutral')" % [team, building.name, bteam, team])

	if building.name == "blacksmith" and building.get_node_or_null("closest_tree") == null:
		_warn(problems, "blacksmith 'buildings/%s/blacksmith' has no 'closest_tree' Marker2D (lumberjack hiring reads it)" % team)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _fail(problems: Array, message: String) -> void:
	problems.append({"level": "error", "message": message})


func _warn(problems: Array, message: String) -> void:
	problems.append({"level": "warning", "message": message})
