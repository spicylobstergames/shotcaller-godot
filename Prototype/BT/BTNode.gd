class_name BTNode extends Node

enum NodeStatus{
	Success,
	Failure,
	In_Progress,
	Error
}

func tick(agent: Node) -> int:
	push_error("tick must be implemented")
	return NodeStatus.Error

func do_stuff(agent: Node) -> int:
	return NodeStatus.Success
