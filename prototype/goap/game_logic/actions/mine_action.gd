extends "res://goap/goap_system/action_contract.gd"


const destroy_time = 5
const collect_time = 16


func get_class_name() -> String:
	return "MineAction"


func set_mine_gold(team, value):
	var game = Goap.get_tree().get_current_scene()
	var leaders = WorldState.get_state("player_leaders")
	var inventories = game.ui.inventories.player_leaders_inv
	if team == WorldState.get_state("enemy_team"):
		leaders = WorldState.get_state("enemy_leaders")
		inventories = game.ui.inventories.enemy_leaders_inv
	for leader in leaders:
		inventories[leader.name].extra_mine_gold = value


func gold_order(button):
	var mine = button.orders.order.mine
	mine.channeling_timer.stop()
	mine.channeling_timer.wait_time = 1
	mine.channeling_timer.start()
	mine.agent.set_state("is_channeling", true)
	match button.orders.gold:
		"collect":
			button.counter = collect_time
			button.hint_label.text = str(collect_time)
			gold_collect_counter(button)
		"destroy":
			button.counter = destroy_time
			button.hint_label.text = str(button.counter)
			gold_destroy_counter(button)


func gold_collect_counter(button):
	var mine = button.orders.order.mine
	await mine.channeling_timer.timeout
	if button.counter > 0:
		button.counter -= 1
		button.hint_label.text = str(button.counter)
		gold_collect_counter(button)
	else:
		mine.channeling_timer.stop()
		button.disabled = false
		if mine.agent.get_state("is_channeling"):
			mine.agent.set_state("is_channeling", false)
			var leaders = WorldState.get_state("player_leaders")
			if mine.team == WorldState.get_state("enemy_team"):
				leaders = WorldState.get_state("enemy_leaders")
			for leader in leaders:
				leader.gold += floor(mine.gold / leaders.size())
			mine.gold = 0


func gold_destroy_counter(button):
	var mine = button.orders.order.mine
	await mine.channeling_timer.timeout
	if button.counter > 0:
		button.counter -= 1
		button.hint_label.text = str(button.counter)
		gold_destroy_counter(button)
	else:
		mine.channeling_timer.stop()
		button.disabled = false
		if mine.agent.get_state("is_channeling"):
			mine.agent.set_state("is_channeling", false)
			mine.gold = 0
			mine.setup_team("neutral")
			var game = Goap.get_tree().get_current_scene()
			game.ui.show_select()
			for leader in WorldState.get_state("player_leaders"):
				game.ui.inventories.leaders[leader.name].extra_mine_gold = 0
