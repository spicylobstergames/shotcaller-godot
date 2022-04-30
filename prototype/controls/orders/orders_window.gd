extends ItemList
var game:Node

# self = game.ui.orders

var cleared = false

var leader_orders = {}
var lane_orders = {}
var mine_orders = {}
var blacksmith_orders = {}
var lumbermill_orders = {}
var camp_orders = {}
var outpost_orders = {}

var mine:Array = []
var blacksmith:Array = []
var lumbermill:Array = []
var camp:Array = []
var outpost:Array = []

const neutrals = ["mine", "blacksmith", "lumbermill", "camp", "outpost"]

var button_template:PackedScene = load("res://controls/orders/button/order_button.tscn")

const order_types = {
	"leader_tactics": ["retreat","defend","default","attack"],
	"lane_tactics": ["defend","default","attack"],
	"priority": ["pawn", "leader", "building"],
	"camp_hire": ["infantry","ranged","mount"],
	"taxes": ["low","default","high"],
	"gold": ["collect", "destroy"],
	"lumberjack": ["hire", "dismiss"],
	"tower_upgrades": ["extra room","fire arrows","reinforce"],
	"pawn_upgrades": ["weapons","armor","boots"]
}

const hint_tooltips_tactics = {
	"retreat": "Retreats on first hit",
	"defend": "Retreats if less than half HP",
	"default": "Retreats if less than third HP",
	"attack": "Never retreats"
}

const hint_tooltips_hire = {
	"infantry": "Extra infantry, costs 5 gold",
	"ranged": "Extra archer, costs 10 gold",
	"mount": "Extra mounted soldier, costs 15 gold"
}

const hint_tooltips_tax = {
	"low": "Only 1 gold coin",
	"default": "Default 20 coins tax",
	"high": "Double taxes to 40 gold coins"
}

const hint_tooltips_gold = {
	"collect": "Sends the collected gold to your castle - 16s",
	"destroy": "Explodes the mine destroying all collected gold - 4s",
}

onready var container = get_node("scroll_container/container")

func _ready():
	game = get_tree().get_current_scene()
	
	hide()
	clear()
	
	yield(get_tree(), "idle_frame")
	
	for neutral in neutrals:
		self[neutral].append( game.map.get_node("buildings/blue/" + neutral) )
		self[neutral].append( game.map.get_node("buildings/red/" + neutral) )
	
	update()



func clear():
	if not cleared:
		for placeholder in container.get_children():
			container.remove_child(placeholder)
			placeholder.queue_free()
		
		cleared = true


func build():
	setup_lanes()
	build_mines()
	build_blacksmiths()
	build_lumbermills()
	build_camps()
	build_outposts()


# LEADERS

func build_leaders():
	for leader in game.player_leaders:
		var orders_container = {
			"node": VBoxContainer.new(),
			"leader": leader
		}
		container.add_child(orders_container.node)
		leader_orders[leader.name] = orders_container
		setup_leader_buttons(orders_container)


func setup_leader_buttons(orders_container):
	var label = game.utils.label("set tactics")
	orders_container.node.add_child(label)
	setup_tactics(orders_container, order_types.leader_tactics)
	var label2 = game.utils.label("set priority")
	orders_container.node.add_child(label2)
	setup_priority(orders_container)
	update()


# LANES

func setup_lanes():
	for lane in game.map.lanes:
		var orders_container = {
			"node": VBoxContainer.new(),
			"type": "lane",
			"lane": lane
		}
		container.add_child(orders_container.node)
		lane_orders[lane] = orders_container
		setup_lane_buttons(orders_container)


func setup_lane_buttons(orders_container):
	var label = game.utils.label(orders_container.lane +"lane tactics")
	orders_container.node.add_child(label)
	setup_tactics(orders_container, order_types.lane_tactics)
	var label2 = game.utils.label(orders_container.lane +" lane priority")
	orders_container.node.add_child(label2)
	setup_priority(orders_container)


# MINES

func build_mines():
	for building in mine:
		var orders = {
			"node": VBoxContainer.new(),
			"camp": building
		}
		container.add_child(orders.node)
		mine_orders[building.name] = orders
		setup_mine_buttons(orders)


func setup_mine_buttons(orders):
	var label = game.utils.label("gold")
	orders.node.add_child(label)
	setup_gold(orders)
	var label2 = game.utils.label("taxes")
	orders.node.add_child(label2)
	setup_taxes(orders)


func setup_gold(orders):
	var buttons_container = HBoxContainer.new()
	orders.node.add_child(buttons_container)
	for order in order_types.gold:
		var button = button_template.instance()
		buttons_container.add_child(button)
		button.hint_tooltip = hint_tooltips_gold[order]
		button.orders = {
			"order": orders,
			"type": "gold",
			"gold": order
		}
		setup_order_button(button)
	orders.node.add_child(HSeparator.new())


# BLACKSMITH

func build_blacksmiths():
	for building in blacksmith:
		var orders = {
			"node": VBoxContainer.new(),
			"camp": building
		}
		container.add_child(orders.node)
		blacksmith_orders[building.name] = orders
		setup_blacksmith_buttons(orders)


func setup_blacksmith_buttons(orders):
#	var label = game.utils.label("pawn upgrades")
#	orders.node.add_child(label)
#	setup_pawn_upgrades(orders)
	var label2 = game.utils.label("taxes")
	orders.node.add_child(label2)
	setup_taxes(orders)


