extends Node

const ChooseTarget = preload("res://goap/game_logic/actions/choose_target.gd")


class TestAgent:
	extends Node
	var state := {}

	func get_state(state_name, default = null):
		return state.get(state_name, default)

	func set_state(state_name, value):
		state[state_name] = value


class TestLane:
	extends Node

	func _init() -> void:
		name = "top"


class TestLeader:
	extends Node
	var team := "blue"
	var type := "leader"
	var agent := TestAgent.new()

	func _init() -> void:
		name = "leader"


func run(harness) -> void:
	var old_player_team = WorldState.get_state("player_team")
	WorldState.set_state("player_team", "blue")

	var action = ChooseTarget.new()
	var lane = TestLane.new()
	action.build_lane_priorities([lane])
	action.set_lane_priority("top", "blue", "building")
	harness.check_equal(
		action.player_lane_priorities.top,
		["building", "pawn", "leader"],
		"Lane target priority is stored by ChooseTarget."
	)

	var leader = TestLeader.new()
	action.build_leader_priorities([leader], [])
	action.set_leader_priority(leader, "building")
	leader.agent.set_state("lane", "top")
	action.set_unit_priority(leader)
	harness.check_equal(
		leader.agent.get_state("target_priority"),
		["building", "pawn", "leader"],
		"Leader target priority is stored in agent state."
	)

	WorldState.set_state("player_team", old_player_team)
	leader.agent.free()
	action.free()
	leader.free()
	lane.free()
