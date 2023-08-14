@icon("./icon.png")
class_name EquipItem
extends Item

# Items can have negative effects sometimes, like a sword/sheild/helmet should reduce running speed, while a bow/torch should not.

## Can be used to increase damage.
@export_range(-10000, 10000) var strength := 0

## Can be used to increase defense.
@export_range(-10000, 10000) var armor := 0

## Withstand damage, can be used to increase maximum health points.
@export_range(-10000, 10000) var endurance := 0

## Can be used to increase vision.
@export_range(-10000, 10000) var sight := 0

## Can be used to increase speed.
@export_range(-10000, 10000) var agility := 0

## Can be used to increase attack range.
@export_range(-10000, 10000) var reach := 0

## Can be used to increase attack speed.
@export_range(-10000, 10000) var cadence := 0

## Can be used to increase the damage over time (DOT) for poison projectiles or poison weapons.
@export_range(-10000, 10000) var infliction := 0

## Can be used to increase health over time.
@export_range(-10000, 10000) var health_regen := 0

## Can be used to increase mana over time.
@export_range(-10000, 10000) var mana_regen := 0


## FIXME: Explain please, is this a passive extra item that has it's own stats?
@export var passive := ""

# the type is manualy set here on initialize, don't change this.
func _init():
    item_type = ITEM_TYPE.EQUIP
    # keep this here to validate every new item on initialize
    validate_item()
