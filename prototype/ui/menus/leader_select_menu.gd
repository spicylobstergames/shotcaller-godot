extends Control

signal leader_selected(leader)


onready var leader_select_button = preload("res://ui/leader_selection/leader_select_button.tscn")

onready var leaders_container = $"%leaders_container"

func _ready():
	for child in leaders_container.get_children():
		leaders_container.remove_child(child)
		child.queue_free()
	for leader in WorldState.leaders:
		var button = leader_select_button.instance()
		#button.prepare(leader)
		leaders_container.add_child(button)
		button.connect("leader_selected", self, "_leader_selected")
	var random_button = leader_select_button.instance()
	#random_button.prepare("random")
	leaders_container.add_child(random_button)
	random_button.connect("leader_selected", self, "_leader_selected")


var selected_leader = ""
func _leader_selected(leader):
	selected_leader = leader[0]
	$Description.prepare(leader[0])
	$Description.show()
	



func clear_color_remap():
	for child in leaders_container.get_children():
		child.clear_color_remap()


func _on_description_confirm():
	$Description.hide()
	emit_signal("leader_selected", selected_leader)
