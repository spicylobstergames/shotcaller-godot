extends RefCounted

const PassiveSkillsScript = preload("res://skills/passive_skills.gd")


class TestUnit:
	extends RefCounted
	var type := "leader"
	var display_name := ""


func run(harness) -> void:
	# Create a PassiveSkills instance and call _ready() manually
	# since we don't have a scene tree in headless tests.
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
