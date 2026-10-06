extends "res://goap/goap_system/action_contract.gd"


var player_tax = "low"
var enemy_tax = "low"

const tax_gold = {
	"low": 0,
	"medium": 1,
	"high": 2
}

const tax_conquer_limit = {
	"low": 0.25,
	"medium": 0.5,
	"high": 0.75
}


func get_class_name() -> String:
	return "TaxesAction"


func set_taxes(tax, team):
	if team == WorldState.get_state("player_team"):
		player_tax = tax
	else:
		enemy_tax = tax


func update_taxes():
	var game = Goap.get_tree().get_current_scene()
	for leader in WorldState.get_state("player_leaders"):
		game.ui.inventories.player_leaders_inv[leader.name].extra_tax_gold = tax_gold[player_tax]
	for leader in WorldState.get_state("enemy_leaders"):
		game.ui.inventories.enemy_leaders_inv[leader.name].extra_tax_gold = tax_gold[enemy_tax]


func remove_tax(team):
	var game = Goap.get_tree().get_current_scene()
	var leaders = WorldState.get_state("player_leaders")
	var inventories = game.ui.inventories.player_leaders_inv
	if team == WorldState.get_state("enemy_team"):
		leaders = WorldState.get_state("enemy_leaders")
		inventories = game.ui.inventories.enemy_leaders_inv
	for leader in leaders:
		inventories[leader.name].extra_tax_gold = 0


func get_tax_for_team(team) -> String:
	return player_tax if team == WorldState.get_state("player_team") else enemy_tax
