extends Node

const RecoverGoal = preload("res://goap/game_logic/goals/recover.gd")


class TestAgent:
	extends Node

	var states := {"tactic": "default"}

	func get_state(state_name: String, default = null):
		return states.get(state_name, default)

	func set_state(state_name: String, value) -> void:
		states[state_name] = value


class TestUnit:
	extends Node

	var agent := TestAgent.new()
	var speed := 10.0
	var hunting_speed := 20.0
	var hp := 100
	var current_hp := 40
	var level := 1
	var current_modifiers := {"hp": [], "speed": []}


func run(harness) -> void:
	var unit = TestUnit.new()
	var recover = RecoverGoal.new()

	unit.agent.set_state("tactic", "attack")
	harness.check_equal(
		Modifiers.get_value(unit, "speed"), 15.0, "Attack tactic adds agent-state movement speed."
	)

	unit.agent.set_state("tactic", "defend")
	harness.check_equal(
		Modifiers.get_value(unit, "speed"), 5.0, "Defend tactic reduces agent-state movement speed."
	)
	harness.check(recover.should_retreat(unit), "Defend tactic retreats when health is below half.")

	unit.agent.set_state("tactic", "default")
	harness.check(
		not recover.should_retreat(unit), "Default tactic does not retreat above one-third health."
	)

	unit.agent.set_state("tactic", "retreat")
	harness.check(recover.should_retreat(unit), "Retreat tactic is read from agent state.")

	recover.free()
	unit.agent.free()
	unit.free()
