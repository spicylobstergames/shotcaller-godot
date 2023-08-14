@tool
extends EditorPlugin

# this plugin will register all the custom classes by default inside it's folder when enabled.


# To register a custom class that can only be added via the scene tree's add dialog.
func _enter_tree():
	#add_custom_type("TestControl", "Control", "./script.gd", preload("./script_icon.png"))
	pass


# You also should remove the class when the plugin is disabled.
func _exit_tree():
	#remove_custom_type("TestControl") 
	pass
