extends RefCounted
## Integration checks: synthetic events through InputMap, real physics frames.

var _tree: SceneTree
var _player: CharacterBody3D
var _checks: Dictionary = {}
var _measurements: Dictionary = {}


func start(tree: SceneTree) -> void:
	# MCP eval has an 8-second call budget; run across frames and poll metadata.
	tree.root.set_meta("phase_1b_result", {"status": "running", "checks": _checks})
	var result := await run(tree)
	result["status"] = "complete"
	tree.root.set_meta("phase_1b_result", result)


func run(tree: SceneTree) -> Dictionary:
	_tree = tree
	_player = tree.current_scene.get_node("Player")
	var camera: Camera3D = _player.movement_camera
	var initial_camera_rotation := camera.rotation
	var initial_position := _player.position
	var initial_visual_rotation: Vector3 = _player.visual.rotation
	await _reset()
	_checks["grounded_idle"] = _player.is_on_floor() and _player.locomotion_state == 0
	var directions := [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]
	var names := ["forward", "backward", "left", "right"]
	for i in range(directions.size()):
		await _reset()
		_stick(directions[i])
		await _step(30)
		var expected := Vector3(directions[i].x, 0, directions[i].y)
		_checks[names[i] + "_movement"] = _player.position.dot(expected) > 0.6
		_checks[names[i] + "_facing"] = (-_player.visual.global_basis.z).dot(expected) > 0.99
		_checks[names[i] + "_walk_state"] = _player.locomotion_state == 1
		_checks[names[i] + "_body_not_rotated"] = _player.rotation.is_zero_approx()
	await _reset()
	_stick(Vector2(1, -1))
	await _step(30)
	_checks["normalized_diagonal"] = absf(_player.horizontal_speed - _player.walk_speed) < 0.03 \
		and _player.movement_input.length() <= 1.0001
	_measurements["diagonal_speed"] = _player.horizontal_speed
	var analog_speeds: Array[float] = []
	for strength in [0.3, 0.55, 1.0]:
		await _reset()
		_stick(Vector2(0, -strength))
		await _step(25)
		analog_speeds.append(_player.horizontal_speed)
		var expected_speed: float = (strength - _player.input_deadzone) / (1.0 - _player.input_deadzone) * _player.walk_speed
		_checks["analog_" + str(strength)] = absf(_player.horizontal_speed - expected_speed) < 0.03
	_measurements["analog_speeds_at_0.3_0.55_1.0"] = analog_speeds
	await _reset()
	_stick(Vector2(0.1, 0))
	await _step(10)
	_checks["deadzone"] = _player.position.length() < 0.02 and _player.movement_input == Vector2.ZERO
	await _reset()
	_stick(Vector2(0, -1))
	await _step(2)
	var early_speed: float = _player.horizontal_speed
	await _step(25)
	var full_speed: float = _player.horizontal_speed
	_checks["progressive_acceleration"] = early_speed > 0.0 and early_speed < full_speed * 0.5
	_stick(Vector2.ZERO)
	await _step(2)
	var braking_speed: float = _player.horizontal_speed
	_checks["progressive_deceleration"] = braking_speed > 0.0 and braking_speed < full_speed
	await _step(20)
	_checks["stops_without_drift"] = _player.horizontal_speed < 0.001 and _player.locomotion_state == 0
	var resting_yaw: float = _player.visual.rotation.y
	await _step(8)
	_checks["no_idle_turning"] = absf(_player.visual.rotation.y - resting_yaw) < 0.0001
	_measurements["early_full_braking_speed"] = [early_speed, full_speed, braking_speed]
	await _reset()
	_stick(Vector2(0, -1))
	await _step(25)
	_stick(Vector2(0, 1))
	await _step(2)
	_checks["reversal_brakes_before_reversing"] = _player.velocity.z < 0.0
	_checks["no_instant_180_turn"] = (-_player.visual.global_basis.z).dot(Vector3.BACK) < 0.9
	await _step(35)
	_checks["reversal_completes"] = _player.velocity.z > 3.0 \
		and (-_player.visual.global_basis.z).dot(Vector3.BACK) > 0.99
	await _reset()
	camera.rotation.y = PI / 2.0
	_stick(Vector2(0, -1))
	await _step(25)
	_checks["camera_relative_yaw"] = _player.position.x < -0.5 and absf(_player.position.z) < 0.02
	_checks["camera_pitch_does_not_reduce_speed"] = absf(_player.horizontal_speed - _player.walk_speed) < 0.03
	camera.rotation = initial_camera_rotation
	await _reset()
	var releases: Array = []
	var on_release := func(duration: float, long_press: bool) -> void: releases.append([duration, long_press])
	_player.sprint_dodge_released.connect(on_release)
	_stick(Vector2(0, -1))
	_button(true)
	await _step(5)
	_checks["no_run_before_threshold"] = not _player.is_sprinting and _player.locomotion_state == 1
	_button(false)
	await _step(1)
	_checks["short_press_preserved"] = releases.size() == 1 and not releases[0][1]
	# Both input events before the next physics tick must still emit a release.
	_button(true)
	_button(false)
	_checks["subtick_tap_preserved"] = releases.size() == 2 and not releases[1][1]
	_button(true)
	await _step(40)
	_checks["hold_activates_run"] = _player.is_sprinting and _player.locomotion_state == 2 \
		and absf(_player.horizontal_speed - _player.run_speed) < 0.03
	_measurements["run_speed"] = _player.horizontal_speed
	_button(false)
	await _step(20)
	_checks["release_returns_to_walk"] = _player.locomotion_state == 1 \
		and absf(_player.horizontal_speed - _player.walk_speed) < 0.03
	_checks["long_release_reported"] = releases.size() == 3 and releases[2][1] \
		and releases[2][0] >= _player.sprint_hold_threshold
	_stick(Vector2.ZERO)
	await _step(20)
	_button(true)
	await _step(20)
	_checks["held_button_at_rest_stays_idle"] = not _player.is_sprinting and _player.locomotion_state == 0
	_button(false)
	_player.sprint_dodge_released.disconnect(on_release)
	await _reset()
	_player.position = Vector3(0, 3, 0)
	_player.velocity = Vector3.ZERO
	await _step(12)
	_checks["gravity_falls"] = _player.position.y < 2.9 and _player.velocity.y < -1.0
	await _step(65)
	_checks["lands_on_floor"] = _player.is_on_floor() and absf(_player.position.y) < 0.02
	await _step(20)
	_checks["stable_floor"] = _player.is_on_floor() and absf(_player.position.y) < 0.02 \
		and absf(_player.velocity.y) < 0.001
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 3, 0.3)
	collider.shape = shape
	wall.add_child(collider)
	_tree.current_scene.add_child(wall)
	wall.position = Vector3(0, 1.5, -1.5)
	_stick(Vector2(0, -1))
	await _step(50)
	_checks["wall_collision"] = _player.position.z > -1.08 and _player.position.z < -0.8 \
		and absf(_player.velocity.z) < 0.01
	wall.queue_free()
	await _reset()
	_player.orient_to_movement = false
	var controlled_yaw: float = _player.visual.rotation.y
	_stick(Vector2(1, 0))
	await _step(20)
	_checks["facing_can_be_controlled_separately"] = absf(_player.visual.rotation.y - controlled_yaw) < 0.0001
	_player.orient_to_movement = true
	await _reset()
	# Verify the integrator at different delta values, with physics paused locally.
	_player.set_physics_process(false)
	var distances: Array[float] = []
	for hz in [30, 60, 120]:
		_player.velocity = Vector3.ZERO
		_player.movement_direction = Vector3.FORWARD
		var distance := 0.0
		for tick in range(hz):
			_player._update_horizontal_velocity(1.0 / hz)
			distance += -_player.velocity.z / hz
		distances.append(distance)
	_checks["delta_integrator_consistency"] = absf(distances[0] - distances[2]) < 0.05
	_measurements["one_second_distance_at_delta_30_60_120"] = distances
	_player.set_physics_process(true)
	await _reset()
	_player.position = initial_position
	_player.visual.rotation = initial_visual_rotation
	await _step(5)
	var failed: Array = []
	for key in _checks:
		if not _checks[key]:
			failed.append(key)
	return {"passed": _checks.size() - failed.size(), "total": _checks.size(),
		"failed": failed, "checks": _checks, "measurements": _measurements,
		"physical_devices": Input.get_connected_joypads(), "input_source": "synthetic normalized gamepad events, ID 7"}


func _reset() -> void:
	_stick(Vector2.ZERO)
	_button(false)
	_player.position = Vector3.ZERO
	_player.velocity = Vector3.ZERO
	_player.visual.rotation = Vector3.ZERO
	await _step(8)


func _step(frames: int) -> void:
	for frame in range(frames):
		await _tree.physics_frame
	await _tree.process_frame


func _stick(value: Vector2) -> void:
	for axis in range(2):
		var event := InputEventJoypadMotion.new()
		event.device = 7
		event.axis = axis
		event.axis_value = value[axis]
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func _button(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 7
	event.button_index = JOY_BUTTON_B
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
