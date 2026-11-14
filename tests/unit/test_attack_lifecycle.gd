extends RefCounted

# Regression suite for the post-kill planning freeze and the ranged hit
# direction.
#
# Bugs fixed (see COVERAGE.md "Known bugs"):
#
# 1. STALE-FACT FREEZE — AttackEnemy.perform's target.dead branch wrote
#    `enemy_dead: true` into agent state and never cleaned it up. The
#    planner's root-satisfaction check (planner.gd) then saw EnemyDefeated's
#    desired state as already achieved and returned an EMPTY plan; the agent
#    held the goal with no actions forever because goap_process only replans
#    when the goal CHANGES. Units stood idle mid-fight; buildings froze after
#    their first kill. The dead branch now also clears
#    `enemy_in_attack_range` (the other branches always did), and
#    EnemyDefeated.is_valid restores the documented lifecycle — enemy_dead is
#    false every frame the goal is valid (docs/ai/world-state.md).
#
# 2. INVERTED RANGED HIT — RangeAttack.projectile_loop called
#    `unit1.take_hit(projectile.target, ...)` on the SHOOTER. Ranged units
#    (all attack buildings) damaged themselves and never killed their target,
#    so AttackEnemy never reached its dead branch and buildings sat in
#    `state=attack` until they died to their own shots. Hits now go to the
#    victim, mirroring MeleeAttack.hit.

const AgentScript = preload("res://goap/goap_system/agent.gd")
const AttackEnemyScript = preload("res://goap/game_logic/actions/attack_enemy.gd")
const RangeAttackScript = preload("res://goap/game_logic/actions/range_attack.gd")
const WorldStateSnapshot = preload("res://tests/helpers/world_state_snapshot.gd")


# Minimal unit double covering every property the real action/goal/planner
# path touches during planning and targeting. Node2D base so
# is_instance_valid() and global_position behave like the real thing.
class TestUnit:
	extends Node2D
	var team := "blue"
	var type := "pawn"
	var dead := false
	var immune := false
	var attacks := true
	var moves := false  # building-like: targets must be in attack range
	var target = null
	var last_target = null
	var attack_count := 0
	var attack_hit_radius := 150.0
	var attack_range := 1.0  # multiplier: get_att_range = hit_radius * attack_range
	var collision_radius := 8.0
	var collision_position := Vector2.ZERO
	var attack_hit_position := Vector2.ZERO
	var aim_point := Vector2.ZERO
	var state := "idle"
	var sight_list: Array = []
	var current_modifiers: Dictionary
	# Movement/agent fields the deeper plan-execution path touches
	# (WaitForRegeneration.is_valid, Move.stop, AttackEnemy.point).
	var regen := 1
	var speed := 35.0
	var current_step := Vector2.ZERO
	var current_destiny := Vector2.ZERO
	var final_destiny := Vector2.ZERO
	var animations = null
	var agent = null
	var ranged := false
	var weapon = null
	var projectiles: Array = []

	var hit_count := 0
	var last_hit_attacker = null

	func _init() -> void:
		current_modifiers = Modifiers.new_modifiers()

	func get_units_in_sight(_filters = {}):
		return sight_list

	func opponent_team():
		return "red"

	func sort_by_distance(units: Array) -> Array:
		var entries := []
		for u in units:
			entries.append({"unit": u, "distance": global_position.distance_to(u.global_position)})
		entries.sort_custom(func(a, b): return a.distance < b.distance)
		return entries

	func mirror_look_at(_point: Vector2) -> void:
		pass

	func point_collision(point: Vector2, offset := 0.0) -> bool:
		# Same contract as Unit.point_collision.
		return Utils.circle_point_collision(
			point, global_position + collision_position, collision_radius + offset)

	func set_state(s) -> void:
		state = s

	func take_hit(attacker, _projectile = null, _mods = {}) -> void:
		hit_count += 1
		last_hit_attacker = attacker


# Real Agent class without _ready()'s scene wiring (mirrors
# test_goap_integration.gd): _unit injected, action_changed connected by hand.
func _make_agent(unit: TestUnit) -> Node:
	var agent = AgentScript.new()
	agent._unit = unit
	unit.agent = agent  # back-reference: AttackEnemy.point reads unit.agent state
	agent._goals = [Goap.get_goal("EnemyDefeated")]
	agent._state = {
		"is_stunned": false,
		"ready_to_fight": true,
	}
	agent.action_changed.connect(agent._on_action_changed)
	return agent


