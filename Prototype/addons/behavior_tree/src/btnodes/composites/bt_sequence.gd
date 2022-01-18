class_name BTSequence, "res://addons/behavior_tree/icons/btsequence.svg" 
extends BTComposite

# Ticks its children as long as ALL of them are successful.
# Successful if ALL the children are successful.
# Fails if ANY of the children fails.

func _tick(agent: Node, blackboard: Blackboard) -> bool:
	var result
	
	for c in children:
		bt_child = c
		
		result = bt_child.tick(agent, blackboard)
		
		if result is GDScriptFunctionState:
			result = yield(result, "completed")
		
		if bt_child.failed():
			return fail()
	
	return succeed()
