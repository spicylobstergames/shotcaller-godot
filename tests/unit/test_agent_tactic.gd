extends Node

const RecoverGoal = preload("res://goap/game_logic/goals/recover.gd")


class TestAgent:
	extends Node

	var states := {"tactic": "default"}
	var unit  # set by the test after construction

	func get_state(state_name: String, default = null):
		return states.get(state_name, default)

	func set_state(state_name: String, value) -> void:
		states[state_name] = value

	func get_unit():
		return unit


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

	# --- Recover maintains its planner facts around planning ---
	# ready_to_fight is set AFTER get_plan(), so a true value at planning time
	# used to yield an empty Recover plan; and is_retreating is only cleared by
	# RetreatAction.exit, which never runs for an empty plan — leaving WalkLane
	# and EnemyDefeated permanently blocked (units stand still).
	var low = TestAgent.new()
	low.unit = unit
	unit.agent.set_state("tactic", "default")
	unit.current_hp = 1
	harness.check(recover.is_valid(low), "A low-HP unit is eligible to recover.")
	harness.check_equal(
		low.get_state("ready_to_fight"),
		false,
		"Recover clears ready_to_fight BEFORE planning (or the plan comes back empty)."
	)

	unit.current_hp = unit.hp
	low.set_state("is_retreating", true)
	harness.check(not recover.is_valid(low), "A healthy unit is not eligible to recover.")
	harness.check_equal(
		low.get_state("is_retreating"),
		false,
		"Recover clears stale is_retreating once healthy (or WalkLane stays blocked)."
	)
	harness.check_equal(
		low.get_state("ready_to_fight"), true, "Recover restores ready_to_fight once healthy."
	)
	low.free()

	recover.free()
	unit.agent.free()
	unit.free()
