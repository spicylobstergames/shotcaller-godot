extends ItemList
var game:Node

var clear = false

var leader_orders = {}
var pawn_orders
var building_orders = {}

var enemy_leader_orders = {}
var enemy_pawn_orders = {}
var enemy_building_orders = {}


var button_template:PackedScene = load("res://orders/button/order_button.tscn")


onready var container = get_node("scroll_container/container")


var order_types = {
		# behavior   move      advance  advance    advance
		# tower     never  only full hp    yes      always
	"tactics": ["retreat","defend","default","attack"],
	"lane_tactics": ["defend","default","attack"],
	"priority": {
		"leader": [],
		"pawn": ["archer", "infantary", "mounted"],
		"building": ["tower", "barrack", "core"]
	},
	"combos": [],
	"leader_movement": ["retreat", "teleport", "lane", "ambush"],
	"buiding_defense": ["alarm bell", "teleport", "fortification"]
}

var hint_tooltips_tactics = {
	"retreat": "Retreat on first hit",
	"defend": "Retreat if less than half HP",
	"default": "Retreat if less than third HP",
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
	game.ui.orders_button.hide()
	update()


func setup_leaders():
	for leader in game.player_leaders:
		var orders = {
			"node": VBoxContainer.new(),
			"leader": leader
		}
		leader_orders[leader.name] = orders
		setup_leader_buttons(orders)
		container.add_child(orders.node)


func setup_pawns():
	var orders = {
		"node": VBoxContainer.new(),
		"type": "pawn"
	}
	pawn_orders = orders
	setup_pawn_buttons(orders)
	container.add_child(orders.node)


func setup_buildings():
	for unit_type in ["castle", "barrack", "tower"]:
		var orders = {
			"node": VBoxContainer.new(),
			"type": "building",
			"building": unit_type
		}
		building_orders[unit_type] = orders
		setup_building_buttons(orders)
		container.add_child(orders.node)



func setup_enemy_leaders():
	for leader in game.player_leaders:
		var orders = {
			"node": Node2D.new(),
			"type": "leader",
			"leader": leader
		}
		enemy_leader_orders[leader.name] = orders
		container.add_child(orders.node)


func setup_enemy_pawns():
	var orders = {
		"node": Node2D.new(),
		"type": "pawn"
	}
	enemy_pawn_orders = orders
	container.add_child(orders.node)



func setup_enemy_buildings():
	for unit_type in ["castle", "barrack", "tower"]:
		var orders = {
			"node": Node2D.new(),
			"type": "building",
			"building": unit_type
		}
		enemy_building_orders[unit_type] = orders
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
			button.set_pressed(true)
			button.set_disabled(true)
		buttons_container.add_child(button)
	orders.node.add_child(buttons_container)


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


func setup_pawn_buttons(orders):
	var label = game.utils.label("lane tactics")
	orders.node.add_child(label)
	setup_tactics(orders, order_types.lane_tactics)
	var label2 = game.utils.label("pawn priority")
	orders.node.add_child(label2)
	setup_priority(orders)


func setup_leader_buttons(orders):
	var label = game.utils.label("set tactics")
	orders.node.add_child(label)
	setup_tactics(orders, order_types.tactics)
	var label2 = game.utils.label("set priority")
	orders.node.add_child(label2)
	setup_priority(orders)
	update()

func setup_building_buttons(orders):
	if orders.building in ["barrack", "tower"]:
		var label = game.utils.label("lane tactics")
		orders.node.add_child(label)
		setup_tactics(orders, order_types.lane_tactics)
	var label2 = game.utils.label(orders.type+" priority")
	orders.node.add_child(label2)
	setup_priority(orders)


func update():
	hide_all()
	if (game.selected_unit and 
			game.selected_unit.team == game.player_team):
		var small = 232
		var large = 302
		match game.selected_unit.type:
			"pawn":
				game.ui.orders_button.show()
				game.ui.orders_window.margin_left = -small
				if not game.test.stress:
					pawn_orders.node.show()
			
			"leader":
				game.ui.orders_button.show()
				game.ui.orders_window.margin_left = -large
				if not game.test.stress:
					leader_orders[game.selected_unit.name].node.show()
			
			"building":
				game.ui.orders_button.show()
				game.ui.orders_window.margin_left = -small
				if not game.test.stress:
					building_orders[game.selected_unit.subtype].node.show()


func hide_all():
	for child in container.get_children():
		child.hide()
	for leader in leader_orders:
		leader_orders[leader].node.hide()
	for building in building_orders:
		building_orders[building].node.hide()



func orders_button_down():
	self.visible = !self.visible
	if self.visible:
		game.ui.shop_window.hide()
		game.ui.inventories.update_buttons()
