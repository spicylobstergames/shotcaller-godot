class_name BTRepeatUntil, "res://addons/behavior_tree/icons/btrepeatuntil.svg"
extends BTDecorator

# Repeats until specified state is returned, then sets state to child state

export(int, "Failure", "Success") var until_what
export(float) var frequency

onready var expected_result = bool(until_what)



func _tick(agent: Node, blackboard: Blackboard) -> bool:
	var result = not expected_result
	
	while result != expected_result:
		result = bt_child.tick(agent, blackboard)
		
		if result is GDScriptFunctionState:
			result = yield(result, "completed")
		
		yield(get_tree().create_timer(frequency, false), "timeout")
	
	return set_state(bt_child.state)
