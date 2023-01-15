extends Container

onready var game = get_tree().get_current_scene()
onready var continue_button : Button = $"%continue_button"
onready var exit_to_menu_button : Button = $"%exit_to_menu_button"
onready var exit_button : Button = $"%exit_button"

func _ready():
# warning-ignore:return_value_discarded
	continue_button.connect("pressed", game, "resume")
# warning-ignore:return_value_discarded
	exit_to_menu_button.connect("pressed", game, "reload")
# warning-ignore:return_value_discarded
	exit_button.connect("pressed", game, "exit")
