extends Node


signal playing

var is_playing: bool = false

var creep_respawn_time: float = 18.0


func game_over(loser: int):
	var winner
	match loser:
		Units.TeamID.Blue:
			winner = Units.TeamID.Red
		Units.TeamID.Red:
			winner = Units.TeamID.Blue
		_:
			winner = Units.TeamID.None
	print("Game is over, winner is %s" % [Units.TeamID.keys()[winner]])
	for unit in Units.get_all_allies(winner):
		if "winner" in unit:
			unit.winner = true
	is_playing = false
