@tool
extends EditorPlugin

# Map editor plugin: registers the dock that scaffolds new map scenes and
# validates them against the runtime contract. All logic lives in
# map_scaffold.gd / map_validator.gd (headless-testable).

const EditorDock := preload("res://addons/map_editor/editor_dock.gd")

var _dock: Control


func _enter_tree() -> void:
	_dock = EditorDock.new()
	_dock.name = "Map Editor"
	add_control_to_dock(DOCK_SLOT_LEFT_UR, _dock)


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.free()
		_dock = null
