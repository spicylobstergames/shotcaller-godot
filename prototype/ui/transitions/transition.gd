extends VBoxContainer

onready var tween = $Tween
onready var texture_rect = $TextureRect
signal transition_completed


func _ready():
	var err = tween.connect("tween_all_completed", self, "transition_done")
	assert(err == OK)
	# For testing on its own
	if get_tree().current_scene == self:
		start_transition()

func start_transition(backwards = false):
	visible = true
	var start = 0.0 if not backwards else 2.0
	var end = 2.0 if not backwards else 0.0
	tween.interpolate_property(texture_rect.get_material(), 
					 "shader_param/progress", 
					 start, end, 2, 
					 Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.start()

func transition_done():
	emit_signal("transition_completed")
