extends "res://Building/Node/BuildingDecor.gd"

export(Texture) var blue_team_texture: Texture
export(Texture) var red_team_texture: Texture


func setup_team() -> void:
	match team:
		Units.TeamID.Blue:
			$Sprite.texture = blue_team_texture
			scale.x = 1
		Units.TeamID.Red:
			$Sprite.texture = red_team_texture
			scale.x = -1
	.setup_team()
