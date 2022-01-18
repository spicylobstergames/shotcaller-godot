extends BTLeaf


# (Optional) Do something BEFORE tick result is returned.
func _pre_tick(agent: Node, blackboard: Blackboard) -> void:
	if not blackboard.get_data("pre_key"):
		blackboard.set_data("not_ready_yet", true)
		print("Not ready yet.")
		return


func _tick(agent: Node, blackboard: Blackboard) -> bool:
	assert(agent.has_method("my_method"))
	
	if (blackboard.get_data("not_ready_yet") 
	or not blackboard.has_data("my_key")):
		return fail()
	
	var result = true
	
	result = agent.call("my_method", blackboard.get_data("my_key"))
	
	# If action is executing, wait for completion and remain in running state
	if result is GDScriptFunctionState:
		# Store what the action returns when completed
		result = yield(result, "completed") 
	
	# If action returns anything but a bool consider it a success
	if not result is bool: 
		result = true
	
	# Once action is complete we return either success or failure.
	if result:
		return succeed()
	return fail()


# (Optional) Do something AFTER tick result is returned.
func _post_tick(agent: Node, blackboard: Blackboard, result: bool) -> void:
	blackboard.set_data("last_result", result)
	agent.call("another_method", result)
