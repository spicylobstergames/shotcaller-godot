@tool
extends Control

# =============================================================================
# Map editor dock (addons/map_editor/editor_dock.gd)
# =============================================================================
# Thin UI shell for the map editor plugin: two buttons and a log. ALL logic
# lives in map_scaffold.gd and map_validator.gd, which are editor-free and
# covered by the headless unit suite (tests/unit/test_map_editor.gd).
# This file is only ever loaded by the Godot editor (plugin.cfg), never at
# game runtime.
# =============================================================================

const Scaffold := preload("res://addons/map_editor/map_scaffold.gd")
const Validator := preload("res://addons/map_editor/map_validator.gd")

var _log: RichTextLabel
var _save_dialog: FileDialog


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
	add_child(_save_dialog)


func _on_new_map_pressed() -> void:
	_save_dialog.popup_file_dialog()


func _on_save_path_chosen(path: String) -> void:
	if not path.ends_with(".tscn"):
		path += ".tscn"
	var err: int = Scaffold.new().write_map(path)
	if err != OK:
		_log_line("FAILED: could not save %s (error %d)" % [path, err])
		return
	_log_line("Created %s — paint tiles, move buildings, then Validate." % path)
	EditorInterface.open_scene_from_path(path)


func _on_validate_pressed() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		_log_line("No scene open.")
		return
	var problems: Array = Validator.new().validate(root)
	if problems.is_empty():
		_log_line("OK: '%s' satisfies the map contract." % root.name)
		return
	var errors := problems.filter(func(p): return p.level == "error")
	_log_line("'%s': %d error(s), %d warning(s)" % [root.name, errors.size(), problems.size() - errors.size()])
	for problem in problems:
		_log_line("[%s] %s" % [problem.level.to_upper(), problem.message])


func _log_line(line: String) -> void:
	_log.text += line + "\n"
