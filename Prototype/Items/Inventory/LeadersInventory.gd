extends HBoxContainer

var inventories = {}

var _equip_item_buttons = []
var _consumable_item_buttons = []
var _inventory_preload = preload("res://Items/Inventory/Inventory.tscn")
var _inventory_item_button_preload = preload("res://Items/Inventory/InventoryItemButton.tscn")
onready var _shop = get_node("../Shop")
onready var _gold_label = get_node("../GoldLabel")


func _ready():
	hide()
	# Setup GUI for inventory
	var inventory = _inventory_preload.instance()
	var counter = 0
	for i in range(inventory.EQUIP_ITEMS_MAX):
		var item_button = _inventory_item_button_preload.instance()
		_equip_item_buttons.append(item_button)
		add_child(item_button)
		item_button.index = counter
		counter += 1
		item_button.set_item_type_to_equip()
		item_button.setup(null)
	for i in range(inventory.CONSUMABLE_ITEMS_MAX):
		var item_button = _inventory_item_button_preload.instance()
		_consumable_item_buttons.append(item_button)
		add_child(item_button)
		item_button.index = counter
		counter += 1
		item_button.setup(null)


func add_inventory(leader):
	var new_inventory = _inventory_preload.instance()
	new_inventory.leader = leader
	inventories[leader.name] = new_inventory
	add_child(new_inventory)


func add_item(leader_name, new_item):
	inventories[leader_name].add_item(new_item)
	
	# THERE SHOULD BE LEADER SELECTION CODE
	return
	var leader
	#
	
	if new_item.type == new_item.ItemType.EQUIP:
		for key in new_item.attributes.keys():
			leader.attributes.stats[key] += new_item.attributes[key]
	
	if leader_name == leader.name:
		 update_gui(leader_name)


func _process(delta):
	# THERE SHOULD BE LEADER SELECTION CODE
	return
	var leader
	#
	
	var leader_inventory = inventories[leader.name]
	
	# Updating gold label
	_gold_label.text = str(leader_inventory.gold)
	
	# Hide or show sell buttons
	if _shop.visible:
		var counter = 0
		for item in leader_inventory.equip_items:
			_equip_item_buttons[counter].show_sell_button()
			counter += 1
		counter = 0
		for item in leader_inventory.consumable_items:
			_consumable_item_buttons[counter].show_sell_button()
			counter += 1
	else:
		for item_button in _equip_item_buttons + _consumable_item_buttons:
			item_button.sell_button.hide()


func update_gui(leader_name):
	var counter = 0
	for item in inventories[leader_name].equip_items:
		_equip_item_buttons[counter].setup(item)
		counter += 1
	counter = 0
	for item in inventories[leader_name].consumable_items:
		_consumable_item_buttons[counter].setup(item)
		counter += 1

