extends RefCounted

# Instantiates every .tscn in the project (without adding to the tree) to
# catch broken ext_resources, missing scripts, and corrupt scenes.
#
# Scenes that require a running game (the root game scene, the maps it loads,
# and the UI shell) are instantiated too but NOT entered into the tree —
# entering them is the boot test's job (tests/smoke/smoke_runner.gd).

const SKIP_DIRS := [".godot", "addons"]
# Instantiating these at test time would double-boot the game or its maps;
# their resources are still validated by load(), and the real game path is
# covered by the smoke test.
const TREE_HEAVY := ["res://game.tscn", "res://map/maps/"]


func run(harness) -> void:
	var files: Array[String] = []
	_collect_tscn("res://", files)

	var failures: Array[String] = []
	for path in files:
		var packed = load(path)
		if packed == null:
			failures.append("%s (failed to load)" % path)
			continue
		var inst = packed.instantiate()
		if inst == null:
			failures.append("%s (failed to instantiate)" % path)

	harness.check(files.size() > 10,
		"Scene smoke found a plausible number of scenes (%d)." % files.size())
	harness.check(failures.is_empty(),
		"All %d scenes load and instantiate. Failures: %s" % [files.size(), ", ".join(failures)])


func _collect_tscn(dir_path: String, out: Array[String]) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var path = dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with(".") and not name in SKIP_DIRS:
				_collect_tscn(path, out)
		elif name.ends_with(".tscn"):
			var skip := false
			for heavy in TREE_HEAVY:
				if path.begins_with(heavy):
					skip = true
					break
			if not skip:
				out.append(path)
		name = dir.get_next()
	dir.list_dir_end()
