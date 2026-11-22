@tool
extends EditorPlugin

# Map editor plugin: registers the dock that scaffolds new map scenes and
# validates them against the runtime contract, plus the lane-drawing canvas
# mode. All decision logic lives in lane_logic.gd / map_scaffold.gd /
# map_validator.gd (headless-testable); this file only moves editor input.

const DockScript := preload("res://addons/map_editor/editor_dock.gd")
const LaneLogic := preload("res://addons/map_editor/lane_logic.gd")
const BuildingLogic := preload("res://addons/map_editor/building_logic.gd")

var _dock: Control
var _lane_mode := false
var _placement_mode := false


func _enter_tree() -> void:
	_dock = DockScript.new()
	_dock.name = "Map Editor"
	_dock.lane_mode_requested.connect(_set_lane_mode)
	_dock.new_lane_requested.connect(_add_lane)
	_dock.building_mode_requested.connect(_set_building_mode)
	add_control_to_dock(DOCK_SLOT_LEFT_UR, _dock)


# Canvas input forwarding is gated on the plugin HANDLING the currently
# edited object (see EditorPlugin._handles docs): without _handles the editor
# never calls _forward_canvas_gui_input/_forward_canvas_draw_over_viewport
# and lane-drawing clicks are silently dropped. We handle any node that
# belongs to a BaseMap scene, so the mode survives selecting lanes/buildings
# while editing a map — and never fires in unrelated scenes.
func _handles(object: Object) -> bool:
	if not (object is Node):
		return false
	var node := object as Node
	if not node.is_inside_tree() or node.get_tree() == null:
		return false
	return node.get_tree().edited_scene_root is BaseMap


# Required companions of _handles; the lane tool keeps no per-object state.
func _edit(_object: Object) -> void:
	pass


func _make_visible(_visible: bool) -> void:
	pass


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.free()
		_dock = null


# ---------------------------------------------------------------------------
# Lane drawing mode (Phase 2): left-click adds snapped points to the target
# lane, Escape (or the dock toggle) leaves the mode.
# ---------------------------------------------------------------------------

func _set_lane_mode(active: bool) -> void:
	if _lane_mode == active:
		return
	_lane_mode = active
	if active and _placement_mode:
		_placement_mode = false  # modes are mutually exclusive
		_dock.set_building_mode_active(false)
	if _dock != null:
		_dock.set_lane_mode_active(active)  # keep the toggle in sync on Escape
	if active:
		# Make the editor treat the map root as the edited object right now, so
		# _handles/_forward_canvas_gui_input kick in even if the user has
		# nothing selected (or a non-map scene object was last edited).
		var map_root := _map_root()
		if map_root != null:
			EditorInterface.edit_node(map_root)
		var lane := LaneLogic.target_lane(map_root, _selected_nodes())
		if lane != null:
			_dock.log_line("Draw-lanes ON: left-click adds snapped points to '%s'; Escape exits." % lane.name)
		else:
			_dock.log_line("Draw-lanes ON, but there is no lane to edit — use 'New lane' first.")
	else:
		_dock.log_line("Draw-lanes OFF.")
	update_overlays()  # redraw the overlay when entering/leaving the mode


# ---------------------------------------------------------------------------
# Building placement mode (Phase 3): pick a scene + team in the dock, then
# left-click instances it under buildings/<team> at the clicked world spot.
# ---------------------------------------------------------------------------

