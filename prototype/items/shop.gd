extends Panel
var game:Node

# self = game.ui.shop

var item_button_preload = preload("res://items/button/item_button.tscn")
var clear =false

onready var container = get_node("scroll_container/container")
onready var equip_items = container.get_node("equip_items")
onready var consumable_items = container.get_node("consumable_items")


const items = {
	"axe": {
		"name" :"Axe", 
		"sprite": 0, 
		"tooltip": "Adds 25 damage", 
		"attributes": {"damage": 25},
		"price": 600,  
		"type": "equip", 
		"delivery_time": 10
	},
	"helmet": {
		"name": "Helmet", 
		"sprite": 1, 
		"tooltip": "Adds 150 HP", 
		"attributes": {"hp": 150},
		"price": 500, 
		"type": "equip", 
		"delivery_time": -1
	},
	"potion": {
		"name": "Potion", 
		"sprite": 2, 
		"tooltip": "Restore 50 HP",
		"price": 5, 
		"type": "consumable", 
		"attributes": {"current_hp": 50},
		"delivery_time": -1
	}
}


func _ready():
	game = get_tree().get_current_scene()
	
	hide()
	
	if not clear:
		for placeholder_item in equip_items.get_children():
			equip_items.remove_child(placeholder_item)
			placeholder_item.queue_free()
		
		for placeholder_item in consumable_items.get_children():
			consumable_items.remove_child(placeholder_item)
			placeholder_item.queue_free()
		
		clear = true


	for item in items:
		add_item(items[item].duplicate(1))
	
	disable_all()



func add_item(item):
	item.sell_price = floor(item.price / 2)
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

