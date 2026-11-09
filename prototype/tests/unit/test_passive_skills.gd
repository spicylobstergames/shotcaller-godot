extends RefCounted

const PassiveSkillsScript = preload("res://skills/passive_skills.gd")
const WorldStateSnapshot = preload("res://tests/helpers/world_state_snapshot.gd")


class TestUnit:
	extends RefCounted
	var type := "leader"
	var display_name := ""


# Combat double: exposes exactly what hit_modifiers and Modifiers.get_value
# touch. RefCounted.get(property) resolves script properties, which is all
# the production code needs.
class CombatUnit:
	extends RefCounted
	var type := "infantry"
	var display_name := ""
	var ranged := false
	var attack_count := 0
	var damage := 5  # fallback damage via Modifiers.get_value
	var level := 1
	var current_modifiers := {
		"hp": [], "regen": [], "vision": [], "speed": [], "damage": [],
		"attack_range": [], "attack_speed": [], "defense": [], "dot": []
	}
	var stunned := false

	func stun_start() -> void:
		stunned = true


# Records EnemyDefeated.take_hit calls so the counter branch can be asserted
# without running the real damage pipeline.
class GoalSpy extends "res://tests/helpers/mock_goal.gd":
	var take_hit_calls: Array = []

	func take_hit(attacker, target, projectile = null, hit_modifiers = {}) -> void:
		take_hit_calls.append({"attacker": attacker, "target": target, "modifiers": hit_modifiers})


func run(harness) -> void:
	# --- get_value (leader skill lookup) ---
	var passive_skills = PassiveSkillsScript.new()
	passive_skills._ready()

	# Raja has "dodge": 0.2 — assert the actual expected value, not just >= 0.
	var raja = TestUnit.new()
	raja.display_name = "raja"
	harness.check_equal(
		passive_skills.get_value(raja, "dodge"),
		0.2,
		"Raja dodge value matches leader_passives.tres (0.2)."
	)

	# Arthur has "stun": 0.25 — another known-good assertion.
	var arthur = TestUnit.new()
	arthur.display_name = "arthur"
	harness.check_equal(
		passive_skills.get_value(arthur, "stun"),
		0.25,
		"Arthur stun value matches leader_passives.tres (0.25)."
	)

	# Unknown leader should return 0 for any skill.
	var unknown = TestUnit.new()
	unknown.display_name = "nobody"
	harness.check_equal(
		passive_skills.get_value(unknown, "dodge"),
		0,
		"Unknown leader returns 0 for dodge."
	)

	# --- hit_modifiers (combat resolution) ---
	_test_damage_passthrough(harness)
	_test_damage_fallback_to_modifiers(harness)
	_test_flag_initialization(harness)
	_test_dodge_always(harness)
	_test_dodge_never(harness)
	_test_stun_applies(harness)
	_test_stun_skips_buildings(harness)
	_test_critical_doubles(harness)
	_test_cleave_multiplies(harness)
	_test_pierce(harness)
	_test_bleed_scales_with_attack_count(harness)
	_test_agile_adds_attack_speed_modifier(harness)
	_test_counter_swaps_damage_and_records_hit(harness)
	_test_counter_skips_ranged_attackers(harness)
	_test_empty_skill_dict_returns_null(harness)
	_test_no_leader_skills_passthrough(harness)


# --- hit_modifiers helpers ---

# A tree-attached PassiveSkills instance so /root/Goap and /root/Modifiers
# resolve (a standalone .new() cannot resolve autoloads).
func _make_skills(harness) -> Node:
	var skills = PassiveSkillsScript.new()
	harness.add_child(skills)  # _ready() fires; leader dict loads from .tres
	return skills


func _teardown(harness, skills, original_leader) -> void:
	skills.leader = original_leader
	skills.queue_free()


