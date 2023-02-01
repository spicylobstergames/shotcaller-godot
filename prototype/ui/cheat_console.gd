extends TextEdit

func _gui_input(event):
	if event is InputEventKey:
		if event.scancode == KEY_ENTER and has_focus():
			var code = text
			WorldState.apply_cheat_code(code)
			text = ""
			release_focus()
			
