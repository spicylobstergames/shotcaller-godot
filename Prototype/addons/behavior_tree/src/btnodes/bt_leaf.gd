class_name BTLeaf, "res://addons/behavior_tree/icons/btleaf.svg" 
extends BTNode

# Leaf nodes are used to implement your own behavior logic.
# That can be for example calling functions on the agent, or checking conditions in the blackboard. 
# Good practice is to not make leaf nodes do too much stuff, and to not have flow logic in them.
# Instead, just use them to do a single action or condition check, and use a composite node
# (BTSequence, BTSelector or BTParallel) to define the flow between multiple leaf nodes.


func _ready():
	assert(get_child_count() == 0, "A BTLeaf cannot have children.")

