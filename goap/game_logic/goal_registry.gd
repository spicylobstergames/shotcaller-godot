# =============================================================================
# GOAP-GUIDE: Goal registry (goap/game_logic/goal_registry.gd)
# =============================================================================
# Name -> goal instance (shared singleton). Which goals a unit evaluates is
# SCENE DATA: the "goals_list" export on its goap_agent node, and
# map/spawns.gd appends WalkLane at spawn.
# Adding a goal: create the script, register it here, then add its name to the
# unit scenes that should consider it.
# =============================================================================

extends Node

# self = Goap.Goals

# Lists all goal contracts.
var _goals: Dictionary = {
	"ArriveAtDestination": preload("res://goap/game_logic/goals/arrive_at_destination.gd").new(),
	"EnemyDefeated": preload("res://goap/game_logic/goals/enemy_defeated.gd").new(),
	"FriendsSafe": preload("res://goap/game_logic/goals/friends_safe.gd").new(),
	"NeedLumber": preload("res://goap/game_logic/goals/need_lumber.gd").new(),
	"NeedSafety": preload("res://goap/game_logic/goals/need_safety.gd").new(),
	"ObeyPlayer": preload("res://goap/game_logic/goals/obey_player.gd").new(),
	"Recover": preload("res://goap/game_logic/goals/recover.gd").new(),
	"WalkLane": preload("res://goap/game_logic/goals/walk_lane.gd").new()
}


func get_goal(goal_name, default = null):
	if _goals.has(goal_name):
		return _goals[goal_name]
	return default


func set_goal(goal_name, value):
	_goals[goal_name] = value


# Debug/lint helper: returns human-readable contract problems ([] when clean).
# Checks that each key matches get_class_name() and that the goal contract
# methods exist. Used by tests/unit/test_goap_contract_lint.gd.
func validate() -> Array[String]:
	var problems: Array[String] = []
	for key in _goals:
		var goal = _goals[key]
		if goal == null:
			problems.append("goal '%s' is null" % key)
			continue
		if not goal.has_method("get_class_name"):
			problems.append("goal '%s' has no get_class_name()" % key)
			continue
		if goal.get_class_name() != key:
			problems.append(
				"goal registered as '%s' but get_class_name() returns '%s'"
				% [key, goal.get_class_name()]
			)
		for method in ["is_valid", "priority", "get_desired_state"]:
			if not goal.has_method(method):
				problems.append("goal '%s' is missing %s()" % [key, method])
	return problems
