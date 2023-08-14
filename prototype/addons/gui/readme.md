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