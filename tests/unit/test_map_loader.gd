extends RefCounted

# =============================================================================
# Map loader tests (tests/unit/test_map_loader.gd)
# =============================================================================
# Covers map_manager's generic map resolution (Phase 2): maps authored with
# the map editor plugin exist only as map/maps/<name>.tscn files, so
# _resolve_map_scene must fall back to loading them by name while the
# preloaded shipping maps keep their fast path.
#
# Deliberately does NOT call load_map(): it mutates shared WorldState state
# and needs the full game/ui bootstrap — booting a scaffolded map end-to-end
# remains a manual check (the boot smoke exercises load_map for the
# three-lane map every suite run).
# =============================================================================

const MapManagerScript = preload("res://map/map_manager.gd")
const Scaffold = preload("res://addons/map_editor/map_scaffold.gd")

const _TMP_MAP_NAME := "_tmp_loader_test_map"


func run(harness) -> void:
	var mm: Node = MapManagerScript.new()

	# Preloaded shipping maps keep their fast path.
	harness.check(mm._resolve_map_scene("one_lane_map") != null,
			"preloaded one_lane_map resolves")
	harness.check(mm._resolve_map_scene("three_lane_map") != null,
			"preloaded three_lane_map resolves")
	harness.check(mm._resolve_map_scene("campaign_map") != null,
			"preloaded campaign_map resolves")

	# Unknown names resolve to null (load_map reports and bails) instead of
	# crashing on self[map_name].
	harness.check_equal(mm._resolve_map_scene("no_such_map_xyz"), null,
			"unknown map name resolves to null")

	# A map authored by the plugin (only a .tscn on disk, no preload) resolves
	# through the map/maps/ fallback. Written into res:// so the resolver's
	# real path is exercised; removed immediately after.
	var err: int = Scaffold.new().write_map("res://map/maps/%s.tscn" % _TMP_MAP_NAME)
	harness.check_equal(err, OK, "scaffold fixture writes into map/maps/")
	if err == OK:
		var resolved = mm._resolve_map_scene(_TMP_MAP_NAME)
		harness.check(resolved != null, "unpreloaded scaffolded map resolves by name")
		if resolved != null:
			harness.check_equal((resolved as PackedScene).get_state().get_node_count() > 1, true,
					"resolved scaffolded scene has content")
		DirAccess.remove_absolute("res://map/maps/%s.tscn" % _TMP_MAP_NAME)

	mm.free()
