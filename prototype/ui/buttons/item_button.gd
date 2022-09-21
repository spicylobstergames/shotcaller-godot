extends Button
var game:Node

var item = null
var index = 0
var saved_icon
var shop_item = false
var price_after_discount

onready var name_label = get_node("name")
onready var price_label = get_node("price")
onready var sell_button = get_node("sell_button")


func _ready():
	game = get_tree().get_current_scene()


func setup(new_item):
	sell_button.visible = false
	
	if new_item == null:
		self.item = null
		self.name = "Item Slot"
		if not self.saved_icon:
			self.saved_icon = self.icon
		self.icon = null
		self.hint_tooltip = "Buy items in the Blacksmith"
		self.disabled = true
		name_label.visible = false
		price_label.visible = false

	else:
		self.item = new_item
		self.name = new_item.name
		self.hint_tooltip = new_item.tooltip
		if not self.shop_item:
			self.disabled = (new_item.type != "consumable")
		var icon_ref = self.icon
		if not icon_ref: icon_ref = self.saved_icon
		var icon = icon_ref.duplicate()
		icon.region.position.x = new_item.sprite * 32
		self.icon = icon
		name_label.text = self.name
		var price = new_item.price
		if not self.shop_item: price = new_item.sell_price
		price_label.text = str(price)
		price_after_discount = price


func on_button_down():
	var leader = game.selected_leader
	
	if self.shop_item:
		# BUY ITEM
		leader.gold -= price_after_discount
		
		game.ui.inventories.add_delivery(leader, item)
		game.ui.shop.disable_all()

	else:
		# use inventory item
		for key in item.attributes.keys():
			if key in leader:
				leader[key] += item.attributes[key]
		
		game.ui.inventories.remove_item(leader, index)



func show_sell_button():
	if item != null:
		sell_button.show()
	else:
		sell_button.hide()



func on_sell_button_down():
	var leader = game.selected_leader
	var sold_item = game.ui.inventories.remove_item(leader, index)
	# Give the leader gold for half the cost of the item
	leader.gold += sold_item.sell_price
	setup(null)

