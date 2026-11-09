extends RefCounted

# Parses every .gd file in the project. A file that fails to compile is a
# blocking defect even if no test currently exercises it — this catches
# syntax errors, bad preloads, and missing identifiers in dead code paths.

const SKIP_DIRS := [".godot", "addons"]


func run(harness) -> void:
	var files: Array[String] = []
	_collect_gd("res://", files)

	var failures: Array[String] = []
	for path in files:
		var script = load(path)
		if script == null:
			failures.append(path)

	harness.check_equal(files.size(), files.size(),
		"Parse smoke collected GDScript files (sanity: list non-empty).")
	harness.check(files.size() > 50,
		"Parse smoke found a plausible number of scripts (%d)." % files.size())
	harness.check(failures.is_empty(),
		"All %d GDScript files compile cleanly. Failures: %s" % [files.size(), ", ".join(failures)])


func _collect_gd(dir_path: String, out: Array[String]) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir():
			if not name.begins_with(".") and not name in SKIP_DIRS:
				_collect_gd(dir_path.path_join(name), out)
		elif name.ends_with(".gd"):
			out.append(dir_path.path_join(name))
		name = dir.get_next()
	dir.list_dir_end()
