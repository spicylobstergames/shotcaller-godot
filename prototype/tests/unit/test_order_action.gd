extends RefCounted

const OrderAction = preload("res://goap/game_logic/actions/order_action.gd")


class TestAgent:
	extends RefCounted
	var state := {
		"player_order": {"type": "attack"},
		"player_order_attack_ended": true,
		"has_player_command": true,
	}

	func get_state(state_name: String, default_value = null):
		return state.get(state_name, default_value)

	func set_state(state_name: String, value) -> void:
		state[state_name] = value

	func erase_state(state_name: String) -> void:
		state.erase(state_name)


func run(harness) -> void:
	var action = OrderAction.new()
	var agent = TestAgent.new()

	harness.check(action.perform(agent, 0.0), "An ended attack order completes its action.")
	harness.check(
		not agent.state.has("player_order"), "Completing an attack removes the active order."
	)
	harness.check_equal(
		agent.get_state("player_order_complete"),
		true,
		"Completing an attack sets the completion state."
	)
	harness.check_equal(
		agent.get_state("player_order_attack_ended"),
		false,
		"Completing an attack consumes the attack-ended state."
	)
	harness.check_equal(
		agent.get_state("has_player_command"),
		false,
		"Completing an attack clears the player-command state."
	)
