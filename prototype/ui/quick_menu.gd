extends CanvasLayer

onready var game = get_tree().get_current_scene()

onready var quick_start_button = $"%quick_start_button"
onready var exit_button = $"%exit_button"
onready var new_game_button = $"%new_game_button"

onready var circle_transition_scene : PackedScene = preload("res://ui/circle_transition.tscn")
onready var square_transition_scene : PackedScene = preload("res://ui/square_transition.tscn")

onready var menu_background = $waterfall_background
onready var team_selection_menu = $team_selection_menu

func _ready():
	randomize()
	quick_start_button.connect("pressed", self, "quick_start")
	exit_button.connect("pressed", self, "quit")
	new_game_button.connect("pressed", self, "show_new_game_menu")

func quick_start():
	game.maps.load_map(game.maps.current_map)

	game.player_choose_leaders = ["arthur", "bokuden", "nagato"]
	game.enemy_choose_leaders = ["lorne", "robin", "rollo"]
	
	var transition = [square_transition_scene, circle_transition_scene][randi() % 2].instance()
	transition.pause_mode = Node.PAUSE_MODE_PROCESS
	game.get_node("transitions").add_child(transition)
	transition.start_transition()
	yield(transition, "transition_completed")
	transition.queue_free()
	# Transition backward not possible due to how minimap is generated
	# transition.start_transition(true)
	visible = false
	game.resume()

func quit():
	game.exit()

func show_new_game_menu():
	team_selection_menu.visible = true
