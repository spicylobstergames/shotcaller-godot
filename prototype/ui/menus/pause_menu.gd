extends Container

@onready var game = get_tree().get_current_scene()
@onready var continue_button : Button = $"%continue_button"
@onready var exit_to_menu_button : Button = $"%exit_to_menu_button"
@onready var exit_button : Button = $"%exit_button"

func _ready():
	continue_button.pressed.connect(game.resume)
	exit_to_menu_button.pressed.connect(game.reload)
	exit_button.pressed.connect(game.exit)
