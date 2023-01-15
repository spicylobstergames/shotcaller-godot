extends CenterContainer

onready var ability_preview_scene = preload("res://ui/panels/leader_preview/ability_preview.tscn")
onready var ability_container = $PanelContainer/VBoxContainer/VBoxContainer

func _ready():
	empty()
	
func prepare(leader):
	empty()
	if leader != 'random':
		var leader_scene = load("res://leaders/%s.tscn" % leader)
		var leader_instance = leader_scene.instance()
		$"%leader_name".text = leader
		for ability in leader_instance.get_node("behavior/abilities").get_children():
			var ability_preview = ability_preview_scene.instance()
			ability_preview.prepare(ability.icon, ability.ability_name, ability.description)
			ability_container.add_child(ability_preview)
		leader_instance.queue_free()


func empty():
	for child in ability_container.get_children():
		ability_container.remove_child(child)
		child.queue_free()
