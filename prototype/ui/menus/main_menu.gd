extends Container

onready var game = get_tree().get_current_scene()

onready var quick_start_button = $"%quick_start_button"
onready var exit_button = $"%exit_button"
onready var new_game_button = $"%new_game_button"
onready var campaign_button = $"%campaign_button"


func quick_start():
	hide()
	game.maps.current_map = "one_lane_map"
	game.player_choose_leaders = ["arthur", "bokuden", "nagato"]
	game.enemy_choose_leaders = ["lorne", "robin", "rollo"]
	game.start()


func show_new_game_menu():
	game.ui.main_menu.hide()
	game.ui.new_game_menu.show()
	

func campaign_start():
	game.player_choose_leaders = ["joan"]
	game.maps.current_map = "rect_test_map"
	hide()
	game.start()


func quit():
	game.exit()