func _set_building_mode(active: bool) -> void:
	if _placement_mode == active:
		return
	_placement_mode = active
	if active and _lane_mode:
		_lane_mode = false  # modes are mutually exclusive
		_dock.set_lane_mode_active(false)
	if _dock != null:
		_dock.set_building_mode_active(active)  # keep the toggle in sync on Escape
	if active:
		# Same _handles bootstrap as lane mode: make the editor treat the map
		# root as the edited object so canvas input starts flowing.
		var map_root := _map_root()
		if map_root != null:
			EditorInterface.edit_node(map_root)
		var scene: String = _dock.selected_building_scene()
		if scene == "":
			_dock.log_line("Place-buildings ON, but the palette is empty — is unit/buildings/ still populated?")
		else:
			_dock.log_line("Place-buildings ON: left-click places '%s' (team '%s'); Escape exits."
					% [BuildingLogic.building_base_name(scene), _dock.selected_team()])
	else:
		_dock.log_line("Place-buildings OFF.")
	update_overlays()


func _add_lane() -> void:
	var map_root := _map_root()
	if map_root == null:
		return
	var lanes_node = map_root.get_node_or_null("lanes")
	if lanes_node == null:
		push_warning("Map Editor: the open scene has no 'lanes' node.")
		return

	var lane := Line2D.new()
	lane.name = LaneLogic.next_lane_name(lanes_node)
	lane.default_color = Color(1, 1, 1, 0.196078)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("Add lane")
	undo_redo.add_do_method(lanes_node, "add_child", lane)
	undo_redo.add_do_method(lane, "set_owner", map_root)
	undo_redo.add_do_reference(lane)
	undo_redo.add_undo_method(lanes_node, "remove_child", lane)
	undo_redo.add_undo_method(lane, "queue_free")
	undo_redo.commit_action()


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not (_lane_mode or _placement_mode):
		return false

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _lane_mode:
			_set_lane_mode(false)
		if _placement_mode:
			_set_building_mode(false)
		return true

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _lane_mode:
			_add_lane_point(event.position)
			return true
		if _placement_mode:
			_place_building(event.position)
			return true

	return false


func _add_lane_point(viewport_pos: Vector2) -> void:
	var map_root := _map_root()
	if map_root == null:
		return
	var lane := LaneLogic.target_lane(map_root, _selected_nodes())
	if lane == null:
		push_warning("Map Editor: no lane to draw on — select a lane or use 'New lane'.")
		return

	# Clicks arrive in the 2D editor's VIEWPORT space. In Godot 4.7 the editor
	# camera (pan/zoom) is the scene SubViewport's global_canvas_transform
	# (CanvasItemEditor pushes its transform there via
	# EditorNode::get_scene_root()->set_global_canvas_transform()); the plain
	# canvas_transform stays identity, which is why the earlier
	# get_global_transform_with_canvas() attempt was near-identity too.
	# viewport_to_node_xform() composes that camera with the lane's global
	# transform, so its inverse yields lane-local coordinates directly
	# (Line2D points are local) and always tracks pan/zoom.
	var xform := LaneLogic.viewport_to_node_xform(
			lane, lane.get_viewport().get_global_canvas_transform())
	var local := LaneLogic.snap_point(xform.affine_inverse() * viewport_pos)
	var index := LaneLogic.insertion_index(lane, local)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("Add lane point")
	undo_redo.add_do_method(lane, "add_point", local, index)
	undo_redo.add_undo_method(lane, "remove_point", index)
	undo_redo.commit_action()
	if _dock != null:
		_dock.log_line("Added point %d at %s to '%s' (clicked %s; lane xform origin %s)" % [
			index, local, lane.name, viewport_pos, xform.origin,
		])
	update_overlays()