# Standard scenario: attacker "hero", target "villain"; skill dicts injected
# via the production seam (Skills.leader is the real lookup table).
func _combat_setup(skills, attacker_skills: Dictionary, target_skills: Dictionary):
	# Only skill-bearing units get a leader-table entry — production data
	# never contains empty skill dicts, and hit_modifiers early-returns null
	# on them (see _test_empty_skill_dict_returns_null).
	var entry := {}
	if not attacker_skills.is_empty():
		entry["hero"] = attacker_skills
	if not target_skills.is_empty():
		entry["villain"] = target_skills
	skills.leader = entry
	var attacker = CombatUnit.new()
	attacker.display_name = "hero"
	var target = CombatUnit.new()
	target.display_name = "villain"
	return [attacker, target]


func _test_damage_passthrough(harness) -> void:
	var skills = _make_skills(harness)
	var original = skills.leader
	var pair = _combat_setup(skills, {}, {})
	var attacker = pair[0]
	var target = pair[1]
	var result = skills.hit_modifiers(attacker, target, null, {"damage": 7})
	harness.check_equal(result.damage, 7,
		"hit_modifiers uses provided damage when present.")
	_teardown(harness, skills, original)


func _test_damage_fallback_to_modifiers(harness) -> void:
	var skills = _make_skills(harness)
	var original = skills.leader
	var pair = _combat_setup(skills, {}, {})
	var attacker = pair[0]
	var target = pair[1]
	# No damage in input modifiers: falls back to Modifiers.get_value(attacker, "damage").
	var result = skills.hit_modifiers(attacker, target, null, {})
	harness.check_equal(result.damage, 5,
		"hit_modifiers falls back to the attacker's damage modifier (CombatUnit.damage = 5).")
	_teardown(harness, skills, original)


func _test_flag_initialization(harness) -> void:
	var skills = _make_skills(harness)
	var original = skills.leader
	var pair = _combat_setup(skills, {}, {})
	var attacker = pair[0]
	var target = pair[1]
	var result = skills.hit_modifiers(attacker, target, null, {"damage": 5, "cleave": true})
	harness.check(result.cleave == true, "Cleave flag passes through from input modifiers.")
	harness.check(result.dodge == false, "Dodge starts false when target has no dodge skill.")
	harness.check(result.pierce == false, "Pierce starts false when attacker has no pierce skill.")
	harness.check(result.counter == true, "Counter defaults to true when input omits it.")
	var result2 = skills.hit_modifiers(attacker, target, null, {"damage": 5, "counter": false})
	harness.check(result2.counter == false, "Counter=false is preserved from input modifiers.")
	_teardown(harness, skills, original)


func _test_dodge_always(harness) -> void:
	var skills = _make_skills(harness)
	var original = skills.leader
	var pair = _combat_setup(skills, {}, {"dodge": 1.0})
	var result = skills.hit_modifiers(pair[0], pair[1], null, {"damage": 5})
	harness.check(result.dodge == true,
		"Dodge skill 1.0 always dodges (deterministic: no RNG dependency).")
	_teardown(harness, skills, original)


func _test_dodge_never(harness) -> void:
	var skills = _make_skills(harness)
	var original = skills.leader
	var pair = _combat_setup(skills, {}, {"dodge": 0.0})
	var result = skills.hit_modifiers(pair[0], pair[1], null, {"damage": 5})
	harness.check(result.dodge == false,
		"Dodge skill 0.0 never dodges (deterministic: no RNG dependency).")
	_teardown(harness, skills, original)


func _test_stun_applies(harness) -> void:
	var skills = _make_skills(harness)
	var original = skills.leader
	var pair = _combat_setup(skills, {"stun": 1.0}, {})
	var target = pair[1]
	skills.hit_modifiers(pair[0], target, null, {"damage": 5, "counter": false})
	harness.check(target.stunned == true,
		"Stun skill 1.0 always stuns non-building targets.")
	_teardown(harness, skills, original)


func _test_stun_skips_buildings(harness) -> void:
	var skills = _make_skills(harness)
	var original = skills.leader
	var pair = _combat_setup(skills, {"stun": 1.0}, {})
	var target = pair[1]
	target.type = "building"
	skills.hit_modifiers(pair[0], target, null, {"damage": 5, "counter": false})
	harness.check(target.stunned == false,
		"Buildings are never stunned, even with stun skill 1.0.")
	_teardown(harness, skills, original)