func run(harness) -> void:
	# --- 1. The kill itself: AttackEnemy.perform's dead branch cleans up ---
	var action = AttackEnemyScript.new()
	var unit = TestUnit.new()
	unit.global_position = Vector2.ZERO
	var agent = _make_agent(unit)
	var corpse = TestUnit.new()
	corpse.team = "red"
	corpse.dead = true
	unit.target = corpse
	agent._state["enemy_in_attack_range"] = true
	agent._state["enemy_dead"] = false

	var done = action.perform(agent, 0.0)
	harness.check(done, "AttackEnemy: perform() completes when the target is dead.")
	harness.check(agent.get_state("enemy_dead") == true,
		"AttackEnemy: a recorded kill writes enemy_dead=true.")
	harness.check(agent.get_state("enemy_in_attack_range") == false,
		"AttackEnemy: the dead branch clears enemy_in_attack_range (was left stale).")
	harness.check(unit.target == null,
		"AttackEnemy: the dead branch releases the target.")
	action.free()

	# --- 2. enter() dead branch cleans up too ---
	var action2 = AttackEnemyScript.new()
	var agent2 = _make_agent(unit)
	unit.target = corpse
	agent2._state["enemy_in_attack_range"] = true
	agent2._state["enemy_dead"] = false
	action2.enter(agent2)
	harness.check(agent2.get_state("enemy_in_attack_range") == false
		and agent2.get_state("enemy_dead") == true,
		"AttackEnemy: enter() on a dead target clears the stale range fact.")
	action2.free()

	# --- 3. THE FREEZE: re-planning EnemyDefeated after a kill ---
	# Replicates production flow: the kill ran through the real perform()
	# above (enemy_dead=true in state); a NEW enemy now walks into vision.
	# Before the fix the planner early-satisfied the goal with the stale fact
	# and returned an empty plan; the agent then held the goal forever.
	unit.sight_list = []
	var enemies = Goap.get_goal("EnemyDefeated")
	var enemy = TestUnit.new()
	enemy.team = "red"
	enemy.global_position = Vector2(50, 100)  # within range (158) and in bounds
	unit.sight_list = [enemy]

	# The documented lifecycle: is_valid() clears enemy_dead while the goal is
	# valid, BEFORE the planner reads it in the same tick.
	var still_valid = enemies.is_valid(agent)
	harness.check(still_valid, "EnemyDefeated: valid while an enemy is in sight.")
	harness.check(agent.get_state("enemy_dead") == false,
		"EnemyDefeated: is_valid() resets the stale enemy_dead fact (documented lifecycle).")

	agent.goap_process(0.0)
	var plan_names: Array = []
	for a in agent._current_plan:
		plan_names.append(a.get_class_name())
	harness.check(not agent._current_plan.is_empty(),
		"Replan after a kill: agent gets a plan, not an empty one (was frozen forever).")
	harness.check(not plan_names.is_empty() and plan_names[0] == "ChooseTarget",
		"Replan after a kill: fresh target acquisition first (plan: %s)" % [", ".join(plan_names)])
	harness.check(plan_names.has("AttackEnemy"),
		"Replan after a kill: the plan still ends in AttackEnemy.")
	harness.check(agent.get_current_action() != null,
		"Replan after a kill: the agent has a current action (was null with an empty plan).")

	# --- 4. End to end: the agent fights the new enemy ---
	# Walk the plan forward: ChooseTarget (already entered via the replan)
	# -> PursueEnemy -> AttackEnemy.enter points and starts the attack.
	var ws = WorldStateSnapshot.new()
	ws.set_state("map", _FakeMap.new())
	agent.goap_process(0.0)  # ChooseTarget.perform completes -> PursueEnemy enters
	agent.goap_process(0.0)  # PursueEnemy.perform: in range -> AttackEnemy enters
	var current = agent.get_current_action()
	harness.check(current != null and current.get_class_name() == "AttackEnemy",
		"Engagement: the agent reaches AttackEnemy against the new enemy.")
	harness.check(agent.get_current_goal() == enemies,
		"Engagement: the EnemyDefeated goal stays current and actionable.")
	agent.goap_process(0.0)  # AttackEnemy.perform: target alive and in range -> keep attacking
	harness.check(current != null and agent.get_current_action() == current,
		"Engagement: AttackEnemy keeps performing while the target lives.")
	harness.check(unit.state == "attack",
		"Engagement: the attack animation state was started.")
	harness.check(unit.aim_point == enemy.global_position + enemy.collision_position,
		"Engagement: the unit aims at the live enemy.")
	ws.restore()
	agent.free()

	# --- 5. Ranged hits go to the victim, not the shooter ---
	var range_action = RangeAttackScript.new()
	var shooter = TestUnit.new()
	shooter.global_position = Vector2.ZERO
	var victim = TestUnit.new()
	victim.team = "red"
	# One loop tick moves the projectile 16px from (10,0) to (26,0); the
	# victim stands within its collision radius of that landing point.
	victim.global_position = Vector2(30, 0)
	var projectile_node = Node2D.new()
	projectile_node.global_position = Vector2(10, 0)
	var projectile = {
		"target": victim,
		"targets": null,
		"node": projectile_node,
		"sprite": null,
		"speed": Vector2(1000, 0),
		"rotation": 0.0,
		"radius": 10000.0,
		"stuck": false,
	}
	shooter.projectiles = [projectile]
	range_action.projectile_loop(shooter, 0.016)
	harness.check(victim.hit_count == 1 and victim.last_hit_attacker == shooter,
		"Ranged hit: the projectile damages the TARGET from the shooter.")
	harness.check(shooter.hit_count == 0,
		"Ranged hit: the shooter no longer damages itself (was killing towers).")
	range_action.free()
	projectile_node.free()


# Minimal stand-in for the map singleton: only what Move.in_bounds reads.
class _FakeMap:
	var tile_size := 64
	var size := Vector2(2048, 2048)
