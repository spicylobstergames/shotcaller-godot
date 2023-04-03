extends HBoxContainer


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var status_effect_dict_hash = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	is_empty()


func is_empty():
	for child in get_children():
		remove_child(child)
		child.queue_free()

func prepare(status_effects):
	var new_hash = status_effects.hash()
	if new_hash != status_effect_dict_hash:
		status_effect_dict_hash = new_hash
		is_empty()
		for status_effect in status_effects.values():
			add_icon(status_effect["icon"], status_effect["hint"])

func add_icon(texture, hint):
	var modifer_node : TextureRect = TextureRect.new()
	modifer_node.tooltip_text = hint
	modifer_node.texture = texture
	add_child(modifer_node)
