extends CanvasLayer

@onready var circle_transition_scene : PackedScene = preload("res://ui/transitions/circle_transition.tscn")
@onready var square_transition_scene : PackedScene = preload("res://ui/transitions/square_transition.tscn")

@onready var game = get_tree().get_current_scene()

signal transition_completed

func start():
	#var transition = random()
	var transition = circle_transition_scene.instantiate()
	add_child(transition)
	transition.transition_completed.connect(on_transition_end.bind(transition))


func on_transition_end(transition = null):
	# clears transition
	if transition: transition.queue_free()
	# prepare to screenshot the map
	emit_signal("transition_completed")


func random():
	return [square_transition_scene, circle_transition_scene][randi() % 2].instantiate()
