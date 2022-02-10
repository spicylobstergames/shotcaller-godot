class_name Skill
extends Node


enum AbilitySlot{
	DefaultAttack
	Slot1,
	Slot2,
	Slot3
}

export var cooldown_length: float
export(AbilitySlot) var slot
var cooldown: float
var agent: Node2D

func _ready():
	agent = get_parent().get_parent()
	
func react(skill: Skill):
	pass

func _process(delta):
	if self.cooldown > 0.0:
		self.cooldown -= delta

func cast() -> bool:
	if self.cooldown <= 0.0:
		self.cooldown = cooldown_length
		return true
	else:
		return false

func get_range() -> float:
	push_error("get_range must be implemented")
	return 0.0


