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
# placement-side mirror of it. TEAM_STRUCTURE_NAMES get subtype = lane and
# team = directory (validator-enforced). TEAM_OWNED_NAMES ship team-owned in
# the shipping maps (three_lane_map.tscn carries team = "red" for the red
# church) but their subtype stays backwood; the validator accepts team or
# neutral for them. Everything else is a neutral backwood building.
const TEAM_DIRECTORIES := ["blue", "red"]
const TEAM_STRUCTURE_NAMES := ["castle", "barrack", "tower"]
const TEAM_OWNED_NAMES := ["church"]
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


# Neutrals must sit under a team directory (validator: only blue/red children
# under 'buildings'), so a "neutral" placement hosts under the first team
# directory that exists — blue by convention, else red, else "" (dock errors).
static func neutral_host_team(map_root: Node) -> String:
	for team in TEAM_DIRECTORIES:
		if place_target(map_root, team) != null:
			return team
	return ""


# Whether the chosen team is legal for this building KIND. Team structures
# (castle/barrack/tower) must be team-owned: the validator fails a neutral
# castle and the win condition looks up buildings/<team>/castle.
static func is_placement_allowed(base_name: String, team: String) -> bool:
	if team == "neutral" and base_name in TEAM_STRUCTURE_NAMES:
		return false
	return true


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


# Team/subtype metadata per the validator's rules and the shipping maps
# (see the header). base_name is the building KIND (the scene base name,
# e.g. "tower") — NOT the minted node name: a placed "tower_2" must still be
# a tower, and matching on the renamed node made every second+ placement of
# a team structure silently neutral (the bug this fixed).
static func apply_building_meta(building: Node, base_name: String, team: String, lane_name: String) -> void:
	if base_name in TEAM_STRUCTURE_NAMES:
		building.team = team
		building.subtype = lane_name
	elif base_name in TEAM_OWNED_NAMES:
		building.team = team
		building.subtype = NEUTRAL_SUBTYPE
	else:
		building.team = "neutral"
		building.subtype = NEUTRAL_SUBTYPE


# Editor-preview counterpart of Unit.set_anim: the building scenes ship with
# the blue "default" animation, and the team recolor only happens at runtime
# (Unit.setup_team), so a red/neutral placement would sit in the editor
# looking blue until the game boots. Apply the same animation mapping to the
# instance's sprites so the editor shows the team color; sprites whose
# SpriteFrames lack the animation are skipped (same as runtime, which only
# touches body/weapon/flags — and runtime re-applies per actual team anyway,
# so these overrides are preview-only and save-safe).
static func apply_editor_team_visuals(building: Node, team: String) -> void:
	var animation := "default"
	match team:
		"red":
			animation = "red"
		"neutral":
			animation = "neutral"
	_set_animations(building, animation)


static func _set_animations(node: Node, animation: String) -> void:
	if node is AnimatedSprite2D and node.sprite_frames != null \
			and node.sprite_frames.has_animation(animation):
		node.animation = animation
	for child in node.get_children():
		_set_animations(child, animation)
