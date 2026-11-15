extends RefCounted

# Builds docs/ai/goap-index.md from the GOAP-GUIDE banners.
#
# The banners are the single source of truth: this file never hard-codes an
# action/goal list. tests/unit/test_goap_index.gd compares build() against the
# committed index, so the docs cannot drift from the code.

const INDEX_PATH := "res://docs/ai/goap-index.md"


static func build() -> String:
	var files: Array[String] = []
	_collect("res://goap", ".gd", files)
	files.sort()

	var goals: Array = []
	var actions: Array = []
	for path in files:
		var kind := "goal" if "/goals/" in path else ("action" if "/actions/" in path else "")
		if kind == "":
			continue
		var text := FileAccess.get_file_as_string(path)
		if not text.contains("GOAP-GUIDE"):
			continue
		var parsed := _parse_banner(text, path)
		if parsed.is_empty():
			continue
		parsed["kind"] = kind
		if kind == "goal":
			goals.append(parsed)
		else:
			actions.append(parsed)

	var out := "# GOAP Index (generated)\n\n"
	out += "Generated from the `GOAP-GUIDE` banners at the top of every GOAP script.\n"
	out += "Do not edit by hand — run `./tools/gen_goap_index.sh` after changing a banner.\n"
	out += "`tests/unit/test_goap_index.gd` fails when this file is stale.\n\n"
	out += "Companion docs: `ARCHITECTURE.md` (system map), `goap-cheatsheet.md`\n"
	out += "(one-page summary), `world-state.md` (fact catalog). Fields shown as\n"
	out += "`-` are not stated in that script's banner (usually a service action).\n\n"

	out += "## Goals (%d)\n\n" % goals.size()
	out += "| Goal | Priority | Desired state | File |\n"
	out += "|------|----------|---------------|------|\n"
	for goal in goals:
		out += "| %s | %s | %s | `%s` |\n" % [
			_cell(goal["name"]),
			_cell(goal["fields"].get("priority", "-")),
			_cell(goal["fields"].get("desired", "-")),
			goal["file"],
		]

	out += "\n## Actions (%d)\n\n" % actions.size()
	out += "| Action | Plannable | Preconditions | Effects | File |\n"
	out += "|--------|-----------|---------------|---------|------|\n"
	for action in actions:
		out += "| %s | %s | %s | %s | `%s` |\n" % [
			_cell(action["name"]),
			_cell(action["fields"].get("plannable", "-")),
			_cell(action["fields"].get("precond", "-")),
			_cell(action["fields"].get("effects", "-")),
			action["file"],
		]
	return out


static func write() -> int:
	var text := build()
	var f := FileAccess.open(INDEX_PATH, FileAccess.WRITE)
	if f == null:
		push_error("goap_index: cannot write %s" % INDEX_PATH)
		return -1
	f.store_string(text)
	f.close()
	return text.length()


# --- parsing ---------------------------------------------------------------

static func _parse_banner(text: String, path: String) -> Dictionary:
	var lines := text.split("\n")
	var start := -1
	for i in range(lines.size()):
		if lines[i].contains("GOAP-GUIDE:"):
			start = i
			break
	if start < 0:
		return {}

	var title := lines[start].split("GOAP-GUIDE:", true, 1)
	var name := ""
	if title.size() == 2:
		name = title[1].strip_edges()
		if " - " in name:
			name = name.split(" - ")[0].strip_edges()
	if name.is_empty():
		return {}

	var fields := {}
	var last := ""
	for i in range(start + 1, lines.size()):
		var raw := lines[i].strip_edges()
		if not raw.begins_with("#"):
			break
		var stripped := raw.trim_prefix("#").strip_edges()
		if stripped.is_empty() or stripped.begins_with("===="):
			continue
		var colon := stripped.find(":")
		var is_label := colon > 0
		if is_label:
			var label := stripped.substr(0, colon).strip_edges()
			for ch in label:
				if not (ch == "_" or ch == " " or (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z")):
					is_label = false
					break
		if is_label:
			last = stripped.substr(0, colon).strip_edges().to_lower()
			fields[last] = stripped.substr(colon + 1).strip_edges()
		elif last != "":
			fields[last] = (fields[last] + " " + stripped).strip_edges()

	return {"name": name, "file": path.trim_prefix("res://"), "fields": fields}


static func _cell(value: String) -> String:
	return value.replace("|", "\\|")


static func _collect(dir_path: String, extension: String, out: Array[String]) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var path = dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				_collect(path, extension, out)
		elif name.ends_with(extension):
			out.append(path)
		name = dir.get_next()
	dir.list_dir_end()
