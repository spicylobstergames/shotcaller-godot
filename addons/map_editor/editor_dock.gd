@tool
extends Control

# =============================================================================
# Map editor dock (addons/map_editor/editor_dock.gd)
# =============================================================================
# Thin UI shell for the map editor plugin: scaffold/validate buttons, the
# lane-drawing mode toggle, the building-placement palette, and a log. ALL
# logic lives in map_scaffold.gd, map_validator.gd, lane_logic.gd, and
# building_logic.gd, which are editor-free and covered by the headless unit
# suite (tests/unit/test_map_editor.gd, test_lane_logic.gd,
# test_building_logic.gd, test_map_loader.gd). This file is only ever loaded
# by the Godot editor (plugin.cfg), never at game runtime.
# =============================================================================

signal lane_mode_requested(active: bool)
signal new_lane_requested
signal building_mode_requested(active: bool)

const Scaffold := preload("res://addons/map_editor/map_scaffold.gd")
const Validator := preload("res://addons/map_editor/map_validator.gd")
const BuildingLogic := preload("res://addons/map_editor/building_logic.gd")

var _log: RichTextLabel
var _save_dialog: FileDialog
var _lane_mode_button: Button
var _building_mode_button: Button
var _scene_option: OptionButton
var _team_option: OptionButton


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
	_scene_option.tooltip_text = "Building scene to place (unit/buildings/*.tscn)"
	box.add_child(_scene_option)

	_team_option = OptionButton.new()
	for team in BuildingLogic.TEAM_DIRECTORIES:
		_team_option.add_item(team)
	_team_option.tooltip_text = "Team directory the building is placed under (neutrals still get team = 'neutral')"
	box.add_child(_team_option)

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


# res:// path of the building scene the palette has selected ("" when empty).
func selected_building_scene() -> String:
	if _scene_option == null or _scene_option.selected < 0:
		return ""
	var scenes := BuildingLogic.list_building_scenes()
	if _scene_option.selected >= scenes.size():
		return ""
	return scenes[_scene_option.selected]


# Team directory placements attach to ("blue" / "red").
func selected_team() -> String:
	if _team_option == null or _team_option.selected < 0:
		return ""
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
