extends Button

var orders

func _ready():
# warning-ignore:return_value_discarded
	connect("pressed", self, "_button_down")
# warning-ignore:return_value_discarded
	get_node("touch_button").connect("pressed", self, "_button_down")



func _button_down():
	
	print(self.orders.type, ' ',self.orders.order.type)
	match self.orders.type:
		"tactic":
			print(self.orders.tactic)
		"priority":
			print(self.orders.priority)
			
	pass
