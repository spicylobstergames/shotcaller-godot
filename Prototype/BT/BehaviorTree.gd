class_name BehaviorTree extends Node

export var agent: NodePath
var is_active = true

func _physics_process(delta):
	if not is_active:
		return
	assert(get_child_count() <= 1)
	
	if is_inside_tree():
		for child in get_children():
			child.tick(get_node(agent))
