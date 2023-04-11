extends VBoxContainer

#@onready var tween = $Tween
@onready var tween = get_tree().create_tween()
@onready var texture_rect = $TextureRect
signal transition_completed


func _ready():
	if get_tree().current_scene == self:
		start_transition()


func start_transition(backwards = false):
	show()
	var start = 0.0 if not backwards else 2.0
	var end = 2.0 if not backwards else 0.0
	var material = texture_rect.get_material()
	material.set("shader_param/progress", start)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(material, "shader_param/progress", start, end)
	tween.tween_callback(self.transition_done)


func transition_done():
	emit_signal("transition_completed")
