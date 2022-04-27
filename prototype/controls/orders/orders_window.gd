extends ItemList
var game:Node

# self = game.ui.orders

var cleared = false

var leader_orders = {}
var lane_orders = {}
var camp_orders = {}

var camps

var button_template:PackedScene = load("res://controls/orders/button/order_button.tscn")

onready var container = get_node("scroll_container/container")


const order_types = {
	"leader_tactics": ["retreat","defend","default","attack"],
	"lane_tactics": ["defend","default","attack"],
	"priority": ["pawn", "leader", "building"],
	"camp_hire": ["infantry","ranged","mount"],
	"taxes": ["low_taxes","default_taxes","high_taxes"],
	"mine": ["collect", "explode"],
	"lumbermill": ["hire", "dismiss"]
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
	"low_taxes": "Only 1 gold coin",
	"default_taxes": "Default 20 coins tax",
	"high_taxes": "Double taxes to 40 gold coins"
}

func _ready():
	game = get_tree().get_current_scene()
	
	hide()
	clear()
	
	yield(get_tree(), "idle_frame")
	
	camps = [
		game.map.get_node("buildings/blue/camp"),
		game.map.get_node("buildings/red/camp")
	]
	
	update()



func clear():
	if not cleared:
		for placeholder in container.get_children():
			container.remove_child(placeholder)
			placeholder.queue_free()
		
		cleared = true


func build():
	setup_lanes()
	build_camps()
	#build_lumbermills()


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


# CAMPS

func build_camps():
	for camp in camps:
		var orders = {
			"node": VBoxContainer.new(),
			"camp": camp
		}
		container.add_child(orders.node)
		camp_orders[camp.name] = orders
		setup_camp_buttons(orders)


func setup_camp_buttons(orders):
	var label = game.utils.label("hire")
	orders.node.add_child(label)
	setup_hire(orders)
	var label2 = game.utils.label("camp taxes")
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
		if tax == "default_taxes":
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

