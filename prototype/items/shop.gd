extends Panel
var game:Node

# self = game.ui.shop

var item_button_preload = preload("res://ui/buttons/item_button.tscn")
var cleared =false

onready var container = get_node("scroll_container/container")
onready var equip_items = container.get_node("equip_items")
onready var consumable_items = container.get_node("consumable_items")
onready var throwable_items = container.get_node("throwable_items")

var blacksmiths

const items = {
	# Offensive
	"axe": {
		"name": "Axe",
		"sprite": 0,
		"tooltip": "Used to chop wood, now used for war\nDamage +25",
		"attributes": {"damage": 25},
		"price": 250,
		"type": "equip",
		"delivery_time": 20
	},
	"sword": {
		"name": "Sword",
		"sprite": 1,
		"tooltip": "Forged of pure high-carbon steel\nDamage +50 Attack speed +50%",
		"attributes": {"damage": 50, "attack_speed": .5},
		"price": 500,
		"type": "equip",
		"delivery_time": 30
	},
	"bow": {
		"name": "Elven\nBow",
		"sprite": 2,
		"tooltip": "\nDamage +20, Attack speed +25% Range +40%",
		"attributes": {"damage": 20, "attack_speed": .25, "attack_range": .4},
		"price": 500,
		"type": "equip",
		"delivery_time": 30
	},

	# Defensive
	"helmet": {
		"name": "Helmet",
		"sprite": 3,
		"tooltip": "Adds 150 HP",
		"attributes": {"hp": 150},
		"price": 300,
		"type": "equip",
		"delivery_time": 20
	},
	"great_helm": {
		"name": "Great\nHelm",
		"sprite": 4,
		"tooltip": "Adds 150 HP Defense +5",
		"attributes": {"hp": 200, "defense": 5},
		"price": 500,
		"type": "equip",
		"delivery_time": 20
	},
	"boots": {
		"name": "Boots",
		"sprite": 5,
		"tooltip": "Protect your feet from the ground\nSpeed +15",
		"attributes": {"speed": 15},
		"price": 300,
		"type": "equip",
		"delivery_time": 15
	},
	"shield": {
		"name": "Shield",
		"sprite": 6,
		"tooltip": "Wooden shield\nHealth +50",
		"attributes": {"hp": 100},
		"price": 200,
		"type": "equip",
		"delivery_time": 30
	},
	"holy_shield": {
		"name": "Holy\nShield",
		"sprite": 7,
		"tooltip": "Magically reinforced, stronger than steel\nHealth +200 Vision +50",
		"attributes": {"hp": 150, "vision": 50},
		"price": 450,
		"type": "equip",
		"delivery_time": 30,
		"passive": "res://items/passives/holy_shield.tscn" # nearby units +50 health
	},
	"scale": {
		"name": "Dragon\nscale",
		"sprite": 8,
		"tooltip": "No dragons were harmed in the making of this armor\nHealth +300 Defense +4 Speed -10",
		"attributes": {"hp": 300, "defense": 4, "speed": -10},
		"price": 500,
		"type": "equip",
		"delivery_time": 30
	},


	# Utility
	"torch": {
		"name": "Torch",
		"sprite": 9,
		"tooltip": "This torch will never burn out\nVision +50",
		"attributes": {"vision": 50},
		"price": 150,
		"type": "equip",
		"delivery_time": 15
	},
	"feather": {
		"name": "Magic\nFeather",
		"sprite": 10,
		"tooltip": "A feather imbued with magical force\nRegen +2 Speed +15",
		"attributes": {"regen": 2, "speed": 5}, # Other 10 comes from passive
		"price": 350,
		"type": "equip",
		"delivery_time": 15,
		"passive": "res://items/passives/feather.tscn" # nearby units +10 speed
	},
	"eye": {
		"name": "Oligan's\nEye",
		"sprite": 11,
		"tooltip": "The Eye has helped heroes navigate the battlefield for centuries\nVision +100 Speed +10",
		"attributes": {"vision": 100, "speed": 10},
		"price": 350,
		"type": "equip",
		"delivery_time": 30
	},

	# Consumables
	"small_hp": {
		"name": "Small\nHealth",
		"sprite": 12,
		"tooltip": "Restore 100 HP",
		"attributes": {"current_hp": 100},
		"price": 50,
		"type": "consumable",
		"delivery_time": 10
	},
	"medium_hp": {
		"name": "Medium\nHealth",
		"sprite": 13,
		"tooltip": "Restore 150 HP",
		"attributes": {"current_hp": 150},
		"price": 75,
		"type": "consumable",
		"delivery_time": 15
	},
	"large_hp": {
		"name": "Large\nHealth",
		"sprite": 14,
		"tooltip": "Restore 250 HP",
		"attributes": {"current_hp": 250},
		"price": 125,
		"type": "consumable",
		"delivery_time": 20
	},
	"small_poison_bomb": {
		"name": "Small\nPoison",
		"sprite": 15,
		"tooltip": "Slows down and deals 10 damage per second for 5 seconds",
		"attributes": {"dot": 10, "speed": -10},
		"price": 75,
		"type": "throwable",
		"delivery_time": 15,
		"duration": 5
	},
	"medium_poison_bomb": {
		"name": "Medium\nPoison",
		"sprite": 16,
		"tooltip": "Slows down and deals 15 damage per second for 5 seconds",
		"attributes": {"dot": 15, "speed": -20},
		"price": 100,
		"type": "throwable",
		"delivery_time": 30,
		"duration": 5
	},
	"large_poison_bomb": {
		"name": "Large\nPoison",
		"sprite": 17,
		"tooltip": "Slows down and deals 25 damage per second for 5 seconds",
		"attributes": {"dot": 25, "speed": -30},
		"price": 175,
		"type": "throwable",
		"delivery_time": 50,
		"duration": 5
	}
}


