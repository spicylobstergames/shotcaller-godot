extends Node

const GoalContract = preload("res://goap/goap_system/goal_contract.gd")
const AgentScript = preload("res://goap/goap_system/agent.gd")

func _ready() -> void:
	print("Loaded successfully")
	print("GoalContract type: " + str(typeof(GoalContract)))
	print("AgentScript type: " + str(typeof(AgentScript)))
	get_tree().quit(0)
