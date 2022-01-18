extends Button


export(Units.TeamID) var team = Units.TeamID.Blue


func _on_Button_pressed() -> void:
	Player.selected_team = team
