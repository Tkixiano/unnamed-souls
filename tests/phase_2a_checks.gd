extends RefCounted

const Attributes = preload("res://scripts/systems/actor_attributes.gd")
const ActionState = preload("res://scripts/player/action_state.gd")

var _tree: SceneTree
var _player: CharacterBody3D
var _lock: Node
var _rig: Node3D
var _checks: Dictionary = {}
var _measurements: Dictionary = {}


func start(tree: SceneTree) -> void:
	tree.root.set_meta("phase_2a_result", {"status": "running", "checks": _checks})
	var result := await run(tree)
	result["status"] = "complete"
	tree.root.set_meta("phase_2a_result", result)


func run(tree: SceneTree) -> Dictionary:
	_tree = tree
	var arena := tree.current_scene
	_player = arena.get_node("Player")
	_lock = arena.get_node("LockOnController")
	_rig = arena.get_node("CameraRig")
	_test_attributes()
	_test_action_states()
	await _reset()
	_checks["player_initial_attributes"] = _player.attributes.current_health == 100.0 \
		and _player.attributes.current_stamina == 100.0 and _player.attributes.max_health == 100.0 \
		and _player.attributes.max_stamina == 100.0
	var hud: Control = arena.get_node("HUD/PlayerVitals")
	_player.attributes.apply_damage(23.0)
	_player.attributes.consume_stamina(31.0)
	_checks["hud_updates_immediately_from_signals"] = hud.health_bar.value == 77.0 and hud.stamina_bar.value == 69.0
	_player.attributes.max_health = 120.0
	_checks["hud_maximum_updates"] = hud.health_bar.max_value == 120.0
	_player.attributes.max_health = 100.0
	_checks["hud_in_viewport"] = tree.root.get_visible_rect().encloses(hud.get_global_rect())
	await _reset()
	_player.attributes.consume_stamina(20.0)
	_player.attributes.set_regeneration_blocked(&"test_walk", true)
	Input.action_press("move_forward")
	await _step(25)
	_checks["walking_does_not_consume"] = _player.attributes.current_stamina == 80.0 \
		and _player.position.z < -0.5 and _player.locomotion_state == 1
	await _reset()
	Input.action_press("move_forward")
	Input.action_press("sprint_dodge")
	await _step(20)
	_checks["sprint_uses_existing_hold_threshold"] = _player.is_sprinting
	var before: float = _player.attributes.current_stamina
	await _step(30)
	var spent: float = before - _player.attributes.current_stamina
	_checks["continuous_sprint_cost"] = absf(spent - 6.0) < 0.25
	_checks["no_regeneration_during_sprint"] = _player.attributes.is_regeneration_blocked() and spent > 5.8
	_measurements["stamina_spent_in_30_sprint_ticks"] = spent
	await _reset()
	_player.attributes.consume_stamina(94.0)
	Input.action_press("move_forward")
	Input.action_press("sprint_dodge")
	await _step(50)
	_checks["sprint_exhausts_to_zero"] = _player.attributes.current_stamina < 0.001
	_checks["exhaustion_returns_to_walk"] = not _player.is_sprinting and _player.locomotion_state == 1
	await _step(10)
	_checks["walk_speed_after_exhaustion"] = absf(_player.horizontal_speed - _player.walk_speed) < 0.03
	Input.action_release("move_forward")
	# Keep B held, freeze regeneration and place below the recovery threshold.
	_player.attributes.set_regeneration_blocked(&"test_threshold", true)
	_player.attributes.restore_stamina(14.0)
	Input.action_press("move_right")
	await _step(10)
	_checks["no_restart_below_15"] = not _player.is_sprinting and _player.attributes.current_stamina == 14.0
	_player.attributes.restore_stamina(1.0)
	_player.attributes.set_regeneration_blocked(&"test_threshold", false)
	# Allow the existing acceleration to finish the forward-to-right turn.
	await _step(24)
	_checks["restart_at_threshold"] = _player.is_sprinting and _player.locomotion_state == 2 \
		and absf(_player.horizontal_speed - _player.run_speed) < 0.03
	_checks["hysteresis_no_threshold_oscillation"] = _player.attributes.current_stamina < 15.0 and _player.is_sprinting
	_measurements["stamina_after_restart_24_ticks"] = _player.attributes.current_stamina
	await _reset()
	_player.attributes.consume_stamina(50.0)
	await _step(30)
	_checks["runtime_regen_delay"] = absf(_player.attributes.current_stamina - 50.0) < 0.001
	await _step(60)
	_checks["runtime_regenerates"] = _player.attributes.current_stamina > 65.0 and _player.attributes.current_stamina < 72.0
	_measurements["stamina_after_1_5_seconds"] = _player.attributes.current_stamina
	await _reset()
	_player.attributes.consume_stamina(30.0)
	_player.action_states.transition_to(ActionState.State.STAGGERED)
	Input.action_press("move_forward")
	await _step(65)
	_checks["busy_policy_blocks_move_and_regen"] = _player.position.length() < 0.02 \
		and _player.attributes.current_stamina == 70.0
	_player.action_states.transition_to(ActionState.State.FREE)
	await _step(12)
	_checks["free_policy_restores_move_and_regen"] = _player.position.z < -0.1 and _player.attributes.current_stamina > 70.0
	await _reset()
	_player.attributes.consume_stamina(100.0)
	_lock.try_acquire()
	Input.action_press("move_left")
	await _step(25)
	_checks["zero_stamina_preserves_lock_and_strafe"] = _lock.is_locked() and _player.position.x < -0.5 \
		and _player.locomotion_state == 1
	_checks["stamina_does_not_gate_target_switch"] = _lock.switch_target(1)
	await _reset()
	_lock.try_acquire()
	Input.action_press("move_forward")
	var releases: Array = []
	var on_release := func(duration: float, long_press: bool) -> void: releases.append([duration, long_press])
	_player.sprint_dodge_released.connect(on_release)
	Input.action_press("sprint_dodge")
	await _step(5)
	Input.action_release("sprint_dodge")
	await _step(2)
	_checks["short_press_preserved_without_cost"] = releases.size() == 1 and not releases[0][1] \
		and _player.attributes.current_stamina == 100.0 and _lock.is_locked()
	Input.action_press("sprint_dodge")
	await _step(35)
	_checks["stamina_sprint_preserves_lock"] = _lock.is_locked() \
		and _player.is_sprinting and _player.attributes.current_stamina < 100.0
	Input.action_release("sprint_dodge")
	await _step(2)
	_checks["long_release_preserved"] = releases.size() == 2 and releases[1][1]
	_player.sprint_dodge_released.disconnect(on_release)
	await _reset()
	_lock.try_acquire()
	var deaths: Array = []
	var on_death := func() -> void: deaths.append(true)
	_player.attributes.died.connect(on_death)
	_player.attributes.apply_damage(1000.0)
	_player.attributes.apply_damage(1.0)
	_checks["lethal_damage_enters_dead"] = _player.attributes.current_health == 0.0 \
		and _player.action_states.current_state == ActionState.State.DEAD
	_checks["one_death_signal"] = deaths.size() == 1
	_checks["death_immediately_releases_lock"] = not _lock.is_locked() and _lock.last_release_reason == &"dead" \
		and _rig.control_mode == 0
	_checks["dead_cannot_transition_normally"] = not _player.action_states.transition_to(ActionState.State.FREE)
	_checks["dead_cannot_heal_normally"] = _player.attributes.restore_health(100.0) == 0.0
	_checks["dead_cannot_acquire"] = not _lock.try_acquire()
	var death_position := _player.position
	Input.action_press("move_forward")
	Input.action_press("sprint_dodge")
	await _step(20)
	_checks["dead_blocks_movement_and_sprint"] = _player.position.distance_to(death_position) < 0.02 \
		and not _player.is_sprinting and _player.locomotion_state == 0
	_checks["death_hud_zero"] = hud.health_bar.value == 0.0
	_player.attributes.died.disconnect(on_death)
	await _reset()
	_checks["explicit_restore_revives"] = _player.can_move() and _player.action_states.current_state == ActionState.State.FREE \
		and _player.attributes.current_health == 100.0 and _player.attributes.current_stamina == 100.0
	Input.action_press("camera_right")
	var old_angles: Vector2 = _rig.get_orbit_angles()
	await _step(10)
	_checks["orbital_camera_preserved"] = _rig.get_orbit_angles().distance_to(old_angles) > 0.1 \
		and _player.rotation.is_zero_approx()
	Input.action_release("camera_right")
	await _reset()
	var failed: Array = []
	for key in _checks:
		if not _checks[key]:
			failed.append(key)
	return {"passed": _checks.size() - failed.size(), "total": _checks.size(), "failed": failed,
		"checks": _checks, "measurements": _measurements, "physical_devices": Input.get_connected_joypads(),
		"source": "component tests, simulated actions and real physics ticks"}


