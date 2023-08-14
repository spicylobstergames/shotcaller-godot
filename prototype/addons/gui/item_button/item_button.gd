@tool
@icon("./icon.png")
class_name ItemButton
extends Button

## Connect this signal and it will return the current item when the button is pressed.
signal item_pressed(item)

# TODO: Item's Delivery should be handled by the inventory, not by the item button or the Item Resource
# Shop: Buy item -> Create new ItemResource inside Inventory -> Create a new DeliveryTimer like (DeliveryTimer.new(Item))
# Connect the DeliveryTimer's Delivered signal to the Inventory and When the signal emits add the Item to a new ItemButton,
# then add the ItemButton to the Inventory. On exit or save the timers remaining time and it's item should be Saved to avoid losing them.

## don't use Item class here, use it's derived classes [EquipItem, ThrowableItem, ConsumableItem], and extend them instead of extending this class.
@export var item: Item:
    set(value):
        item = value
        if not item:
            name_label.text = ""
            price_label.text = ""
            icon = null
            print_debug("invalid item! item = %s", item)
            return
        # FIXME: this should be done in a better way inside the validation function
        # it will only print item info in editor and debug releases.
        print_debug("item_name = %s, item_value = %s, has_texture = %s" % [item.item_name, item.price, item.icon != null])
        ## The item icon is just a path, so we need to load it to an image then create a texture from the image.
        if item.icon:
            var img := Image.load_from_file(item.icon)
            icon = ImageTexture.create_from_image(img)
        # Update label and price text.
        name_label.text = item.item_name
        price_label.text = str(item.price)

## This should be here because it's a temp variable
var price_after_discount

# Node Setup
var name_label := Label.new()
var price_label := Label.new()

# TODO: Most of helper classes that will need an easy access should be defined in the GUI class
# var sell_button := GUI.SellButton.new()


# We need to pass an item so it automatically loads it. In editor we can add the item manually to the item property
func _init(new_item = null):
    if item:
        item = new_item
    
    custom_minimum_size = Vector2i(64, 64)

    # Theme setup
    texture_filter = TEXTURE_FILTER_NEAREST
    icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    price_label.add_theme_color_override("font_color", Color(1, 0.796, 0.243))
    
    # Node setup
    ## a margin container will be easier than usign anchors, and will allow us to define margins for the labels.
    var margin := MarginContainer.new()
    for m in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_%s" % m, 4)
    add_child(margin)
    margin.set_anchors_preset(PRESET_FULL_RECT)

    margin.add_child(name_label)
    name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    name_label.size_flags_vertical = SIZE_SHRINK_BEGIN
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    margin.add_child(price_label)
    price_label.size_flags_horizontal = SIZE_EXPAND | SIZE_SHRINK_END
    price_label.size_flags_vertical = SIZE_SHRINK_END
    
    pressed.connect(_on_button_pressed)


## A remap for button's pressed signal that will return the item when the button is pressed0.
func _on_button_pressed():
    emit_signal("item_pressed", item)

# # FIXME: remove this later.
# func _ready():
#     var item_test := Item.new()
#     # save the Item's Image path then load it on item's creation.
#     item_test.icon = Item.IMAGES_PATH + "item1.png"
#     item = item_test

# class Item:
#     extends Resource

#     var item_name := "Item Name"
#     var icon: ImageTexture
#     var price := 101
#     var sell_price := 69
#     var quantaty = 1
#     var max_quantaty = 10
#     var is_shop_item := true


# Sell button should goes to a new script, because we will have lots of instances of this Class.

"""
class SellButton:
    extends Button

    func _init():
        pass
"""

# FIXME: not needed here, guessing it's root ? use get_tree().get_root().get_node("Game") or get_tree().get_current_scene()
# var game:Node

# FIXME: which index? we may not need this, since every Item will be extended from the Item class.
# index in inventory grid ? use item.get_index()
# var index = 0

# This should be handled in the Item's script
# var saved_icon

# FIXME: don't know it's use case.
# var poison = preload("res://item/potions/poison.tscn").instantiate()


# func setup(new_item):
# 	sell_button.hide()
	
# 	if new_item == null:
# 		self.item = null
# 		self.name = "Item Slot"
# 		if not self.saved_icon:
# 			self.saved_icon = self.icon
# 		self.icon = null
# 		self.tooltip_text = "Buy items in the Blacksmith"
# 		self.disabled = true
# 		name_label.hide()
# 		price_label.hide()

# 	else:
# 		self.item = new_item
# 		self.name = new_item.name
# 		self.tooltip_text = new_item.tooltip
# 		if not self.shop_item:
# 			self.disabled = (new_item.type != "consumable")
# 		var icon_ref = self.icon
# 		if not icon_ref: icon_ref = self.saved_icon
# 		icon = icon_ref.duplicate()
# 		icon.region.position.x = new_item.sprite * 32
# 		name_label.text = self.name
# 		var price = new_item.price
# 		if not self.shop_item: price = new_item.sell_price
# 		price_label.text = str(price)
# 		price_after_discount = price


# func on_button_down():
# 	var leader = game.selected_leader
# 	if self.shop_item:
# 		# BUY ITEM
		
# 		# sell is only enabled if leader has enough gold
# 		# no need to check here
# 		leader.gold -= price_after_discount
		
# 		game.ui.inventories.add_delivery(leader, item)
# 		game.ui.shop.disable_all()

# 	else:
# 		# use inventory item
# 		if item.type == "throwable":
# 			poison.poison_throw(leader, item)
# 		elif item.type == "consumable":
# 			for key in item.attributes.keys():
# 				if key in leader:
# 					leader[key] += item.attributes[key]
# 		game.ui.inventories.remove_item(leader, index)
# 		setup(null)


# func on_sell_button_down():
# 	var leader = game.selected_leader
# 	var sold_item = game.ui.inventories.remove_item(leader, index)
# 	# Give the leader gold for half the cost of the item
# 	leader.gold += sold_item.sell_price
# 	setup(null)

