extends Control
var game:Node

const Item = preload("res:///items/item.gd")

# Dictionary of all leaders inventories
var inventories = {}

var _inventory_preload = preload("res://items/inventory/inventory.tscn")
var _inventory_item_button_preload = preload("res://items/inventory/inventory_item_button.tscn")

var shop_window:Node
var gold = 0
var _gold_timer


func _ready():
	yield(get_tree(), "idle_frame")
	game = get_tree().get_current_scene()
	shop_window = game.ui.shop_window
	hide()


func add_inventory(leader):
	
	# Setup GUI for inventory
	var inventory = _inventory_preload.instance()
	inventory.leader = leader
	
	inventories[leader.name] = inventory
	add_child(inventory)
	var counter = 0
# warning-ignore:unused_variable
	for i in range(inventory.EQUIP_ITEMS_MAX):
		var item_button = _inventory_item_button_preload.instance()
		inventory._equip_item_buttons.append(item_button)
		inventory.add_child(item_button)
		item_button.index = counter
		counter += 1
		item_button.set_item_type_to_equip()
		item_button.setup(null)
		
# warning-ignore:unused_variable
	for i in range(inventory.CONSUMABLE_ITEMS_MAX):
		var item_button = _inventory_item_button_preload.instance()
		inventory._consumable_item_buttons.append(item_button)
		inventory.add_child(item_button)
		item_button.index = counter
		counter += 1
		item_button.setup(null)


func add_timer(_leader, _item):
	#print(_leader)
	pass


func give_item(leader, new_item):
	inventories[leader.name].add_item(new_item)
	
	if new_item.type == new_item.ItemType.EQUIP:
		for key in new_item.attributes.keys():
			if key in leader:
				leader[key] += new_item.attributes[key]
	
	update_gui(leader.name)


func remove_item(leader, index):
	var leader_items = inventories[leader.name].equip_items + inventories[leader.name].consumable_items
	var item = leader_items[index]
	
	if item.type == Item.ItemType.EQUIP:
		# Remove attributes that were added when purchasing an item
		for key in item.attributes.keys():
			leader.attributes.stats[key] -= item.attributes[key]
		inventories[leader.name].equip_items[index] = null
	elif item.type == Item.ItemType.CONSUMABLE:
		inventories[leader.name].consumable_items[index - inventories[leader.name].EQUIP_ITEMS_MAX] = null
	
	update_gui(leader.name)
	
	return item


func update_gui(leader_name):
	var counter = 0
	var inventory = inventories[leader_name]
	for item in inventory.equip_items:
		inventory._equip_item_buttons[counter].setup(item)
		counter += 1
	counter = 0
	for item in inventory.consumable_items:
		inventory._consumable_item_buttons[counter].setup(item)
		counter += 1
	update_buttons()

func update_buttons():
	show()
	for leader in inventories:
		inventories[leader].hide()
	
	if game.selected_leader and game.selected_leader.name in inventories:
		var inventory = inventories[game.selected_leader.name]
		inventory.show()
		# Hide or show sell buttons
		if shop_window.visible:
			var counter = 0
			for item in inventory.equip_items:
				inventory._equip_item_buttons[counter].show_sell_button()
				counter += 1
			counter = 0
			for item in inventory.consumable_items:
				inventory._consumable_item_buttons[counter].show_sell_button()
				counter += 1
		else:
			for item_button in inventory._equip_item_buttons + inventory._consumable_item_buttons:
				item_button.hide_sell_button()
