extends RefCounted

# PORT (post-restructure): OrderAction was rewritten. Completion is now
# driven by the player_order_complete/has_player_command agent states (set
# by the agent's attack-end handling) plus an idle-state check for
# move/advance/lane orders; the old "player_order_attack_ended" consumption
# moved into agent.gd. These tests pin the current contract.

const OrderAction = preload("res://goap/game_logic/actions/order_action.gd")
const Agent = preload("res://goap/goap_system/agent.gd")


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


# Minimal goal double so the REAL Agent can install a plan (_replace_plan
# calls enter/exit unguarded on goal change). get_class_name() feeds the
# state_changed emission.
class ObeyPlayerGoal:
	extends RefCounted

	func enter(_agent) -> void:
		pass

	func exit(_agent) -> void:
		pass

	func get_class_name() -> String:
		return "ObeyPlayer"


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

	# --- a dead unit cancels its order through the REAL Agent path ---
	# Production Agent.cancel_player_order() clears the plan and sets
	# player_order_complete / has_player_command (agent.gd). The old version
	# of this test asserted "player_order_cancelled", a key only its own
	# TestAgent double ever set — it was testing the mock, not the game.
	var real_agent = Agent.new()
	real_agent._unit = TestUnit.new()
	real_agent._unit.dead = true
	real_agent.set_state("player_order", {"type": "move"})
	real_agent.set_state("player_order_complete", false)
	real_agent.set_state("has_player_command", true)
	var order_step = OrderAction.new()
	real_agent._replace_plan(ObeyPlayerGoal.new(), [order_step])
	harness.check(
		real_agent.get_current_action() == order_step,
		"The order action is installed as the agent's current plan step."
	)
	harness.check(
		order_step.perform(real_agent, 0.0),
		"A dead unit's order completes (cancelled)."
	)
	harness.check(
		real_agent.get_state("player_order") == null,
		"A dead unit's order is erased from the agent state."
	)
	harness.check_equal(
		real_agent.get_state("player_order_complete"),
		true,
		"Cancellation marks the order complete for the ObeyPlayer goal."
	)
	harness.check_equal(
		real_agent.get_state("has_player_command"),
		false,
		"Cancellation clears the player-command state."
	)
	harness.check(
		real_agent.get_current_action() == null and real_agent.get_current_goal() == null,
		"Cancellation clears the agent's plan and goal."
	)
	real_agent.free()
