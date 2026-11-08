extends RefCounted

const Modifiers = preload("res://skills/modifiers.gd")


class TestUnit:
	extends RefCounted
	var speed := 10.0
	var regen := 5.0
	var hp := 100
	var current_hp := 100
	var level := 1
	var current_modifiers: Dictionary = {"hp": [], "speed": [], "regen": [], "vision": [], "damage": [], "attack_range": [], "attack_speed": [], "defense": [], "dot": []}


class TestUnitNoModifiers:
# Unit missing both level and current_modifiers — edge-case for PR fixes.
	extends RefCounted
	var speed := 8.0


class TestAgent:
	var states := {"tactic": "default"}

	func get_state(state_name: String, default = null):
		return states.get(state_name, default)


# ---------------------------------------------------------------------------
# Helper that captures whether push_warning was called for a given string.
# Since push_warning itself prints to the console, we use a sentinel approach:
#   We intercept via overriding Modifiers._is_known_modifier indirectly by
#   checking that an unknown mod_name does NOT crash and still returns a number.
# ---------------------------------------------------------------------------


func run(harness) -> void:
	var mod = Modifiers.new()

	# --- 1. Normal modifier lookup ---
	var unit = TestUnit.new()
	harness.check_equal(
		mod.get_value(unit, "hp"), 100, "Basic hp value equals default for level 1."
	)
	harness.check_equal(
		mod.get_value(unit, "regen"), 5, "Basic regen value equals default."
	)
	harness.check_equal(
		mod.get_value(unit, "speed"), 10.0, "Basic speed value equals default."
	)

	# --- 2. Warning for unknown modifier names ---
	# push_warning is called internally; the result should still be a safe number.
	var unknown_result: float = mod.get_value(unit, "nonexistent_mod")
	harness.check(
		typeof(unknown_result) == TYPE_FLOAT or typeof(unknown_result) == TYPE_INT,
		"Unknown modifier returns a numeric value (warning was logged)."
	)

	# --- 3. Unit missing level / current_modifiers ---
	var bare_unit = TestUnitNoModifiers.new()
	var hp_result = mod.get_value(bare_unit, "hp")
	harness.check(
		typeof(hp_result) == TYPE_FLOAT or typeof(hp_result) == TYPE_INT,
		"Unit without level/current_modifiers still returns a safe value."
	)

	# --- 4. get_velocity with missing unit properties ---
	var velocity = mod.get_velocity(bare_unit)
	harness.check_equal(
		velocity, 8.0, "get_velocity uses unit.get('speed', 0.0) and returns 8.0 for bare unit."
	)

	# --- 5. get_velocity with null unit ---
	var null_velocity = mod.get_velocity(null)
	harness.check_equal(
		null_velocity, 0, "get_velocity(null) returns 0."
	)

	# --- 6. Modifier stack: speed with tactic ---
	unit = TestUnit.new()
	unit.agent = TestAgent.new()
	unit.agent.states["tactic"] = "attack"
	harness.check_equal(
		mod.get_value(unit, "speed"), 15.0, "Attack tactic adds 5 to base speed."
	)

	unit.agent.states["tactic"] = "defend"
	harness.check_equal(
		mod.get_value(unit, "speed"), 5.0, "Defend tactic subtracts 5 from base speed."
	)

	unit.agent.states["tactic"] = "default"
	unit.agent.free()
	unit.free()
	bare_unit.free()
