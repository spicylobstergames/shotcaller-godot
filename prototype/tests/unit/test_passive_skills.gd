extends Node

const PassiveSkillsScript = preload("res://skills/passive_skills.gd")


func run(harness) -> void:
	# Create a PassiveSkills instance inside a scene tree so _ready() fires.
	var container = Node.new()
	var passive_skills = PassiveSkillsScript.new()
	container.add_child(passive_skills)

	# _ready() on passive_skills loads the preload once; adding to tree
	# ensures any deferred initialization also runs.
	await container.get_tree().process_frame

	# ---- helper: build a minimal mock unit with `type` and `display_name` ----
	func make_unit(display_name: String) -> RefCounted:
		var u = RefCounted.new()
		u.type = "leader"
		u.display_name = display_name
		return u

	# Raja has "dodge": 0.2 — assert the actual expected value, not just >= 0.
	var raja = make_unit("raja")
	harness.check_equal(
		passive_skills.get_value(raja, "dodge"),
		0.2,
		"Raja dodge value matches leader_passives.tres (0.2)."
	)

	# Arthur has "stun": 0.25 — another known-good assertion.
	var arthur = make_unit("arthur")
	harness.check_equal(
		passive_skills.get_value(arthur, "stun"),
		0.25,
		"Arthur stun value matches leader_passives.tres (0.25)."
	)

	# Unknown leader should return 0 for any skill.
	var unknown = make_unit("nobody")
	harness.check_equal(
		passive_skills.get_value(unknown, "dodge"),
		0,
		"Unknown leader returns 0 for dodge."
	)

	container.free()
