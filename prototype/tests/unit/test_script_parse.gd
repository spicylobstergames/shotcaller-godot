extends RefCounted

# Parses every .gd file in the project. A file that fails to compile is a
# blocking defect even if no test currently exercises it — this catches
# syntax errors, bad preloads, and missing identifiers in dead code paths.
#
# NOTE: load() alone does NOT detect parse errors — it returns a non-null
# GDScript resource for uncompilable scripts (verified by sabotage). The
# compile check below uses can_instantiate(), which is false for scripts
# that failed to compile.

const FsScan = preload("res://tests/helpers/fs_scan.gd")


func run(harness) -> void:
	var files: Array[String] = []
	FsScan.collect("res://", ".gd", files)

	var failures: Array[String] = []
	for path in files:
		var script = load(path)
		if script == null:
			failures.append("%s (load returned null)" % path)
			continue
		if not (script is GDScript):
			failures.append("%s (not a GDScript)" % path)
			continue
		if not script.can_instantiate():
			failures.append("%s (failed to compile)" % path)

	harness.check(files.size() > 50,
		"Parse smoke found a plausible number of scripts (%d)." % files.size())
	harness.check(failures.is_empty(),
		"All %d GDScript files compile cleanly. Failures: %s" % [files.size(), ", ".join(failures)])
