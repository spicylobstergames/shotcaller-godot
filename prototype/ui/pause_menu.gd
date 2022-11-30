extends CenterContainer

onready var game = get_tree().get_current_scene()
onready var continue_button : Button = $"%continue_button"
onready var exit_to_menu_button : Button = $"%exit_to_menu_button"
onready var exit_button : Button = $"%exit_button"

func _ready():
	continue_button.connect("pressed", game, "resume")
	exit_to_menu_button.connect("pressed", game, "reload")
	exit_button.connect("pressed", game, "exit")
