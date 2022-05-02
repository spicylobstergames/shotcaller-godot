extends Node
var game:Node

# self = game.unit.orders

var player_lanes_orders = {}
var enemy_lanes_orders = {}
var player_leaders_orders = {}
var enemy_leaders_orders = {}



func _ready():
	game = get_tree().get_current_scene()
	


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


# LANES

func build_lanes():
	for lane in game.map.lanes:
		player_lanes_orders[lane] = new_orders()
		enemy_lanes_orders[lane] = new_orders()


func set_lane_tactic(tactic):
	var lane = game.selected_unit.lane
	var lane_tactics
	if game.selected_unit.team == game.player_team:
		lane_tactics = player_lanes_orders[lane].tactics
	else: lane_tactics = enemy_lanes_orders[lane].tactics
	lane_tactics.tactic = tactic
	lane_tactics.speed = tactics_extra_speed[tactic]


func set_lane_priority(priority):
	var lane = game.selected_unit.lane
	var lane_priority
	if game.selected_unit.team == game.player_team:
		lane_priority = player_lanes_orders[lane].priority
	else: lane_priority = enemy_lanes_orders[lane].priority
	lane_priority.erase(priority)
	lane_priority.push_front(priority)


func set_pawn(pawn):
	var lane = pawn.lane
	var lane_orders
	if pawn.team == game.player_team:
		lane_orders = player_lanes_orders[lane]
	else: lane_orders = enemy_lanes_orders[lane]
	pawn.tactics = lane_orders.tactics.tactic
	pawn.priority = lane_orders.priority.duplicate()


func lanes_cycle(): # called every 8 sec
	for building in game.player_buildings:
		if building.lane:
			var priority = player_lanes_orders[building.lane].priority.duplicate()
			building.priority = priority
			
	for building in game.enemy_buildings:
		if building.lane:
			var priority = enemy_lanes_orders[building.lane].priority.duplicate()
			building.priority = priority


# LEADERS

func build_leaders():
	for leader in game.player_leaders:
		player_leaders_orders[leader.name] = new_orders()
		
	for leader in game.enemy_leaders:
		enemy_leaders_orders[leader.name] = new_orders()
	
	hp_regen_cycle()


func hp_regen_cycle(): # called every second
	if not game.paused:
		for unit in game.all_units:
			if unit.regen > 0:
				set_regen(unit)
				if unit.type == "leader" and unit.team == game.player_team:
					game.ui.inventories.update_consumables(unit)
		
	yield(get_tree().create_timer(1), "timeout")
	hp_regen_cycle()


func set_regen(unit):
	if not unit.dead:
		var regen = game.unit.modifiers.get_value(unit, "regen")
		unit.heal(regen)
	else: unit.regen = 0



func leaders_cycle(): # called every 4 sec
	for leader in game.player_leaders:
		set_leader(leader, player_leaders_orders[leader.name])
		
	for leader in game.enemy_leaders:
		set_leader(leader, enemy_leaders_orders[leader.name])



func set_leader(leader, orders):
	var tactics = orders.tactics
	leader.tactics = tactics.tactic
	leader.priority = orders.priority.duplicate()

	# get back to lane 
	if (not leader.working and
			not leader.retreating and 
			not (leader.team == game.player_team and game.ui.shop.close_to_blacksmith(leader)) ): 
				
		game.unit.follow.lane(leader)



func set_leader_tactic(tactic):
	var leader = game.selected_leader
	var leader_tactics
	if game.selected_unit.team == game.player_team:
		leader_tactics = player_leaders_orders[leader.name].tactics
	else: leader_tactics = enemy_leaders_orders[leader.name].tactics
	leader_tactics.tactic = tactic
	leader_tactics.speed = tactics_extra_speed[tactic]


func set_leader_priority(priority):
	var leader = game.selected_unit
	var leader_orders
	if leader.team == game.player_team:
		leader_orders = player_leaders_orders[leader.name]
	else: leader_orders = enemy_leaders_orders[leader.name]
	var leader_priority = leader_orders.priority
	leader_priority.erase(priority)
	leader_priority.push_front(priority)



func select_target(unit, enemies):
	var n = enemies.size()
	if n == 0: return
	
	if n == 1:
		return enemies[0]
	
	var sorted = game.utils.sort_by_distance(unit, enemies)
	var closest_unit = sorted[0].unit
	
	if n == 2:
		var further_unit = sorted[1].unit
		var index1 = unit.priority.find(closest_unit.type)
		var index2 = unit.priority.find(further_unit.type)
		if index2 < index1: 
			return further_unit
			
	# n > 2
	if not unit.ranged: # melee
		return closest_unit
		
	else: # ranged
		for priority_type in unit.priority:
			for enemy in sorted:
				if enemy.unit.type == priority_type:
					return enemy.unit


func closest_unit(unit, enemies):
	var sorted = game.utils.sort_by_distance(unit, enemies)
	return sorted[0].unit



func conquer_building(unit):
	var point = unit.global_position
	point.y -= game.map.tile_size
	var building = game.utils.buildings_click(point)
	
	if building and building.team == "neutral" and not unit.stunned:
		unit.channeling = true
		unit.working = true
		if unit.channeling_timer.time_left > 0: 
			unit.channeling_timer.stop()
		unit.channeling_timer.wait_time = 3
		unit.channeling_timer.start()
		yield(unit.channeling_timer, "timeout")
		if unit.channeling:
			unit.channeling = false
			unit.working = false
			building.team = unit.team
			match building.display_name:
				"camp", "outpost":
					building.attacks = true
			building.setup_team()


# RETREAT

func take_hit_retreat(attacker, target):
	match target.type:
		"leader":
			var hp = game.unit.modifiers.get_value(target, "hp")
			match target.tactics:
				"escape":
					retreat(target)
				"defensive":
					if target.current_hp < hp / 2:
						retreat(target)
				"default":
					if target.current_hp < hp / 3:
						retreat(target)


func retreat(unit):
	unit.retreating = true
	unit.current_path = []
	game.unit.attack.set_target(unit, null)
	var order
	if unit.team == game.player_team:
		order = player_leaders_orders[unit.name]
	else: order = enemy_leaders_orders[unit.name]
	set_leader(unit, order)
	var lane = unit.lane
	var path = game.map[lane].duplicate()
	if unit.team == "blue": path.invert()
	game.unit.follow.smart(unit, path, "move")
	

