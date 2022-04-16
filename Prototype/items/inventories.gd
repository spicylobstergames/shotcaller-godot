extends Control
var game:Node

var clear = false
var gold = 0

const equip_items_max = 2
const consumable_items_max = 1

const delivery_time = 2

# Dictionary of all leaders inventories
var leaders = {}
var deliveries = {}


var item_button_preload = preload("res://items/button/item_button.tscn")
var sell_button_margin = 40


func _ready():
	yield(get_tree(), "idle_frame")
	game = get_tree().get_current_scene()
	
	hide()
	
	if not clear:
		var placeholder = self.get_node("placeholder")
		self.remove_child(placeholder)
		placeholder.queue_free()
		clear = true


func new_inventory():
	var inventory = {
		"container": HBoxContainer.new(),
		"gold": 0,
		"leader": null,
		"equip_items": [],
		"consumable_items":[],
		"equip_item_buttons": [],
		"consumable_item_buttons": []
	}
	#inventory.container.set("custom_constants/separation", 0)
	inventory.container.margin_top = sell_button_margin
# warning-ignore:unused_variable
	for index in range(equip_items_max):
		inventory.equip_items.append(null)
# warning-ignore:unused_variable
	for index in range(consumable_items_max):
		inventory.consumable_items.append(null)
	return inventory


func build_leaders():
	for leader in game.player_leaders:
		add_inventory(leader)


func add_inventory(leader):
	# Setup GUI for inventory
	var inventory = new_inventory()
	add_child(inventory.container)
	leaders[leader.name] = inventory
	inventory.leader = leader
	gold_timer_timeout(inventory)
	var counter = 0
	var item_button
# warning-ignore:unused_variable
	for i in range(equip_items_max):
		item_button = item_button_preload.instance()
		inventory.equip_item_buttons.append(item_button)
		inventory.container.add_child(item_button)
		item_button.index = counter
		counter += 1
		item_button.setup(null)
# warning-ignore:unused_variable
	for i in range(consumable_items_max):
		item_button = item_button_preload.instance()
		inventory.consumable_item_buttons.append(item_button)
		inventory.container.add_child(item_button)
		item_button.index = counter
		counter += 1
		item_button.setup(null)
		

func gold_timer_timeout(inventory):
		# Updating gold label
	inventory.gold += 10
	if game.selected_leader: game.ui.stats.update()
	game.ui.shop_window.update_buttons()
	yield(get_tree().create_timer(1), "timeout")
	gold_timer_timeout(inventory)



func equip_items_has_slots(leader_name):
	var inventory = leaders[leader_name]
	for item in inventory.equip_items:
		if item == null:
			return true
	return false



func consumable_items_has_slots(leader_name):
	var inventory = leaders[leader_name]
	for item in inventory.consumable_items:
		if item == null:
			return true
	return false



func add_delivery(leader, item):
	var new_delivery = {
		"item": item,
		"leader": leader,
		"time": delivery_time+1,
		"index": 0,
		"label": null,
		"button": null
	}
	deliveries[leader.name] = new_delivery
	
	var inventory = leaders[leader.name]
	
	if item.type == "equip":
		for index in range(equip_items_max):
			if inventory.equip_items[index] == null:
				new_delivery.index = index
				new_delivery.button = inventory.equip_item_buttons[index]
				new_delivery.label = new_delivery.button.price_label
				break
	elif item.type == "consumable":
		for index in range(consumable_items_max):
			if inventory.consumable_items[index] == null:
				new_delivery.index = index
				new_delivery.button = inventory.consumable_item_buttons[index]
				new_delivery.label = new_delivery.button.price_label
				break
	
	delivery_timer(new_delivery)


func delivery_timer(delivery):
	delivery.label.show()
	delivery.time -= 1
	if delivery.time > 0:
		delivery.label.text = "0:0"+str(delivery.time)
		yield(get_tree().create_timer(1), "timeout")
		delivery_timer(delivery)
	else:
		give_item(delivery)


func give_item(delivery):
	var leader = delivery.leader
	var inventory = leaders[leader.name]
	var item = delivery.item
	var index = delivery.index
	
	match item.type:
		"equip":
			inventory.equip_items[index] = item
			for key in item.attributes.keys():
				match key:
					"hp":
						leader.current_hp += item.attributes[key]
					"damage":
						leader.current_damage += item.attributes[key]
					
				leader[key] += item.attributes[key]
		"consumable":
			inventory.consumable_items[index] = item
	
	deliveries.erase(leader.name)
	
	leader.get_node("hud").update_hpbar(leader)
	update_gui(leader.name)



func remove_item(leader, index):
	var leader_items = leaders[leader.name].equip_items + leaders[leader.name].consumable_items
	var item = leader_items[index]
	
	if item.type == "equip":
		# Remove attributes that were added when purchasing an item
		for key in item.attributes.keys():
			match key:
				"hp":
					leader.current_hp -= item.attributes[key]
				"damage":
					leader.current_damage -= item.attributes[key]
			leader[key] -= item.attributes[key]
			
		leaders[leader.name].equip_items[index] = null
	elif item.type == "consumable":
		leaders[leader.name].consumable_items[index - equip_items_max] = null
	
	leader.get_node("hud").update_hpbar(leader)
	update_gui(leader.name)
	
	return item



func update_gui(leader_name):
	var counter = 0
	var inventory = leaders[leader_name]
	for item in inventory.equip_items:
		inventory.equip_item_buttons[counter].setup(item)
		counter += 1
	counter = 0
	for item in inventory.consumable_items:
		inventory.consumable_item_buttons[counter].setup(item)
		counter += 1
		
	update_buttons()
	game.ui.stats.update()



func update_buttons():
	for leader in leaders:
		leaders[leader].container.hide()
	
	if game.selected_leader and game.selected_leader.name in leaders:
		var inventory = leaders[game.selected_leader.name]
		
		show()
		inventory.container.show()
		
		# Hide or show sell buttons
		if game.ui.shop_window.visible:
			var counter = 0
			for item in inventory.equip_items:
				inventory.equip_item_buttons[counter].show_sell_button()
				counter += 1
			counter = 0
			for item in inventory.consumable_items:
				inventory.consumable_item_buttons[counter].show_sell_button()
				counter += 1
		else:
			for item_button in inventory.equip_item_buttons + inventory.consumable_item_buttons:
				item_button.sell_button.hide()


func move_down():
	get_parent().remove_child(self)
	game.ui.get_node("bot_right/inventory").add_child(self)

func move_up():
	get_parent().remove_child(self)
	game.ui.get_node("top_right/inventory").add_child(self)
