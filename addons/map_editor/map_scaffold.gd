extends RefCounted

# =============================================================================
# Map scaffold (addons/map_editor/map_scaffold.gd)
# =============================================================================
# Builds a fresh map scene tree that satisfies the runtime contract consumed
# by map_manager.gd and spawns.gd (see map/README.md), so a new map starts
# from a valid skeleton instead of a hand-copied .tscn.
#
# Editor-free (RefCounted, no EditorInterface) so it runs in the headless
# unit suite: tests/unit/test_map_editor.gd.
#
# TileSets are borrowed live from one_lane_map.tscn rather than duplicated —
# the scaffold always paints with the same ground/wall/tree tiles the
# shipping maps use, without a second copy of the TileSet resource to keep
# in sync.
# =============================================================================

const BASE_MAP_SCRIPT := preload("res://map/maps/base_map.gd")
const SOURCE_MAP := preload("res://map/maps/one_lane_map.tscn")
const CASTLE_SCENE := preload("res://unit/buildings/castle.tscn")
const BARRACK_SCENE := preload("res://unit/buildings/barrack.tscn")
const TOWER_SCENE := preload("res://unit/buildings/tower.tscn")

const DEFAULT_LANE_NAME := "mid"

# A short diagonal across the default 1056x1056 map, mirroring the one-lane
# map's blue -> red axis. The user redraws it in Phase 2 (lane drawing).
# NOTE: a static func, not a const — const Packed*Array members built from
# Vector2() constructors cannot be resolved from other scripts (GDScript
# 4.x limitation; caught by tests/unit/test_map_editor.gd's compile).
static func default_lane_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(324, 737), Vector2(367, 635), Vector2(527, 526),
		Vector2(661, 444), Vector2(737, 313),
	])

const FOG_COLOR := Color(0.392157, 0.392157, 0.392157, 1)
const LANE_COLOR := Color(1, 1, 1, 0.196078)

# Start positions on the default map, loosely mirroring one_lane_map's
# blue (bottom-left) vs red (top-right) layouts.
const BLUE_POSITIONS := {
	"castle": Vector2(164, 932),
	"barrack": Vector2(280, 804),
	"tower": Vector2(412, 664),
	"blacksmith": Vector2(286, 373),
	"camp": Vector2(258, 467),
}
const RED_POSITIONS := {
	"castle": Vector2(924, 180),
	"barrack": Vector2(800, 284),
	"tower": Vector2(612, 424),
	"blacksmith": Vector2(770, 683),
	"camp": Vector2(798, 689),
}


func build_map() -> Node2D:
	var map := Node2D.new()
	map.name = "map"
	map.set_script(BASE_MAP_SCRIPT)
	map.y_sort_enabled = true
	map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_build_tiles(map)
	_build_fog(map)
	_build_buildings(map)
	_build_lanes(map)
	# Matches the shipping maps: ui/minimap.gd snapshots the zoomed-out view
	# into this sprite (it stays invisible; the minimap fills it in).
	var zoom_out := Sprite2D.new()
	zoom_out.name = "zoom_out_sprite"
	zoom_out.visible = false
	zoom_out.z_index = -1
	zoom_out.position = Vector2(528, 528)
	map.add_child(zoom_out)
	return map


# Builds the tree AND saves it as a .tscn. Returns OK or a Godot error code.
# The caller owns nothing: build_map's tree is freed here before returning.
func write_map(path: String) -> int:
	var map := build_map()
	# pack() only serializes nodes the root OWNS; programmatically built
	# children keep a null owner unless assigned (scene-file editing gets
	# this for free). Without this, the saved scene is just a bare root.
	_assign_owner(map, map)
	var packed := PackedScene.new()
	var err := packed.pack(map)
	map.free()
	if err != OK:
		return err
	return ResourceSaver.save(packed, path)


# Only claims nodes that belong to NO scene yet (owner == null): instanced
# building subtrees keep their internal owner, so pack() serializes them as
# instances instead of flattening their internals into the map file (which
# produced "name clashes with buildings/blue/castle/hud" on load).
func _assign_owner(node: Node, owner: Node) -> void:
	for child in node.get_children():
		if child.get_owner() != null:
			continue
		child.owner = owner
		_assign_owner(child, owner)


# ---------------------------------------------------------------------------
# tiles/ — Ground, Walls, Trees TileMapLayers with the shared TileSets
# ---------------------------------------------------------------------------

