extends RefCounted
## Synthetic InputMap events, real physics/shape sweeps. No hardware claims.

var _tree: SceneTree
var _rig: Node3D
var _player: CharacterBody3D
var _checks: Dictionary = {}
var _measurements: Dictionary = {}


func start(tree: SceneTree) -> void:
	tree.root.set_meta("phase_1c_result", {"status": "running", "checks": _checks})
	var result := await run(tree)
	result["status"] = "complete"
	tree.root.set_meta("phase_1c_result", result)


func run(tree: SceneTree) -> Dictionary:
	_tree = tree
	_rig = tree.current_scene.get_node("CameraRig")
	_player = tree.current_scene.get_node("Player")
	await _reset()
	_checks["explicit_target_and_camera"] = _rig.get_follow_target() == _player \
		and _player.movement_camera == _rig.camera
	_checks["hierarchy"] = _rig.has_node("YawPivot/PitchPivot/SpringArm3D/Camera3D")
	_checks["interpolation_enabled"] = ProjectSettings.get_setting("physics/common/physics_interpolation") \
		and _rig.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_ON
	var original_player_position := _player.position
	var original_visual_rotation: Vector3 = _player.visual.rotation
	# At 150°/s, 144 fixed ticks traverse a full orbit.
	_right_stick(Vector2(1, 0))
	var unwrapped_yaw := 0.0
	var orbit_clear := true
	var camera_probe := PhysicsShapeQueryParameters3D.new()
	var probe_shape := SphereShape3D.new()
	probe_shape.radius = 0.1
	camera_probe.shape = probe_shape
	camera_probe.collision_mask = 1
	var previous_yaw: float = _rig.get_orbit_angles().x
	for tick in range(144):
		await _step(1)
		var yaw: float = _rig.get_orbit_angles().x
		unwrapped_yaw += angle_difference(previous_yaw, yaw)
		previous_yaw = yaw
		camera_probe.transform = Transform3D(Basis.IDENTITY, _rig.camera.global_position)
		orbit_clear = orbit_clear and _rig.get_world_3d().direct_space_state.intersect_shape(camera_probe, 1).is_empty()
	_right_stick(Vector2.ZERO)
	_checks["full_horizontal_orbit"] = absf(unwrapped_yaw) > TAU - 0.1
	_checks["orbit_camera_does_not_overlap_world"] = orbit_clear
	_measurements["horizontal_orbit_degrees"] = rad_to_deg(unwrapped_yaw)
	_checks["camera_only_does_not_move_or_turn_player"] = _player.position.distance_to(original_player_position) < 0.01 \
		and _player.rotation.is_zero_approx() and _player.visual.rotation.is_equal_approx(original_visual_rotation)
	await _reset()
	_right_stick(Vector2(0, 1))
	await _step(60)
	_checks["minimum_pitch_clamp"] = absf(_rig.get_orbit_angles().y - deg_to_rad(_rig.minimum_pitch)) < 0.001
	_right_stick(Vector2(0, -1))
	await _step(75)
	_checks["maximum_pitch_clamp"] = absf(_rig.get_orbit_angles().y - deg_to_rad(_rig.maximum_pitch)) < 0.001
	await _reset()
	var still_angles: Vector2 = _rig.get_orbit_angles()
	_right_stick(Vector2(0.1, -0.1))
	await _step(15)
	_checks["deadzone_no_drift"] = _rig.get_orbit_angles().distance_to(still_angles) < 0.0001
	var rates: Array[float] = []
	for strength in [0.5, 1.0]:
		await _reset()
		_right_stick(Vector2(strength, 0))
		await _step(12)
		rates.append(absf(_rig.get_orbit_angles().x))
	_checks["analog_sensitivity"] = rates[0] > 0.05 and rates[0] < rates[1] * 0.5
	_measurements["yaw_radians_at_half_full"] = rates
	await _reset()
	var initial_pitch: float = _rig.get_orbit_angles().y
	_rig.invert_vertical = true
	_right_stick(Vector2(0, 0.5))
	await _step(10)
	_checks["vertical_inversion"] = _rig.get_orbit_angles().y > initial_pitch
	_rig.invert_vertical = false
	await _reset()
	# Numerical time-step verification; not a claim of testing 3 GPU framerates.
	_rig.set_physics_process(false)
	_right_stick(Vector2(1, 0))
	var delta_yaws: Array[float] = []
	var delta_follow_errors: Array[float] = []
	for hz in [30, 60, 120]:
		_rig.set_orbit_angles(0.0, deg_to_rad(_rig.initial_pitch))
		_rig.global_position = _player.global_position + Vector3.UP * _rig.follow_height + Vector3.BACK * 2.0
		for tick in range(hz):
			_rig._physics_process(1.0 / hz)
		delta_yaws.append(_rig.get_orbit_angles().x)
		delta_follow_errors.append(_rig.global_position.distance_to(_player.global_position + Vector3.UP * _rig.follow_height))
	_checks["orbit_delta_independence"] = absf(delta_yaws[0] - delta_yaws[2]) < 0.0001 \
		and absf(delta_yaws[0] + deg_to_rad(_rig.horizontal_sensitivity)) < 0.0001
	_checks["follow_delta_independence"] = absf(delta_follow_errors[0] - delta_follow_errors[2]) < 0.0001
	_measurements["yaw_after_one_second_delta_30_60_120"] = delta_yaws
	_rig.set_physics_process(true)
	await _reset()
	_rig.set_control_mode(1)
	_rig.set_orbit_angles(PI / 2.0, -0.3)
	var external_angles: Vector2 = _rig.get_orbit_angles()
	_right_stick(Vector2(1, 1))
	await _step(10)
	_checks["external_mode_blocks_free_input"] = _rig.get_orbit_angles().is_equal_approx(external_angles)
	_right_stick(Vector2.ZERO)
	_rig.set_control_mode(0)
	_right_stick(Vector2(1, 0))
	await _step(5)
	_checks["free_mode_resumes"] = not _rig.get_orbit_angles().is_equal_approx(external_angles)
	await _reset()
	# Discrete mouse displacement must change angle once, not every physics tick.
	var mouse := InputEventMouseMotion.new()
	mouse.button_mask = MOUSE_BUTTON_MASK_RIGHT
	mouse.relative = Vector2(30, 0)
	Input.parse_input_event(mouse)
	Input.flush_buffered_events()
	await _step(2)
	var mouse_yaw: float = _rig.get_orbit_angles().x
	_checks["technical_mouse_drag"] = absf(mouse_yaw + deg_to_rad(30.0 * _rig.mouse_sensitivity)) < 0.001
	await _step(5)
	_checks["mouse_has_no_persistent_drift"] = absf(_rig.get_orbit_angles().x - mouse_yaw) < 0.0001
	await _reset()
	# Follow the actual moving CharacterBody and measure bounded, smooth lag.
	Input.action_press("move_forward")
	var maximum_error := 0.0
	for tick in range(40):
		await _step(1)
		var target_position: Vector3 = _player.global_position + Vector3.UP * _rig.follow_height
		maximum_error = maxf(maximum_error, _rig.global_position.distance_to(target_position))
	Input.action_release("move_forward")
	await _step(30)
	_checks["smooth_follow_bounded_lag"] = maximum_error < 0.35 and maximum_error > 0.0
	_checks["follow_settles_after_braking"] = _rig.global_position.distance_to(_player.global_position + Vector3.UP * _rig.follow_height) < 0.015
	_measurements["maximum_walking_follow_error_m"] = maximum_error
	await _reset()
	for yaw in [PI / 2.0, -PI / 2.0, PI]:
		_rig.set_orbit_angles(yaw, -0.4)
		var expected_forward: Vector3 = -_rig.camera.global_basis.z
		expected_forward.y = 0.0
		expected_forward = expected_forward.normalized()
		Input.action_press("move_forward")
		await _step(25)
		_checks["camera_relative_forward_" + str(yaw)] = _player.position.dot(expected_forward) > 0.5
		Input.action_release("move_forward")
		await _reset()
	_rig.set_orbit_angles(PI / 2.0, -0.8)
	Input.action_press("move_right")
	await _step(25)
	_checks["right_after_orbit"] = _player.position.z < -0.5
	_checks["pitch_independent_walk_speed"] = absf(_player.horizontal_speed - _player.walk_speed) < 0.03
	Input.action_release("move_right")
	await _reset()
	Input.action_press("move_forward")
	Input.action_press("move_right")
	await _step(25)
	_checks["diagonal_still_normalized"] = absf(_player.horizontal_speed - _player.walk_speed) < 0.03
	Input.action_press("sprint_dodge")
	await _step(35)
	_checks["sprint_regression"] = absf(_player.horizontal_speed - _player.run_speed) < 0.03 and _player.locomotion_state == 2
	_release_movement()
	await _step(30)
	_checks["deceleration_regression"] = _player.horizontal_speed < 0.001 and _player.locomotion_state == 0
	await _reset()
	# Rear wall at z=5.5; both endpoints remain on its player-facing side.
	_player.position.z = 2.5
	_rig.snap_to_target()
	await _step(8)
	var contracted: float = _rig.spring_arm.current_distance
	_checks["rear_wall_contracts"] = contracted < 3.0 and _rig.camera.global_position.z < 5.05
	_checks["safe_distance_used_same_physics_tick"] = _rig.spring_arm.current_distance <= _rig.spring_arm.get_hit_length() + 0.001
	var collision_distances: Array[float] = []
	for tick in range(20):
		await _step(1)
		collision_distances.append(_rig.spring_arm.current_distance)
	_checks["stationary_collision_no_oscillation"] = collision_distances.max() - collision_distances.min() < 0.005
	_player.position = Vector3.ZERO
	_rig.snap_to_target()
	await _step(1)
	var first_recovery: float = _rig.spring_arm.current_distance
	_checks["collision_recovery_is_smoothed"] = first_recovery > contracted and first_recovery < _rig.normal_distance - 0.1
	await _step(60)
	_checks["collision_recovers_normal_distance"] = absf(_rig.spring_arm.current_distance - _rig.normal_distance) < 0.01
	_measurements["collision_contracted_first_recovery_final"] = [contracted, first_recovery, _rig.spring_arm.current_distance]
	# Rotate toward the west wall and the column, without adding heavy geometry.
	_rig.set_orbit_angles(-PI / 2.0, 0.0)
	_player.position.x = -2.0
	_rig.snap_to_target()
	await _step(8)
	_checks["west_wall_contracts"] = _rig.spring_arm.current_distance < 2.6 and _rig.camera.global_position.x > -4.55
	await _reset()
	_rig.set_orbit_angles(PI / 2.0, 0.0)
	await _step(8)
	_checks["column_collision"] = _rig.spring_arm.current_distance < 2.3 and _rig.camera.global_position.x < 2.2
	await _reset()
	# Explicit RID exclusion is tested even if the player temporarily uses World.
	var saved_layer := _player.collision_layer
	_player.collision_layer = 1
	await _step(8)
	_checks["player_explicitly_excluded"] = _rig.spring_arm.get_hit_length() > 4.4
	_player.collision_layer = saved_layer
	_checks["world_only_collision_mask"] = _rig.spring_arm.collision_mask == 1
	_player.position.z = 4.65
	_rig.snap_to_target()
	await _step(8)
	_checks["tight_space_safety_over_minimum"] = _rig.camera.global_position.z < 5.05 \
		and _rig.spring_arm.current_distance < _rig.minimum_distance
	await _reset()
	# Sample reversal: finite poses, bounded follow and no body rotation.
	Input.action_press("move_forward")
	await _step(20)
	Input.action_release("move_forward")
	Input.action_press("move_backward")
	var reversal_error := 0.0
	for tick in range(35):
		await _step(1)
		reversal_error = maxf(reversal_error, _rig.global_position.distance_to(_player.global_position + Vector3.UP * _rig.follow_height))
	_checks["reversal_follow_stable"] = reversal_error < 0.35 and _rig.camera.global_position.is_finite() \
		and _player.rotation.is_zero_approx()
	await _reset()
	var failed: Array = []
	for key in _checks:
		if not _checks[key]:
			failed.append(key)
	return {"passed": _checks.size() - failed.size(), "total": _checks.size(),
		"failed": failed, "checks": _checks, "measurements": _measurements,
		"physical_devices": Input.get_connected_joypads(), "source": "synthetic events and real physics; no physical controller"}


func _reset() -> void:
	_release_movement()
	_right_stick(Vector2.ZERO)
	_rig.set_control_mode(0)
	_rig.set_orbit_angles(0.0, deg_to_rad(_rig.initial_pitch))
	_player.position = Vector3.ZERO
	_player.velocity = Vector3.ZERO
	_player.visual.rotation = Vector3.ZERO
	_player.reset_physics_interpolation()
	_rig.snap_to_target()
	await _step(8)


func _step(frames: int) -> void:
	for frame in range(frames):
		await _tree.physics_frame
	await _tree.process_frame


func _release_movement() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_backward", "sprint_dodge"]:
		Input.action_release(action)


func _right_stick(value: Vector2) -> void:
	for component in range(2):
		var event := InputEventJoypadMotion.new()
		event.device = 7
		event.axis = JOY_AXIS_RIGHT_X + component
		event.axis_value = value[component]
		Input.parse_input_event(event)
	Input.flush_buffered_events()
