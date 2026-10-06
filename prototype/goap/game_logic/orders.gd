extends Node


var player_lanes_orders = {}
var enemy_lanes_orders = {}
var player_leaders_orders = {}
var enemy_leaders_orders = {}

const tactics_extra_speed = {
	"retreat": 0,
	"defend": -5,
	"default": 0,
	"attack": 5
}


func new_orders():
	return {
		"priority": ["pawn", "leader", "building"],
		"tactics": {
			"tactic": "default",
			"speed": 0
		}
	}


func build_lanes():
	# todo fix instantiated scene call
	for lane in WorldState.get_state("map").get_node("lanes").get_children():
		player_lanes_orders[lane.name] = new_orders()
		enemy_lanes_orders[lane.name] = new_orders()


func set_lane_tactic(tactic):
	var selected_unit = WorldState.get_state("selected_unit")
	if selected_unit:
		var lane = selected_unit.agent.get_state("lane")
		var lane_tactics
		if selected_unit.team == WorldState.get_state("player_team"):
			lane_tactics = player_lanes_orders[lane].tactics
		else:
			lane_tactics = enemy_lanes_orders[lane].tactics
		lane_tactics.tactic = tactic
		lane_tactics.speed = tactics_extra_speed[tactic]


func set_lane_priority(priority):
	var selected_unit = WorldState.get_state("selected_unit")
	if selected_unit:
		var lane = selected_unit.agent.get_state("lane")
		var lane_priority
		if selected_unit.team == WorldState.get_state("player_team"):
			lane_priority = player_lanes_orders[lane].priority
		else:
			lane_priority = enemy_lanes_orders[lane].priority
		lane_priority.erase(priority)
		lane_priority.push_front(priority)


func set_pawn(pawn):
	var lane = pawn.agent.get_state("lane")
	var lane_orders
	if pawn.team == WorldState.get_state("player_team"):
		lane_orders = player_lanes_orders[lane]
	else:
		lane_orders = enemy_lanes_orders[lane]
	pawn.tactics = lane_orders.tactics.tactic
	pawn.priority = lane_orders.priority.duplicate()


func lanes_cycle():
	for building in WorldState.get_state("all_buildings"):
		var lane = building.agent.get_state("lane")
		if lane in player_lanes_orders:
			building.priority = player_lanes_orders[lane].priority.duplicate()


func build_leaders():
	for leader in WorldState.get_state("player_leaders"):
		player_leaders_orders[leader.name] = new_orders()
	for leader in WorldState.get_state("enemy_leaders"):
		enemy_leaders_orders[leader.name] = new_orders()


func leaders_cycle():
	for leader in WorldState.get_state("player_leaders"):
		set_leader(leader, player_leaders_orders[leader.name])
	for leader in WorldState.get_state("enemy_leaders"):
		set_leader(leader, enemy_leaders_orders[leader.name])


func set_leader(leader, orders):
	if orders:
		var tactics = orders.tactics
		leader.tactics = tactics.tactic
		leader.priority = orders.priority.duplicate()
		var extra_unit = WorldState.get_state("player_extra_unit")
		if leader.team == WorldState.get_state("enemy_team"):
			extra_unit = WorldState.get_state("enemy_extra_unit")
		var cost
		match extra_unit:
			"infantry":
				cost = 1
			"archer":
				cost = 2
			"mounted":
				cost = 3
		leader.gold -= cost


func set_leader_tactic(tactic):
	var leader = WorldState.get_state("selected_leader")
	var leader_tactics
	if leader.team == WorldState.get_state("player_team"):
		leader_tactics = player_leaders_orders[leader.name].tactics
	else:
		leader_tactics = enemy_leaders_orders[leader.name].tactics
	leader_tactics.tactic = tactic
	leader_tactics.speed = tactics_extra_speed[tactic]


func set_leader_priority(priority):
	var leader = WorldState.get_state("selected_leader")
	var leader_orders
	if leader.team == WorldState.get_state("player_team"):
		leader_orders = player_leaders_orders[leader.name]
	else:
		leader_orders = enemy_leaders_orders[leader.name]
	var leader_priority = leader_orders.priority
	leader_priority.erase(priority)
	leader_priority.push_front(priority)
