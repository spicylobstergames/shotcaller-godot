## Items Usage

To create a new item:

- 1- Create a new Resource and choose from [[EquipItem](/addons/items/classes/equip_item/equip_item.gd), [ConsumableItem](/addons/items/classes/consumable_item/consumable_item.gd), [ThrowableItem](/addons/items/classes/throwable_item/throwable_item.gd)]
- 2- To Use the Items, Create a new ItemButton then add any created item to it's item property.
- 3- To Create more Item types extend the Item class, look at the equip_item.gd for reference
- 4- to add more textures check the Images class and add your image there then add it's path inside the Item's icon property
- 5- feel free to edit those files to match the game.

## GUI

this should have 3 classes works together [[ItemButton](/addons/gui/item_button/item_button.gd), [Inventory](), [InventoryPanel]()]

## ItemButton
- It needs an [Item] to work
---

## Inventory
- It can handle ItemButtons by connecting `ItemButton.item_pressed` to it's `Inventory._on_item_pressed(item: Item)`
---

## InventoryPanel
- just set the Inventoy.item_panel from script to this node, During development don't use path for control nodes since the UI will change alot and you will keep updating the path, instead you can enable access by unique name and you get the node like this `get_node("%InventoryPanel")`
---

Note: Users should not use Item class directly, only extend it and don't edit the file because it may break all the other derived classes.