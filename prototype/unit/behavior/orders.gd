extends Node
var game:Node

# self = Behavior.orders

const player_lanes_orders = {}
const enemy_lanes_orders = {}
const player_leaders_orders = {}
const enemy_leaders_orders = {}

var player_tax = "low"
var enemy_tax = "low"

var player_extra_unit = "infantry"
var enemy_extra_unit = "infantry"

const lumberjack_cost = 100
const conquer_time = 3
const destroy_time = 5
const collect_time = 16
const pray_time = 10
const pray_cooldown = 60
const cut_time = 6

const _pray_bonuses = [
	["regen", 1],
	["defense", 2],
	["hp", 10]
]

	
const tax_gold = {
	"low": 0,
	"medium": 1,
	"high": 2
}

const tax_conquer_limit = {
	"low": 0.25,
	"medium": 0.5,
	"high": 0.75
}

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


func _ready():
	game = get_tree().get_current_scene()

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


func leaders_cycle(): # called every 4 sec
	for leader in game.player_leaders:
		set_leader(leader, player_leaders_orders[leader.name])
		
	for leader in game.enemy_leaders:
		set_leader(leader, enemy_leaders_orders[leader.name])


func set_leader(leader, orders):
	var tactics = orders.tactics
	leader.tactics = tactics.tactic
	leader.priority = orders.priority.duplicate()
	
	var extra_unit = player_extra_unit
	if leader.team == game.enemy_team:
		extra_unit = enemy_extra_unit
	var cost
	match extra_unit:
		"infantry": cost = 1
		"archer": cost = 2
		"mounted": cost = 3
	leader.gold -= cost
	
	# get back to lane 
	if (not leader.after_arive == "conquer" and
			not leader.after_arive == "attack" and
			not leader.after_arive == "pray" and
			not leader.working and
			not leader.channeling and
			not leader.retreating and 
			not (game.can_control(leader) and game.ui.shop.close_to_blacksmith(leader)) ): 
				
		Behavior.follow.lane(leader)



func set_leader_tactic(tactic):
	var leader = game.selected_leader
	var leader_tactics
	if game.selected_unit.team == game.player_team:
		leader_tactics = player_leaders_orders[leader.name].tactics
	else: leader_tactics = enemy_leaders_orders[leader.name].tactics
	leader_tactics.tactic = tactic
	leader_tactics.speed = tactics_extra_speed[tactic]


func set_leader_priority(priority):
	var leader = game.selected_leader
	var leader_orders
	if leader.team == game.player_team:
		leader_orders = player_leaders_orders[leader.name]
	else: leader_orders = enemy_leaders_orders[leader.name]
	var leader_priority = leader_orders.priority
	leader_priority.erase(priority)
	leader_priority.push_front(priority)



func select_target(unit, enemies):
	var filtered = []
	
	for enemy in enemies:
		if Behavior.attack.can_hit(unit, enemy): filtered.append(enemy)
	
	var n = filtered.size()
	if n == 0: return
	
	if n == 1:
		return filtered[0]
	
	var sorted = unit.sort_by_distance(filtered)
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



# BACKWOOD


func conquer_building(unit):
	unit.after_arive = "stop"
	var point = unit.global_position
	point.y -= game.map.tile_size
	var building = game.utils.get_building(point)
	if not unit.stunned and not unit.command_casting and building:
		var hp = float(Behavior.modifiers.get_value(building, "hp"))
		var current_hp = float(building.current_hp)
		var building_full_hp = ( (current_hp / hp) == 1 )
		if building.team == "neutral" and building_full_hp:
			unit.channel_start(conquer_time)
			yield(unit.channeling_timer, "timeout")
			# conquer
			if unit.channeling:
				unit.channeling = false
				unit.working = false
				building.channeling = false
				building.setup_team(unit.team)
				
				match building.display_name:
					"camp", "outpost": building.attacks = true
					"mine": set_mine_gold(unit.team, 1)
				
				game.ui.show_select()


func lose_building(building):
	var team = building.team
	
	match building.display_name:
		# todo "blacksmith": allow stealing enemy item
		"camp": 
			if team == game.player_team:
				player_extra_unit = "infantry"
			else: enemy_extra_unit = "infantry"
			building.attacks = false
		
		"outpost": building.attacks = false
		"mine": set_mine_gold(team, 0)
		
	building.setup_team("neutral")
	
	if not game.map.has_neutral_buildings(team): remove_tax(team)



# CHURCH


func pray_in_church(unit):
	unit.after_arive = "stop"
	var point = unit.global_position
	point.y -= game.map.tile_size
	var building = game.utils.get_building(point)
	if (building and building.team == unit.team 
			and building.display_name == "church" 
			and building.channeling == false 
			and not unit.stunned
			and not unit.command_casting):
		building.channeling = true
		unit.channel_start(pray_time)
		yield(unit.channeling_timer, "timeout")
		if unit.channeling:
			unit.channeling = false
			unit.working = false
			pray(unit)
			game.ui.show_select()
			# Chruch pray cooldown <- temporary solution
			yield(get_tree().create_timer(pray_cooldown), "timeout")
			building.channeling = false



