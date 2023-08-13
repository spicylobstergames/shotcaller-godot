extends Container

@onready var game = get_tree().get_current_scene()

@onready var quick_start_button = $"%quick_start_button"
@onready var exit_button = $"%exit_button"
@onready var new_game_button = $"%new_game_button"
@onready var campaign_button = $"%campaign_button"

var once = true


func _input(event):
	if once and event is InputEventKey:
		quick_start_button.grab_focus()
		once = false


func quick_start():
	hide()
	game.map_manager.current_map = "one_lane_map"
	WorldState.set_state("player_team", "blue")
	WorldState.set_state("enemy_team", "red")
	WorldState.set_state("player_leaders_names", ["arthur", "bokuden", "nagato"])
	WorldState.set_state("enemy_leaders_names", ["lorne", "robin", "rollo"])
	WorldState.set_state("game_mode", "match")
	game.start()


func show_new_game_menu():
	game.ui.main_menu.hide()
	game.ui.new_game_menu.show()


func campaign_start():
	hide()
	game.map_manager.current_map = "rect_test_map"
	WorldState.set_state("player_leaders_names", ["joan"])
	WorldState.set_state("player_team", "blue")
	WorldState.set_state("enemy_team", "red")
	WorldState.set_state("game_mode", "campaign")
	game.start()


func on_exit():
	game.exit()



func _on_options_button_pressed():
	game.transitions.start()
	game.transitions.transition_completed.connect(game.reload)
