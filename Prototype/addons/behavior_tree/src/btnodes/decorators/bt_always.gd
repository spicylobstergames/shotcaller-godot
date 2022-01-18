class_name BTAlways, "res://addons/behavior_tree/icons/btalways.svg"
extends BTDecorator

# Executes the child and always either succeeds or fails.

export(int, "Fail", "Succeed") var always_what

onready var return_func: String = "fail" if always_what == 0 else "succeed"



func _tick(agent: Node, blackboard: Blackboard) -> bool:
	var result = bt_child.tick(agent, blackboard)
	
	if result is GDScriptFunctionState:
		result = yield(result, "completed")
	
	return call(return_func)