func _test_critical_doubles(harness) -> void:
	var skills = _make_skills(harness)
	var original = skills.leader
	var pair = _combat_setup(skills, {"critical": 1.0}, {})
	var result = skills.hit_modifiers(pair[0], pair[1], null, {"damage": 5, "counter": false})
	harness.check_equal(result.damage, 10,
		"Critical skill 1.0 always doubles damage.")
	var pair2 = _combat_setup(skills, {"critical": 0.0}, {})
	var result2 = skills.hit_modifiers(pair2[0], pair2[1], null, {"damage": 5, "counter": false})
	harness.check_equal(result2.damage, 5,
		"Critical skill 0.0 never doubles damage.")
	_teardown(harness, skills, original)


func _test_cleave_multiplies(harness) -> void:
	var skills = _make_skills(harness)
	var original = skills.leader
	# Cleave requires BOTH the input flag and the attacker skill.
	var pair = _combat_setup(skills, {"cleave": 2.0}, {})
	var result = skills.hit_modifiers(pair[0], pair[1], null, {"damage": 5, "cleave": true, "counter": false})
	harness.check_equal(result.damage, 10,
		"Cleave skill 2.0 doubles damage when the input cleave flag is set.")
	# Without the input flag, cleave does not apply.
	var result2 = skills.hit_modifiers(pair[0], pair[1], null, {"damage": 5, "counter": false})
	harness.check_equal(result2.damage, 5,
		"Cleave skill does not apply without the input cleave flag.")
	_teardown(harness, skills, original)


func _test_pierce(harness) -> void:
	var skills = _make_skills(harness)
	var original = skills.leader
	var pair = _combat_setup(skills, {"pierce": 1.0}, {})
	var result = skills.hit_modifiers(pair[0], pair[1], null, {"damage": 5, "counter": false})
	harness.check(result.pierce == true, "Pierce skill 1.0 always pierces.")
	var pair2 = _combat_setup(skills, {"pierce": 0.0}, {})
	var result2 = skills.hit_modifiers(pair2[0], pair2[1], null, {"damage": 5, "counter": false})
	harness.check(result2.pierce == false, "Pierce skill 0.0 never pierces.")
	_teardown(harness, skills, original)


func _test_bleed_scales_with_attack_count(harness) -> void:
	var skills = _make_skills(harness)
	var original = skills.leader
	var pair = _combat_setup(skills, {"bleed": 2}, {})
	var attacker = pair[0]
	attacker.attack_count = 3
	var result = skills.hit_modifiers(attacker, pair[1], null, {"damage": 5, "counter": false})
	harness.check_equal(result.damage, 11,
		"Bleed adds skill value x attack_count (2 x 3 = 6 on top of 5).")
	# Bleed caps at 10 stacks.
	attacker.attack_count = 50
	var result2 = skills.hit_modifiers(attacker, pair[1], null, {"damage": 5, "counter": false})
	harness.check_equal(result2.damage, 25,
		"Bleed caps at 10 stacks (2 x 10 = 20 on top of 5).")
	_teardown(harness, skills, original)


func _test_agile_adds_attack_speed_modifier(harness) -> void:
	var skills = _make_skills(harness)
	var original = skills.leader
	var pair = _combat_setup(skills, {"agile": 0.1}, {})
	var attacker = pair[0]
	attacker.attack_count = 4
	skills.hit_modifiers(attacker, pair[1], null, {"damage": 5, "counter": false})
	# The real Modifiers autoload should now hold an "agile" attack_speed entry.
	var agile_mods = attacker.current_modifiers["attack_speed"]
	harness.check_equal(agile_mods.size(), 1,
		"Agile adds one attack_speed modifier to the attacker.")
	if agile_mods.size() == 1:
		harness.check_equal(agile_mods[0]["name"], "agile",
			"Agile modifier is named 'agile' in the real Modifiers stack.")
		harness.check_equal(agile_mods[0]["value"], 0.4,
			"Agile value scales with attack_count (0.1 x 4).")
	_teardown(harness, skills, original)


