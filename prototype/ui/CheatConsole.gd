extends TextEdit

func _gui_input(event):
	if event is InputEventKey:
		if event.scancode == KEY_ENTER and has_focus():
			var code = text
			text = ""
			EventMachine.register_event(Events.CHEAT_CODE, [code])
			
