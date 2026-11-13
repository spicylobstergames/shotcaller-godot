extends Control

signal preview_confirm(leader_name: String)

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
		var leader_scene = load("res://unit/leaders/%s.tscn" % leader)
		var leader_instance = leader_scene.instantiate()
		leader_name_label.text = Utils.first_to_uppper(leader)
		var abilities_node = leader_instance.get_node_or_null("goap_agent/abilities")
		if abilities_node:
			for ability in abilities_node.get_children():
				var ability_preview = ability_preview_scene.instantiate()
				ability_preview.prepare(
					ability.skill_data.icon,
					ability.skill_data.display_name,
					ability.skill_data.description
				)
				abilities_preview_container.add_child(ability_preview)
		leader_instance.queue_free()


func is_empty():
	for child in abilities_preview_container.get_children():
		abilities_preview_container.remove_child(child)
		child.queue_free()


func confirm_button_pressed():
	preview_confirm.emit(leader_name)


func cancel_button_pressed():
	hide()
