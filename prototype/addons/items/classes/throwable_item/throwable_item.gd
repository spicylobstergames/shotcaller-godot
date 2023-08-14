@icon("./icon.png")
class_name ThrowableItem
extends Item

## Can be used to assign the duration of the effects.
@export_range(0, 10000) var duration := 0

## Can be used to reduce health points over time. negative values only.
@export_range(-10000, 0) var damage_over_time := 0

## Can be used to reduce speed for a short time. negative values only.
@export_range(-10000, 0) var deceleration := 0

# the type is manualy set here on initialize, don't change this.
func _init():
    item_type = ITEM_TYPE.THROWABLE
    # keep this here to validate every new item on initialize
    validate_item()