@tool
extends Control

# =============================================================================
# Map editor dock (addons/map_editor/editor_dock.gd)
# =============================================================================
# Thin UI shell for the map editor plugin: scaffold/validate buttons, the
# lane-drawing mode toggle, the building-placement palette, the tile-painting
# brushes, and a log. ALL logic lives in map_scaffold.gd, map_validator.gd,
# lane_logic.gd, building_logic.gd, and tile_brush_logic.gd, which are
# editor-free and covered by the headless unit suite (tests/unit/
# test_map_editor.gd, test_lane_logic.gd, test_building_logic.gd,
# test_tile_brush_logic.gd, test_map_loader.gd, test_mirror_tiles.gd). This
# file is only ever loaded by the Godot editor (plugin.cfg), never at game
# runtime.
# =============================================================================

signal lane_mode_requested(active: bool)
signal new_lane_requested
signal building_mode_requested(active: bool)
signal tile_mode_requested(active: bool)

const Scaffold := preload("res://addons/map_editor/map_scaffold.gd")
const Validator := preload("res://addons/map_editor/map_validator.gd")
const BuildingLogic := preload("res://addons/map_editor/building_logic.gd")
const TileBrush := preload("res://addons/map_editor/tile_brush_logic.gd")

var _log: RichTextLabel
var _save_dialog: FileDialog
var _lane_mode_button: Button
var _building_mode_button: Button
var _scene_option: OptionButton
var _team_option: OptionButton
var _tile_mode_button: Button
var _brush_option: OptionButton
var _tile_option: OptionButton
var _block_option: OptionButton
var _block_values: Array[int] = []


func _ready() -> void:
	custom_minimum_size = Vector2(240, 160)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(box)

	var new_button := Button.new()
	new_button.text = "New map scene..."
	new_button.pressed.connect(_on_new_map_pressed)
	box.add_child(new_button)

	var validate_button := Button.new()
	validate_button.text = "Validate open map"
	validate_button.pressed.connect(_on_validate_pressed)
	box.add_child(validate_button)

	_lane_mode_button = Button.new()
	_lane_mode_button.text = "Draw lanes"
	_lane_mode_button.toggle_mode = true
	_lane_mode_button.toggled.connect(func(active: bool): lane_mode_requested.emit(active))
	_lane_mode_button.tooltip_text = "Left-click on the map to add snapped points to the selected lane. Escape exits."
	box.add_child(_lane_mode_button)

	var new_lane_button := Button.new()
	new_lane_button.text = "New lane"
	new_lane_button.pressed.connect(func(): new_lane_requested.emit())
	box.add_child(new_lane_button)

	# --- Building placement (Phase 3): palette + team, then click to place ---
	_building_mode_button = Button.new()
	_building_mode_button.text = "Place buildings"
	_building_mode_button.toggle_mode = true
	_building_mode_button.toggled.connect(func(active: bool): building_mode_requested.emit(active))
	_building_mode_button.tooltip_text = "Left-click on the map to place the selected building under the selected team. Escape exits."
	box.add_child(_building_mode_button)

	_scene_option = OptionButton.new()
	var scenes := BuildingLogic.list_building_scenes()
	if scenes.is_empty():
		_scene_option.disabled = true
		_scene_option.text = "no building scenes"
	else:
		for scene_path in scenes:
			_scene_option.add_item(BuildingLogic.building_base_name(scene_path))
		_scene_option.select(0)  # selected defaults to -1 until told otherwise
	_scene_option.tooltip_text = "Building scene to place (unit/buildings/*.tscn)"
	box.add_child(_scene_option)

	_team_option = OptionButton.new()
	for team in BuildingLogic.TEAM_DIRECTORIES:
		_team_option.add_item(team)
	_team_option.add_item("neutral")
	_team_option.select(0)
	_team_option.tooltip_text = "Team metadata for the placement: blue/red (placed under buildings/<team>) or neutral (hosted under an existing team directory; castle/barrack/tower cannot be neutral)"
	box.add_child(_team_option)

	# --- Tile painting (Phase 4): brush + tile, then click to paint ---
	_tile_mode_button = Button.new()
	_tile_mode_button.text = "Paint tiles"
	_tile_mode_button.toggle_mode = true
	_tile_mode_button.toggled.connect(func(active: bool): tile_mode_requested.emit(active))
	_tile_mode_button.tooltip_text = "Left-click paints the selected tile, right-click erases, drag works. Escape exits."
	box.add_child(_tile_mode_button)

	_brush_option = OptionButton.new()
	for brush in TileBrush.BRUSHES:
		_brush_option.add_item(brush.capitalize())
	_brush_option.select(0)
	_brush_option.item_selected.connect(func(_index: int): refresh_tile_picker())
	_brush_option.tooltip_text = "Which contract layer to paint (ground/walls/trees)"
	box.add_child(_brush_option)

	_block_option = OptionButton.new()
	_block_option.tooltip_text = "How many cells one click covers. The full-tile size (largest) keeps the whole 64px tile painted; smaller sizes paint detail."
	box.add_child(_block_option)

	_tile_option = OptionButton.new()
	_tile_option.tooltip_text = "Tile to paint — (source, atlas) pairs of the layer's TileSet. For walls, the source picks the team (0 = blue)."
	box.add_child(_tile_option)
	refresh_tile_picker()

	_log = RichTextLabel.new()
	_log.bbcode_enabled = false
	_log.fit_content = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_log)

	_save_dialog = FileDialog.new()
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = FileDialog.ACCESS_RESOURCES
	_save_dialog.filters = PackedStringArray(["*.tscn ; Godot scene"])
	_save_dialog.current_dir = "res://map/maps"
	_save_dialog.file_selected.connect(_on_save_path_chosen)
	# A Window (FileDialog) must live directly under the root viewport for
	# popup() to work; parenting it to this dock Control makes popup() fail
	# ("attempting to parent and popup a dialog that already has a parent").
	get_tree().root.add_child.call_deferred(_save_dialog)


