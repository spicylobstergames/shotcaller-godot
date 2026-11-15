# =============================================================================
# GOAP-GUIDE: AttackEnemy - action (goap/game_logic/actions/attack_enemy.gd)
# =============================================================================
# Purpose   : Attack unit.target in range; close the distance when out of range.
# Plannable : yes - EnemyDefeated ({enemy_dead: true}) -> AttackEnemy.
# is_valid  : unit.attacks
# cost      : 1
# precond   : {"enemy_in_attack_range": true}
# effects   : {"enemy_dead": true, "friends_safe": true}
# enter     : reject an invalid/dead/unhittable target (clearing its facts),
#             otherwise aim (point) or approach.
# perform   : true when the target vanished/died/cannot be hit; otherwise
#             refresh enemy_in_attack_range and return (not in_range).
# exit      : Move.stop
# Reads     : unit.target; ChooseTarget.can_hit / in_range
# Writes    : enemy_in_attack_range, enemy_dead, target (via agent.set_state)
# Traps     : every dead/invalid branch MUST clear enemy_in_attack_range, or
#             the planner satisfies the precondition with no real target.
# See       : tests/unit/test_attack_lifecycle.gd; ARCHITECTURE.md "State facts".
# =============================================================================

extends "res://goap/goap_system/action_contract.gd"


func get_class_name():
	return "AttackEnemy"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	return unit.attacks


func get_cost(_agent) -> int:
	return 1


func get_preconditions() -> Dictionary:
	return {"enemy_in_attack_range": true}


func get_effects() -> Dictionary:
	return {
		"enemy_dead": true,
		"friends_safe": true
		}


func perform(agent, _delta) -> bool:
	var unit = agent.get_unit()
	var target = unit.target
	var choose_target = Goap.get_action("ChooseTarget")
	if not is_instance_valid(target):
		agent.set_state("target", null)
		agent.set_state("enemy_in_attack_range", false)
		agent.set_state("enemy_dead", false)
		return true
	if target.dead:
		agent.set_state("enemy_dead", true)
		agent.set_state("target", null)
		# A dead target is never in range: leaving the previous `true` here
		# makes the planner satisfy AttackEnemy's precondition without
		# PursueEnemy/ChooseTarget on the next plan (see COVERAGE.md known bug).
		agent.set_state("enemy_in_attack_range", false)
		return true
	if not choose_target.can_hit(unit, target):
		agent.set_state("target", null)
		agent.set_state("enemy_in_attack_range", false)
		agent.set_state("enemy_dead", false)
		return true
	var target_in_range = choose_target.in_range(unit, target)
	agent.set_state("enemy_in_attack_range", target_in_range)
	return not target_in_range


func enter(agent):
	var unit = agent.get_unit()
	var target = unit.target
	if not is_instance_valid(target):
		agent.set_state("target", null)
		agent.set_state("enemy_in_attack_range", false)
		agent.set_state("enemy_dead", false)
		return
	if target.dead:
		agent.set_state("enemy_dead", true)
		agent.set_state("target", null)
		agent.set_state("enemy_in_attack_range", false)
		return
	if not Goap.get_action("ChooseTarget").can_hit(unit, target):
		agent.set_state("target", null)
		agent.set_state("enemy_in_attack_range", false)
		agent.set_state("enemy_dead", false)
		return
	if Goap.get_action("ChooseTarget").is_valid_target(unit, target):
		point(unit, target.global_position + target.collision_position)
	else:
		unit.final_destiny = target.global_position
		# Same fallback as PursueEnemy._approach: buildings sit on blocked
		# tiles, so Navigate.move finds no path into them — walk straight at
		# the target to close into attack range instead of freezing.
		if not Goap.get_action("Navigate").move(unit, target.global_position):
			Goap.get_action("Move").move(unit, target.global_position)


func on_animation_end(agent):
	var unit = agent.get_unit()
	var target = unit.target
	
	if target and target.dead:
		agent.set_state("enemy_dead", false)
	
	var choose_target = Goap.get_action("ChooseTarget")
	if is_instance_valid(target) and choose_target.can_hit(unit, target):
		if choose_target.in_range(unit, target):
			point(unit, target.global_position + target.collision_position)
		else:
			unit.final_destiny = target.global_position
			if not Goap.get_action("Navigate").move(unit, target.global_position):
				Goap.get_action("Move").move(unit, target.global_position)
	else:
		Goap.get_action("Move").stop(unit)


func exit(agent):
	var unit = agent.get_unit()
	Goap.get_action("Move").stop(unit)


func point(unit, target_point: Vector2) -> void:
	if (
		unit.attacks
		and not unit.agent.get_state("is_stunned")
		and Goap.get_action("Move").in_bounds(target_point)
	):
		if unit.ranged and unit.weapon:
			unit.weapon.look_at(target_point)

		if not unit.target:
			var neighbors = Collisions.get_units_in_radius(target_point, 1)
			if neighbors:
				var choose_target = Goap.get_action("ChooseTarget")
				var target = choose_target.select_target(unit, neighbors)
				if choose_target.is_valid_target(unit, target):
					unit.agent.set_state("target", target)

		unit.aim_point = target_point
		unit.mirror_look_at(target_point)
		var animations = unit.get_node_or_null("animations")
		if animations:
			animations.speed_scale = Modifiers.get_value(unit, "attack_speed")
		unit.set_state("attack")
