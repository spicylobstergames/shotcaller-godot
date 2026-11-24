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

static func ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(MAP_DIR)


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


# Sorted basenames of the saved maps. [] when user://maps does not exist yet;
# directories and non-.tscn files are never listed.
static func list_maps() -> PackedStringArray:
	var maps := PackedStringArray()
	var dir := DirAccess.open(MAP_DIR)
	if dir == null:
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
	var path := path_for(name)
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