func _exit_tree() -> void:
	if _save_dialog != null and is_instance_valid(_save_dialog):
		_save_dialog.queue_free()
		_save_dialog = null


# Called by the plugin when lane mode changes outside the button (Escape),
# so the toggle stays in sync without re-emitting the signal.
func set_lane_mode_active(active: bool) -> void:
	if _lane_mode_button != null:
		_lane_mode_button.set_pressed_no_signal(active)


# Same sync contract as set_lane_mode_active, for the placement toggle.
func set_building_mode_active(active: bool) -> void:
	if _building_mode_button != null:
		_building_mode_button.set_pressed_no_signal(active)


# Same sync contract as set_lane_mode_active, for the tile-painting toggle.
func set_tile_mode_active(active: bool) -> void:
	if _tile_mode_button != null:
		_tile_mode_button.set_pressed_no_signal(active)


# The selected brush key ("ground"/"walls"/"trees").
func selected_brush() -> String:
	if _brush_option == null or _brush_option.selected < 0:
		return ""
	var keys := TileBrush.BRUSHES.keys()
	if _brush_option.selected >= keys.size():
		return ""
	return keys[_brush_option.selected]


# The selected tile as {source_id, atlas_coords} ({} when nothing picked).
func selected_tile() -> Dictionary:
	if _tile_option == null or _tile_option.selected < 0:
		return {}
	var tiles := _picker_tiles()
	if _tile_option.selected >= tiles.size():
		return {}
	return tiles[_tile_option.selected]


# How many cells one click covers (the dock's block choice).
func selected_block_cells() -> int:
	if _block_values.is_empty() or _block_option == null \
			or _block_option.selected < 0 or _block_option.selected >= _block_values.size():
		return 1
	return _block_values[_block_option.selected]


# True when the block choice is the largest (full-tile) size, whose strokes
# snap to whole 64px map tiles; smaller sizes anchor at the clicked cell.
func selected_block_is_full_tile() -> bool:
	return _block_values.is_empty() \
			or (_block_option != null and _block_option.selected >= _block_values.size() - 1)


