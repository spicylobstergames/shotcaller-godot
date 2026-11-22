extends RefCounted

# =============================================================================
# Building placement logic tests (tests/unit/test_building_logic.gd)
# =============================================================================
# Covers addons/map_editor/building_logic.gd — the editor-free core of the
# plugin's building-placement mode: palette listing, target-team resolution,
# name minting, and the team/subtype metadata contract. The interactive
# click-to-place flow itself is editor-only and untestable headless; the
# shared click->world conversion is pinned in test_lane_logic.gd.
# =============================================================================

const BuildingLogic = preload("res://addons/map_editor/building_logic.gd")
const Scaffold = preload("res://addons/map_editor/map_scaffold.gd")


func run(harness) -> void:
	_test_list_building_scenes(harness)
	_test_building_base_name(harness)
	_test_place_target(harness)
	_test_next_building_name(harness)
	_test_apply_building_meta(harness)


# ---------------------------------------------------------------------------
# Palette: the unit/buildings/*.tscn scenes
# ---------------------------------------------------------------------------

func _test_list_building_scenes(harness) -> void:
	var scenes := BuildingLogic.list_building_scenes()
	harness.check(not scenes.is_empty(), "the palette finds building scenes")
	harness.check(scenes.has("res://unit/buildings/castle.tscn"),
			"the palette includes the win-condition castle")
	var all_tscn := true
	var unique := true
	var seen := {}
	var sorted := true
	var no_decoration := true
	var previous := ""
	for scene_path in scenes:
		if not scene_path.ends_with(".tscn"):
			all_tscn = false
		if seen.has(scene_path):
			unique = false
		seen[scene_path] = true
		if previous != "" and scene_path < previous:
			sorted = false
		if scene_path.contains("/decoration/"):
			no_decoration = false
		previous = scene_path
	harness.check(all_tscn, "every palette entry is a .tscn scene")
	harness.check(unique, "the palette has no duplicate entries")
	harness.check(sorted, "the palette is sorted (stable dock order)")
	harness.check(no_decoration, "the palette skips decoration subdirectories")


# ---------------------------------------------------------------------------
# Names: scene path -> base name
# ---------------------------------------------------------------------------

func _test_building_base_name(harness) -> void:
	harness.check_equal(BuildingLogic.building_base_name("res://unit/buildings/tower.tscn"), "tower",
			"a scene path reduces to its base name")
	harness.check_equal(BuildingLogic.building_base_name("res://unit/buildings/decoration/flag.tscn"), "flag",
			"subdirectory scenes still reduce to the base name")


# ---------------------------------------------------------------------------
# Target resolution: which buildings/<team> does a placement attach to?
# ---------------------------------------------------------------------------

func _test_place_target(harness) -> void:
	var map: Node = Scaffold.new().build_map()
	var blue: Node = map.get_node("buildings/blue")

	harness.check_equal(BuildingLogic.place_target(map, "blue"), blue,
			"an existing team directory is the placement target")
	harness.check_equal(BuildingLogic.place_target(map, "green"), null,
			"a nonexistent team directory resolves to null (dock errors instead of crashing)")

	var bare := Node2D.new()
	harness.check_equal(BuildingLogic.place_target(bare, "blue"), null,
			"a map without a 'buildings' node resolves to null")

	map.free()
	bare.free()


# ---------------------------------------------------------------------------
# Names: first free building name per team
# ---------------------------------------------------------------------------

func _test_next_building_name(harness) -> void:
	var team_node := Node2D.new()

	harness.check_equal(BuildingLogic.next_building_name(team_node, "tower"), "tower",
			"an empty team directory yields the base name")

	var tower := Node2D.new()
	tower.name = "tower"
	team_node.add_child(tower)
	harness.check_equal(BuildingLogic.next_building_name(team_node, "tower"), "tower_2",
			"a taken base name yields base_2")

	var tower2 := Node2D.new()
	tower2.name = "tower_2"
	team_node.add_child(tower2)
	harness.check_equal(BuildingLogic.next_building_name(team_node, "tower"), "tower_3",
			"tower_2 taken -> tower_3")

	harness.check_equal(BuildingLogic.next_building_name(team_node, "mine"), "mine",
			"an unrelated base name is unaffected by tower numbering")

	# Free tower the safe way: detach before freeing, or the parent keeps a
	# dangling child and the final team_node.free() crashes.
	team_node.remove_child(tower)
	tower.free()
	harness.check_equal(BuildingLogic.next_building_name(team_node, "tower"), "tower",
			"freed names are reused")

	team_node.free()


# ---------------------------------------------------------------------------
# Metadata: team/subtype per the validator contract
# ---------------------------------------------------------------------------

func _test_apply_building_meta(harness) -> void:
	var scaffold_map: Node = Scaffold.new().build_map()
	var lane_name: String = scaffold_map.get_node("lanes").get_children()[0].name

	# Real building scenes: Unit.gd carries the @export team/subtype the
	# validator and map_manager.setup_buildings read.
	var castle: Node = (load("res://unit/buildings/castle.tscn") as PackedScene).instantiate()
	BuildingLogic.apply_building_meta(castle, "castle", "blue", lane_name)
	harness.check_equal(castle.team, "blue",
			"a team structure takes the directory team")
	harness.check_equal(castle.subtype, lane_name,
			"a team structure's subtype is the active lane (WalkLane reads it)")

	var blacksmith: Node = (load("res://unit/buildings/blacksmith.tscn") as PackedScene).instantiate()
	BuildingLogic.apply_building_meta(blacksmith, "blacksmith", "red", lane_name)
	harness.check_equal(blacksmith.team, "neutral",
			"a non-structure building is neutral regardless of the chosen team")
	harness.check_equal(blacksmith.subtype, BuildingLogic.NEUTRAL_SUBTYPE,
			"a non-structure building carries the backwood subtype")

	scaffold_map.free()
	castle.free()
	blacksmith.free()
