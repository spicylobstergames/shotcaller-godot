extends Node
const Contract = preload("res://goap/goap_system/action_contract.gd")
const Retreat = preload("res://goap/game_logic/actions/retreat_action.gd")
const Agent = preload("res://goap/goap_system/agent.gd")
func _ready():
	print("Compiled OK")
	get_tree().quit(0)
