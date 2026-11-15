extends RefCounted

# Scans the GOAP tree for state-fact usage so the lint tests can check the
# string-key contract against docs/ai/world-state.md.
#
# Comment lines are ignored on purpose: the GOAP-GUIDE banners and inline
# examples mention fact names that are not usages.
#
# Exposes:
#   files        - every .gd under res://goap
#   state_calls  - key -> files that read/write/erase it via *_state()
#   required     - key -> files that list it as a precondition or desired fact
#   produced     - key -> files that list it as an effect
#   undocumented - keys missing from docs/ai/world-state.md
#   unproduced   - required keys with no effect writer and no *_state() writer

const FsScan = preload("res://tests/helpers/fs_scan.gd")

const GOAP_DIR := "res://goap"
const CATALOG := "res://docs/ai/world-state.md"
const TARGET_FUNCS := [
	"func get_preconditions(",
	"func get_effects(",
	"func get_desired_state(",
]

var files: Array[String] = []
var state_calls: Dictionary = {}
var required: Dictionary = {}
var produced: Dictionary = {}
var undocumented: Array[String] = []
var unproduced: Array[String] = []

var _re_calls: RegEx
var _re_keys: RegEx


func scan() -> void:
	_re_calls = RegEx.new()
	_re_calls.compile("(?:set_state|get_state|erase_state)\\(\\s*\"([^\"]+)\"")
	_re_keys = RegEx.new()
	_re_keys.compile("\"([^\"]+)\"\\s*:")

	FsScan.collect(GOAP_DIR, ".gd", files)
	for path in files:
		_scan_file(path)
	_compute_undocumented()
	_compute_unproduced()


func _scan_file(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return
	var mode := ""  # "", "required", "effects"
	for line in text.split("\n"):
		if line.begins_with("func "):
			mode = ""
			for target in TARGET_FUNCS:
				if line.begins_with(target):
					mode = "effects" if target == "func get_effects(" else "required"
					break
		if line.strip_edges().begins_with("#"):
			continue
		for m in _re_calls.search_all(line):
			_add(state_calls, m.get_string(1), path)
		if mode == "required":
			for m in _re_keys.search_all(line):
				_add(required, m.get_string(1), path)
		elif mode == "effects":
			for m in _re_keys.search_all(line):
				_add(produced, m.get_string(1), path)


func _add(bucket: Dictionary, key: String, path: String) -> void:
	if not bucket.has(key):
		bucket[key] = []
	bucket[key].append(path)


func all_keys() -> Dictionary:
	var keys := {}
	for bucket in [state_calls, required, produced]:
		for key in bucket:
			keys[key] = true
	return keys


func _compute_undocumented() -> void:
	var catalog := FileAccess.get_file_as_string(CATALOG)
	undocumented = []
	for key in all_keys():
		# Catalog entries are written as `key`, so a substring match on the
		# backticked form avoids matching a key inside an unrelated word.
		if not catalog.contains("`%s`" % key):
			undocumented.append(key)
	undocumented.sort()


func _compute_unproduced() -> void:
	unproduced = []
	for key in required:
		if produced.has(key) or state_calls.has(key):
			continue
		unproduced.append(key)
	unproduced.sort()
