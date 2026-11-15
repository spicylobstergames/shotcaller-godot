# GOAP-GUIDE: MyAction - action (goap/game_logic/actions/my_action.gd)
# =============================================================================
# New action scaffold (from docs/ai/templates/action_template.gd).
# Replace every TODO, then follow docs/ai/adding-behavior.md.
# =============================================================================
# Purpose   : TODO one line: what this action does.
# Plannable : TODO "yes - <goal> ({fact: value}) -> MyAction" or
#             "no - service object reached via Goap.get_action(\"MyAction\")".
# is_valid  : TODO planning eligibility (default true is inherited).
# cost      : 1
# precond   : TODO {"fact": value} or {} -- must hold BEFORE the action.
# effects   : TODO {"fact": value} -- non-empty effects is what makes it
#             plannable; leave {} only for a service object.
# enter     : TODO start the work.
# perform   : TODO return true once the step is complete (no FAILED state).
# exit      : TODO clean up (usually Goap.get_action("Move").stop(unit)).
# Reads     : TODO facts/objects read.
# Writes    : TODO facts/objects written.
# Traps     : TODO anything that silently breaks planning.
# See       : docs/ai/adding-behavior.md; docs/ai/world-state.md.
# =============================================================================

extends "res://goap/goap_system/action_contract.gd"


func get_class_name() -> String:
	return "MyAction"


func is_valid(_agent) -> bool:
	# TODO: return false until implemented -- an action with effects is
	# plannable as soon as is_valid() allows it.
	return false


func get_cost(_agent) -> int:
	return 1


func get_preconditions() -> Dictionary:
	return {}


func get_effects() -> Dictionary:
	return {}


func enter(_agent) -> void:
	pass


func perform(_agent, _delta: float) -> bool:
	return false


func exit(_agent) -> void:
	pass
