class_name BTGuard, "res://addons/behavior_tree/icons/btguard.svg"
extends BTDecorator

# Can lock the whole branch below itself. The lock happens either after the child ticks, 
# or after any other BTNode ticks. Then it stays locked for a given time, or until another
# specified BTNode ticks. You can set all this from the inspector.
# If you don't specify a locker, the lock_if variable will be based on the child.
# If you don't specify an unlocker, the unlock_if variable is useless and only the lock_time will 
# be considered, and viceversa.
# You can also choose to lock permanently or to lock on startup.
#
# A locked BTGuard will always return fail().

export(bool) var start_locked = false
export(bool) var permanent = false
export(NodePath) var _locker
export(int, "Failure", "Success", "Always") var lock_if
export(NodePath) var _unlocker
export(int, "Failure", "Success") var unlock_if
export(float) var lock_time = 0.05

var locked: bool = false

onready var unlocker: BTNode = get_node_or_null(_unlocker)
onready var locker: BTNode = get_node_or_null(_locker)



func _ready():
	if start_locked:
		lock()
	
	if locker:
		locker.connect("tick", self, "_on_locker_tick")


func _on_locker_tick(_result):
	check_lock(locker)
	set_state(locker.state)


func lock():
	locked = true
	
	if debug:
		print(name + " locked for " + str(lock_time) + " seconds")
	
	if permanent:
		return
	elif unlocker:
		while locked:
			var result = yield(unlocker, "tick")
			if result == bool(unlock_if):
				locked = false
	else:
		yield(get_tree().create_timer(lock_time, false), "timeout")
		locked = false
	
	if debug:
		print(name + " unlocked")


func check_lock(current_locker: BTNode):
	if ((lock_if == 2 and not current_locker.running()) 
	or ( lock_if == 1 and current_locker.succeeded()) 
	or ( lock_if == 0 and current_locker.failed())):
		lock()


func _tick(agent: Node, blackboard: Blackboard) -> bool:
	if locked:
		return fail()
	return ._tick(agent, blackboard)


func _post_tick(agent: Node, blackboard: Blackboard, result: bool) -> void:
	if not locker:
		check_lock(bt_child)


