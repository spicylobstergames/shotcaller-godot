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
	var old_all_leaders = WorldState.get_state("all_leaders")
	var old_player_leaders = WorldState.get_state("player_leaders")
	var old_enemy_leaders = WorldState.get_state("enemy_leaders")
	var old_player_team = WorldState.get_state("player_team")
	var choose_target = Goap.get_action("ChooseTarget")

	var leader = TestLeader.new()
	WorldState.set_state("all_leaders", [])
	WorldState.set_state("player_leaders", [leader])
	WorldState.set_state("enemy_leaders", [])
	WorldState.set_state("player_team", "blue")

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
	WorldState.set_state("all_leaders", old_all_leaders)
	WorldState.set_state("player_leaders", old_player_leaders)
	WorldState.set_state("enemy_leaders", old_enemy_leaders)
	WorldState.set_state("player_team", old_player_team)
	choose_target.build_leader_priorities(
		old_player_leaders if old_player_leaders is Array else [],
		old_enemy_leaders if old_enemy_leaders is Array else []
	)
