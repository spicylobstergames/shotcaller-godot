extends Control

# campaign_transition intro text

@onready var game = get_tree().get_current_scene()

signal intro_completed

func _ready():
	show()
	game.ui.hide_all()
	await get_tree().create_timer(5.0).timeout
	intro_done()


func _input(event):
	if visible and event.is_pressed():
		intro_done()

func intro_done():
		intro_completed.emit()
