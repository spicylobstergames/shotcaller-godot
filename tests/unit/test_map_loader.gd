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
const MapStore = preload("res://map/editor/map_store.gd")

const _TMP_MAP_NAME := "_tmp_loader_test_map"
# M4: runtime-authored maps live under user://maps/ (res:// is read-only in
# exported builds), so the resolver must reach them by full path and by name.
const _TMP_USER_MAP_NAME := "_tmp_loader_user_map"


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

	_test_user_maps(harness, mm)

	mm.free()


# M4: the runtime editor's maps live under user://maps/ (res:// is read-only in
# exported builds), so the resolver must reach them both ways: as the full path
# game.gd boots them with, and as a bare name for map_manager.current_map.
# The fixture carries a marker lane so a resolution can be attributed to the
# file that actually answered.
func _test_user_maps(harness, mm: Node) -> void:
	MapStore.delete_map(_TMP_USER_MAP_NAME)
	var marker_lane := "_tmp_user_only_lane"
	var map: Node2D = Scaffold.new().build_map()
	var marker := Line2D.new()
	marker.name = marker_lane
	marker.add_point(Vector2(64, 64))
	marker.add_point(Vector2(192, 64))
	map.get_node("lanes").add_child(marker)
	var save_err := MapStore.save_map(map, _TMP_USER_MAP_NAME)
	map.free()
	harness.check_equal(save_err, OK, "map_store fixture writes into user://maps/")
	if save_err != OK:
		return

	var user_path := MapStore.path_for(_TMP_USER_MAP_NAME)
	harness.check(user_path == "user://maps/%s.tscn" % _TMP_USER_MAP_NAME,
			"the fixture path is the user:// path the resolver must accept")

	var by_path = mm._resolve_map_scene(user_path)
	harness.check(by_path is PackedScene, "user:// full path resolves")
	if by_path is PackedScene:
		var from_path: Node = (by_path as PackedScene).instantiate()
		harness.check(from_path.get_node_or_null("lanes/" + marker_lane) is Line2D,
				"the user:// full path resolves to the user fixture (marker lane present)")
		from_path.free()

	# Bare name: no preloaded var, no res://map/maps/ file — falls back to
	# user://maps/. The res:// fixture earlier in run() was already removed, so
	# only the user map can answer this name.
	var by_name = mm._resolve_map_scene(_TMP_USER_MAP_NAME)
	harness.check(by_name is PackedScene, "bare name falls back to user://maps/<name>.tscn")
	if by_name is PackedScene:
		var from_name: Node = (by_name as PackedScene).instantiate()
		harness.check(from_name.get_node_or_null("lanes/" + marker_lane) is Line2D,
				"the bare name resolves to the user fixture (marker lane present)")
		from_name.free()

	# Precedence: the shipping path is checked first, so a name that exists in
	# both places boots the shipped map. A plain scaffold (no marker) is written
	# into res://map/maps/ under the same name.
	var shadow_err: int = Scaffold.new().write_map("res://map/maps/%s.tscn" % _TMP_USER_MAP_NAME)
	harness.check_equal(shadow_err, OK, "shipping-path shadow fixture writes")
	if shadow_err == OK:
		var shadowed = mm._resolve_map_scene(_TMP_USER_MAP_NAME)
		harness.check(shadowed is PackedScene, "shadowed name still resolves")
		if shadowed is PackedScene:
			var from_shadow: Node = (shadowed as PackedScene).instantiate()
			harness.check(from_shadow.get_node_or_null("lanes/" + marker_lane) == null,
					"res://map/maps/<name>.tscn wins over user://maps/<name>.tscn")
			from_shadow.free()
		DirAccess.remove_absolute("res://map/maps/%s.tscn" % _TMP_USER_MAP_NAME)

	# Shipping maps keep answering even while a user map exists, and a name that
	# answers nothing returns null instead of crashing on self[map_name] —
	# including a traversal-shaped name and an explicit missing user path (the
	# load_map() push_error bail).
	harness.check(mm._resolve_map_scene("three_lane_map") != null,
			"shipping maps still resolve with a user map present")
	harness.check_equal(mm._resolve_map_scene("no_such_map_xyz"), null,
			"unknown map name still resolves to null")
	harness.check_equal(mm._resolve_map_scene("../no_such_map_xyz"), null,
			"a traversal-shaped name resolves to null, not outside map/maps/")
	harness.check_equal(mm._resolve_map_scene("user://maps/no_such_map_xyz.tscn"), null,
			"a missing user:// map path resolves to null")

	harness.check_equal(MapStore.delete_map(_TMP_USER_MAP_NAME), OK, "user:// fixture is removed")
