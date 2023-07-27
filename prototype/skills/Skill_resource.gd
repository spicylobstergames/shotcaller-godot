extends Resource

class_name Skill_resource

@export var name:String = "Skill Name"
@export var tooltip:String = "Skill description\nDamage = 10"
@export var attributes:Dictionary = {"angle": 90, "radius": 50, "center_pos": Vector2(0, 8), "finish_pos": Vector2(300, 0), "color": Color(0,0,100,0.05)}
@export var type:String = "active"
@export var visualize:String = "arc"
@export var cooldown:int = 30
@export var sprite:int = 0
@export var effects:Array = []
