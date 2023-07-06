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
	game.maps.current_map = "one_lane_map"
	game.player_choose_leaders = ["arthur", "bokuden", "nagato"]
	game.enemy_choose_leaders = ["lorne", "robin", "rollo"]
	WorldState.set_state("player_team", "blue")
	game.mode = "match"
	game.start()


func show_new_game_menu():
	game.ui.main_menu.hide()
	game.ui.new_game_menu.show()
	game.mode = "match"
	

func campaign_start():
	hide()
	game.maps.current_map = "rect_test_map"
	game.player_choose_leaders = ["joan"]
	game.mode = "campaign"
	game.start()


func on_exit():
	game.exit()