func _ready():
	game = get_tree().get_current_scene()

	hide()

	clear()

	for item in items:
		var new_item = items[item].duplicate(true)
		new_item.ready = false
		new_item.delivered = false
		add_item(new_item)

	disable_all()

	yield(get_tree(), "idle_frame")


func clear():
	if not cleared:
		for placeholder_item in equip_items.get_children():
			equip_items.remove_child(placeholder_item)
			placeholder_item.queue_free()

		for placeholder_item in consumable_items.get_children():
			consumable_items.remove_child(placeholder_item)
			placeholder_item.queue_free()
		
		for placeholder_item in throwable_items.get_children():
			throwable_items.remove_child(placeholder_item)
			placeholder_item.queue_free()

		cleared = true


func add_item(item):
	item.sell_price = floor(item.price / 2)
	var new_item_button = item_button_preload.instance()
	new_item_button.shop_item = true
	if item.type == "consumable": consumable_items.add_child(new_item_button)
	elif item.type == "throwable":throwable_items.add_child(new_item_button)
	else: equip_items.add_child(new_item_button)
	new_item_button.setup(item)


func disable_all():
	for item_button in equip_items.get_children() + consumable_items.get_children() + throwable_items.get_children():
		item_button.disabled = true


func disable_equip():
	for item_button in equip_items.get_children():
		item_button.disabled = true


func close_to_blacksmith(leader):
	for blacksmith in blacksmiths:
		var distance = leader.global_position.distance_to(blacksmith.global_position)
		if distance < Behavior.modifiers.get_value(leader, "vision"):
			return true
	return false


func update_buttons():
	if visible:
		var leader = game.selected_leader
		var trader = null
		
		if leader != null:
			trader = leader.get_node_or_null("behavior/abilities/trader")
		
		# checks if leader has trader ability, updates price labels
		if trader != null:
			for item_button in equip_items.get_children() + consumable_items.get_children() + throwable_items.get_children():
				var price = item_button.item.price
				item_button.price_after_discount = price - price * (float(trader.VALUE * leader.level)/100)
				item_button.price_after_discount = int(item_button.price_after_discount)
				item_button.price_label.text = str(item_button.price_after_discount)
		else:
			for item_button in equip_items.get_children() + consumable_items.get_children() + throwable_items.get_children():
				item_button.price_after_discount = item_button.item.price
				item_button.price_label.text = str(item_button.price_after_discount)
		
		
		# disable all buttons if no leader selected or if delivery in proccess
		if not leader or game.ui.inventories.is_delivering(leader):
			disable_all()
			return

		# disable equip if leader is not close to shop
		if not close_to_blacksmith(leader):
			disable_equip()

		# enable/disable buttons on which leader don't have enough golds
		var inventory = game.ui.inventories.get_leader_inventory(leader)
		if leader and inventory:
			for item_button in equip_items.get_children() + consumable_items.get_children() + throwable_items.get_children():
				var item_price = item_button.item.price
				item_button.disabled = (leader.gold < item_price)

		# disable buttons if leader don't have empty slots for item
		if leader and inventory:
			if !game.ui.inventories.equip_items_has_slots(leader):
				for item_button in equip_items.get_children():
					item_button.disabled = true
			if !game.ui.inventories.consumable_items_has_slots(leader):
				for item_button in consumable_items.get_children():
					item_button.disabled = true
			if !game.ui.inventories.consumable_items_has_slots(leader):
				for item_button in throwable_items.get_children():
					item_button.disabled = true

