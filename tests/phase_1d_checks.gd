extends RefCounted

var _tree: SceneTree
var _player: CharacterBody3D
var _rig: Node3D
var _lock: Node
var _center: Node3D
var _left: Node3D
var _right: Node3D
var _indicator: Control
var _checks: Dictionary = {}
var _measurements: Dictionary = {}


func start(tree: SceneTree) -> void:
	tree.root.set_meta("phase_1d_result", {"status": "running", "checks": _checks})
	var result := await run(tree)
	result["status"] = "complete"
	tree.root.set_meta("phase_1d_result", result)


func run(tree: SceneTree) -> Dictionary:
	_tree = tree
	var arena := tree.current_scene
	_player = arena.get_node("Player")
	_rig = arena.get_node("CameraRig")
	_lock = arena.get_node("LockOnController")
	_center = arena.get_node("Targets/Center")
	_left = arena.get_node("Targets/Left")
	_right = arena.get_node("Targets/Right")
	_indicator = arena.get_node("HUD/LockOnIndicator")
	await _reset()
	_checks["target_contract"] = _center.is_in_group("lockable_targets") and _center.is_available() \
		and _center.target_id == &"arena_center" and _center.lock_point != null
	_r3()
	await _step(3)
	_checks["r3_acquires_center"] = _lock.current_target == _center
	_checks["external_camera_and_visual_facing"] = _rig.control_mode == 1 and not _player.orient_to_movement \
		and _player.rotation.is_zero_approx()
	_checks["indicator_visible"] = _indicator.visible
	await _step(60)
	var viewport_rect := tree.root.get_visible_rect().grow(-12)
	var target_screen: Vector2 = _rig.camera.unproject_position(_center.get_aim_position())
	var player_head: Vector2 = _rig.camera.unproject_position(_player.global_position + Vector3.UP * 1.8)
	_checks["player_and_target_framed"] = viewport_rect.has_point(target_screen) and viewport_rect.has_point(player_head) \
		and viewport_rect.has_point(_rig.camera.unproject_position(_player.global_position))
	_checks["target_not_hidden_by_player_silhouette"] = target_screen.y < player_head.y - 5.0
	_checks["indicator_tracks_projection"] = _indicator.get("_point").distance_to(target_screen) < 1.0
	var before_release: Vector2 = _rig.get_orbit_angles()
	_r3()
	await _step(2)
	_checks["r3_cancels"] = not _lock.is_locked() and _rig.control_mode == 0 and _player.orient_to_movement
	_checks["cancel_keeps_camera_angles"] = _rig.get_orbit_angles().distance_to(before_release) < 0.001
	_checks["indicator_hidden_after_cancel"] = not _indicator.visible
	await _reset()
	_center.available = false
	_left.available = false
	_right.available = false
	_r3()
	await _step(2)
	_checks["no_candidates_stays_free"] = not _lock.is_locked() and _rig.control_mode == 0
	await _reset()
	_rig.set_orbit_angles(0.54, -0.3)
	await _step(3)
	_lock.try_acquire()
	_checks["camera_center_preference"] = _lock.current_target == _left
	await _reset()
	_center.position.z = -25.0
	_checks["reject_out_of_range"] = not _lock.can_acquire(_center)
	_center.position = Vector3(0, 0, 7)
	_checks["reject_behind_camera"] = not _lock.can_acquire(_center)
	_center.position = Vector3(0, 0, -6)
	_center.alive = false
	_checks["reject_dead"] = not _lock.can_acquire(_center)
	_center.alive = true
	_center.available = false
	_checks["reject_disabled"] = not _lock.can_acquire(_center)
	await _reset()
	var blocker := _make_blocker()
	await _step(2)
	_checks["reject_through_wall"] = not _lock.can_acquire(_center)
	_lock.try_acquire()
	_checks["wall_blocks_all_acquisition"] = not _lock.is_locked()
	blocker.queue_free()
	await _step(3)
	await _reset()
	# Start at left, then hold right. Repeating incorrectly would advance to Right.
	_rig.set_orbit_angles(0.54, -0.3)
	await _step(3)
	_lock.try_acquire()
	await _step(3)
	_switch_axis(1.0)
	await _step(4)
	_checks["switch_left_to_center"] = _lock.current_target == _center
	await _step(24)
	_checks["held_stick_does_not_repeat"] = _lock.current_target == _center
	_switch_axis(0.0)
	await _step(3)
	_switch_axis(1.0)
	await _step(4)
	_checks["neutral_rearms_next_switch"] = _lock.current_target == _right
	_switch_axis(0.0)
	await _step(3)
	_switch_axis(1.0)
	await _step(4)
	_checks["no_candidate_keeps_current"] = _lock.current_target == _right
	_switch_axis(0.0)
	await _step(3)
	_switch_axis(-1.0)
	await _step(4)
	_checks["switch_back_leftward"] = _lock.current_target == _center
	await _reset()
	_lock.try_acquire()
	await _step(3)
	_right.available = false
	_checks["switch_skips_disabled"] = not _lock.switch_target(1) and _lock.current_target == _center
	await _reset()
	_lock.try_acquire()
	_center.position.z = -20.0
	await _step(2)
	_checks["distance_breaks_lock"] = not _lock.is_locked() and _lock.last_release_reason == &"distance"
	await _reset()
	_lock.try_acquire()
	_center.available = false
	await _step(2)
	_checks["deactivation_breaks_lock"] = not _lock.is_locked() and _player.orient_to_movement
	await _reset()
	_lock.try_acquire()
	_center.alive = false
	await _step(2)
	_checks["death_flag_breaks_lock"] = not _lock.is_locked()
	await _reset()
	_lock.try_acquire()
	_center.visible = false
	await _step(2)
	_checks["hidden_target_breaks_lock"] = not _lock.is_locked() and not _indicator.visible
	await _reset()
	var temporary: Node3D = load("res://scenes/props/lockable_dummy.tscn").instantiate()
	temporary.target_id = &"test_destroy"
	temporary.position = Vector3(0, 0, -4)
	arena.add_child(temporary)
	_center.available = false
	_left.available = false
	_right.available = false
	_lock.try_acquire()
	_checks["temporary_target_acquired"] = _lock.current_target == temporary
	temporary.queue_free()
	await _step(3)
	_checks["destroyed_target_safe_release"] = not _lock.is_locked() and not _indicator.visible \
		and _rig.control_mode == 0 and _player.orient_to_movement
	await _reset()
	_lock.try_acquire()
	blocker = _make_blocker()
	await _step(5)
	_checks["brief_occlusion_tolerated"] = _lock.current_target == _center
	blocker.queue_free()
	await _step(5)
	_checks["visibility_restores_lock_grace"] = _lock.current_target == _center
	blocker = _make_blocker()
	await _step(35)
	_checks["persistent_occlusion_breaks"] = not _lock.is_locked() and _lock.last_release_reason == &"occlusion"
	blocker.queue_free()
	await _step(3)
	await _reset()
	_lock.try_acquire()
	var start_distance := _player.global_position.distance_to(_center.global_position)
	Input.action_press("move_left")
	await _step(25)
	_checks["locked_strafe_left"] = _player.position.x < -0.5 \
		and absf(_player.position.distance_to(_center.position) - start_distance) < 0.2
	_checks["strafe_faces_enemy"] = _facing_dot() > 0.98 and _player.rotation.is_zero_approx()
	Input.action_release("move_left")
	await _reset()
	_lock.try_acquire()
	Input.action_press("move_backward")
	await _step(25)
	_checks["backward_retreats"] = _player.position.z > 0.5
	_checks["retreat_faces_enemy"] = _facing_dot() > 0.99 and _player.locomotion_state == 1
	await _reset()
	_lock.try_acquire()
	Input.action_press("move_forward")
	await _step(25)
	_checks["forward_approaches"] = _player.position.z < -0.5
	await _reset()
	_lock.try_acquire()
	Input.action_press("move_right")
	await _step(25)
	_checks["locked_strafe_right"] = _player.position.x > 0.5 and _facing_dot() > 0.98
	await _reset()
	_lock.try_acquire()
	Input.action_press("move_forward")
	Input.action_press("move_right")
	await _step(25)
	_checks["locked_diagonal_normalized"] = absf(_player.horizontal_speed - _player.walk_speed) < 0.03
	_measurements["locked_diagonal_speed"] = _player.horizontal_speed
	await _reset()
	_lock.try_acquire()
	var releases: Array = []
	var on_release := func(duration: float, long_press: bool) -> void: releases.append([duration, long_press])
	_player.sprint_dodge_released.connect(on_release)
	Input.action_press("move_forward")
	Input.action_press("sprint_dodge")
	await _step(5)
	Input.action_release("sprint_dodge")
	await _step(2)
	_checks["short_press_keeps_lock_and_release"] = _lock.is_locked() and releases.size() == 1 and not releases[0][1]
	Input.action_press("sprint_dodge")
	await _step(40)
	_checks["long_hold_keeps_lock_and_runs"] = _lock.is_locked() and _lock.current_target == _center \
		and _player.locomotion_state == 2 and absf(_player.horizontal_speed - _player.run_speed) < 0.03
	_checks["sprint_preserves_locked_orientation"] = not _player.orient_to_movement and _rig.control_mode == 1
	Input.action_release("sprint_dodge")
	await _step(2)
	_checks["long_release_preserved"] = releases.size() == 2 and releases[1][1]
	_player.sprint_dodge_released.disconnect(on_release)
	await _reset()
	_lock.try_acquire()
	var camera_angles: Vector2 = _rig.get_orbit_angles()
	_lock.switch_target(1)
	await _step(1)
	var angle_delta: Vector2 = _rig.get_orbit_angles() - camera_angles
	_checks["camera_switch_is_rate_limited"] = absf(angle_delta.x) <= deg_to_rad(_lock.maximum_camera_turn) / 60.0 + 0.01
	await _reset()
	_player.position.z = 2.5
	_player.reset_physics_interpolation()
	_rig.snap_to_target()
	# Teleport must settle the SpringArm before querying LOS from the camera.
	await _step(8)
	_lock.try_acquire()
	await _step(20)
	_checks["camera_wall_collision_while_locked"] = _lock.is_locked() \
		and _rig.spring_arm.current_distance < 3.0 and _rig.camera.global_position.z < 5.05
	_measurements["locked_camera_wall_distance"] = _rig.spring_arm.current_distance
	_player.position = Vector3.ZERO
	_player.reset_physics_interpolation()
	_rig.snap_to_target()
	await _step(60)
	_checks["locked_camera_recovers_distance"] = _lock.is_locked() and absf(_rig.spring_arm.current_distance - _rig.normal_distance) < 0.01
	await _reset()
	var failed: Array = []
	for key in _checks:
		if not _checks[key]:
			failed.append(key)
	return {"passed": _checks.size() - failed.size(), "total": _checks.size(), "failed": failed,
		"checks": _checks, "measurements": _measurements, "physical_devices": Input.get_connected_joypads(),
		"source": "synthetic R3 and stick events plus action simulation, real physics"}


