extends CanvasLayer

onready var circle_transition_scene : PackedScene = preload("res://ui/transitions/circle_transition.tscn")
onready var square_transition_scene : PackedScene = preload("res://ui/transitions/square_transition.tscn")

onready var game = get_tree().get_current_scene()


func start():
	var transition = random()
	add_child(transition)
	transition.start_transition()
	transition.connect("transition_completed", self, "on_transition_end", [transition])


func on_transition_end(transition = null):
	# clears transition
	if transition: transition.queue_free()
	game.background.visible = false
	game.ui.main_menu.visible = false
	# prepare to screenshot the map
	game.ui.minimap.update_map_texture = true
	game.resume()


func random():
	return [square_transition_scene, circle_transition_scene][randi() % 2].instance()
