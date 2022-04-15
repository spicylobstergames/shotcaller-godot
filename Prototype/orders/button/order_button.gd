extends Button
var game:Node


onready var name_label = get_node("name")

var orders
var saved_icon

func _ready():
	game = get_tree().get_current_scene()
# warning-ignore:return_value_discarded
	connect("pressed", self, "_button_down")
# warning-ignore:return_value_discarded
	get_node("touch_button").connect("pressed", self, "_button_down")


func setup_order_button():
	var name = self.orders[self.orders.type]
	name_label.text = name
	var icon_ref = self.icon
	if not icon_ref: icon_ref = self.saved_icon
	var icon = icon_ref.duplicate()
	var sprite
	match name:
		"building": sprite = 0
		"pawn": sprite = 1
		"leader": sprite = 2
		
		"retreat": sprite = 3
		"defend": sprite = 3
		"default": sprite = 3
		"attack": sprite = 3
		
	icon.region.position.x = sprite * 64
	icon.region.position.y = -2
	self.icon = icon


func _button_down():
	match self.orders.type:
		"tactic":
			clear_siblings(self)
			
			if game.selected_unit.type == "leader":
				game.unit.orders.set_leader_tactic(self.orders.tactic)
			else: game.unit.orders.set_lane_tactic(self.orders.tactic)
		
		"priority":
			if not is_first_child(self):
				move_to_front(self)
				if game.selected_unit.type == "leader":
					game.unit.orders.set_leader_priority(self.orders.tactic)
				else: game.unit.orders.set_lane_priority(self.orders.priority)



func clear_siblings(button):
	for child in button.get_parent().get_children():
		if child != button: child.pressed = false


func is_first_child(button):
	return button.get_parent().get_children()[0] == button


func move_to_front(button):
	button.get_parent().move_child(button, 0)
