extends Control

# =============================================================================
# Runtime map editor UI (map/editor/editor_ui.gd)
# =============================================================================
# Built entirely from plain Controls in code: no EditorPlugin, no EditorInterface,
# no @tool, no FileDialog. It is the runtime counterpart of the plugin's
# editor_dock.gd (same tools, same pickers, same picker wording), and it makes
# NO decision about the map: every control emits a request signal and
# map_editor.gd does the work, which is also what keeps this file out of the
# headless tests.
#
# Mouse policy: this node covers the whole screen, so it IGNORES mouse input and
# only the panel (and its ScrollContainer) swallow clicks. A click that lands on
# the panel never reaches map_editor.gd's _unhandled_input, which is how the map
# tools stay click-accurate next to the tool panel.
# =============================================================================

const MapStore = preload("res://map/editor/map_store.gd")
const BuildingLogic = preload("res://addons/map_editor/building_logic.gd")
const TileBrush = preload("res://addons/map_editor/tile_brush_logic.gd")

const PANEL_WIDTH := 300.0
const LOG_LINES := 80
const TILE_ICON_PX := 96

signal new_map_requested
signal open_map_requested(map_name: String)
signal save_map_requested
signal delete_map_requested(map_name: String)
signal validate_requested
signal play_requested
signal exit_requested
signal lane_mode_requested(active: bool)
signal building_mode_requested(active: bool)
signal tile_mode_requested(active: bool)
signal new_lane_requested
signal lane_selected(lane_name: String)
signal undo_requested
signal redo_requested

# The map whose lanes/tiles fill the lane and tile pickers (set by the host;
# null when there is no map yet).
var map_root: Node2D = null

var _map_option: OptionButton
var _name_entry: LineEdit
var _lane_option: OptionButton
var _building_option: OptionButton
var _team_option: OptionButton
var _brush_option: OptionButton
var _tile_option: OptionButton
var _block_option: OptionButton
var _lane_toggle: Button
var _building_toggle: Button
var _tile_toggle: Button
var _log: RichTextLabel

