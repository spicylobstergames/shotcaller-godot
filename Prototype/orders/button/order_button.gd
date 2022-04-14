extends Button
var game:Node

var orders

func _ready():
	game = get_tree().get_current_scene()
# warning-ignore:return_value_discarded
	connect("pressed", self, "_button_down")
# warning-ignore:return_value_discarded
	get_node("touch_button").connect("pressed", self, "_button_down")



func _button_down():
	match self.orders.type:
		"tactic":
			clear_siblings(self)
			
			if game.selected_unit.type != "leader":
				game.unit.orders.lane_tactic(self.orders.tactic)
		
		
		"priority":
			if not is_first_child(self):
				move_to_front(self)
				if game.selected_unit.type != "leader":
					game.unit.orders.lane_priority(self.orders.priority)
			




func clear_siblings(button):
	for child in button.get_parent().get_children():
		if child != button: child.pressed = false


func is_first_child(button):
	return button.get_parent().get_children()[0] == button

func move_to_front(button):
	button.get_parent().move_child(button, 0)