func _build_tiles(map: Node) -> void:
	var tiles := Node2D.new()
	tiles.name = "tiles"
	tiles.y_sort_enabled = true
	tiles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map.add_child(tiles)

	var sets := _source_tile_sets()

	var ground := Node2D.new()
	ground.name = "ground"
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tiles.add_child(ground)
	_add_layer("Ground", sets["ground"], ground)

	var walls := Node2D.new()
	walls.name = "walls"
	walls.y_sort_enabled = true
	walls.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tiles.add_child(walls)
	_add_layer("Walls", sets["walls"], walls, true)

	var trees := Node2D.new()
	trees.name = "trees"
	trees.y_sort_enabled = true
	tiles.add_child(trees)
	_add_layer("Trees", sets["trees"], trees, true)


# Pulls the TileSet resources out of the source map so the scaffold paints
# with the same tiles as the shipping maps.
func _source_tile_sets() -> Dictionary:
	var source := SOURCE_MAP.instantiate()
	var sets := {}
	for layer_path in ["tiles/ground/Ground", "tiles/walls/Walls", "tiles/trees/Trees"]:
		var layer = source.get_node_or_null(layer_path)
		# Key by the directory ("ground"/"walls"/"trees"), not the layer name.
		sets[layer_path.get_file().to_lower()] = layer.tile_set if layer else null
	source.free()
	return sets


func _add_layer(layer_name: String, tile_set: TileSet, parent: Node, y_sort := false) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.y_sort_enabled = y_sort
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.use_parent_material = true
	layer.tile_set = tile_set
	layer.rendering_quadrant_size = 32
	parent.add_child(layer)
	return layer


# ---------------------------------------------------------------------------
# fog — CanvasModulate, same default color as the shipping maps
# ---------------------------------------------------------------------------

func _build_fog(map: Node) -> void:
	var fog := CanvasModulate.new()
	fog.name = "fog"
	fog.color = FOG_COLOR
	map.add_child(fog)


# ---------------------------------------------------------------------------
# buildings/<team>/ — castle, barrack, tower, blacksmith, camp
# ---------------------------------------------------------------------------

func _build_buildings(map: Node) -> void:
	var buildings := Node2D.new()
	buildings.name = "buildings"
	buildings.y_sort_enabled = true
	buildings.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map.add_child(buildings)

	var blue := Node2D.new()
	blue.name = "blue"
	blue.y_sort_enabled = true
	buildings.add_child(blue)
	_populate_team(blue, BLUE_POSITIONS, "blue")

	var red := Node2D.new()
	red.name = "red"
	red.y_sort_enabled = true
	buildings.add_child(red)
	_populate_team(red, RED_POSITIONS, "red")


func _populate_team(team_node: Node, positions: Dictionary, team: String) -> void:
	var scenes := {
		"castle": CASTLE_SCENE,
		"barrack": BARRACK_SCENE,
		"tower": TOWER_SCENE,
	}
	for building_name in scenes:
		_add_building(team_node, scenes[building_name], building_name,
				positions[building_name], DEFAULT_LANE_NAME, team)

	# Neutrals follow the shipping maps' convention: they sit under a team
	# directory but carry team = "neutral" (map_manager sorts them into
	# WorldState neutral_buildings) and the special "backwood" subtype
	# (Taxes/Conquer behavior — Unit.gd, tactics_panel.gd).
	_add_building(team_node, preload("res://unit/buildings/blacksmith.tscn"),
			"blacksmith", positions["blacksmith"], "backwood", "neutral")
	var blacksmith: Node = team_node.get_node("blacksmith")
	var closest_tree := Marker2D.new()
	closest_tree.name = "closest_tree"
	closest_tree.position = Vector2(-94, 67)
	blacksmith.add_child(closest_tree)

	_add_building(team_node, preload("res://unit/buildings/camp.tscn"),
			"camp", positions["camp"], "backwood", "neutral")


func _add_building(parent: Node, scene: PackedScene, building_name: String,
		position: Vector2, subtype: String, team: String) -> Node:
	var building: Node = scene.instantiate()
	building.name = building_name
	building.position = position
	building.subtype = subtype
	building.team = team
	parent.add_child(building)
	return building


# ---------------------------------------------------------------------------
# lanes/<name> — Line2D walk paths (kept hidden, like the shipping maps)
# ---------------------------------------------------------------------------

func _build_lanes(map: Node) -> void:
	var lanes := Node2D.new()
	lanes.name = "lanes"
	lanes.visible = false
	lanes.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map.add_child(lanes)

	var lane := Line2D.new()
	lane.name = DEFAULT_LANE_NAME
	lane.points = default_lane_points()
	lane.default_color = LANE_COLOR
	lanes.add_child(lane)