var _block_values: Array[int] = []
var _picker_tiles: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _build() -> void:
	var panel := PanelContainer.new()
	panel.name = "ToolPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = PANEL_WIDTH
	panel.offset_bottom = 0.0
	add_child(panel)

	# More controls than fit a 600px-tall window, so the panel scrolls.
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var box := VBoxContainer.new()
	box.name = "Tools"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 0.0)
	scroll.add_child(box)

	_map_option = OptionButton.new()
	_map_option.tooltip_text = "Maps saved in user://maps/ (shipping maps are not editable)."
	box.add_child(_map_option)
	# Choosing a saved map pre-fills the name field, so Save writes back into
	# the map that is open instead of minting a second file.
	_map_option.item_selected.connect(func(_index: int) -> void:
		_name_entry.text = selected_map_name())

	var map_row := HBoxContainer.new()
	box.add_child(map_row)
	_add_button(map_row, "Open", "open_map_requested", "Open the selected map for editing.")
	var refresh := _add_button(map_row, "Refresh", "", "Re-read user://maps/.")
	refresh.pressed.connect(refresh_map_list)
	_add_button(map_row, "New map", "new_map_requested", "Create a fresh scaffolded map.")

	_name_entry = LineEdit.new()
	_name_entry.text = "untitled"
	_name_entry.tooltip_text = "Saved as user://maps/<name>.tscn"
	box.add_child(_name_entry)

	var file_row := HBoxContainer.new()
	box.add_child(file_row)
	_add_button(file_row, "Save", "save_map_requested",
			"Save into user://maps/ (validation problems are logged, never blocking).")
	_add_button(file_row, "Delete", "delete_map_requested", "Delete the selected saved map.")
	_add_button(file_row, "Validate", "validate_requested", "Report map problems without saving.")
	_add_button(file_row, "Play", "play_requested", "Save and boot the map: player blue vs enemy red.")
	_add_button(box, "Exit", "exit_requested", "Back to the main menu (unsaved edits are lost).")

	_section(box, "Lanes")
	_lane_option = OptionButton.new()
	_lane_option.tooltip_text = "The lane clicks edit in Draw lanes mode."
	box.add_child(_lane_option)
	_lane_option.item_selected.connect(func(index: int) -> void:
		lane_selected.emit(_lane_option.get_item_text(index)))
	var lane_row := HBoxContainer.new()
	box.add_child(lane_row)
	_add_button(lane_row, "New lane", "new_lane_requested", "Add an empty lane and select it.")
	_lane_toggle = _add_toggle(box, "Draw lanes",
			func(active: bool) -> void: lane_mode_requested.emit(active))

	_section(box, "Buildings")
	_building_toggle = _add_toggle(box, "Place buildings",
			func(active: bool) -> void: building_mode_requested.emit(active))
	_building_option = OptionButton.new()
	_building_option.tooltip_text = "Building scene to instantiate (res://unit/buildings/)."
	box.add_child(_building_option)
	for path in BuildingLogic.list_building_scenes():
		# OptionButton.add_item returns void in 4.7: the index is the count first.
		var building_index := _building_option.item_count
		_building_option.add_item(path.get_file().get_basename())
		_building_option.set_item_metadata(building_index, path)
	_team_option = OptionButton.new()
	_team_option.tooltip_text = "neutral places into the first team directory the map already has."
	box.add_child(_team_option)
	for team in BuildingLogic.TEAM_DIRECTORIES:
		_team_option.add_item(team)
	_team_option.add_item("neutral")
	_team_option.select(0)

	_section(box, "Tiles")
	_tile_toggle = _add_toggle(box, "Paint tiles",
			func(active: bool) -> void: tile_mode_requested.emit(active))
	_brush_option = OptionButton.new()
	_brush_option.tooltip_text = "Which TileMapLayer the clicks paint."
	box.add_child(_brush_option)
	for brush in TileBrush.BRUSHES.keys():
		var brush_index := _brush_option.item_count
		_brush_option.add_item(brush)
		_brush_option.set_item_metadata(brush_index, brush)
	_brush_option.select(0)
	_brush_option.item_selected.connect(func(_index: int) -> void: refresh_tile_picker())

	_block_option = OptionButton.new()
	_block_option.tooltip_text = ("How many cells one click covers. The full-tile size "
			+ "(largest) keeps the whole 64px tile painted; smaller sizes paint detail.")
	box.add_child(_block_option)

	_tile_option = OptionButton.new()
	_tile_option.tooltip_text = ("Tile to paint — (source, atlas) pairs of the layer's TileSet. "
			+ "For walls, the source picks the team (0 = blue).")
	box.add_child(_tile_option)

	_section(box, "History")
	var history_row := HBoxContainer.new()
	box.add_child(history_row)
	_add_button(history_row, "Undo", "undo_requested", "Ctrl+Z.")
	_add_button(history_row, "Redo", "redo_requested", "Ctrl+Y.")

	_log = RichTextLabel.new()
	_log.name = "Log"
	_log.bbcode_enabled = false
	_log.fit_content = true
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 120.0)
	box.add_child(_log)

	refresh_map_list()
	refresh_tile_picker()


func _section(box: VBoxContainer, title: String) -> void:
	# HSeparator, not Separator: Separator is abstract and cannot be constructed.
	box.add_child(HSeparator.new())
	var label := Label.new()
	label.text = title
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)