func _test_attributes() -> void:
	var stats := Attributes.new()
	stats.max_health = 120.0
	stats.max_stamina = 80.0
	_tree.root.add_child(stats)
	stats.set_physics_process(false)
	_checks["inspector_maxima_initialize_full"] = stats.current_health == 120.0 and stats.current_stamina == 80.0
	stats.max_health = 100.0
	stats.max_stamina = 100.0
	stats.restore_all()
	var health_events: Array = []
	var stamina_events: Array = []
	var on_health := func(current: float, maximum: float) -> void: health_events.append([current, maximum])
	var on_stamina := func(current: float, maximum: float) -> void: stamina_events.append([current, maximum])
	stats.health_changed.connect(on_health)
	stats.stamina_changed.connect(on_stamina)
	_checks["normal_consume"] = stats.has_stamina(30.0) and stats.consume_stamina(30.0) and stats.current_stamina == 70.0
	_checks["reject_overdraft_atomically"] = not stats.consume_stamina(71.0) and stats.current_stamina == 70.0
	_checks["reject_bad_numbers"] = not stats.consume_stamina(-1.0) and not stats.consume_stamina(INF) \
		and not stats.has_stamina(NAN) and stats.restore_stamina(INF) == 0.0 \
		and stats.apply_damage(-10.0) == 0.0 and stats.restore_health(NAN) == 0.0
	stats.restore_stamina(1000.0)
	_checks["stamina_upper_bound"] = stats.current_stamina == 100.0
	stats.consume_stamina(100.0)
	_checks["stamina_lower_bound"] = stats.current_stamina == 0.0 and not stats.consume_stamina(0.01)
	stats.restore_all()
	stats.consume_stamina(40.0)
	stats.advance_regeneration(1.0 / 60.0)
	stats.advance_regeneration(0.5)
	_checks["regen_delay_half_second"] = stats.current_stamina == 60.0
	stats.advance_regeneration(0.25)
	_checks["regen_delay_exact_boundary"] = stats.current_stamina == 60.0
	stats.advance_regeneration(0.4)
	_checks["regen_rate_25"] = absf(stats.current_stamina - 70.0) < 0.001
	stats.advance_regeneration(100.0)
	_checks["regen_caps_at_maximum"] = stats.current_stamina == 100.0
	stats.consume_stamina(40.0)
	stats.advance_regeneration(1.0 / 60.0)
	stats.set_regeneration_blocked(&"owner_a", true)
	stats.set_regeneration_blocked(&"owner_b", true)
	stats.advance_regeneration(2.0)
	stats.set_regeneration_blocked(&"owner_a", false)
	stats.advance_regeneration(1.0)
	_checks["independent_regen_block_owners"] = stats.current_stamina == 60.0
	stats.set_regeneration_blocked(&"owner_b", false)
	stats.advance_regeneration(0.4)
	_checks["unblocked_regeneration"] = absf(stats.current_stamina - 70.0) < 0.001
	stats.apply_damage(20.0)
	_checks["damage_and_heal"] = stats.current_health == 80.0 and stats.restore_health(1000.0) == 20.0 \
		and stats.current_health == 100.0
	stats.apply_damage(1000.0)
	stats.advance_regeneration(10.0)
	_checks["dead_attributes_do_not_regenerate"] = stats.current_health == 0.0 and stats.current_stamina == 70.0 \
		and not stats.consume_stamina(1.0)
	_checks["signals_report_values_and_maxima"] = not health_events.is_empty() and not stamina_events.is_empty() \
		and health_events.back() == [0.0, 100.0]
	var recovered: Array[float] = []
	for hz in [30, 60, 120]:
		stats.restore_all()
		stats.consume_stamina(50.0)
		stats.advance_regeneration(1.0 / hz)
		for tick in range(hz * 2):
			stats.advance_regeneration(1.0 / hz)
		recovered.append(stats.current_stamina)
	_checks["regen_delta_independence"] = absf(recovered[0] - 81.25) < 0.001 and absf(recovered[0] - recovered[2]) < 0.001
	_measurements["regen_after_two_seconds_delta_30_60_120"] = recovered
	stats.queue_free()


