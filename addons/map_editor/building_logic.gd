extends RefCounted

# =============================================================================
# Building placement logic (addons/map_editor/building_logic.gd)
# =============================================================================
# Pure, editor-free helpers for the plugin's building-placement mode — the
# sibling of lane_logic.gd. Everything that decides WHICH team directory a
# click targets, WHAT the placed building is named, and WHICH team/subtype
# metadata it carries lives here so it runs in the headless unit suite
# (tests/unit/test_building_logic.gd); the plugin only forwards editor
# input/output to these functions.
#
# Contract being honored (map_validator.gd / map/map_manager.gd
# setup_buildings): every child of 'buildings' is a team directory (blue/
# red); team structures (castle, barrack, tower) need team == directory and
# subtype == a real lane name; neutrals sit under a team directory but carry
# team = "neutral" and subtype "backwood" or a lane (shipping-map
# convention). Building names must be unique per team (get_node resolves
# only the first match).
# =============================================================================

const BUILDINGS_DIR := "res://unit/buildings"

# Kept in sync with map_validator.gd (_TEAM_DIRECTORIES,
# _TEAM_STRUCTURE_NAMES); the validator is the runtime contract, this is the
# placement-side mirror of it.
const TEAM_DIRECTORIES := ["blue", "red"]
const TEAM_STRUCTURE_NAMES := ["castle", "barrack", "tower"]
const NEUTRAL_SUBTYPE := "backwood"


# Palette scenes: the top-level *.tscn building scenes, sorted (decoration/
# and any other subdirectories are not placements). Empty when the project
# layout moved — the dock logs a reason instead of showing an empty palette.
static func list_building_scenes() -> PackedStringArray:
	var scenes := PackedStringArray()
	var dir := DirAccess.open(BUILDINGS_DIR)
	if dir == null:
		return scenes
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".tscn"):
			scenes.append(BUILDINGS_DIR + "/" + file)
		file = dir.get_next()
	dir.list_dir_end()
	scenes.sort()
	return scenes


# "res://unit/buildings/tower.tscn" -> "tower".
static func building_base_name(scene_path: String) -> String:
	return scene_path.get_file().get_basename()


# The team node a placement should attach to: buildings/<team>, or null
# (missing 'buildings' node or missing team directory — the dock logs and
# skips; this must not crash on maps without that team).
static func place_target(map_root: Node, team: String) -> Node:
	var buildings_node = map_root.get_node_or_null("buildings")
	if buildings_node == null:
		return null
	return buildings_node.get_node_or_null(team)


# First free name for a new building: the base name itself, then
# base_2, base_3, ... (validator warns on duplicate names — get_node
# resolves only the first match; freed names are reusable, mirroring
# LaneLogic.next_lane_name).
static func next_building_name(team_node: Node, base_name: String) -> String:
	if team_node.get_node_or_null(base_name) == null:
		return base_name
	var index := 2
	while team_node.get_node_or_null("%s_%d" % [base_name, index]) != null:
		index += 1
	return "%s_%d" % [base_name, index]


# Team/subtype metadata per the validator's rules (see the header): team
# structures take the directory team and the lane the map is currently
# drawing; everything else is a neutral backwood building.
static func apply_building_meta(building: Node, building_name: String, team: String, lane_name: String) -> void:
	if building_name in TEAM_STRUCTURE_NAMES:
		building.team = team
		building.subtype = lane_name
	else:
		building.team = "neutral"
		building.subtype = NEUTRAL_SUBTYPE