func setup_pawn_upgrades(orders):
	var buttons_container = HBoxContainer.new()
	orders.node.add_child(buttons_container)
	for order in order_types.pawn_upgrades:
		var button = button_template.instance()
		buttons_container.add_child(button)
		#button.hint_tooltip = hint_tooltips_pawn_upgrades[order]
		button.orders = {
			"order": orders,
			"type": "pawn_upgrade",
			"pawn_upgrade": order
		}
		setup_order_button(button)
	orders.node.add_child(HSeparator.new())



# LUMBERMILL

func build_lumbermills():
	for building in lumbermill:
		var orders = {
			"node": VBoxContainer.new(),
			"camp": building
		}
		container.add_child(orders.node)
		lumbermill_orders[building.name] = orders
		setup_lumbermill_buttons(orders)


func setup_lumbermill_buttons(orders):
	var label = game.utils.label("hire")
	orders.node.add_child(label)
	setup_lumberjack(orders)
	var label2 = game.utils.label("taxes")
	orders.node.add_child(label2)
	setup_taxes(orders)


func setup_lumberjack(orders):
	var buttons_container = HBoxContainer.new()
	orders.node.add_child(buttons_container)
	for order in order_types.gold:
		var button = button_template.instance()
		buttons_container.add_child(button)
		#button.hint_tooltip = hint_tooltips_lumberjack[order]
		button.orders = {
			"order": orders,
			"type": "lumberjack",
			"lumberjack": order
		}
		setup_order_button(button)
	orders.node.add_child(HSeparator.new())


# CAMPS

func build_camps():
	for building in camp:
		var orders = {
			"node": VBoxContainer.new(),
			"camp": building
		}
		container.add_child(orders.node)
		camp_orders[building.name] = orders
		setup_camp_buttons(orders)


func setup_camp_buttons(orders):
	var label = game.utils.label("hire")
	orders.node.add_child(label)
	setup_hire(orders)
	var label2 = game.utils.label("taxes")
	orders.node.add_child(label2)
	setup_taxes(orders)


func setup_hire(orders):
	var buttons_container = HBoxContainer.new()
	orders.node.add_child(buttons_container)
	for hire in order_types.camp_hire:
		var button = button_template.instance()
		buttons_container.add_child(button)
		button.hint_tooltip = hint_tooltips_hire[hire]
		button.orders = {
			"order": orders,
			"type": "hire",
			"hire": hire
		}
		setup_order_button(button)
		if hire == "melee":
			button.pressed = true
			button.disabled = true
	orders.node.add_child(HSeparator.new())


# OUTPOSTS

func build_outposts():
	for building in outpost:
		var orders = {
			"node": VBoxContainer.new(),
			"camp": building
		}
		container.add_child(orders.node)
		outpost_orders[building.name] = orders
		setup_outpost_buttons(orders)


func setup_outpost_buttons(orders):
	#var label = game.utils.label("tower upgrades")
	#orders.node.add_child(label)
	#setup_tower_upgrades(orders)
	var label2 = game.utils.label("taxes")
	orders.node.add_child(label2)
	setup_taxes(orders)


# TAXES

func setup_taxes(orders):
	var buttons_container = HBoxContainer.new()
	orders.node.add_child(buttons_container)
	for tax in order_types.taxes:
		var button = button_template.instance()
		buttons_container.add_child(button)
		button.hint_tooltip = hint_tooltips_tax[tax]
		button.orders = {
			"order": orders,
			"type": "taxes",
			"taxes": tax
		}
		setup_order_button(button)
		if tax == "default":
			button.pressed = true
			button.disabled = true
	orders.node.add_child(HSeparator.new())


# TACTICS

func setup_tactics(orders_container, tactics):
	var buttons_container = HBoxContainer.new()
	orders_container.node.add_child(buttons_container)
	for tactic in tactics:
		var button = button_template.instance()
		button.hint_tooltip = hint_tooltips_tactics[tactic]
		button.orders = {
			"order": orders_container,
			"type": "tactic",
			"tactic": tactic
		}
		setup_order_button(button)
		if tactic == "default":
			button.pressed = true
			button.disabled = true
		buttons_container.add_child(button)
	orders_container.node.add_child(HSeparator.new())


# PRIORITY

func setup_priority(orders_container):
	var buttons_container = HBoxContainer.new()
	orders_container.node.add_child(buttons_container)
	for priority in order_types.priority:
		var button = button_template.instance()
		button.orders =  {
			"order": orders_container,
			"type": "priority",
			"priority": priority
		}
		setup_order_button(button)
		button.set_toggle_mode(false)
		button.set_action_mode(true)
		buttons_container.add_child(button)
	var first = buttons_container.get_child(0)
	first.set_pressed(true)
	first.set_disabled(true)



func setup_order_button(button):
	yield(get_tree(), "idle_frame")
	button.setup_order_button()


func update():
	hide_all()
	if game.selected_unit and game.selected_unit.team == game.player_team:
		if game.selected_unit.subtype == "backwood":
			match game.selected_unit.display_name:
				"camp":
					show_orders()
					camp_orders[game.selected_unit.name].node.show()
				"mine":
					show_orders()
					mine_orders[game.selected_unit.name].node.show()
			
		else: 
			match game.selected_unit.type:
				"pawn", "building": 
					show_orders()
					lane_orders[game.selected_unit.lane].node.show()
				"leader": 
					show_orders()
					leader_orders[game.selected_unit.name].node.show()

	else:
		game.ui.orders_button.disabled = true


func show_orders():
	game.ui.orders_button.disabled = false


func hide_all():
	for child in container.get_children():
		child.hide()
	for leader in leader_orders:
		leader_orders[leader].node.hide()
	for lane in lane_orders:
		lane_orders[lane].node.hide()

