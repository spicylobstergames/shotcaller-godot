extends "res://Building/Building.gd"

var firework_scene = preload("res://Firework.tscn")
const FlagClass := preload("res://Building/Node/Flag.gd")

var winner = false

func _setup_team() -> void:
	for t in $TextureContainer.get_children():
		if t is FlagClass:
			t.set_team(team)
	._setup_team()

func final_actions():
	Game.game_over(team)
	
func _physics_process(delta):
	if winner and randf() > 0.95:
		var firework = firework_scene.instance()
		firework.team = Player.selected_team
		add_child(firework)
	._physics_process(delta)
