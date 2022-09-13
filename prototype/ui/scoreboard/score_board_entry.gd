extends MarginContainer
onready var kda_label : Label = $"%kda"
onready var gold_label : Label = $"%gold_amount"
onready var portrait : Sprite = $"%portrait"
onready var last_hits_label : Label = $"%last_hits"
onready var level_label : Label = $"%level"
var leader : Unit

func initialize_red_leader(new_leader):
	leader = new_leader
	portrait.prepare(leader.display_name)
	
	
func initialize_blue_leader(new_leader):
	leader = new_leader
	portrait.prepare(leader.display_name)

func update():
	if leader != null:
		kda_label.text = "%d/%d/%d" % [leader.kills, leader.deaths, leader.assists]
		gold_label.text = str(leader.gold)
		last_hits_label.text = str(leader.last_hit_count)
		level_label.text = str(leader.level)
