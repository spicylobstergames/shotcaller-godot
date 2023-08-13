extends Button

class_name Menu_button

var focus_color = get("custom_colors/font_color_focus")


func _on_Menu_button_mouse_entered():
	#set("custom_colors/font_color_hover", focus_color)
	grab_focus()
	pass


func _on_Menu_button_focus_exited():
	#set("custom_colors/font_color_hover", null)
	pass


func _on_Menu_button_focus_entered():
	#set("custom_colors/font_color_hover", focus_color)
	pass
