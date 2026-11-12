extends "res://tests/hotfix/b_checks.gd"
func key(action: String, pressed: bool) -> bool:
	for binding in InputMap.action_get_events(action):
		if binding is InputEventKey:
			var event: InputEventKey = binding.duplicate()
			event.pressed = pressed
			event.echo = false
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			return true
	return false
func start(t: SceneTree) -> void:
	tree = t
	tree.change_scene_to_file("res://scenes/levels/test_arena.tscn")
	await tree.scene_changed
	await step(8)
	p = tree.current_scene.get_node("Player")
	d = p.dodge_controller
	rig = tree.current_scene.get_node("CameraRig")
	lock = tree.current_scene.get_node("LockOnController")
	tree.current_scene.get_node("Soldier").process_mode = Node.PROCESS_MODE_DISABLED
	var cases: Array = [["move_forward"],["move_backward"],["move_left"],["move_right"],["move_forward","move_left"],["move_forward","move_right"],["move_backward","move_left"],["move_backward","move_right"]]
	for locked in [false,true]:
		for index in range(cases.size()):
			await reset()
			if locked: lock.try_acquire()
			var bindings_valid: bool = true
			for action in cases[index]: bindings_valid = key(action,true) and bindings_valid
			await step(2)
			var v: Vector2 = Input.get_vector("move_left","move_right","move_forward","move_backward",p.input_deadzone)
			var expected: Vector3 = p.camera_relative_direction(v).normalized()
			var sample: Dictionary = {}
			var callback := func(_profile: StringName, direction: Vector3, backstep: bool):
				sample.direction = direction
				sample.backstep = backstep
				sample.position = p.position
			d.dodge_started.connect(callback, CONNECT_ONE_SHOT)
			bindings_valid = key("sprint_dodge",true) and bindings_valid
			await step(2)
			# Capture camera orientation at the same release event as the input interpreter.
			expected = p.camera_relative_direction(v).normalized()
			key("sprint_dodge",false)
			for action in cases[index]: key(action,false)
			await step(38)
			var tag: String = ("locked_" if locked else "free_")+str(index)
			checks[tag+"_keyboard_route"] = bindings_valid and not sample.is_empty() and not sample.backstep and sample.direction.dot(expected)>0.999
			if not sample.is_empty():
				var delta: Vector3 = p.position-sample.position
				delta.y = 0
				checks[tag+"_physical_distance"] = absf(delta.length()-3.0)<0.035
			if locked: checks[tag+"_lock_kept"] = lock.is_locked()
	var failed: Array = []
	for name in checks:
		if not checks[name]: failed.append(name)
	var result := {"status":"complete","passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed,"checks":checks,"physical_devices":Input.get_connected_joypads(),"method":"Synthetic keyboard events cloned from the actual InputMap; full short-press interpreter and real body motion. No physical keyboard/gamepad claim."}
	FileAccess.open("res://tests/hotfix/keyboard_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("HOTFIX_KEYBOARD ",result.passed,"/",result.total," failed=",failed)
