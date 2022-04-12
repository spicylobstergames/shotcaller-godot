extends ItemList
var game:Node

var leader_orders = {}
var pawn_orders
var building_orders = {}

var enemy_leader_orders = {}
var enemy_unit_orders = {}
var enemy_building_orders = {}

func _ready():
	game = get_tree().get_current_scene()
	hide()

func setup():
	setup_leaders()
	setup_pawns()
	setup_buildings()


func update():
	hide()
	hide_all()
	if game.selected_unit and game.selected_unit.team == game.player_team:
		match game.selected_unit.type:
			"pawn":
				show()
				pawn_orders.node.show()
			
			"leader":
				show()
				leader_orders[game.selected_unit.name].node.show()
			
			"building":
				show()
				building_orders[game.selected_unit.subtype].node.show()


func hide_all():
	for child in self.get_children():
		child.hide()
	for leader in leader_orders:
		leader_orders[leader].node.hide()
	for building in building_orders:
		building_orders[building].node.hide()



func setup_leaders():
	for leader in game.player_leaders:
		var orders = {
			"node": VBoxContainer.new(),
			"leader": leader
		}
		leader_orders[leader.name] = orders
		game.unit.orders.setup_leader_buttons(orders)
		self.add_child(orders.node)


func setup_pawns():
	var orders = {
		"node": VBoxContainer.new(),
		"type": "pawn"
	}
	pawn_orders = orders
	game.unit.orders.setup_pawn_buttons(orders)
	self.add_child(orders.node)


func setup_buildings():
	for unit_type in ["castle", "barrack", "tower"]:
		var orders = {
			"node": VBoxContainer.new(),
			"type": unit_type
		}
		building_orders[unit_type] = orders
		game.unit.orders.setup_building_buttons(orders)
		self.add_child(orders.node)



func setup_enemy_leaders():
	for leader in game.player_leaders:
		var orders = {
			"node": Node2D.new(),
			"leader": leader
		}
		enemy_leader_orders[leader.name] = orders
		self.add_child(orders.node)


func setup_enemy_units():
	for unit_type in ["infantary", "archer"]:
		var orders = {
			"node": Node2D.new(),
			"type": unit_type
		}
		enemy_unit_orders[unit_type] = orders
		self.add_child(orders.node)


func setup_enemy_buildings():
	for unit_type in ["castle", "barrack", "tower"]:
		var orders = {
			"node": Node2D.new(),
			"type": unit_type
		}
		enemy_building_orders[unit_type] = orders
		self.add_child(orders.node)
