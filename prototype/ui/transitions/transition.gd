extends Control

@onready var texture_rect = $TextureRect
signal transition_completed


func _ready():
	show()
	var start := 0.0
	var end := 2.0
	var duration := 2.0
	var texture_material = texture_rect.get_material()
	texture_material.set("shader_parameter/progress", start)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(texture_material, "shader_parameter/progress", end, duration)
	tween.tween_callback(self.transition_done)


func transition_done():
	emit_signal("transition_completed")
