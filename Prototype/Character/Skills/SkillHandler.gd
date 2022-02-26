class_name SkillHandler
extends Node


func trigger_skill(index: int) -> bool:
	return get_skill(index).cast()

func get_skill(index: int):
	if index < get_child_count():
		return get_child(index)
	else:
		push_error("Skill index is out of bounds")
