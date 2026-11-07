extends RefCounted

var _tree: SceneTree
var _p: CharacterBody3D
var _d: Node
var _rig: Node3D
var _lock: Node
var _checks: Dictionary = {}
var _measurements: Dictionary = {}
const CLEAR_ORIGIN := Vector3(-1, 0, 1)


func start(tree: SceneTree) -> void:
	tree.root.set_meta("phase_2b_result", {"status": "running", "checks": _checks})
	var result := await run(tree)
	result["status"] = "complete"
	tree.root.set_meta("phase_2b_result", result)


func run(tree: SceneTree) -> Dictionary:
	_tree = tree
	_p = tree.current_scene.get_node("Player")
	_d = _p.dodge_controller
	_rig = tree.current_scene.get_node("CameraRig")
	_lock = tree.current_scene.get_node("LockOnController")
	await _reset()
	var inputs := [Vector2(0,-1), Vector2(0,1), Vector2(-1,0), Vector2(1,0),
		Vector2(1,-1), Vector2(-1,-1), Vector2(1,1), Vector2(-1,1)]
	for i in range(inputs.size()):
		await _reset()
		var started: bool = _d.try_dodge(inputs[i])
		var initial := _p.position
		var expected := Vector3(inputs[i].x, 0, inputs[i].y).normalized()
		await _step(38)
		var offset := _p.position - initial
		offset.y = 0.0
		_checks["free_roll_direction_" + str(i)] = started and offset.normalized().dot(expected) > 0.999 \
			and absf(offset.length() - 3.0) < 0.03
		_checks["free_roll_completes_" + str(i)] = not _d.is_active() and _p.action_states.current_state == 0
	await _reset()
	var cancel_attempts: Array = []
	var on_state := func(_previous: int, current: int) -> void:
		if current == 2:
			cancel_attempts.append(_p.action_states.transition_to(0))
	_p.action_states.state_changed.connect(on_state)
	var ownership_start: bool = _d.try_dodge(Vector2(0,-1))
	_checks["ownership_already_protected_inside_state_signal"] = ownership_start and cancel_attempts == [false]
	_p.action_states.state_changed.disconnect(on_state)
	await _reset()
	_d.try_dodge(Vector2(0,-1))
	var fixed_direction: Vector3 = _d.direction
	Input.action_press("move_right")
	Input.action_press("sprint_dodge")
	await _step(10)
	_checks["direction_cannot_be_steered"] = _d.direction.is_equal_approx(fixed_direction) and absf(_p.position.x - CLEAR_ORIGIN.x) < 0.01
	_checks["no_simultaneous_second_roll"] = not _d.try_dodge(Vector2(1,0)) and _p.attributes.current_stamina == 75.0
	_checks["dodge_owner_blocks_cancel_and_other_states"] = not _p.action_states.transition_to(0) \
		and not _p.action_states.transition_to(1) and not _p.action_states.complete_owned_state(_rig)
	_checks["sprint_cannot_cancel_roll"] = not _p.is_sprinting and _p.action_states.current_state == 2
	Input.action_release("move_right")
	Input.action_release("sprint_dodge")
	await _step(28)
	_checks["owned_completion_returns_free"] = _p.action_states.current_state == 0 and not _d.is_active()
	_checks["one_stamina_charge_and_no_regen_in_action"] = _p.attributes.current_stamina == 75.0
	await _step(30)
	_checks["delay_restarts_after_recovery"] = _p.attributes.current_stamina == 75.0
	await _step(30)
	_checks["regen_resumes_after_action_delay"] = _p.attributes.current_stamina > 79.0
	await _reset()
	_p.attributes.consume_stamina(90.0)
	_checks["insufficient_stamina_rejected_without_cost"] = not _d.try_dodge(Vector2(0,-1)) \
		and _p.attributes.current_stamina == 10.0 and _p.action_states.current_state == 0
	var totals: Array[float] = []
	var distances: Array[float] = []
	for load_percent in [25.0, 25.01, 50.0, 50.01, 100.0, 100.01]:
		await _reset()
		_d.equipment_load_percent = load_percent
		var expected_class := 0 if load_percent <= 25.0 else (1 if load_percent <= 50.0 else (2 if load_percent <= 100.0 else 3))
		_checks["weight_boundary_" + str(load_percent)] = _d.get_weight_class() == expected_class
	for load_percent in [25.0, 40.0, 75.0]:
		await _reset()
		_d.equipment_load_percent = load_percent
		var initial := _p.position
		_d.try_dodge(Vector2(0,-1))
		var ticks := 0
		while _d.is_active() and ticks < 90:
			await _step(1)
			ticks += 1
		totals.append(ticks / 60.0)
		distances.append(initial.distance_to(_p.position))
	_checks["profiles_have_different_distances_and_durations"] = distances[0] > distances[1] and distances[1] > distances[2] \
		and totals[0] < totals[1] and totals[1] < totals[2]
	_measurements["profile_durations"] = totals
	_measurements["profile_distances"] = distances
	await _reset()
	_d.equipment_load_percent = 101.0
	_checks["overloaded_rejects_roll_and_backstep"] = not _d.try_dodge(Vector2(0,-1)) and not _d.try_dodge(Vector2.ZERO) \
		and _p.attributes.current_stamina == 100.0 and not _d.is_active()
	await _reset()
	var initial_yaw: float = _p.visual.rotation.y
	_d.try_dodge(Vector2.ZERO)
	await _step(29)
	_checks["backstep_retreats_one_metre"] = absf(_p.position.z - CLEAR_ORIGIN.z - 1.0) < 0.02
	_checks["backstep_preserves_facing_and_cost"] = absf(_p.visual.rotation.y - initial_yaw) < 0.001 \
		and _p.attributes.current_stamina == 85.0 and not _d.is_active()
	# Real input route: release decides once; no duplicate emission on the next tick.
	await _reset()
	Input.action_press("move_forward")
	_button(true)
	await _step(3)
	_button(false)
	await _step(2)
	_checks["short_directional_release_starts_roll"] = _d.is_active() and not _d.is_backstep and _p.attributes.current_stamina == 75.0
	Input.action_release("move_forward")
	await _step(38)
	await _reset()
	_button(true)
	_button(false)
	await _step(2)
	_checks["subtick_neutral_release_starts_backstep"] = _d.is_active() and _d.is_backstep \
		and _p.attributes.current_stamina == 85.0
	await _step(29)
	await _reset()
	Input.action_press("move_forward")
	_button(true)
	await _step(35)
	_checks["long_press_runs_without_dodge"] = _p.is_sprinting and not _d.is_active()
	_button(false)
	Input.action_release("move_forward")
	await _step(3)
	_checks["long_release_does_not_roll"] = not _d.is_active() and _p.action_states.current_state == 0
	await _reset()
	for input_vector in [Vector2(0,-1), Vector2(0,1), Vector2(-1,0), Vector2(1,0), Vector2(1,-1), Vector2(0.9,0.3)]:
		await _reset()
		_lock.try_acquire()
		await _step(2)
		var cardinal := Vector2(signf(input_vector.x),0) if absf(input_vector.x) > absf(input_vector.y) else Vector2(0,signf(input_vector.y))
		var expected: Vector3 = _p.resolve_movement_direction(cardinal).normalized()
		_d.try_dodge(input_vector)
		_checks["locked_cardinal_" + str(input_vector)] = _d.direction.dot(expected) > 0.999
		await _step(38)
		_checks["lock_survives_dodge_" + str(input_vector)] = _lock.is_locked()
	await _reset()
	# Sample each physics tick, including vulnerable startup and recovery.
	var iframe_samples: Array = []
	_d.try_dodge(Vector2(0,-1))
	_checks["no_iframes_before_start"] = not _p.is_invulnerable() and _p.can_receive_attack()
	var window_correct := true
	for tick in range(38):
		await _step(1)
		var time: float = _d.elapsed
		var expected: bool = _d.is_active() and time + 0.0000001 >= 0.04 and time < 0.30 - 0.0000001
		window_correct = window_correct and _p.is_invulnerable() == expected \
			and not _p.get_node("CollisionShape3D").disabled
		if _p.is_invulnerable():
			iframe_samples.append(time)
	_checks["iframe_window_only_and_physical_collision_kept"] = window_correct and not iframe_samples.is_empty()
	_checks["no_iframes_after_action"] = not _p.is_invulnerable() and _p.can_receive_attack()
	_measurements["fast_iframe_sample_times"] = iframe_samples
	await _reset()
	_d.try_dodge(Vector2.ZERO)
	var backstep_iframes := 0
	for tick in range(29):
		await _step(1)
		if _p.is_invulnerable():
			backstep_iframes += 1
	_checks["backstep_has_separate_short_window"] = backstep_iframes > 0 and backstep_iframes < iframe_samples.size()
	await _reset()
	_d.try_dodge(Vector2(0,-1))
	await _step(5)
	_p.action_states.transition_to(7)
	_checks["death_interrupts_and_clears_iframes"] = not _d.is_active() and not _p.is_invulnerable() and not _p.can_receive_attack()
	await _reset()
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5,3,0.3)
	collider.shape = shape
	wall.add_child(collider)
	_tree.current_scene.add_child(wall)
	wall.position = CLEAR_ORIGIN + Vector3(0,1.5,-1.5)
	await _step(2)
	_d.try_dodge(Vector2(0,-1))
	await _step(38)
	_checks["wall_blocks_dodge_displacement"] = _p.position.z > CLEAR_ORIGIN.z - 1.08 \
		and _p.position.z < CLEAR_ORIGIN.z - 0.8
	_checks["ground_collision_stable_after_dodge"] = _p.is_on_floor() and absf(_p.position.y) < 0.02
	wall.queue_free()
	await _step(2)
	await _reset()
	_p.position = Vector3(8.8,0,8)
	_p.reset_physics_interpolation()
	_rig.snap_to_target()
	await _step(3)
	_d.try_dodge(Vector2(1,0))
	await _step(50)
	_checks["edge_roll_falls_without_levitation"] = _p.position.x > 10.0 and _p.position.y < -0.1 and not _p.is_on_floor()
	_checks["cannot_start_airborne_dodge"] = not _d.try_dodge(Vector2(1,0))
	await _reset()
	Input.action_press("camera_right")
	var yaw: float = _rig.get_orbit_angles().x
	await _step(5)
	_checks["orbital_camera_still_works"] = absf(_rig.get_orbit_angles().x - yaw) > 0.05
	Input.action_release("camera_right")
	# Numeric integration at several deltas, without moving a physical body.
	var integrated: Array[float] = []
	for hz in [30,60,120]:
		await _reset()
		_p.set_physics_process(false)
		_d.try_dodge(Vector2(0,-1))
		var distance := 0.0
		for tick in range(hz):
			distance += _d.advance_motion(1.0/hz).length() / hz
			_d.finish_physics_step()
		integrated.append(distance)
		_p.set_physics_process(true)
	_checks["distance_integration_independent_of_delta"] = absf(integrated[0]-3.0) < 0.001 and absf(integrated[0]-integrated[2]) < 0.001
	_measurements["distance_delta_30_60_120"] = integrated
	await _reset()
	_p.position = Vector3.ZERO
	_p.reset_physics_interpolation()
	_rig.snap_to_target()
	var failed: Array = []
	for key in _checks:
		if not _checks[key]:
			failed.append(key)
	return {"passed":_checks.size()-failed.size(),"total":_checks.size(),"failed":failed,
		"checks":_checks,"measurements":_measurements,"physical_devices":Input.get_connected_joypads()}


func _reset() -> void:
	_lock.release_lock(&"test_reset")
	for action in ["move_left","move_right","move_forward","move_backward","sprint_dodge","camera_right"]:
		Input.action_release(action)
	_p.attributes.restore_all()
	_d.input_enabled = true
	_d.equipment_load_percent = 25.0
	_p.position = CLEAR_ORIGIN
	_p.velocity = Vector3.ZERO
	_p.visual.rotation = Vector3.ZERO
	_p.reset_physics_interpolation()
	_rig.set_control_mode(0)
	_rig.set_orbit_angles(0,deg_to_rad(_rig.initial_pitch))
	_rig.snap_to_target()
	await _step(8)


func _step(frames: int) -> void:
	for frame in range(frames):
		await _tree.physics_frame
	await _tree.process_frame


func _button(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 7
	event.button_index = JOY_BUTTON_B
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
