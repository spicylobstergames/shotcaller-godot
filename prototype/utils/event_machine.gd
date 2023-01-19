# This class is an Autoload accessible globaly
extends Node

var event_listeners = {}

func register_event(event : int, args : Array = []):
	if event_listeners.keys().has(event):
		for listener in event_listeners[event]:
			listener["node"].callv(listener["method"], args + listener["extra_args"])


func register_listener(event : int, node : Node, method : String, extra_args : Array = []):
	assert(node.has_method(method), "Error registering listener: Node %s does not have method %s" % [node.name, method])
	if not event_listeners.keys().has(event):
		event_listeners[event] = []
	else:
# warning-ignore:return_value_discarded
		deregister_listener(event, node, method)
		
	event_listeners[event].append({
		"node" : node,
		"method" : method,
		"extra_args" : extra_args
	})


# Return number of deregistered event listeners
func deregister_listener(event : int, node : Node, method : String) -> int:
	if not event_listeners.keys().has(event):
		return 0
	var listeners : Array = event_listeners[event]

	for i in range(listeners.size() - 1, -1, -1):
		if listeners[i]["node"] == node and listeners[i]["method"] == method:
			listeners.remove(i)
			return 1
	return 0

func reset():
	event_listeners = {}