func pray(unit):
	var random_bonus = _pray_bonuses[randi() % _pray_bonuses.size()]
	Behavior.modifiers.add(unit, random_bonus[0], "pray", random_bonus[1])


# MINE

func set_mine_gold(team, value):
	var leaders = game.player_leaders
	var inventories = game.ui.inventories.player_leaders_inv
	if team == game.enemy_team:
		leaders = game.enemy_leaders
		inventories = game.ui.inventories.enemy_leaders_inv
	for leader in leaders:
		inventories[leader.name].extra_mine_gold = value


func gold_order(button):
	var mine = button.orders.order.mine
	mine.channeling_timer.stop()
	mine.channeling_timer.wait_time = 1
	mine.channeling_timer.start()
	mine.channeling = true
	match button.orders.gold:
		"collect":
			button.counter = collect_time
			button.hint_label.text = str(collect_time)
			gold_collect_counter(button)
		"destroy":
			button.counter = destroy_time
			button.hint_label.text = str(button.counter)
			gold_destroy_counter(button)


func gold_collect_counter(button):
	var mine = button.orders.order.mine
	yield(mine.channeling_timer, "timeout")
	if button.counter > 0:
		button.counter -= 1
		button.hint_label.text = str(button.counter)
		gold_collect_counter(button)
	else:
		mine.channeling_timer.stop()
		button.disabled = false
		if mine.channeling:
			mine.channeling = false
			var leaders = game.player_leaders
			if mine.team == game.enemy_team: leaders = game.enemy_leaders
			for leader in leaders:
				leader.gold += floor(mine.gold / leaders.size())
			mine.gold = 0


func gold_destroy_counter(button):
	var mine = button.orders.order.mine
	yield(mine.channeling_timer, "timeout")
	if button.counter > 0:
		button.counter -= 1
		button.hint_label.text = str(button.counter)
		gold_destroy_counter(button)
	else:
		mine.channeling_timer.stop()
		button.disabled = false
		if mine.channeling:
			mine.channeling = false
			mine.gold = 0
			mine.setup_team("neutral")
			game.ui.show_select()
			for leader in game.player_leaders:
				game.ui.inventories.leaders[leader.name].extra_mine_gold = 0



# CAMP

func camp_hire(unit, team):
	if team == game.player_team:
		player_extra_unit = unit
	else: enemy_extra_unit = unit
	
	var cost
	match unit:
		"infantry": cost = 1
		"archer": cost = 2
		"mounted": cost = 3
	
	var leaders = game.player_leaders
	if team == game.enemy_team: leaders = game.enemy_leaders
	for leader in leaders: leader.gold -= cost


# LUMBERMILL

func lumberjack_hire(orders, team):
	var lumbermill = game.selected_unit
	var lumberjack = lumbermill.target
	
	# create lumberjack
	if not lumberjack:
		lumberjack = Behavior.spawn.next_to_building("lumberjack", lumbermill)
		lumberjack.origin = lumberjack.global_position
		lumberjack.target = lumbermill
		lumbermill.target = lumberjack
		
	lumberjack.setup_team(team)
	lumberjack.visible = true
	
	# charge player
	var leaders = game.player_leaders
	if team == game.enemy_team: leaders = game.enemy_leaders
	for leader in leaders: leader.gold -= floor(lumberjack_cost/leaders.size())

# TAXES

func set_taxes(tax, team):
	if team == game.player_team:
		player_tax = tax
	else: enemy_tax = tax


func update_taxes():
	for leader in game.player_leaders:
		game.ui.inventories.player_leaders_inv[leader.name].extra_tax_gold = tax_gold[player_tax]
	for leader in game.enemy_leaders:
		game.ui.inventories.enemy_leaders_inv[leader.name].extra_tax_gold = tax_gold[enemy_tax] 


func remove_tax(team):
	var leaders = game.player_leaders
	var inventories = game.ui.inventories.player_leaders_inv
	if team == game.enemy_team:
		leaders = game.enemy_leaders
		inventories = game.ui.inventories.enemy_leaders_inv
	for leader in leaders:
		var inventory = inventories[leader.name]
		inventory.extra_tax_gold = 0


# RETREAT

func take_hit_retreat(attacker, target):
	match target.type:
		"leader":
			var hp = Behavior.modifiers.get_value(target, "hp")
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
	Behavior.attack.set_target(unit, null)
	var order
	if unit.team == game.player_team:
		order = player_leaders_orders[unit.name]
	else: order = enemy_leaders_orders[unit.name]
	set_leader(unit, order)
	var lane = unit.lane
	var path = game.map.lanes_paths[lane].duplicate()
	if unit.team == "blue": path.invert()
	Behavior.follow.smart(unit, path, "move")
	

