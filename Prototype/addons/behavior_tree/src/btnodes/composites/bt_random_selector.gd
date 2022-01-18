class_name BTRandomSelector, "res://addons/behavior_tree/icons/btrndselector.svg"
extends BTSelector

# Executes a random child and is successful at the first successful tick.
# Attempts a number of ticks equal to the number of children. If no successful
# child was found, it fails.


func _pre_tick(agent: Node, blackboard: Blackboard) -> void:
	randomize()
	children.shuffle()
