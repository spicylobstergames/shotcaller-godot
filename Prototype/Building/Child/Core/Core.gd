extends "res://Building/Building.gd"


const FlagClass := preload("res://Building/Node/Flag.gd")


func _setup_team() -> void:
	for t in $TextureContainer.get_children():
		if t is FlagClass:
			t.set_team(team)
	._setup_team()

func final_actions():
	Game.game_over(team)
	