func _test_counter_swaps_damage_and_records_hit(harness) -> void:
	var skills = _make_skills(harness)
	var original = skills.leader
	var pair = _combat_setup(skills, {}, {"counter": 10})
	var attacker = pair[0]
	var target = pair[1]

	# Swap the real EnemyDefeated goal for a spy: the counter branch calls
	# take_hit, and the real goal would recurse into the full damage pipeline.
	var original_goal = Goap.get_goal("EnemyDefeated")
	var spy = GoalSpy.new()
	Goap._goals.set_goal("EnemyDefeated", spy)

	var result = skills.hit_modifiers(attacker, target, null, {"damage": 5, "counter": false})

	Goap._goals.set_goal("EnemyDefeated", original_goal)

	harness.check_equal(result.damage, 10,
		"Counter sets damage to the target's counter value (10).")
	harness.check_equal(spy.take_hit_calls.size(), 1,
		"Counter branch calls EnemyDefeated.take_hit exactly once.")
	if spy.take_hit_calls.size() == 1:
		# take_hit is called with (target, attacker) — the hit lands on the attacker.
		harness.check(spy.take_hit_calls[0]["attacker"] == target,
			"Counter take_hit passes the TARGET as the new attacker (retaliation direction).")
		harness.check(spy.take_hit_calls[0]["target"] == attacker,
			"Counter take_hit passes the ATTACKER as the victim (retaliation direction).")
	_teardown(harness, skills, original)


func _test_counter_skips_ranged_attackers(harness) -> void:
	var skills = _make_skills(harness)
	var original = skills.leader
	var pair = _combat_setup(skills, {}, {"counter": 10})
	var attacker = pair[0]
	var target = pair[1]
	attacker.ranged = true

	var original_goal = Goap.get_goal("EnemyDefeated")
	var spy = GoalSpy.new()
	Goap._goals.set_goal("EnemyDefeated", spy)

	var result = skills.hit_modifiers(attacker, target, null, {"damage": 5, "counter": false})

	Goap._goals.set_goal("EnemyDefeated", original_goal)

	harness.check_equal(result.damage, 5,
		"Ranged attackers take no counter damage.")
	harness.check_equal(spy.take_hit_calls.size(), 0,
		"Counter branch never fires for ranged attackers.")
	_teardown(harness, skills, original)


func _test_empty_skill_dict_returns_null(harness) -> void:
	# DOCUMENTED QUIRK (latent bug): a unit present in the leader table with an
	# EMPTY skill dict makes hit_modifiers early-return null instead of the
	# modifiers dictionary — any caller doing result.damage would crash.
	# Production .tres data never produces empty dicts, so this is latent;
	# this test pins current behavior so a fix flips it deliberately.
	var skills = _make_skills(harness)
	var original = skills.leader
	skills.leader = {"hero": {}, "villain": {"dodge": 1.0}}
	var attacker = CombatUnit.new()
	attacker.display_name = "hero"
	var target = CombatUnit.new()
	target.display_name = "villain"
	var result = skills.hit_modifiers(attacker, target, null, {"damage": 5})
	harness.check(result == null,
		"QUIRK: empty attacker skill dict makes hit_modifiers return null (latent caller crash, pinned current behavior).")
	_teardown(harness, skills, original)


func _test_no_leader_skills_passthrough(harness) -> void:
	var skills = _make_skills(harness)
	var original = skills.leader
	skills.leader = {}  # neither unit is a known leader
	var attacker = CombatUnit.new()
	attacker.display_name = "hero"
	var target = CombatUnit.new()
	target.display_name = "villain"
	var result = skills.hit_modifiers(attacker, target, null, {"damage": 5, "counter": false})
	harness.check_equal(result.damage, 5,
		"Unknown leaders: damage passes through untouched.")
	harness.check(result.counter == false,
		"Unknown leaders: input counter flag preserved.")
	_teardown(harness, skills, original)
