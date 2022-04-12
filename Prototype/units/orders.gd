extends Node
var game:Node


var button_template:PackedScene = load("res://ui/order_button.tscn")


var order_types = {
		# speed:     fast        slow   default"     fast 
		# behavior   move      advance  advance    advance
		# tower     never  only full hp    yes      always
	"tactics": ["escape","defensive","default","aggressive"],
	"lane_tactics": ["defensive","default","aggressive"],
	"priority": {
		"leaders": [],
		"pawns": ["archer", "infantary", "mounted"],
		"buildings": ["tower", "barrack", "core"]
	},
	"combos": [],
	"leader_movement": ["retreat", "teleport", "lane", "ambush"],
	"buiding_defense": ["alarm bell", "teleport", "fortification"]
}

#var unit_types = {
#	"pawns": ["lane_tactics", "priority"],
#	"leaders":  ["leader_movement", "combos", "tactics", "priority"],
#	"buildings": {
#		"tower": ["lane_tactics", "buiding_defense", "priority"],
#		"barrack": ["lane_tactics", "buiding_defense", "priority"],
#		"core": ["buiding_defense", "priority"]
#	}
#}


func _ready():
	game = get_tree().get_current_scene()


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


func setup_building_buttons(orders):
	if orders.type in ["barrack", "tower"]:
		var label = game.utils.label("lane tactics")
		orders.node.add_child(label)
		setup_tactics(orders, order_types.lane_tactics)
	var label2 = game.utils.label(orders.type+" priority")
	orders.node.add_child(label2)
	setup_priority(orders)

func setup_tactics(orders, tactics):
	var buttons_container = HBoxContainer.new()
	for tactic in tactics:
		var button = button_template.instance()
		button.text = tactic
		button.orders = {
			"order": orders,
			"type": "tactic",
			"tactic": tactic
		}
		buttons_container.add_child(button)
	orders.node.add_child(buttons_container)



func setup_priority(orders):
	var buttons_container = HBoxContainer.new()
	for priority in order_types.priority:
		var button = button_template.instance()
		button.text = priority
		button.orders =  {
			"order": orders,
			"type": "priority",
			"priority": priority
		}
		buttons_container.add_child(button)
	orders.node.add_child(buttons_container)
		# add submenu buttons