# Repopulate the tile picker (with preview icons) and the block-size choices
# from the selected brush's layer. Called by the plugin when tile mode turns
# on (the open scene may have changed) and by the brush dropdown itself.
func refresh_tile_picker() -> void:
	if _tile_option == null or _block_option == null:
		return
	var layer := _picker_layer()

	# Block sizes: powers of two up to the layer's full-tile cell count.
	_block_option.clear()
	_block_values = []
	var map_root := EditorInterface.get_edited_scene_root()
	var map_tile: int = 64
	if map_root != null:
		var exported = map_root.get("tile_size")
		if (exported is int or exported is float) and exported > 0:
			map_tile = int(exported)
	for n in TileBrush.block_options_for(TileBrush.cell_size_of(layer), map_tile):
		_block_values.append(n)
		if n == _block_values[-1] and n > 1:
			_block_option.add_item("%dx%d (full tile)" % [n, n])
		else:
			_block_option.add_item("%dx%d" % [n, n])
	_block_option.select(_block_values.size() - 1)  # default: the full tile

	# Tiles, with a preview icon per entry.
	_tile_option.clear()
	var tiles := TileBrush.list_layer_tiles(layer)
	if tiles.is_empty():
		_tile_option.disabled = true
		_tile_option.add_item("no tiles")
		return
	_tile_option.disabled = false
	for tile in tiles:
		var icon: Texture2D = TileBrush.tile_icon(layer.tile_set, tile.source_id, tile.atlas_coords)
		# OptionButton.add_item takes an int id here (not an icon); icons are
		# set on the underlying popup per item index.
		var index: int = _tile_option.item_count
		_tile_option.add_item("s%d %s" % [tile.source_id, tile.atlas_coords])
		if icon != null:
			_tile_option.get_popup().set_item_icon(index, icon)
	_tile_option.select(0)  # selected defaults to -1 until told otherwise


# The layer behind the brush/tile pickers, re-resolved on demand so the
# pickers survive scene switches without stale indices.
func _picker_layer() -> TileMapLayer:
	return TileBrush.layer_for_brush(EditorInterface.get_edited_scene_root(), selected_brush())


func _picker_tiles() -> Array[Dictionary]:
	return TileBrush.list_layer_tiles(_picker_layer())


# res:// path of the building scene the palette has selected ("" when empty).
func selected_building_scene() -> String:
	if _scene_option == null or _scene_option.selected < 0:
		return ""
	var scenes := BuildingLogic.list_building_scenes()
	if _scene_option.selected >= scenes.size():
		return ""
	return scenes[_scene_option.selected]


# Team metadata for placements: "blue"/"red" (placed under buildings/<team>)
# or "neutral" (the plugin hosts it under an existing team directory).
func selected_team() -> String:
	if _team_option == null or _team_option.selected < 0:
		return ""
	if _team_option.selected >= BuildingLogic.TEAM_DIRECTORIES.size():
		return "neutral"
	return BuildingLogic.TEAM_DIRECTORIES[_team_option.selected]


func _on_new_map_pressed() -> void:
	_save_dialog.popup_file_dialog()


func _on_save_path_chosen(path: String) -> void:
	if not path.ends_with(".tscn"):
		path += ".tscn"
	var err: int = Scaffold.new().write_map(path)
	if err != OK:
		log_line("FAILED: could not save %s (error %d)" % [path, err])
		return
	log_line("Created %s — paint tiles, move buildings, then Validate." % path)
	EditorInterface.open_scene_from_path(path)


func _on_validate_pressed() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		log_line("No scene open.")
		return
	var problems: Array = Validator.new().validate(root)
	if problems.is_empty():
		log_line("OK: '%s' satisfies the map contract." % root.name)
		return
	var errors := problems.filter(func(p): return p.level == "error")
	log_line("'%s': %d error(s), %d warning(s)" % [root.name, errors.size(), problems.size() - errors.size()])
	for problem in problems:
		log_line("[%s] %s" % [problem.level.to_upper(), problem.message])


func log_line(line: String) -> void:
	_log.text += line + "\n"
