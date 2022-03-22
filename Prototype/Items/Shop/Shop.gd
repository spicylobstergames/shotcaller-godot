extends Panel

const Item = preload("res:///Items/Item.gd")

var _deliveries = {}
var _shop_item_button_preload = preload("res://Items/Shop/ShopItemButton.tscn")
var _shop_delivery_preload = preload("res://Items/Shop/ShopDelivery.tscn")

onready var _equip_items = $ScrollContainer/VBoxContainer/EquipItems
onready var _consumable_items = $ScrollContainer/VBoxContainer/ConsumableItems
onready var _leaders_inventories = get_node("../../../BotRightContainer/LeadersInventories")


func _ready():
	hide()
	# Test items
	add_item(Item.new().build("Axe", load("res://Assets/Items/Axe.png"), "Add 5 damage to the leader's attack", 10, Item.ItemType.EQUIP, {"damage": 5}), _equip_items)
	add_item(Item.new().build("Helmet", load("res://Assets/Items/Helm.png"), "Add 5 defense points to leader stats", 25, Item.ItemType.EQUIP, {"max_health": 10000}), _equip_items)
	add_item(Item.new().build("Heal Potion", load("res://Assets/Items/Red Potion 3.png"), "Restore 50 HP", 5, Item.ItemType.CONSUMABLE, {"health": 100}), _consumable_items)
	
	get_tree().get_current_scene().get_node("GUI/TopRightContainer/Shop/ShopButton").connect("button_down", self, "_shop_button_down")


func add_delivery(leader):
	var new_shop_delivery = _shop_delivery_preload.instance()
	new_shop_delivery._leader = leader
	add_child(new_shop_delivery)
	_deliveries[leader.name] = new_shop_delivery


func add_item(item, container):
	var new_item_button = _shop_item_button_preload.instance()
	container.add_child(new_item_button)
	new_item_button.setup(item)


func _process(delta):
	if !visible:
		return
	
	var leader = Leaders.selected_leader
	
	if leader == null:
		# Disable all buttons because leader is not selected
		for item_button in _equip_items.get_children() + _consumable_items.get_children():
			item_button.disable()
		return
	
	# Disable all buttons if delivery in proccess
	if _deliveries[leader.name].is_working():
		for item_button in _equip_items.get_children() + _consumable_items.get_children():
			item_button.disable()
		return
	
	# Disable all buttons on which leader don't have enough gold
	for item_button in _equip_items.get_children() + _consumable_items.get_children():
		if _leaders_inventories.inventories[leader.name].gold < item_button.get_price():
			item_button.disable()
		else:
			item_button.enable()
	
	# Disable buttons if leader don't have empty slots for item
	if !_leaders_inventories.inventories[leader.name].is_equip_items_has_slots():
		for item_button in _equip_items.get_children():
			item_button.disable()
	if !_leaders_inventories.inventories[leader.name].is_consumable_items_has_slots():
		for item_button in _consumable_items.get_children():
			item_button.disable()


func buy(item):
	var leader = Leaders.selected_leader
	
	_leaders_inventories.inventories[leader.name].gold -= item.price
	_deliveries[leader.name].start(item)


func sell(item_index):
	var leader = Leaders.selected_leader
	
	var sold_item = _leaders_inventories.remove_item(leader, item_index)
	
	# Give the leader gold for half the cost of the item
	_leaders_inventories.inventories[leader.name].gold += floor(sold_item.price / 2)
	
	_leaders_inventories.update_gui(leader.name)


func _shop_button_down():
	self.visible = !self.visible
