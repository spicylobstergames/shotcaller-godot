extends Button
var game:Node


onready var name_label = get_node("name")
onready var hint_label = get_node("hint")

var orders
var saved_icon
var counter = 0

func _ready():
	game = get_tree().get_current_scene()


func setup_order_button():
	var name = self.orders[self.orders.type]
	name_label.text = name
	var hint = str(get_index()+1)
	if "hint" in self.orders: hint = orders.hint
	hint_label.text = hint
	var icon_ref = self.icon
	if not icon_ref: icon_ref = self.saved_icon
	var icon = icon_ref.duplicate()
	var sprite
	match name:
		"building","extra room": sprite = 0
		"pawn","infantry": sprite = 1
		"ranged","fire arrows": sprite = 2
		"leader","mounted": sprite = 3
		"retreat": sprite = 4
		"defend","reinforce","armor": sprite = 5
		"default","boots": sprite = 6
		"attack","destroy","weapons": sprite = 7
		"hire": sprite = 8
		"low": sprite = 9
		"medium","dismiss": sprite = 10
		"high","collect": sprite = 11
		"menu": sprite = 12
		"order","teleport": sprite = 13
		
	icon.region.position.x = sprite * 48
	
	self.icon = icon


func button_down():
	match self.orders.type:
		"tactic":
			clear_siblings(self)
			if game.selected_unit.type == "leader":
				Behavior.orders.set_leader_tactic(self.orders.tactic)
			else: Behavior.orders.set_lane_tactic(self.orders.tactic)		
			self.disabled = true
		
		"priority":
			if not is_first_child(self):
				move_to_front(self)
				if game.selected_leader:
					Behavior.orders.set_leader_priority(self.orders.priority)
				else: Behavior.orders.set_lane_priority(self.orders.priority)
		
		"taxes":
			for button in game.ui.orders.tax_buttons:
				if button.orders.taxes == self.orders.taxes:
					button.pressed = true
					button.disabled = true
				else: 
					button.pressed = false
					button.disabled = false
			Behavior.orders.set_taxes(self.orders.taxes, game.selected_unit.team)
			self.disabled = true
		
		"gold":
			Behavior.orders.gold_order(self)
			disable_siblings(self)
			self.disabled = true
		
		"camp_hire":
			clear_siblings(self)
			Behavior.orders.camp_hire(self.orders.camp_hire, game.selected_unit.team)
			self.disabled = true
		
		"lumberjack":
			Behavior.spawn.lumberjack_hire(game.selected_unit, game.player_team)
			# update dismiss after lumberjack hire
			self.disabled = true
		
		"dismiss":
			#todo
			self.disabled = true
		
		"pawn_upgrades":
			Behavior.orders.pawn_upgrades(self.orders.pawn_upgrade)
			self.disabled = true
		
		"tower_upgrades":
			Behavior.orders.tower_upgrades(self.orders.pawn_upgrade)
			self.disabled = true


func clear_siblings(button):
	for child in button.get_parent().get_children():
		if child != button: 
			child.pressed = false
			child.disabled = false


func disable_siblings(button):
	for child in button.get_parent().get_children():
		if child != button: 
			child.disabled = true


func is_first_child(button):
	return button.get_parent().get_children()[0] == button


func move_to_front(button):
	var buttons = button.get_parent().get_children()
	for sibling_button in buttons:
		sibling_button.disabled = false
	button.get_parent().move_child(button, 0)
	button.disabled = true
