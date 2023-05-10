extends Control

signal preview_confirm

@onready var ability_preview_scene = preload("ability_preview.tscn")
@onready var abilities_preview_container = $"%abilities_preview_container"

@onready var leader_name_label = $"%leader_name"
var leader_name:String

func _ready():
	is_empty()
	
func prepare(leader):
	leader_name = leader
	is_empty()
	if leader != "random":
		var leader_scene = load("res://leaders/%s.tscn" % leader)
		var leader_instance = leader_scene.instantiate()
		leader_name_label.text = Utils.first_to_uppper(leader)
		for ability in leader_instance.get_node("behavior/abilities").get_children():
			var ability_preview = ability_preview_scene.instantiate()
			ability_preview.prepare(ability.icon, ability.ability_name, ability.description)
			abilities_preview_container.add_child(ability_preview)
		leader_instance.queue_free()


func is_empty():
	for child in abilities_preview_container.get_children():
		abilities_preview_container.remove_child(child)
		child.queue_free()


func confirm_button_pressed():
	emit_signal("preview_confirm", leader_name)


func cancel_button_pressed():
	hide()