func _test_action_states() -> void:
	var actions := ActionState.new()
	_checks["action_initial_free"] = actions.current_state == ActionState.State.FREE and actions.can_move()
	_checks["valid_busy_entry"] = actions.transition_to(ActionState.State.ATTACKING) and not actions.can_sprint()
	_checks["reject_incompatible_busy_transition"] = not actions.transition_to(ActionState.State.DODGING)
	_checks["valid_busy_exit"] = actions.transition_to(ActionState.State.FREE)
	_checks["reject_invalid_state_ids"] = not actions.transition_to(-1) and not actions.transition_to(999)
	_checks["same_state_no_transition"] = not actions.transition_to(ActionState.State.FREE)
	var placeholders_valid := true
	for state in range(ActionState.State.ATTACKING, ActionState.State.DEAD):
		placeholders_valid = placeholders_valid and actions.transition_to(state) \
			and actions.blocks_regeneration() and not actions.can_move() \
			and actions.transition_to(ActionState.State.FREE)
	_checks["all_placeholders_defined_without_mechanics"] = placeholders_valid
	actions.transition_to(ActionState.State.ATTACKING)
	_checks["death_interrupts_busy_state"] = actions.transition_to(ActionState.State.DEAD)
	_checks["dead_is_terminal_for_normal_requests"] = not actions.transition_to(ActionState.State.FREE) \
		and not actions.transition_to(ActionState.State.HEALING)
	actions.reset_to_free()
	_checks["explicit_action_reset"] = actions.current_state == ActionState.State.FREE
	actions.free()


func _reset() -> void:
	_lock.release_lock(&"test_reset")
	for action in ["move_forward", "move_backward", "move_left", "move_right", "sprint_dodge", "camera_right"]:
		Input.action_release(action)
	_player.attributes.restore_all()
	_player.position = Vector3.ZERO
	_player.velocity = Vector3.ZERO
	_player.visual.rotation = Vector3.ZERO
	_player.reset_physics_interpolation()
	_rig.set_control_mode(0)
	_rig.set_orbit_angles(0.0, deg_to_rad(_rig.initial_pitch))
	_rig.snap_to_target()
	await _step(8)


func _step(frames: int) -> void:
	for frame in range(frames):
		await _tree.physics_frame
	await _tree.process_frame
