extends CanvasLayer

@onready var circle_transition_scene : PackedScene = preload("res://ui/transitions/circle_transition.tscn")
@onready var square_transition_scene : PackedScene = preload("res://ui/transitions/square_transition.tscn")
@onready var campaign_intro_scene : PackedScene = preload("res://ui/transitions/campaign_intro.tscn")

@onready var game = get_tree().get_current_scene()

signal transition_completed

var intro_ended = false
var intro_text:Control

func start():
	#var transition = random()
	if game.map_manager.current_map == "campaign_map" and intro_ended:
		intro()
	else:
		transition()


func transition():
	var new_transition = circle_transition_scene.instantiate()
	add_child(new_transition)
	new_transition.transition_completed.connect(on_transition_end.bind(new_transition))


func intro():
	var intro_scene = campaign_intro_scene.instantiate()
	add_child(intro_scene)
	intro_text = intro_scene
	intro_scene.intro_completed.connect(intro_end)

func intro_end():
	intro_ended = true
	transition()
	

func on_transition_end(end_transition = null):
	# clears transition
	if end_transition: end_transition.queue_free()
	
	if game.map_manager.current_map == "campaign_map" and !intro_ended:
		intro()
	else:
		if intro_text: intro_text.queue_free()
		emit_signal("transition_completed")


func random():
	return [square_transition_scene, circle_transition_scene][randi() % 2].instantiate()
