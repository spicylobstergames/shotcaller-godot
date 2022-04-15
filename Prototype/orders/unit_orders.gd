extends Node
var game:Node


var leaders = {}
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
		leaders[leader.name] = new_orders()
	for leader in game.enemy_leaders:
		leaders[leader.name] = new_orders()
	
	hp_regen_cycle()


func hp_regen_cycle():
	for leader in game.player_leaders:
		if leader.retreating: leader.current_hp += 10
		else: leader.current_hp += 1
		if leader.current_hp >= leader.hp: leader.current_hp = leader.hp
		game.unit.hud.update_hpbar(leader)
		if leader == game.selected_unit: game.ui.stats.update()
	
	for leader in game.enemy_leaders:
		if leader.retreating: leader.current_hp += 10
		else: leader.current_hp += 1
		if leader.current_hp >= leader.hp: leader.current_hp = leader.hp
		game.unit.hud.update_hpbar(leader)
		if leader == game.selected_unit: game.ui.stats.update()
		
	yield(get_tree().create_timer(1), "timeout")
	hp_regen_cycle()


func setup_pawn(unit, lane):
	unit.current_speed *= lanes[lane].speed


func setup_leaders():
	for leader in game.player_leaders:
		var leader_orders = leaders[leader.name]
		var tactics = leader_orders.tactics
		leader.priority = leader_orders.priority.duplicate()
		leader.current_speed = tactics.speed * leader.speed
		leader.tactics = tactics.tactic


func setup_lanes_priority():
	for building in game.player_buildings:
		var priority = lanes[building.lane].priority.duplicate()
		building.priority = priority


func set_lane_tactic(tactic):
	var lane = game.selected_unit.lane
	var lane_tactics = lanes[lane]
	lane_tactics.tactic = tactic
	match tactic:
		"defensive":
			lane_tactics.speed = 0.9
		"default":
			lane_tactics.speed = 1
		"aggressive":
			lane_tactics.speed = 1.1


func set_leader_tactic(tactic):
	var leader = game.selected_leader
	var leader_tactics = leaders[leader.name].tactics
	leader_tactics.tactic = tactic
	match tactic:
		"retreat":
			leader_tactics.speed = 1.1
		"defensive":
			leader_tactics.speed = 0.9
		"default":
			leader_tactics.speed = 1
		"aggressive":
			leader_tactics.speed = 1



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


func take_hit(attacker, target):
	match target.type:
		"leader":
			match target.tactics:
				"escape":
					target.retreating = true
					game.unit.move.start(target, target.origin)
				"defensive":
					if target.current_hp < target.hp / 2:
						target.retreating = true
						game.unit.move.start(target, target.origin)
				"default":
					if target.current_hp < target.hp / 3:
						target.retreating = true
						game.unit.move.start(target, target.origin)


