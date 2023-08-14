@icon("./icon.png")
class_name ConsumableItem
extends Item

## Can be used to restore health points.
@export_range(-10000, 10000) var health := 0

## Can be used to restore stamina points.
@export_range(-10000, 10000) var stamina := 0

# the type is manualy set here on initialize, don't change this.
func _init():
    item_type = ITEM_TYPE.CONSUMABLE
    # keep this here to validate every new item on initialize
    validate_item()