func _place_building(viewport_pos: Vector2) -> void:
	var map_root := _map_root()
	if map_root == null:
		return
	var scene_path: String = _dock.selected_building_scene()
	if scene_path == "":
		push_warning("Map Editor: building palette is empty — nothing to place.")
		return
	# The chosen team is the METADATA (blue/red/neutral); the parent
	# directory follows it, with neutrals hosted under an existing team dir
	# (the validator only allows blue/red children under 'buildings').
	var team: String = _dock.selected_team()
	var parent_team := team
	if team == "neutral":
		parent_team = BuildingLogic.neutral_host_team(map_root)
		if parent_team == "":
			push_warning("Map Editor: no buildings/blue or buildings/red to host a neutral building.")
			return
	var base_name := BuildingLogic.building_base_name(scene_path)
	if not BuildingLogic.is_placement_allowed(base_name, team):
		_dock.log_line("REFUSED: a %s cannot be neutral — the win condition needs buildings/<team>/%s. Pick blue or red." % [base_name, base_name])
		return
	var team_node := BuildingLogic.place_target(map_root, parent_team)
	if team_node == null:
		push_warning("Map Editor: the open scene has no 'buildings/%s' node." % parent_team)
		return
	var lane := LaneLogic.target_lane(map_root, _selected_nodes())
	if lane == null:
		push_warning("Map Editor: no lane to derive subtype from — draw a lane first.")
		return

	# Clicks arrive in the 2D editor's VIEWPORT space (see _add_lane_point for
	# the 4.7 global_canvas_transform story). Compose the editor camera with
	# the team node's global transform so the click lands in the coordinate
	# space add_child expects, then snap to the tile grid.
	var camera := map_root.get_viewport().get_global_canvas_transform()
	var local := LaneLogic.snap_point(
			LaneLogic.viewport_to_node_xform(team_node, camera).affine_inverse() * viewport_pos)

	var building: Node = (load(scene_path) as PackedScene).instantiate()
	# Configure eagerly (not via undo methods): redo re-adds THIS node, and
	# names/metadata must be final before add_child — the Node API dedupes
	# sibling names with "@..." otherwise (scaffold gotcha).
	building.name = BuildingLogic.next_building_name(team_node, base_name)
	building.position = local
	# Metadata keys off the building KIND (base_name), never the minted node
	# name — "tower_2" must still be a tower (that mixup made every second+
	# structure placement silently neutral).
	BuildingLogic.apply_building_meta(building, base_name, team, lane.name)
	# Show the runtime team color in the editor too (the scenes ship blue;
	# Unit.setup_team only recolors at runtime).
	BuildingLogic.apply_editor_team_visuals(building, building.team)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("Place building")
	undo_redo.add_do_method(team_node, "add_child", building)
	undo_redo.add_do_method(building, "set_owner", map_root)
	undo_redo.add_do_reference(building)
	undo_redo.add_undo_method(team_node, "remove_child", building)
	undo_redo.add_undo_method(building, "queue_free")
	undo_redo.commit_action()
	_dock.log_line("Placed '%s' (%s) at %s under buildings/%s (team '%s', subtype '%s'; clicked %s)" % [
		building.name, scene_path.get_file(), local, parent_team, building.team, building.subtype, viewport_pos,
	])
	update_overlays()


func _forward_canvas_draw_over_viewport(viewport_control: Control) -> void:
	if not _lane_mode:
		return
	var map_root := _map_root()
	if map_root == null:
		return
	var lane := LaneLogic.target_lane(map_root, _selected_nodes())
	if lane == null:
		return

	# Show the user which lane is live and where its points are. Same
	# viewport->lane transform as the input path (see _add_lane_point), so
	# overlay and clicks agree and the overlay tracks the world when
	# panning/zooming instead of gluing to the editor window.
	var xform := LaneLogic.viewport_to_node_xform(
			lane, lane.get_viewport().get_global_canvas_transform())
	var points := PackedVector2Array()
	for i in lane.get_point_count():
		points.append(xform * lane.get_point_position(i))
	if points.size() >= 2:
		viewport_control.draw_polyline(points, Color(0.3, 0.7, 1.0, 0.9), 2.0)
	for point in points:
		viewport_control.draw_circle(point, 4.0, Color(0.3, 0.7, 1.0, 1.0))


func _map_root() -> Node:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or not (root is BaseMap):
		return null
	return root


func _selected_nodes() -> Array:
	var selection := EditorInterface.get_selection()
	if selection == null:
		return []
	return selection.get_selected_nodes()
