extends Node2D

var signal_no = 0

var callback_call_count = 0

func test_callback():
	callback_call_count += 1
	
func _ready():
	test1()
	test2()
	test3()
	test4()

	
func test1():
	callback_call_count = 0
	EventMachine.reset()
	EventMachine.register_listener(signal_no, self, "test_callback")
	EventMachine.register_event(signal_no)
	EventMachine.reset()
	assert(callback_call_count == 1)
	
func test2():
	callback_call_count = 0
	EventMachine.reset()
	EventMachine.register_listener(signal_no, self, "test_callback")
	EventMachine.register_listener(signal_no, self, "test_callback")
	EventMachine.register_event(signal_no)
	EventMachine.reset()
	assert(callback_call_count == 1)

func test3():
	callback_call_count = 0
	EventMachine.reset()
	EventMachine.register_listener(signal_no, self, "test_callback")
	assert(EventMachine.deregister_listener(signal_no, self, "test_callback") == 1)
	EventMachine.register_event(signal_no)
	EventMachine.reset()
	assert(callback_call_count == 0)

func test4():
	EventMachine.reset()
	assert(EventMachine.deregister_listener(signal_no, self, "test_callback") == 0)
