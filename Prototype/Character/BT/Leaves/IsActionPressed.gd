extends BTLeaf

export var key: String

var is_button_pressed = false


func _unhandled_input(event):
	if event is InputEventKey:
		self.is_button_pressed = event.is_action_pressed(key)


func do_stuff(agent: Node) -> int:
	if self.is_button_pressed:
		return NodeStatus.Success
	else:
		return NodeStatus.Failure
