extends Node
var game:Node


var leaders = {}
var leaders_priority = ["building", "leader", "pawn"]

var lanes = {
	"top": {
		"speed": 1,
		"priority": ["pawn", "leader", "building"]
	},
	"mid": {
		"speed": 1,
		"priority": ["pawn", "leader", "building"]
	},
	"bot": {
		"speed": 1,
		"priority": ["pawn", "leader", "building"]
	}
}


func _ready():
	game = get_tree().get_current_scene()



func build_leaders():
	for leader in game.player_leaders:
		leaders[leader.name] = {
			"priority": leaders_priority.duplicate(),
			"tactic": {
				"speed": 1
			}
		}


func setup_pawn(unit, lane):
	unit.current_speed *= lanes[lane].speed


func setup_leaders():
	for leader in game.player_leaders:
		var leader_orders = leaders[leader.name]
		leader.priority = leader_orders.priority.duplicate()
		leader.current_speed = leader_orders.tactic.speed * leader.speed



func setup_lanes_priority():
	for building in game.player_buildings:
		var priority = lanes[building.lane].priority.duplicate()
		building.priority = priority


func set_lane_tactic(tactic):
	var lane = game.selected_unit.lane
	match tactic:
		"defensive":
			lanes[lane].speed = 0.9
		"default":
			lanes[lane].speed = 1
		"aggressive":
			lanes[lane].speed = 1.1


func set_leader_tactic(tactic):
	var leader = game.selected_leader
	var leader_tactic = leaders[leader.name].tactic
	match tactic:
		"escape":
			leader_tactic.speed = 1.1
		"defensive":
			leader_tactic.speed = 0.9
		"default":
			leader_tactic.speed = 1
		"aggressive":
			leader_tactic.speed = 1



func set_lane_priority(priority):
	var lane = game.selected_unit.lane
	var lane_priority = lanes[lane].priority
	lane_priority.erase(priority)
	lane_priority.push_front(priority)


func set_leader_priority(priority):
	var leader = leaders[game.selected_leader.name]
	var lane_priority = leader.priority
	lane_priority.erase(priority)
	lane_priority.push_front(priority)


func select_target(unit, enemies):
	var n = enemies.size()
	var target
	if n == 1:
		target = enemies[0]
		return target
	
	var sorted = game.utils.sort_by_distance(unit, enemies)
	var closest_unit = sorted[0].unit
	
	if n == 2:
		var further_unit = sorted[1].unit
		var index1 = unit.priority.find(closest_unit.type)
		var index2 = unit.priority.find(further_unit.type)
		if index2 < index1: 
			return further_unit
			
	# n > 2
	target = closest_unit
	return target


func closest_unit(unit, enemies):
	var sorted = game.utils.sort_by_distance(unit, enemies)
	return sorted[0].unit

