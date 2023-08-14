@icon("./icon.png")
class_name Item
extends Resource

# Don't use this class directly, Instead you can extend it, this is the base class for all items.

## We will have lots of instances of this Class, and to make it easier to get the images folder we can use this constant.
const IMAGES_PATH := "res://addons/items/images/"

## Item Type is used in every derived class, has no effect here but should be set in the derived class.
enum ITEM_TYPE {
	EQUIP,
	CONSUMABLE,
	THROWABLE,
	MAX,
}

## Not exported, because every new Item's derived from this class will assign it in it's initialize function.
var item_type: int = ITEM_TYPE.MAX

# Item info
@export_category("Item Info")
## Can't be empty, needed to display the Item name in ItemButton.
@export var item_name := ""
## Can't be empty, needed to display the Item Icon in ItemButton.
@export_file("*.png") var icon := ""
## Don't use as tooltip for button's because it's not good for games and will block input or distract the player if the mouse is over them.
## Instead, the InventoryPanel will show this info when the Item is pressed, don't include any stats info just change them in the derived class.
@export var item_info := ""
@export_group("Quantaty")
# On selling or consuming we should destroy the item when it's quantanty is equal 0.
@export_range(0, 100) var quantaty := 1
@export_range(1, 100) var max_quantaty := 1

# Shop info
@export_category("Shop Info")
## if false, the item cannot be added to shop.
@export var is_shop_item := false
@export_range(0, 100000) var delivery_time := 0
@export_group("Price")
@export_range(0, 100000) var price := 0
@export_range(0, 100000) var sell_price := 0

#TODO: this should insure that the Item's important data is valid!. has no effect here but should be used in every derived class.
func validate_item():
	pass
