extends Control
var game:Node

# self = game.ui.inventories

var cleared = false

const equip_items_max = 2
const consumable_items_max = 1

const delivery_time = 2

# Dictionary of all leaders inventories
var player_leaders_inv = {}
var player_deliveries = {}

var enemy_leaders_inv = {}
var enemy_deliveries = {}


var item_button_preload = preload("res://ui/buttons/item_button.tscn")
var sell_button_margin = 40


func _ready():
	game = get_tree().get_current_scene()

	hide()
	clear()


func clear():
	if not cleared:
		var placeholder = self.get_node("placeholder")
		self.remove_child(placeholder)
		placeholder.queue_free()
		cleared = true


func new_inventory(leader):
	var extra_skill_gold = 0
	if leader.display_name in Behavior.skills.leader:
		var leader_skills = Behavior.skills.leader[leader.display_name]
		if "extra_gold" in leader_skills:
				extra_skill_gold = leader_skills.extra_gold

	var inventory = {
		"container": HBoxContainer.new(),
		"extra_skill_gold": extra_skill_gold,
		"extra_tax_gold": 0,
		"extra_mine_gold": 0,
		"leader": null,
		"equip_items": [],
		"consumable_items":[],
		"equip_item_buttons": [],
		"consumable_item_buttons": []
	}

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
	for leader in game.enemy_leaders:
		add_inventory(leader)
	EventMachine.register_listener(Events.ONE_SEC, self, "gold_update_cycle")


func get_leader_inventory(leader):
	if leader.type == 'leader':
		var inv = player_leaders_inv
		if not leader.team == game.player_team:
			inv = enemy_leaders_inv
		if leader.name in inv: return inv[leader.name]


func set_leader_inventory(leader, inventory):
	if leader.type == 'leader':
		var inv = player_leaders_inv
		if not leader.team == game.player_team:
			inv = enemy_leaders_inv

		inventory.leader = leader
		inv[leader.name] = inventory


func get_leader_delivery(leader):
	if leader.type == 'leader':
		var deliv = player_deliveries
		if not leader.team == game.player_team:
			deliv = enemy_deliveries
		if leader.name in deliv: return deliv[leader.name]

func gold_timer(unit):
	EventMachine.register_listener(Events.ONE_SEC, self, "gold_timer_timeout",[unit])

func set_leader_delivery(leader, delivery):
	if leader.type == 'leader':
		var deliv = player_deliveries
		if not leader.team == game.player_team:
			deliv = enemy_deliveries
		deliv[leader.name] = delivery


func gold_update_cycle():
	if not game.paused:
		game.ui.shop.update_buttons()
		update_buttons()


func add_inventory(leader):
	# Setup GUI for inventory
	var inventory = new_inventory(leader)
	add_child(inventory.container)
	set_leader_inventory(leader, inventory)
	EventMachine.register_listener(Events.ONE_SEC, self, "gold_timer_timeout",[leader])
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


func gold_timer_timeout(unit):
	if not game.paused:
		var inventory = get_leader_inventory(unit)
		var gold_per_sec = 1
		if inventory:
			gold_per_sec += inventory.extra_skill_gold
			gold_per_sec += inventory.extra_tax_gold
			gold_per_sec += inventory.extra_mine_gold
		unit.gold += gold_per_sec
		# Updates gold label
		if unit == game.selected_unit: game.ui.stats.update()


func equip_items_has_slots(leader):
	var inventory = get_leader_inventory(leader)
	for item in inventory.equip_items:
		if item == null:
			return true
	return false



func consumable_items_has_slots(leader):
	var inventory = get_leader_inventory(leader)
	for item in inventory.consumable_items:
		if item == null:
			return true
	return false



func add_delivery(leader, item):
	var new_delivery = {
		"item": item,
		"leader": leader,
		"time": item.delivery_time+1,
		"index": 0,
		"label": null,
		"button": null
	}
	set_leader_delivery(leader, new_delivery)
	var inventory = get_leader_inventory(leader)

	if item.type == "equip":
		for index in range(equip_items_max):
			if inventory.equip_items[index] == null:
				new_delivery.index = index
				new_delivery.button = inventory.equip_item_buttons[index]
				break
	elif item.type == "consumable":
		for index in range(consumable_items_max):
			if inventory.consumable_items[index] == null:
				new_delivery.index = index
				new_delivery.button = inventory.consumable_item_buttons[index]
				break
	elif item.type == "throwable":
		for index in range(consumable_items_max):
			if inventory.consumable_items[index] == null:
				new_delivery.index = index
				new_delivery.button = inventory.consumable_item_buttons[index]
				break
				
	new_delivery.label = new_delivery.button.price_label
	delivery_timer(new_delivery)