func _reset() -> void:
	_lock.release_lock(&"test_reset")
	for action in ["move_forward", "move_backward", "move_left", "move_right", "sprint_dodge"]:
		Input.action_release(action)
	_switch_axis(0.0)
	_player.position = Vector3.ZERO
	_player.velocity = Vector3.ZERO
	_player.visual.rotation = Vector3.ZERO
	_player.reset_physics_interpolation()
	_center.position = Vector3(0, 0, -6)
	_left.position = Vector3(-3, 0, -5)
	_right.position = Vector3(3, 0, -5)
	for target in [_center, _left, _right]:
		target.available = true
		target.alive = true
		target.visible = true
	_rig.set_control_mode(0)
	_rig.set_orbit_angles(0.0, deg_to_rad(_rig.initial_pitch))
	_rig.snap_to_target()
	await _step(8)


func _step(frames: int) -> void:
	for frame in range(frames):
		await _tree.physics_frame
	await _tree.process_frame


func _r3() -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 7
		event.button_index = JOY_BUTTON_RIGHT_STICK
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func _switch_axis(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 7
	event.axis = JOY_AXIS_RIGHT_X
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _facing_dot() -> float:
	var toward := _center.global_position - _player.global_position
	toward.y = 0.0
	return (-_player.visual.global_basis.z).dot(toward.normalized())


func _make_blocker() -> StaticBody3D:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8, 3, 0.3)
	collider.shape = shape
	body.add_child(collider)
	_tree.current_scene.add_child(body)
	body.position = Vector3(0, 1.5, -3)
	return body
