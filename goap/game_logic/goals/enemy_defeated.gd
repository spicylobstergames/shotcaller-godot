extends "res://goap/goap_system/goal_contract.gd"


func get_class_name() -> String:
	return "EnemyDefeated"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var ready_to_fight = agent.get_state("ready_to_fight", true)
	if !ready_to_fight or !unit.attacks:
		return false
	# Documented lifecycle (docs/ai/world-state.md): while the goal is valid,
	# enemy_dead is false every frame. Without this reset, the fact written by
	# AttackEnemy after a kill stays stale and the planner sees the goal's
	# desired state as already satisfied — it returns an empty plan and the
	# agent holds EnemyDefeated with no actions forever (agent.gd only replans
	# when the goal changes).
	agent.set_state("enemy_dead", false)
	# Release a dead/invalid target reference. Nothing else clears unit.target
	# if AttackEnemy never runs again after the kill: goap_process re-selects
	# the goal BEFORE perform() sees the corpse, so a goal switch (e.g. a
	# brief FriendsSafe window) or the target dying later to someone else
	# leaves the corpse held — which blocks WalkLane (truthy unit.target) and
	# ChooseTarget (!unit.target), and the unit stands idle after the fight.
	var target = unit.target
	if target != null and (not is_instance_valid(target) or target.dead):
		agent.set_state("target", null)
	var enemies = unit.get_units_in_sight({ "team": unit.opponent_team() })
	agent.set_state("opponents_in_sight", enemies)
	# An enemy in sight is not necessarily an enemy this unit can engage:
	# immune units (churches, neutrals) pass the team filter but ChooseTarget
	# — and therefore every combat action — refuses them, and a stationary
	# unit cannot engage enemies outside its attack range. Claiming this
	# priority-6 goal for an untargetable sight list hijacked WalkLane
	# (priority 2) and froze the agent in a replan churn that never selected
	# a target — visible as units standing frozen on their lane next to a
	# church. Require an actually targetable enemy.
	return Goap.get_action("ChooseTarget").select_target(unit, enemies) != null


func priority(_agent) -> int:
	return 6


func get_desired_state(_agent) -> Dictionary:
	return {"enemy_dead": true}
