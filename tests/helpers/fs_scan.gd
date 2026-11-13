extends RefCounted

# Shared file-scanning helper for the whole-project smoke tests.

const SKIP_DIRS := [".godot", "addons"]


# Collects every file under dir_path whose name ends with `extension`
# (e.g. ".gd", ".tscn"), skipping hidden dirs, Godot's cache dir, and addons.
# Everything else — including test scripts themselves — is scanned: a broken
# test file is as much a defect as a broken production file.
static func collect(dir_path: String, extension: String, out: Array[String]) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var path = dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with(".") and not name in SKIP_DIRS:
				collect(path, extension, out)
		elif name.ends_with(extension):
			out.append(path)
		name = dir.get_next()
	dir.list_dir_end()
