extends Panel
var game:Node

const Item = preload("res:///items/item.gd")

var deliveries = {}
var _shop_item_button_preload = preload("res://items/shop/shop_item_button.tscn")
var _shop_delivery_preload = preload("res://items/shop/shop_delivery.tscn")

onready var _container = get_node("scroll_container/container")
onready var _equip_items = _container.get_node("equip_items")
onready var _consumable_items = _container.get_node("consumable_items")
var leaders_inventories:Node

func _ready():
	yield(get_tree(), "idle_frame")
	game = get_tree().get_current_scene()
	leaders_inventories = game.ui.leaders_inventories
	
	hide()
	
	# Test items
	add_item(Item.new().build("Axe", load("res://assets/items/axe.png"), "Add 5 damage to the leader's attack", 1, Item.ItemType.EQUIP, {}), _equip_items)
	add_item(Item.new().build("Helmet", load("res://assets/items/helm.png"), "Add 5 defense points to leader stats", 2, Item.ItemType.EQUIP, {"max_health": 10000}), _equip_items)
	add_item(Item.new().build("Heal Potion", load("res://assets/items/red_potion.png"), "Restore 50 HP", 5, Item.ItemType.CONSUMABLE, {"health": 100}), _consumable_items)
	
# warning-ignore:return_value_discarded
	game.ui.shop_button.connect("button_down", self, "_shop_button_down")
# warning-ignore:return_value_discarded
	game.ui.shop_button.get_node("shop_touch_button").connect("button_down", self, "_shop_button_down")
	
	game.ui.shop_window.disable_all()


func add_delivery(leader):
	var new_shop_delivery = _shop_delivery_preload.instance()
	new_shop_delivery._leader = leader
	add_child(new_shop_delivery)
	deliveries[leader.name] = new_shop_delivery


func add_item(item, container):
	var new_item_button = _shop_item_button_preload.instance()
	container.add_child(new_item_button)
	new_item_button.setup(item)


func disable_all():
	# Disable all buttons because leader is not selected or if delivery in proccess
	for item_button in _equip_items.get_children() + _consumable_items.get_children():
		item_button.disable()
	return

func update_buttons():
	var leader = game.selected_leader
	# Disable all buttons on which leader don't have enough golds
	for item_button in _equip_items.get_children() + _consumable_items.get_children():
		if leader.name in leaders_inventories.inventories:
			if leaders_inventories.inventories[leader.name].gold < item_button.get_price():
				item_button.disable()
			else:
				item_button.enable()
	
	# Disable buttons if leader don't have empty slots for item
	if leader.name in leaders_inventories.inventories:
		if !leaders_inventories.inventories[leader.name].is_equip_items_has_slots():
			for item_button in _equip_items.get_children():
				item_button.disable()
		if !leaders_inventories.inventories[leader.name].is_consumable_items_has_slots():
			for item_button in _consumable_items.get_children():
				item_button.disable()


func buy(item):
	var leader = game.selected_leader
	
	leaders_inventories.inventories[leader.name].gold -= item.price
	deliveries[leader.name].start(item)
	
	disable_all()


func sell(item_index):
	var leader = game.selected_leader
	
	var sold_item = leaders_inventories.remove_item(leader, item_index)
	
	# Give the leader gold for half the cost of the item
	leaders_inventories.inventories[leader.name].gold += floor(sold_item.price / 2)
	
	leaders_inventories.update_gui(leader.name)


func _shop_button_down():
	self.visible = !self.visible

