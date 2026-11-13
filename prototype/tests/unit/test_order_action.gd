extends RefCounted

# PORT (post-restructure): OrderAction was rewritten. Completion is now
# driven by the player_order_complete/has_player_command agent states (set
# by the agent's attack-end handling) plus an idle-state check for
# move/advance/lane orders; the old "player_order_attack_ended" consumption
# moved into agent.gd. These tests pin the current contract.

const OrderAction = preload("res://goap/game_logic/actions/order_action.gd")


class TestUnit:
	extends RefCounted
	var dead := false
	var state := "idle"
	var current_path: Array = []
	var current_destiny := Vector2.ZERO
	var final_destiny := Vector2.ZERO
	var current_step := Vector2.ZERO
	var animations = null


class TestAgent:
	extends RefCounted
	var unit
	var state := {}

	func _init(test_unit = null):
		unit = test_unit if test_unit else TestUnit.new()

	func get_unit():
		return unit

	func get_state(state_name: String, default_value = null):
		return state.get(state_name, default_value)

	func set_state(state_name: String, value) -> void:
		state[state_name] = value

	func erase_state(state_name: String) -> void:
		state.erase(state_name)

	func cancel_player_order() -> void:
		erase_state("player_order")
		set_state("player_order_cancelled", true)


func run(harness) -> void:
	var action = OrderAction.new()

	# --- is_valid: a non-empty order dict is required ---
	var agent = TestAgent.new()
	harness.check(not action.is_valid(agent), "No order state means the order action is invalid.")
	agent.set_state("player_order", {"type": "move"})
	harness.check(action.is_valid(agent), "A pending order activates the order action.")

	# --- perform with no order: trivially complete ---
	agent.erase_state("player_order")
	harness.check(
		action.perform(agent, 0.0),
		"perform() with no pending order reports complete."
	)

	# --- perform completes an acknowledged attack order ---
	agent.set_state("player_order", {"type": "attack"})
	agent.set_state("player_order_complete", true)
	agent.set_state("has_player_command", true)
	harness.check(action.perform(agent, 0.0), "An acknowledged attack order completes its action.")
	harness.check(
		not agent.state.has("player_order"), "Completing an order removes the active order."
	)
	harness.check_equal(
		agent.get_state("has_player_command"),
		false,
		"Completing an order clears the player-command state."
	)

	# --- perform with a move order still in progress is not complete ---
	var moving_agent = TestAgent.new()
	moving_agent.set_state("player_order", {"type": "move"})
	moving_agent.unit.state = "move"
	moving_agent.unit.current_path = [Vector2(100, 100)]
	harness.check(
		not action.perform(moving_agent, 0.0),
		"A move order in progress is not complete."
	)

	# --- perform completes a move order once the unit is idle again ---
	moving_agent.unit.state = "idle"
	moving_agent.unit.current_path = []
	moving_agent.unit.current_destiny = Vector2.ZERO
	moving_agent.unit.final_destiny = Vector2.ZERO
	harness.check(
		action.perform(moving_agent, 0.0),
		"A move order completes when the unit is idle with no path or destiny."
	)
	harness.check(
		not moving_agent.state.has("player_order"),
		"The completed move order is removed."
	)

	# --- a dead unit cancels its order ---
	var dead_agent = TestAgent.new()
	dead_agent.unit.dead = true
	dead_agent.set_state("player_order", {"type": "move"})
	harness.check(action.perform(dead_agent, 0.0), "A dead unit's order completes (cancelled).")
	harness.check_equal(
		dead_agent.get_state("player_order_cancelled"),
		true,
		"A dead unit's order is cancelled, not completed normally."
	)
