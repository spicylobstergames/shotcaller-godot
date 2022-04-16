extends Node
var game:Node


var retreat_regen = 10

var player_orders = {}
var enemy_orders = {}
var leaders_priority = ["building", "leader", "pawn"]

var lanes = {
	"top": {
		"tactic": "default",
		"speed": 1,
		"priority": ["pawn", "leader", "building"]
	},
	"mid": {
		"tactic": "default",
		"speed": 1,
		"priority": ["pawn", "leader", "building"]
	},
	"bot": {
		"tactic": "default",
		"speed": 1,
		"priority": ["pawn", "leader", "building"]
	}
}

var retreat_speed = 1.1

func _ready():
	game = get_tree().get_current_scene()


func new_orders():
	 return {
			"priority": leaders_priority.duplicate(),
			"tactics": {
				"tactic": "default",
				"speed": 1
			}
		}


func build_leaders():
	for leader in game.player_leaders:
		player_orders[leader.name] = new_orders()
	for leader in game.enemy_leaders:
		enemy_orders[leader.name] = new_orders()
	
	hp_regen_cycle()


func hp_regen_cycle():
	
	for leader in game.player_leaders:
		set_regen(leader)
	for leader in game.enemy_leaders:
		set_regen(leader)
		
	yield(get_tree().create_timer(1), "timeout")
	hp_regen_cycle()


func set_regen(leader):
	if leader.retreating: leader.regen = retreat_regen
	else: leader.regen = 1
	leader.current_hp += leader.regen
	leader.current_hp = min(leader.current_hp, leader.hp)
	game.unit.hud.update_hpbar(leader)
	if leader == game.selected_unit: game.ui.stats.update()


func setup_pawn(unit, lane):
	unit.current_speed *= lanes[lane].speed


func setup_leaders():
	for leader in game.player_leaders:
		set_leader(leader, player_orders[leader.name])
	
	for leader in game.enemy_leaders:
		set_leader(leader, enemy_orders[leader.name])


func set_leader(leader, orders):
	var tactics = orders.tactics
	if leader.retreating: leader.current_speed = 1.1 * leader.speed
	else: leader.current_speed = tactics.speed * leader.speed
	leader.tactics = tactics.tactic
	leader.priority = orders.priority.duplicate()



func setup_lanes_priority():
	for building in game.player_buildings:
		var priority = lanes[building.lane].priority.duplicate()
		building.priority = priority


func set_lane_tactic(tactic):
	var lane = game.selected_unit.lane
	var lane_tactics = lanes[lane]
	lane_tactics.tactic = tactic
	match tactic:
		"defend":
			lane_tactics.speed = 0.9
		"default":
			lane_tactics.speed = 1
		"attack":
			lane_tactics.speed = 1.1


func set_leader_tactic(tactic):
	var leader = game.selected_leader
	var leader_tactics = player_orders[leader.name].tactics
	leader_tactics.tactic = tactic
	match tactic:
		"retreat":
			leader_tactics.speed = 1
		"defend":
			leader_tactics.speed = 0.9
		"default":
			leader_tactics.speed = 1
		"attack":
			leader_tactics.speed = 1



func set_lane_priority(priority):
	var lane = game.selected_unit.lane
	var lane_priority = lanes[lane].priority
	lane_priority.erase(priority)
	lane_priority.push_front(priority)


func set_leader_priority(priority):
	var leader = player_orders[game.selected_leader.name]
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


func take_hit(attacker, target):
	match target.type:
		"leader":
			match target.tactics:
				"escape":
					retreat(target)
				"defensive":
					if target.current_hp < target.hp / 2:
						retreat(target)
				"default":
					if target.current_hp < target.hp / 3:
						retreat(target)


func retreat(unit):
	unit.retreating = true
	unit.current_path = []
	game.unit.move.start(unit, unit.origin)


func retreat_end(unit):
	if unit.retreating and unit.current_destiny == unit.origin:
		unit.retreating = false
		var path = game.map.new_path(unit.lane, unit.team)
		game.unit.path.follow(unit, path.follow, "advance")
		return true
	return false
