extends Panel
var game:Node

var item_button_preload = preload("res://items/button/item_button.tscn")
var clear =false

onready var container = get_node("scroll_container/container")
onready var equip_items = container.get_node("equip_items")
onready var consumable_items = container.get_node("consumable_items")



func _ready():
	yield(get_tree(), "idle_frame")
	game = get_tree().get_current_scene()
	
	hide()
	game.ui.shop_button.hide()
	
	if not clear:
		for placeholder_item in equip_items.get_children():
			equip_items.remove_child(placeholder_item)
			placeholder_item.queue_free()
		
		for placeholder_item in consumable_items.get_children():
			consumable_items.remove_child(placeholder_item)
			placeholder_item.queue_free()
		
		container.get_node("placeholder").hide()
		container.get_node("placeholder_items").hide()
		
		clear = true


	# Test items
	add_item(build_item("Axe", 0, "Add 20 damage to the leader's attack", 10,  "equip", {"damage": 20}))
	add_item(build_item("Helmet", 1, "Add 50 HP to leader stats", 20, "equip", {"hp": 50}))
	add_item(build_item("Potion", 2, "Restore 50 HP", 5, "consumable", {"current_hp": 50}))
	
	game.ui.shop_window.disable_all()


func build_item(name, sprite, description, price, type, attributes):
	var item = {
		"name": name,
		"sprite": sprite,
		"description": description,
		"price": price,
		"sell_price": floor(price / 2),
		"type": type,
		"attributes": attributes
	}
	return item


func add_item(item):
	var new_item_button = item_button_preload.instance()
	new_item_button.shop_item = true
	if item.type == "consumable": consumable_items.add_child(new_item_button)
	else: equip_items.add_child(new_item_button)
	new_item_button.setup(item)


func disable_all():
	# Disable all buttons because leader is not selected or if delivery in proccess
	for item_button in equip_items.get_children() + consumable_items.get_children():
		item_button.disabled = true
	return


func update_buttons():
	if visible:
		var leader = game.selected_leader
		if not leader or leader.name in game.ui.inventories.deliveries: 
			disable_all()
			return
		
		# Disable all buttons on which leader don't have enough golds
		for item_button in equip_items.get_children() + consumable_items.get_children():
			if leader and leader.name in game.ui.inventories.leaders:
				var leader_gold = game.ui.inventories.leaders[leader.name].gold
				var item_price = item_button.item.price
				item_button.disabled = (leader_gold < item_price)
		
		
		# Disable buttons if leader don't have empty slots for item
		if leader and leader.name in game.ui.inventories.leaders:
			if !game.ui.inventories.equip_items_has_slots(leader.name):
				for item_button in equip_items.get_children():
					item_button.disabled = true
			if !game.ui.inventories.consumable_items_has_slots(leader.name):
				for item_button in consumable_items.get_children():
					item_button.disabled = true



func shop_button_down():
	self.visible = !self.visible
	game.ui.inventories.update_buttons()
	if self.visible:
		game.ui.shop_window.update_buttons()
		game.ui.orders_window.hide()
