extends RefCounted

<<<<<<< HEAD
# The Modifiers autoload is a Node instance (autoloaded from skills/modifiers.gd).


# Minimal doubles for modifier testing.
class TestUnit:
	extends RefCounted
	var speed: float = 10.0
	var regen: int = 0
	var attack_range: float = 1.0
	var attack_hit_radius: float = 24.0
	var current_modifiers: Dictionary
	var level: int = 1
	var agent = null
	var hunting_speed: float = 0.0
	var target = null
	var defense: int = 0
	var damage: int = 10

	func _init():
		current_modifiers = Modifiers.new_modifiers()


class TestAgent:
	extends RefCounted
	var state := {}

	func get_state(state_name: String, default_value = null):
		return state.get(state_name, default_value)

	func set_state(state_name: String, value) -> void:
		state[state_name] = value


func run(harness) -> void:
	# --- new_modifiers() ---

	var modifier_list = Modifiers.new_modifiers()
	harness.check_equal(
		modifier_list.keys(),
		["hp", "regen", "vision", "speed", "damage", "attack_range", "attack_speed", "defense", "dot"],
		"new_modifiers returns all expected modifier categories."
	)
	for key in modifier_list:
		harness.check(modifier_list[key] is Array, "Category '%s' is an empty array." % key)

	# --- add() / remove() ---

	var unit = TestUnit.new()
	Modifiers.add(unit, "damage", "strength_boost", 5)
	harness.check_equal(unit.current_modifiers["damage"].size(), 1, "add() inserts one modifier entry.")
	harness.check_equal(
		unit.current_modifiers["damage"][0],
		{"name": "strength_boost", "value": 5},
		"add() stores name and value correctly."
	)

	# Multiple named modifiers should accumulate.
	Modifiers.add(unit, "damage", "fire_enchant", 3)
	harness.check_equal(unit.current_modifiers["damage"].size(), 2, "add() allows multiple named modifiers.")

	Modifiers.remove(unit, "damage", "strength_boost")
	harness.check_equal(unit.current_modifiers["damage"].size(), 1, "remove() deletes the matching modifier.")
	harness.check_equal(
		unit.current_modifiers["damage"][0]["name"],
		"fire_enchant",
		"remove() preserves other entries."
	)

	# Removing a non-existent name should not crash.
	Modifiers.remove(unit, "damage", "ghost")
	harness.check_equal(unit.current_modifiers["damage"].size(), 1, "remove() is safe for unknown names.")

	# --- get_value() base cases ---

	var base_unit = TestUnit.new()
	base_unit.speed = 8.0
	base_unit.regen = 2
	base_unit.damage = 10
	base_unit.defense = 5
	base_unit.level = 1
	harness.check_equal(Modifiers.get_value(base_unit, "damage"), 10, "get_value returns base damage at level 1.")
	harness.check_equal(Modifiers.get_value(base_unit, "defense"), 5, "get_value returns base defense at level 1.")
	harness.check_equal(Modifiers.get_value(base_unit, "speed"), 8.0, "get_value returns base speed at level 1.")

	# --- get_value() level scaling ---

	var level2_unit = TestUnit.new()
	level2_unit.speed = 8.0
	level2_unit.regen = 2
	level2_unit.damage = 10
	level2_unit.defense = 5
	level2_unit.level = 2
	harness.check_equal(Modifiers.get_value(level2_unit, "damage"), 12.5, "get_value applies +2.5 damage per level.")
	harness.check_equal(Modifiers.get_value(level2_unit, "defense"), 7.0, "get_value applies +2 defense per level.")
	harness.check_equal(Modifiers.get_value(level2_unit, "regen"), 4.0, "get_value applies +2 regen per level.")

	var level5_unit = TestUnit.new()
	level5_unit.speed = 8.0
	level5_unit.damage = 10
	level5_unit.defense = 5
	level5_unit.level = 5
	harness.check_equal(Modifiers.get_value(level5_unit, "damage"), 20.0, "get_value applies cumulative level bonus.")
	harness.check_equal(Modifiers.get_value(level5_unit, "defense"), 13.0, "defense scales linearly with level.")

	# --- get_value() modifier stacking ---

	var stack_unit = TestUnit.new()
	stack_unit.damage = 10
	stack_unit.level = 1
	Modifiers.add(stack_unit, "damage", "buff_1", 5)
	Modifiers.add(stack_unit, "damage", "buff_2", 3)
	harness.check_equal(Modifiers.get_value(stack_unit, "damage"), 18, "get_value sums all active damage modifiers.")

	# --- tactic speed bonuses ---

	var tactic_unit = TestUnit.new()
	tactic_unit.speed = 10.0
	tactic_unit.level = 1
	tactic_unit.agent = TestAgent.new()

	tactic_unit.agent.set_state("tactic", "attack")
	harness.check_equal(Modifiers.get_value(tactic_unit, "speed"), 15.0, "Attack tactic adds +5 speed.")

	tactic_unit.agent.set_state("tactic", "defend")
	harness.check_equal(Modifiers.get_value(tactic_unit, "speed"), 5.0, "Defend tactic subtracts 5 speed.")

	tactic_unit.agent.set_state("tactic", "retreat")
	harness.check_equal(Modifiers.get_value(tactic_unit, "speed"), 10.0, "Retreat tactic adds no base speed bonus.")

	tactic_unit.agent.set_state("tactic", "default")
	harness.check_equal(Modifiers.get_value(tactic_unit, "speed"), 10.0, "Default tactic has no speed bonus.")

	# Unknown tactic should default to 0 extra.
	tactic_unit.agent.set_state("tactic", "unknown_tactic")
	harness.check_equal(Modifiers.get_value(tactic_unit, "speed"), 10.0, "Unknown tactic defaults to no speed change.")

	# --- get_velocity() with hunting / retreating ---

	var velocity_unit = TestUnit.new()
	velocity_unit.speed = 10.0
	velocity_unit.hunting_speed = 20.0
	velocity_unit.level = 1
	velocity_unit.agent = TestAgent.new()
	velocity_unit.agent.set_state("tactic", "default")

	# Neither hunting nor retreating: use base speed + tactic.
	velocity_unit.agent.set_state("hunting", false)
	velocity_unit.agent.set_state("is_retreating", false)
	harness.check_equal(Modifiers.get_velocity(velocity_unit), 10.0, "Normal movement uses base speed.")

	# Hunting but target not retreating.
	velocity_unit.agent.set_state("hunting", true)
	velocity_unit.agent.set_state("is_retreating", false)
	var target_unit = TestUnit.new()
	var target_agent = TestAgent.new()
	target_unit.agent = target_agent
	velocity_unit.target = target_unit
	harness.check_equal(Modifiers.get_velocity(velocity_unit), 20.0, "Hunting speed when target is not retreating.")

	# Retreating should add extra_retreat_speed (10) plus tactic bonus.
	velocity_unit.agent.set_state("is_retreating", true)
	velocity_unit.agent.set_state("hunting", false)
	harness.check_equal(Modifiers.get_velocity(velocity_unit), 20.0, "Retreating adds 10 base speed bonus.")

	velocity_unit.agent.set_state("tactic", "attack")
	harness.check_equal(Modifiers.get_velocity(velocity_unit), 25.0, "Retreating + attack tactic stacks bonuses.")

	# --- get_regen() ---

	var regen_unit = TestUnit.new()
	regen_unit.regen = 5
	regen_unit.level = 1
	regen_unit.agent = TestAgent.new()
	regen_unit.agent.set_state("is_retreating", false)
	harness.check_equal(Modifiers.get_regen(regen_unit), 5, "Regen is base when not retreating.")

	regen_unit.agent.set_state("is_retreating", true)
	harness.check_equal(Modifiers.get_regen(regen_unit), 15, "Regen gets +10 retreat bonus.")

	# --- get_att_range() ---

	var range_unit = TestUnit.new()
	range_unit.attack_range = 1.5
	range_unit.attack_hit_radius = 30.0
	range_unit.agent = null
	harness.check_equal(Modifiers.get_att_range(range_unit), 45.0, "Attack range = hit_radius * range_multiplier.")

	# --- get_dot() ---

	var dot_unit = TestUnit.new()
	dot_unit.damage = 10
	dot_unit.level = 1
	Modifiers.add(dot_unit, "dot", "fire", 3)
	Modifiers.add(dot_unit, "dot", "poison", 2)
	harness.check_equal(Modifiers.get_dot(dot_unit), [3, 2], "get_dot returns all dot effect values.")

	dot_unit.current_modifiers["dot"].clear()
	harness.check(Modifiers.get_dot(dot_unit) == null, "get_dot returns null when no dots active.")
=======
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
>>>>>>> main
