extends Button



func _on_Play_pressed() -> void:
	if not Game.is_playing:
		Game.emit_signal("playing")
		disabled = true
