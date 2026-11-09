extends Node

const OrdersPanelScene = preload("res://ui/panels/orders_panel.tscn")


class TestAgent:
	extends Node

	var state := {}
	var unit

	func set_state(state_name, value) -> void:
		state[state_name] = value


class TestLeader:
	extends Node

	var team := "blue"
	var type := "leader"
	var agent := TestAgent.new()

	func _init() -> void:
		name = "test_leader"
		agent.unit = self
		agent.set_name("agent")


func run(harness) -> void:
	var ws = preload("res://tests/helpers/world_state_snapshot.gd").new()
	var choose_target = Goap.get_action("ChooseTarget")

	var leader = TestLeader.new()
	ws.set_state("all_leaders", [])
	ws.set_state("player_leaders", [leader])
	ws.set_state("enemy_leaders", [])
	ws.set_state("player_team", "blue")

	var panel = OrdersPanelScene.instantiate()
	add_child(panel)
	leader.add_child(leader.agent)
	add_child(leader)
	panel.leaders_built.connect(Goap.get_goal("WalkLane").build_leaders, CONNECT_ONE_SHOT)
	panel.build_leaders()

	harness.check_equal(
		leader.agent.state.get("target_priority"),
		["pawn", "leader", "building"],
		"Orders panel leader-build signal initializes WalkLane leader priorities."
	)

	panel.free()
	leader.free()
	ws.restore()
	# Re-derive ChooseTarget's cached priorities from the restored leaders —
	# the action is a registry singleton, so its state outlives this test.
	var restored_player = WorldState.get_state("player_leaders")
	var restored_enemy = WorldState.get_state("enemy_leaders")
	choose_target.build_leader_priorities(
		restored_player if restored_player is Array else [],
		restored_enemy if restored_enemy is Array else []
	)
