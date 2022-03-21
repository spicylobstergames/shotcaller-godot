extends Button

func _on_Play_pressed() -> void:
	Game.emit_signal("playing")
	get_node("../BlueButton").disabled = true
	get_node("../RedButton").disabled = true
	#disabled = true