func _add_button(parent: Control, text: String, signal_name: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	if signal_name != "":
		button.pressed.connect(_emit_request.bind(signal_name))
	parent.add_child(button)
	return button


func _add_toggle(parent: Control, text: String, on_toggle: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.tooltip_text = "Click on the map: left places/paints, right erases (tiles). Escape exits."
	button.toggled.connect(on_toggle)
	parent.add_child(button)
	return button


# Signal names as strings keep the button wiring in one helper; the payload is
# the selected map name where the request needs one.
func _emit_request(signal_name: String) -> void:
	match signal_name:
		"open_map_requested":
			open_map_requested.emit(selected_map_name())
		"delete_map_requested":
			delete_map_requested.emit(selected_map_name())
		_:
			_emit_no_payload(signal_name)


func _emit_no_payload(signal_name: String) -> void:
	match signal_name:
		"new_map_requested":
			new_map_requested.emit()
		"save_map_requested":
			save_map_requested.emit()
		"validate_requested":
			validate_requested.emit()
		"play_requested":
			play_requested.emit()
		"exit_requested":
			exit_requested.emit()
		"new_lane_requested":
			new_lane_requested.emit()
		"undo_requested":
			undo_requested.emit()
		"redo_requested":
			redo_requested.emit()


# ---------------------------------------------------------------------------
# Host-facing state
# ---------------------------------------------------------------------------

func set_map_root(map: Node2D) -> void:
	map_root = map
	refresh_lanes()
	refresh_tile_picker()


func set_map_name(name: String) -> void:
	_name_entry.text = name


func map_name() -> String:
	return _name_entry.text


func log_line(line: String) -> void:
	_log.text += line + "\n"
	var lines := _log.text.split("\n")
	if lines.size() > LOG_LINES:
		_log.text = "\n".join(lines.slice(lines.size() - LOG_LINES, lines.size()))


# Re-sync mode toggles from the host after Escape / a mode switch / a map
# install: only one tool mode may be lit at a time.
func set_mode_active(mode_name: String, active: bool) -> void:
	var toggle := _toggle_for(mode_name)
	if toggle == null:
		return
	toggle.set_pressed_no_signal(active)
	if active:
		for other in ["lane", "building", "tile"]:
			if other == mode_name:
				continue
			var other_toggle := _toggle_for(other)
			if other_toggle != null:
				other_toggle.set_pressed_no_signal(false)


func _toggle_for(mode_name: String) -> Button:
	match mode_name:
		"lane":
			return _lane_toggle
		"building":
			return _building_toggle
		"tile":
			return _tile_toggle
	return null


# ---------------------------------------------------------------------------
# Pickers
# ---------------------------------------------------------------------------

func refresh_map_list() -> void:
	var previous := selected_map_name()
	_map_option.clear()
	var maps := MapStore.list_maps()
	for map_name in maps:
		_map_option.add_item(map_name)
	_map_option.disabled = maps.is_empty()
	if maps.is_empty():
		return
	var keep := 0
	for i in maps.size():
		if maps[i] == previous:
			keep = i
			break
	_map_option.select(keep)


func refresh_lanes() -> void:
	var previous := selected_lane_name()
	_lane_option.clear()
	var lanes_node: Node = null
	if map_root != null:
		lanes_node = map_root.get_node_or_null("lanes")
	if lanes_node != null:
		for child in lanes_node.get_children():
			if child is Line2D:
				_lane_option.add_item(String(child.name))
	_lane_option.disabled = _lane_option.item_count == 0
	if _lane_option.item_count == 0:
		return
	var keep := 0
	for i in _lane_option.item_count:
		if _lane_option.get_item_text(i) == previous:
			keep = i
			break
	_lane_option.select(keep)


func select_lane(lane_name: String) -> void:
	for i in _lane_option.item_count:
		if _lane_option.get_item_text(i) == lane_name:
			_lane_option.select(i)
			return


# Rebuild the tile and block pickers from the selected brush's layer. No map or
# no layer (a hand-made map missing tiles/…): clear and disable, so the tile
# tool refuses instead of painting into nothing. Called by the host on map
# install, mode change and undo/redo, and by the brush dropdown itself.
func refresh_tile_picker() -> void:
	# Preserve what the user picked when the list can offer it again: the host
	# refreshes the picker after undo/redo and after map install, and resetting
	# the tile mid-session would be a footgun.
	var keep_tile: Dictionary = selected_tile()
	var keep_block := -1
	if not _block_values.is_empty():
		keep_block = selected_block_cells()
	_picker_tiles = []
	_block_values = []
	_tile_option.clear()
	_block_option.clear()

	var layer: TileMapLayer = null
	if map_root != null:
		layer = TileBrush.layer_for_brush(map_root, selected_brush())
	if layer == null:
		_tile_option.disabled = true
		_tile_option.add_item("no tiles")
		_block_option.disabled = true
		return

	_block_option.disabled = false
	var map_tile := 64
	var exported = map_root.get("tile_size")
	if (exported is int or exported is float) and exported > 0:
		map_tile = int(exported)
	var options: Array[int] = TileBrush.block_options_for(TileBrush.cell_size_of(layer), map_tile)
	for i in options.size():
		var label := "%dx%d" % [options[i], options[i]]
		if i == options.size() - 1 and options[i] > 1:
			label += " (full tile)"
		_block_option.add_item(label)
		_block_values.append(options[i])
	var block_selection := _block_values.size() - 1  # default: the full tile
	if keep_block > 0:
		for i in _block_values.size():
			if _block_values[i] == keep_block:
				block_selection = i
				break
	_block_option.select(block_selection)

	_picker_tiles = TileBrush.list_layer_tiles(layer)
	if _picker_tiles.is_empty():
		_tile_option.disabled = true
		_tile_option.add_item("no tiles")
		return
	_tile_option.disabled = false
	for tile in _picker_tiles:
		_tile_option.add_item("s%d %s" % [tile.source_id, tile.atlas_coords])
		var icon: Texture2D = TileBrush.tile_icon(layer.tile_set, tile.source_id, tile.atlas_coords,
				TILE_ICON_PX)
		if icon != null:
			_tile_option.get_popup().set_item_icon(_tile_option.item_count - 1, icon)
	var tile_selection := 0
	if not keep_tile.is_empty():
		for i in _picker_tiles.size():
			if _picker_tiles[i] == keep_tile:
				tile_selection = i
				break
	_tile_option.select(tile_selection)  # selected defaults to -1 until told otherwise


# ---------------------------------------------------------------------------
# Getters the host reads while it works
# ---------------------------------------------------------------------------

func selected_map_name() -> String:
	if _map_option == null or _map_option.selected < 0 or _map_option.selected >= _map_option.item_count:
		return ""
	return _map_option.get_item_text(_map_option.selected)


func selected_lane_name() -> String:
	if _lane_option == null or _lane_option.selected < 0 or _lane_option.selected >= _lane_option.item_count:
		return ""
	return _lane_option.get_item_text(_lane_option.selected)


func selected_building_scene() -> String:
	if _building_option == null or _building_option.selected < 0 \
			or _building_option.selected >= _building_option.item_count:
		return ""
	var metadata = _building_option.get_item_metadata(_building_option.selected)
	return metadata if metadata is String else ""


func selected_team() -> String:
	if _team_option == null or _team_option.selected < 0 or _team_option.selected >= _team_option.item_count:
		return "neutral"
	return _team_option.get_item_text(_team_option.selected)


func selected_brush() -> String:
	if _brush_option == null or _brush_option.selected < 0 or _brush_option.selected >= _brush_option.item_count:
		return ""
	var metadata = _brush_option.get_item_metadata(_brush_option.selected)
	return metadata if metadata is String else ""


func selected_tile() -> Dictionary:
	if _tile_option == null or _tile_option.selected < 0 or _tile_option.selected >= _picker_tiles.size():
		return {}
	return _picker_tiles[_tile_option.selected]


func selected_block_cells() -> int:
	if _block_values.is_empty() or _block_option == null \
			or _block_option.selected < 0 or _block_option.selected >= _block_values.size():
		return 1
	return _block_values[_block_option.selected]


func selected_block_is_full_tile() -> bool:
	return _block_values.is_empty() \
			or (_block_option != null and _block_option.selected >= _block_values.size() - 1)
