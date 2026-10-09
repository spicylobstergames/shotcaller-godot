extends Node

const Agent = preload("res://goap/goap_system/agent.gd")


class TestUnit:
	extends Node

	var target
	var agent
	var moves := true
	var attack_count := 3
	var last_target
	var current_modifiers := {"attack_speed": [{"name": "agile", "value": 0.5}]}


func run(harness) -> void:
	var agent = Agent.new()
	var unit = TestUnit.new()
	var target = TestUnit.new()
	unit.agent = agent
	agent._unit = unit

	agent.set_state("target", target)
	harness.check_equal(unit.target, target, "Setting target agent state updates the unit target.")
	harness.check(
		agent.get_state("has_attack_target"), "Setting a target marks attack target state."
	)
	harness.check(agent.get_state("hunting"), "Moving units hunt an assigned target.")
	harness.check_equal(unit.attack_count, 0, "Changing target resets the attack count.")
	harness.check_equal(
		unit.current_modifiers.attack_speed,
		[],
		"Changing target removes the agile attack-speed modifier."
	)

	agent.set_state("target", null)
	harness.check_equal(unit.target, null, "Clearing target agent state clears the unit target.")
	harness.check(
		not agent.get_state("has_attack_target"), "Clearing target resets attack target state."
	)
	harness.check(not agent.get_state("hunting"), "Clearing target stops hunting state.")
	harness.check_equal(unit.last_target, target, "Clearing target records the previous target.")

	agent.free()
	unit.free()
	target.free()
