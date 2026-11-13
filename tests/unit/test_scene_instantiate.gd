extends RefCounted

# Instantiates every .tscn in the project (without adding it to the tree) to
# catch broken ext_resources, missing scripts, and corrupt scenes — including
# game.tscn and the map scenes. Entering the full game into the tree is the
# boot smoke test's job; here we only build the node structures.

const FsScan = preload("res://tests/helpers/fs_scan.gd")


func run(harness) -> void:
	var files: Array[String] = []
	FsScan.collect("res://", ".tscn", files)

	var failures: Array[String] = []
	for path in files:
		var packed = load(path)
		if packed == null:
			failures.append("%s (failed to load)" % path)
			continue
		var inst = packed.instantiate()
		if inst == null:
			failures.append("%s (failed to instantiate)" % path)
		elif inst is Node:
			inst.free()  # PackedScene.instantiate() returns a Node we own

	harness.check(files.size() > 10,
		"Scene smoke found a plausible number of scenes (%d)." % files.size())
	harness.check(failures.is_empty(),
		"All %d scenes load and instantiate. Failures: %s" % [files.size(), ", ".join(failures)])