func delivery_timer(delivery):
	if not game.paused:
		delivery.label.show()
		delivery.time -= 1
		if delivery.time > 0:
			delivery.label.text = "0:0"+str(delivery.time)
		else:
			match delivery.item.type:
				"consumable": give_item(delivery)
				"throwable": give_item(delivery)
				"equip":
					if game.ui.shop.close_to_blacksmith(delivery.leader):
						give_item(delivery)
					else:
						var inventory = get_leader_inventory(delivery.leader)
						var index = delivery.index
						inventory.equip_items[index] = delivery.item
						delivery.item.ready = true
						delivery.label.text = "ready"

	yield(get_tree().create_timer(1), "timeout")
	if delivery.time > 0: delivery_timer(delivery)


func is_delivering(leader):
	var delivery = get_leader_delivery(leader)
	if delivery: return (delivery.time > 0)
	return false


func give_item(delivery):
	var leader = delivery.leader
	var inventory = get_leader_inventory(leader)
	var item = delivery.item
	var index = delivery.index

	get_leader_delivery(leader).erase(leader.name)

	match item.type:
		"equip":
			inventory.equip_items[index] = item
			inventory.equip_item_buttons[index].setup(item)
			for key in item.attributes.keys():
				Behavior.modifiers.add(leader, key, item.name, item.attributes[key])
			if "passive" in item:
				var item_scene = load(item.passive)
				leader.get_node("behavior/item_passives").add_child(item_scene.instance())

		"consumable":
			inventory.consumable_items[index] = item
			inventory.consumable_item_buttons[index].setup(item)
		"throwable":
			inventory.consumable_items[index] = item
			inventory.consumable_item_buttons[index].setup(item)
	item.delivered = true

	leader.hud.update_hpbar()



func remove_item(leader, index):
	var inventory = get_leader_inventory(leader)

	var leader_items = inventory.equip_items + inventory.consumable_items
	var item = leader_items[index]

	if item.type == "equip":
		# Remove attributes that were added when purchasing an item
		for key in item.attributes.keys():
			Behavior.modifiers.remove(leader, key, item.name, item.attributes[key])

		inventory.equip_items[index] = null

	elif item.type == "consumable":
		inventory.consumable_items[index - equip_items_max] = null
		
	elif item.type == "throwable":
		inventory.consumable_items[index - equip_items_max] = null

	leader.hud.update_hpbar()

	return item



	# Disable potion if full heath
	# Disable poison if no target

func update_consumables(leader):
	var inventory = get_leader_inventory(leader)
	var counter = 0
	
	for item in inventory.consumable_items:
		var item_button = inventory.consumable_item_buttons[counter]
		if item != null and item.type == "consumable":
			item_button.disabled = (leader.current_hp >= Behavior.modifiers.get_value(leader, "hp"))
			counter += 1
		elif item != null and item.type  == "throwable":
			var enemy_leaders_on_sight = leader.get_enemy_leaders_on_sight(leader)
			item_button.disabled = (enemy_leaders_on_sight.empty())

func update_buttons():
	for leader in game.player_leaders + game.enemy_leaders:
		var inventory = get_leader_inventory(leader)
		var close_to_blacksmith = game.ui.shop.close_to_blacksmith(leader)
		inventory.container.hide()
		# deliver ready items
		if close_to_blacksmith:
			for item in inventory.equip_items:
				if item and item.ready and not item.delivered:
					var delivery = get_leader_delivery(leader)
					give_item(delivery)

	if game.selected_leader:
		var inventory = get_leader_inventory(game.selected_leader)
		var leader = game.selected_leader
		var close_to_blacksmith = game.ui.shop.close_to_blacksmith(leader)

		show()
		inventory.container.show()
		update_consumables(leader)

		# toggle sell buttons
		if game.ui.shop.visible and close_to_blacksmith:
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

