extends Control
var game:Node

# self = game.ui.shop

var item_button_preload = preload("res://ui/buttons/item_button.tscn")
var cleared = false

@onready var equip_items = $"%equip_items"
@onready var consumable_items = $"%consumable_items"
@onready var throwable_items = $"%throwable_items"

var blacksmiths := []

var items := [
	"axe",
	"sword",
	"bow",
	"helm",
	"great_helm",
	"boots",
	"shield",
	"holy_shield",
	"scale",
	"torch",
	"plume",
	"eye",
	"small_hp",
	"medium_hp",
	"large_hp",
	"small_poison",
	"medium_poison",
	"large_poison"
]


func _ready():
	game = get_tree().get_current_scene()
	hide()
	clear()
	
	for item in items:
		var new_item = load("res://item/resources/"+item+".tres").duplicate(true)
		add_item(new_item)
	
	disable_all()



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
	var new_item_button = item_button_preload.instantiate()
	new_item_button.shop_item = true
	if item.type == "consumable": consumable_items.add_child(new_item_button)
	elif item.type == "throwable": throwable_items.add_child(new_item_button)
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

		# enable/disable buttons on which leader don't have enough gold
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

