extends Panel
var game:Node

# self = game.ui.shop

var item_button_preload = preload("res://items/button/item_button.tscn")
var cleared =false

onready var container = get_node("scroll_container/container")
onready var equip_items = container.get_node("equip_items")
onready var consumable_items = container.get_node("consumable_items")

var blacksmiths

const items = {
	"axe": {
		"name" :"Axe", 
		"sprite": 0, 
		"tooltip": "Adds 25 damage", 
		"attributes": {"damage": 25},
		"price": 250,  
		"type": "equip", 
		"delivery_time": 20
	},
	"helmet": {
		"name": "Helmet", 
		"sprite": 1, 
		"tooltip": "Adds 150 HP", 
		"attributes": {"hp": 150},
		"price": 300, 
		"type": "equip", 
		"delivery_time": 25
	},
	"potion": {
		"name": "Potion", 
		"sprite": 2, 
		"tooltip": "Restore 100 HP",
		"attributes": {"current_hp": 100},
		"price": 50, 
		"type": "consumable", 
		"delivery_time": 10
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
	
	blacksmiths = [
		game.map.get_node("buildings/blue/blacksmith"),
		game.map.get_node("buildings/red/blacksmith")
	]


func clear():
	if not cleared:
		for placeholder_item in equip_items.get_children():
			equip_items.remove_child(placeholder_item)
			placeholder_item.queue_free()
		
		for placeholder_item in consumable_items.get_children():
			consumable_items.remove_child(placeholder_item)
			placeholder_item.queue_free()
		
		cleared = true


func add_item(item):
	item.sell_price = floor(item.price / 2)
	var new_item_button = item_button_preload.instance()
	new_item_button.shop_item = true
	if item.type == "consumable": consumable_items.add_child(new_item_button)
	else: equip_items.add_child(new_item_button)
	new_item_button.setup(item)


func disable_all():
	for item_button in equip_items.get_children() + consumable_items.get_children():
		item_button.disabled = true


func disable_equip():
	for item_button in equip_items.get_children():
		item_button.disabled = true


func close_to_blacksmith(leader):
	for blacksmith in blacksmiths:
		var distance = leader.global_position.distance_to(blacksmith.global_position)
		if distance < game.unit.modifiers.get_value(leader, "vision"):
			return true
	return false



func update_buttons():
	if visible:
		var leader = game.selected_leader
		
		
		# disable all buttons if no leader selected or if delivery in proccess
		if not leader or game.ui.inventories.is_delivering(leader): 
			disable_all()
			return
		
		# enable/disable all buttons on which leader don't have enough golds
		if leader and leader.name in game.ui.inventories.leaders:
			for item_button in equip_items.get_children() + consumable_items.get_children():
				var item_price = item_button.item.price
				item_button.disabled = (leader.gold < item_price)
		
		# disable equip if leader is not close to shop
		if not close_to_blacksmith(leader):
			disable_equip()
		
		# disable buttons if leader don't have empty slots for item
		if leader and leader.name in game.ui.inventories.leaders:
			if !game.ui.inventories.equip_items_has_slots(leader.name):
				for item_button in equip_items.get_children():
					item_button.disabled = true
			if !game.ui.inventories.consumable_items_has_slots(leader.name):
				for item_button in consumable_items.get_children():
					item_button.disabled = true

