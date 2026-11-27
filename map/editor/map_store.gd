extends RefCounted

# =============================================================================
# Runtime map store (map/editor/map_store.gd)
# =============================================================================
# The only file that reads/writes map files at runtime. Editor-free and
# headless-testable (tests/unit/test_map_store.gd), so it is the runtime
# counterpart of the plugin's "Save scaffold" action (M1/M3 wrote through
# EditorInterface; this writes through ResourceSaver).
#
# Maps live under user://maps/ — res:// is read-only in exported builds, so
# this store must never resolve a res:// path. Names are sanitized into plain
# basenames before they touch the filesystem: '..'/''/'\'/':' and friends can
# never escape MAP_DIR.
#
# own_tree() is the owner-preservation pattern from map_scaffold.gd's
# _assign_owner, copied rather than shared: a node that already has an owner
# belongs to an instanced scene (a placed building's hud belongs to the
# building) and must keep that owner, otherwise PackedScene.pack() flattens
# the instance's internals into the map scene.
# =============================================================================

const MAP_DIR := "user://maps"
const MAP_EXT := ".tscn"
const FALLBACK_NAME := "map"
const MAX_NAME_LEN := 64

# Characters that are illegal in a file basename on at least one supported
# platform, plus the path separators that would escape MAP_DIR.
const _ILLEGAL_CHARS: Array[String] = [
	"/", "\\", ":", "*", "?", "\"", "<", ">", "|", "\n", "\r", "\t",
]

# The maps dir as an ABSOLUTE filesystem path. Directory operations must go
# through this, never through DirAccess on the user:// scheme directly:
# DirAccessUnix resolves user:// with process-wide chdir bookkeeping
# (core/os/os.cpp's data-dir string enters DirAccess::fix_path), and when that
# data-dir string degrades, DirAccess.open("user://maps") SUCCEEDS while
# latched onto the process CWD — the PR #242 CI flake listed the PROJECT ROOT
# (its only root-level .tscn is game.tscn) and presented "game" as the map
# list instead of failing. FileAccess/FileAccess-based ResourceSaver ops on
# user:// were correct in the same failing process, which is why save and
# load keep the scheme while every DirAccess op globalizes first.
static func maps_dir_absolute() -> String:
	return ProjectSettings.globalize_path(MAP_DIR)


static func ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(maps_dir_absolute())


# A name is a basename, not a path: whitespace becomes '_', path separators and
# other illegal characters are dropped, '..' collapses, and leading/trailing
# dots are trimmed ('.' and '..' are directories, not files). An empty result
# is a real name ("map") so a caller can never save to "…/​.tscn".
static func sanitize_name(raw: String) -> String:
	# Trimmed BEFORE the space→'_' mapping: '  spaced  ' is "spaced", not
	# '__spaced__', and a name that is only whitespace/dots has nothing left.
	var name := ""
	var trimmed := raw.strip_edges()
	for i in trimmed.length():
		var c: String = trimmed[i]
		if c == " ":
			name += "_"
		elif c in _ILLEGAL_CHARS:
			continue
		else:
			name += c
	# Dropping separators can join two dots into a traversal step ("a./." ->
	# "a.."), so collapse repeatedly instead of doing one replace pass.
	while name.contains(".."):
		name = name.replace("..", "")
	while name.begins_with("."):
		name = name.substr(1)
	while name.ends_with("."):
		name = name.substr(0, name.length() - 1)
	if name.length() > MAX_NAME_LEN:
		name = name.substr(0, MAX_NAME_LEN)
		while name.ends_with("."):
			name = name.substr(0, name.length() - 1)
	if name.is_empty():
		return FALLBACK_NAME
	return name


static func path_for(name: String) -> String:
	return MAP_DIR + "/" + sanitize_name(name) + MAP_EXT


# Sorted basenames of the saved maps. [] when the maps dir does not exist
# yet; directories and non-.tscn files are never listed. Only a listing of
# the REAL maps dir may come back: the opened directory is verified against
# maps_dir_absolute(), and anything else is an error, not a (possibly
# foreign-directory) name list.
static func list_maps() -> PackedStringArray:
	var maps := PackedStringArray()
	var dir_path := ProjectSettings.globalize_path(MAP_DIR).simplify_path()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		if DirAccess.dir_exists_absolute(dir_path):
			push_error("map_store: listing %s failed: %s" % [
					dir_path, error_string(DirAccess.get_open_error())])
		return maps  # absent dir = no maps saved yet
	var opened := dir.get_current_dir().simplify_path()
	if opened != dir_path:
		push_error("map_store: listing %s opened %s instead — refusing to read a foreign directory" % [
				dir_path, opened])
		return maps
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and not file.begins_with(".") and file.ends_with(MAP_EXT):
			maps.append(file.get_basename())
		file = dir.get_next()
	dir.list_dir_end()
	maps.sort()
	return maps


static func save_map(map_root: Node, name: String) -> int:
	if map_root == null or not is_instance_valid(map_root):
		return ERR_INVALID_PARAMETER
	ensure_dir()
	own_tree(map_root, map_root)
	var packed := PackedScene.new()
	var err := packed.pack(map_root)
	if err != OK:
		return err
	return ResourceSaver.save(packed, path_for(name))


# null when the map is missing or is not a scene; the caller logs.
static func load_map(name: String) -> Node:
	var path := path_for(name)
	if not FileAccess.file_exists(path):
		return null
	var res = load(path)
	if not (res is PackedScene):
		return null
	var map: Node = (res as PackedScene).instantiate()
	own_tree(map, map)
	return map


# Only files this store could have produced under MAP_DIR are deletable — the
# path is rebuilt from the sanitized name, never taken from the caller.
static func delete_map(name: String) -> int:
	var path := maps_dir_absolute() + "/" + sanitize_name(name) + MAP_EXT
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	return DirAccess.remove_absolute(path)


# Same shape as map_scaffold.gd's _assign_owner: recurse into a child only when
# it has no owner yet, so instanced scenes keep their own ownership tree.
static func own_tree(node: Node, owner: Node) -> void:
	for child in node.get_children():
		if child.get_owner() != null:
			continue
		child.owner = owner
		own_tree(child, owner)
