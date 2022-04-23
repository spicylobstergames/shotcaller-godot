extends ItemList
var game:Node

var clear = false

var leader_orders = {}
var lane_orders = {}


var button_template:PackedScene = load("res://controls/orders/button/order_button.tscn")


onready var container = get_node("scroll_container/container")


const order_types = {
	"leader_tactics": ["retreat","defend","default","attack"],
	"lane_tactics": ["defend","default","attack"],
	"priority": ["pawn", "leader", "building"],
	# subtype priority: melee ranged mounted
	"camp": ["melee","ranged","mounted"],
	"taxes": ["up","down"],
	"mine": ["collect", "explode"],
	"lumbermill": ["hire", "dismiss"]
}

const hint_tooltips_tactics = {
	"retreat": "Retreats on first hit",
	"defend": "Retreats if less than half HP",
	"default": "Retreats if less than third HP",
	"attack": "Never retreats"
}

func _ready():
	game = get_tree().get_current_scene()
	
	hide()
	
	if not clear:
		for placeholder in container.get_children():
			container.remove_child(placeholder)
			placeholder.queue_free()
		
		clear = true
	
	yield(get_tree(), "idle_frame")
	update()


func build_leaders():
	for leader in game.player_leaders:
		var orders = {
			"node": VBoxContainer.new(),
			"leader": leader
		}
		leader_orders[leader.name] = orders
		setup_leader_buttons(orders)
		container.add_child(orders.node)
	
	game.unit.orders.build_leaders()



func setup_lanes():
	for lane in game.map.lanes:
		var orders = {
			"node": VBoxContainer.new(),
			"type": "lane",
			"lane": lane
		}
		lane_orders[lane] = orders
		setup_lane_buttons(orders)
		container.add_child(orders.node)




func setup_tactics(orders, tactics):
	var buttons_container = HBoxContainer.new()
	for tactic in tactics:
		var button = button_template.instance()
		button.hint_tooltip = hint_tooltips_tactics[tactic]
		button.orders = {
			"order": orders,
			"type": "tactic",
			"tactic": tactic
		}
		setup_order_button(button)
		if tactic == "default":
			button.pressed = true
			button.disabled = true
		buttons_container.add_child(button)
	orders.node.add_child(buttons_container)
	orders.node.add_child(HSeparator.new())


func setup_priority(orders):
	var buttons_container = HBoxContainer.new()
	for priority in order_types.priority:
		var button = button_template.instance()
		button.orders =  {
			"order": orders,
			"type": "priority",
			"priority": priority
		}
		setup_order_button(button)
		button.set_toggle_mode(false)
		button.set_action_mode(true)
		buttons_container.add_child(button)
	orders.node.add_child(buttons_container)
	var first = buttons_container.get_child(0)
	first.set_pressed(true)
	first.set_disabled(true)


func setup_order_button(button):
	yield(get_tree(), "idle_frame")
	button.setup_order_button()


func setup_lane_buttons(orders):
	var label = game.utils.label(orders.lane +"lane tactics")
	orders.node.add_child(label)
	setup_tactics(orders, order_types.lane_tactics)
	var label2 = game.utils.label(orders.lane +" lane priority")
	orders.node.add_child(label2)
	setup_priority(orders)


func setup_leader_buttons(orders):
	var label = game.utils.label("set tactics")
	orders.node.add_child(label)
	setup_tactics(orders, order_types.leader_tactics)
	var label2 = game.utils.label("set priority")
	orders.node.add_child(label2)
	setup_priority(orders)
	update()



func update():
	hide_all()
	if (game.selected_unit and 
			game.selected_unit.team == game.player_team and
			game.selected_unit.subtype != "backwood"):
		
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

