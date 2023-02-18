extends Container

onready var game = get_tree().get_current_scene()

onready var quick_start_button = $"%quick_start_button"
onready var exit_button = $"%exit_button"
onready var new_game_button = $"%new_game_button"


func _ready():
	randomize()
	quick_start_button.connect("pressed", self, "quick_start")
	exit_button.connect("pressed", self, "quit")
	new_game_button.connect("pressed", self, "show_new_game_menu")


func quick_start():
	game.player_choose_leaders = ["arthur", "bokuden", "nagato"]
	game.enemy_choose_leaders = ["lorne", "robin", "rollo"]
	game.start()


func quit():
	game.exit()

func show_new_game_menu():
	game.ui.show_team_selection()
