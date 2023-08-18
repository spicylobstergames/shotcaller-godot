@icon("./icon.png")
@tool
class_name Inventory
extends PanelContainer

# Items Base Folder Path, change it when you move the items folder
const EQUIP_ITEMS_PATH := "res://addons/items/items/equip/"
const CONSUMABLE_ITEMS_PATH := "res://addons/items/items/consumables/"
const THROWABLE_ITEMS_PATH := "res://addons/items/items/throwables/"

# Register Items for easy access

# Equip Items
const ITEM_AXE: EquipItem = preload(EQUIP_ITEMS_PATH + "axe.tres")
const ITEM_BOOTS: EquipItem = preload(EQUIP_ITEMS_PATH + "boots.tres")
const ITEM_BOW: EquipItem = preload(EQUIP_ITEMS_PATH + "bow.tres")
const ITEM_DRAGON_EYE: EquipItem = preload(EQUIP_ITEMS_PATH + "dragon_eye.tres")
const ITEM_HELMET: EquipItem = preload(EQUIP_ITEMS_PATH + "helmet.tres")
const ITEM_HOLY_HELMET: EquipItem = preload(EQUIP_ITEMS_PATH + "holy_helmet.tres")
const ITEM_HOLY_SHIELD: EquipItem = preload(EQUIP_ITEMS_PATH + "holy_shield.tres")
const ITEM_PLUME: EquipItem = preload(EQUIP_ITEMS_PATH + "plume.tres")
const ITEM_SCALE: EquipItem = preload(EQUIP_ITEMS_PATH + "scale.tres")
const ITEM_SHIELD: EquipItem = preload(EQUIP_ITEMS_PATH + "shield.tres")
const ITEM_SWORD: EquipItem = preload(EQUIP_ITEMS_PATH + "sword.tres")
const ITEM_TORCH: EquipItem = preload(EQUIP_ITEMS_PATH + "torch.tres")

# Consumables Items
const ITEM_LARGE_HEALTH_POTION: ConsumableItem = preload(CONSUMABLE_ITEMS_PATH + "large_health_potion.tres")
const ITEM_MEDIUM_HEALTH_POTION: ConsumableItem = preload(CONSUMABLE_ITEMS_PATH + "medium_health_potion.tres")
const ITEM_SMALL_HEALTH_POTION: ConsumableItem = preload(CONSUMABLE_ITEMS_PATH + "small_health_potion.tres")

# Throwables Items
const ITEM_LARGE_POISON: ThrowableItem = preload(THROWABLE_ITEMS_PATH + "large_poison.tres")
const ITEM_MEDIUM_POISON: ThrowableItem = preload(THROWABLE_ITEMS_PATH + "medium_poison.tres")
const ITEM_SMALL_POISON: ThrowableItem = preload(THROWABLE_ITEMS_PATH + "small_poison.tres")

var inventory_grid := GridContainer.new()
var cur_item: Item = null
var cur_item_index := -1


func _init():
    # grid scroll container
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    # grid container
    inventory_grid.columns = 2
    inventory_grid.set_anchors_preset(PRESET_FULL_RECT)
    inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
    scroll.add_child(inventory_grid)

## Use it to add item, add_item(ITEM_AXE) add_item(ITEM_BOOTS) and it will return the item index, you can then use remove_item(index)
func add_item(item: Item) -> int:
    var item_button = ItemButton.new(item)
    inventory_grid.add_child(item_button)
    item_button.item_pressed.connect(_on_item_pressed)
    return item_button.get_index()


## Use it to remove item by it's index
## TODO: update the InventoryPanel
func remove_item(index: int):
    var _item = inventory_grid.get_child(index)
    inventory_grid.remove_child(_item)
    _item.queue_free()


## Returns an Item by it's index
func get_item(index: int) -> Item:
    return inventory_grid.get_child(index).item


## Returns an array of all items, useful for save and load
func get_items() -> Array:
    var items_arr := []
    for child in inventory_grid.get_children():
        items_arr.push_back(child.item)
    return items_arr


## Add items to the grid, useful for load
func add_items(items_arr: Array):
    for item in items_arr:
        add_item(item)


## Clear all inventory items.
## TODO: update the InventoryPanel
func remove_all_items():
    for child in inventory_grid.get_children():
        inventory_grid.remove_child(child)
        child.queue_free()


# This will update the cur_item and the cur_item_index, use it to get/remove item by it's index
# TODO: add InventoryPanel class and update it when an item is pressed or removed.
func _on_item_pressed(item: Item):
    cur_item = item
    cur_item_index = item.get_index()

"""
# Usage: uncomment this to use for testing then comment it back after you finish
func _ready():
    add_item(ITEM_AXE)
    add_item(ITEM_BOOTS)
    add_item(ITEM_BOW)
    add_item(ITEM_DRAGON_EYE)
    add_item(ITEM_HELMET)
    add_item(ITEM_HOLY_HELMET)
    add_item(ITEM_HOLY_SHIELD)
    add_item(ITEM_PLUME)
    add_item(ITEM_SCALE)
    add_item(ITEM_SHIELD)
    add_item(ITEM_SWORD)
    add_item(ITEM_TORCH)
"""
