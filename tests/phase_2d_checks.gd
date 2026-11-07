extends RefCounted
## Integrated physics and simulated semantic/controller inputs. No components disabled.
var _tree: SceneTree
var _p: CharacterBody3D
var _a: CharacterBody3D
var _test: Node
var _def: Node
var _checks: Dictionary = {}
var _measurements: Dictionary = {}

func start(tree: SceneTree) -> void:
	tree.root.set_meta("phase_2d_result",{"status":"running","checks":_checks})
	var result := await run(tree)
	result["status"] = "complete"
	tree.root.set_meta("phase_2d_result",result)

func run(tree: SceneTree) -> Dictionary:
	_tree = tree
	_p = tree.current_scene.get_node("Player")
	_a = tree.current_scene.get_node("DefenseTestAttacker")
	_test = tree.current_scene.get_node("DefenseTestController")
	_def = _p.defense_controller
	await _reset()
	Input.action_press("block")
	await _step(3)
	_checks["hold_raises_owned_block"] = _def.is_blocking() and _p.action_states.current_state == 3
	_checks["block_without_continuous_cost"] = _p.attributes.current_stamina == 100.0
	_checks["block_cannot_be_cancelled_by_normal_state_transition"] = not _p.action_states.transition_to(0)
	Input.action_press("move_right")
	await _step(25)
	_checks["block_movement_reduced"] = absf(_p.horizontal_speed-1.44) < 0.001
	_checks["free_defensive_facing_preserved"] = absf(_p.visual.rotation.y) < 0.001
	_checks["attacks_and_dodges_rejected_while_blocking"] = not _p.attack_controller.request_attack(0) and not _p.dodge_controller.try_dodge(Vector2.UP)
	Input.action_release("move_right")
	Input.action_release("block")
	await _step(3)
	_checks["release_lowers_shield"] = _p.action_states.current_state == 0 and not _def.shield_mesh.visible
	await _reset()
	Input.action_press("block")
	await _step(3)
	_checks["front_test_starts"] = _test.execute_test(0)
	await _step(23)
	_checks["front_block_absorbs_all_physical_damage"] = _p.attributes.current_health == 100.0 and _def.last_event == &"blocked"
	_checks["stability_exact_stamina_cost"] = _p.attributes.current_stamina == 84.0
	await _step(3)
	_checks["blocked_contact_not_charged_repeatedly"] = _p.attributes.current_stamina == 84.0
	_checks["hud_receives_defensive_stamina_change"] = tree.current_scene.get_node("HUD/PlayerVitals").stamina_bar.value == 84.0
	_def.absorption = 75.0
	var residual := _hit({"blockable":true,"stamina_damage":10.0})
	_checks["configurable_residual_damage"] = residual.outcome == &"blocked" and residual.damage == 7.5
	_def.absorption = 100.0
	await _reset()
	Input.action_press("block")
	await _step(2)
	_test.execute_test(2)
	await _step(23)
	_checks["rear_attack_not_blocked"] = _p.attributes.current_health == 70.0 and _p.attributes.current_stamina == 100.0
	await _reset()
	Input.action_press("block")
	await _step(2)
	_a.position = Vector3(0,0,-1.6)
	var nonblocking := _hit({"blockable":false,"stamina_damage":50.0})
	_checks["explicit_nonblockable_attack"] = nonblocking.outcome == &"normal" and nonblocking.damage == 30.0
	var other_type := _hit({"blockable":true,"damage_type":&"unimplemented_type","stamina_damage":50.0})
	_checks["unknown_damage_type_not_silently_absorbed"] = other_type.outcome == &"normal" and other_type.damage == 30.0
	await _reset()
	Input.action_press("block")
	await _step(2)
	_p.attributes.consume_stamina(50.0)
	await _step(120)
	_checks["blocking_regeneration_multiplier"] = _p.attributes.current_stamina > 55.0 and _p.attributes.current_stamina < 57.0
	_measurements["stamina_after_2s_shield_regen"] = _p.attributes.current_stamina
	await _reset()
	Input.action_press("block")
	await _step(2)
	_test.execute_test(3)
	await _step(23)
	_checks["guard_break_exhausts_stamina_and_staggers"] = _p.attributes.current_stamina == 0.0 and _p.action_states.current_state == 6
	_checks["guard_break_full_incoming_health_damage"] = _p.attributes.current_health == 60.0 and _def.last_event == &"guard_break"
	_checks["guard_break_blocks_actions"] = not _p.can_move() and not _def.try_parry() and not _p.attack_controller.request_attack(0)
	await _step(70)
	_checks["guard_break_recovery_to_free"] = _p.action_states.current_state == 0
	_checks["held_shield_does_not_auto_reactivate_after_break"] = not _def.is_blocking()
	Input.action_release("block")
	await _step(2)
	Input.action_press("block")
	await _step(2)
	_checks["release_repress_can_raise_after_break"] = _def.is_blocking()
	await _reset()
	_trigger(1.0)
	await _step(2)
	_checks["trigger_starts_parry_and_costs_once"] = _p.action_states.current_state == 4 and _p.attributes.current_stamina == 85.0 and _def.parry_phase == 1
	await _step(5)
	_checks["parry_startup_duration"] = _def.parry_phase == 1
	await _step(1)
	_checks["parry_active_after_startup"] = _def.parry_phase == 2
	await _step(9)
	_checks["parry_recovery_after_active"] = _def.parry_phase == 3
	await _step(35)
	_checks["parry_completes_to_free_without_repeat_on_hold"] = _p.action_states.current_state == 0 and _def.mode == 0
	_trigger(0.0)
	await _reset()
	_test.execute_test(0)
	_def.try_parry()
	var early := _hit({"blockable":true,"parryable":true,"direction":Vector3.BACK})
	_checks["contact_during_startup_not_parried"] = early.outcome == &"normal" and early.damage == 30.0
	await _reset()
	_test.execute_test(0)
	_def.try_parry()
	await _step(18)
	_checks["real_contact_outside_parry_window_causes_damage"] = _p.attributes.current_health == 70.0
	await _reset()
	_test.execute_test(1)
	await _step(6)
	_def.try_parry()
	await _step(17)
	_checks["nonparryable_real_attack_rejected"] = _p.attributes.current_health == 70.0 and not _a.critical_vulnerability.is_available()
	await _reset()
	_test.execute_test(2)
	await _step(6)
	_def.try_parry()
	await _step(17)
	_checks["rear_real_attack_not_parried"] = _p.attributes.current_health == 70.0 and not _a.critical_vulnerability.is_available()
	await _reset()
	_test.execute_test(0)
	await _step(6)
	_def.try_parry()
	await _step(8)
	var misdirected := _hit({"parryable":true,"direction":Vector3.FORWARD})
	_checks["wrong_attack_direction_not_parried"] = misdirected.outcome == &"normal"
	await _reset()
	_def.try_parry()
	await _step(8)
	_checks["proximity_without_contact_not_success"] = _def.last_event != &"parry_success" and not _a.critical_vulnerability.is_available()
	await _reset()
	await _successful_parry()
	_checks["actual_contact_parry_success"] = _def.last_event == &"parry_success" and _p.attributes.current_health == 100.0
	_checks["parry_interrupts_hitbox_and_opens_vulnerability"] = not _a.attack_controller.is_active() and not _a.attack_controller.hitbox.is_active() and _a.critical_vulnerability.is_available()
	_checks["vulnerable_target_cannot_attack"] = not _a.attack_controller.request_attack(0) and _a.action_states.current_state == 6
	await _step(115)
	_checks["vulnerability_expires_safely"] = not _a.critical_vulnerability.is_available() and _a.action_states.current_state == 0
	await _reset()
	await _successful_parry()
	await _step(36)
	var hp_before: float = _a.attributes.current_health
	var stamina_before: float = _p.attributes.current_stamina
	var pos_before: Vector3 = _p.position
	_button(true)
	await _step(2)
	_button(false)
	_checks["rb_context_prioritizes_riposte"] = _p.riposte_controller.is_active() and _p.attack_controller.current_attack_name() == &"RIPOSTE" and not _p.attack_controller.is_active()
	_checks["riposte_cost_exact_and_pair_committed"] = absf(stamina_before-_p.attributes.current_stamina-30.0) < 0.001 and _a.critical_vulnerability.is_reserved()
	_checks["duplicate_riposte_rejected"] = not _p.attack_controller.request_attack(0) and _p.riposte_controller.try_contextual() == 2
	_checks["critical_normal_hitbox_off"] = not _p.attack_controller.hitbox.is_active()
	_checks["critical_pair_protected_from_normal_hits"] = _a.get_node("Hurtbox").receive_hit(_p,&"player",20.0,999) == 0.0
	Input.action_press("move_forward")
	await _step(22)
	_checks["critical_damage_once_at_configured_time"] = _a.attributes.current_health == hp_before-120.0 and _p.riposte_controller.damage_applied == 120.0
	var spoof: Dictionary = _a.get_node("Hurtbox").resolve_hit(_p,&"player",120.0,1000,{"critical_owner":_p.riposte_controller})
	_checks["critical_damage_token_single_use"] = spoof.damage == 0.0
	_checks["riposte_no_teleport_or_movement"] = _p.position.distance_to(pos_before) < 0.02 and _a.position.distance_to(Vector3(0,0,-1.6)) < 0.03
	Input.action_release("move_forward")
	await _step(45)
	_checks["riposte_completion_restores_both_states"] = _p.action_states.current_state == 0 and _a.action_states.current_state == 0 and not _p.riposte_controller.is_active()
	_checks["no_additional_normal_or_critical_damage"] = _a.attributes.current_health == hp_before-120.0
	await _reset()
	await _successful_parry()
	await _step(36)
	_p.attributes.consume_stamina(_p.attributes.current_stamina)
	_checks["insufficient_critical_stamina_rejects_without_light_fallback"] = not _p.attack_controller.request_attack(0) and not _p.attack_controller.is_active() and not _a.critical_vulnerability.is_reserved()
	await _reset()
	await _successful_parry()
	await _step(36)
	_p.visual.rotation.y = PI
	_checks["riposte_rejects_bad_facing"] = _p.riposte_controller.try_contextual() == 0
	_p.visual.rotation.y = 0.0
	_p.position.z = 2.0
	_checks["riposte_rejects_out_of_range"] = _p.riposte_controller.try_contextual() == 0
	await _reset()
	_a.position = Vector3(0,0,-1.6)
	_p.dodge_controller.try_dodge(Vector2.UP)
	_checks["parry_rejected_during_dodge"] = not _def.try_parry()
	await _step(3)
	_checks["iframes_take_precedence_over_damage"] = _p.is_invulnerable() and _hit({"blockable":true,"parryable":true}).outcome == &"evaded"
	_checks["physical_capsule_stays_enabled"] = not _p.get_node("CollisionShape3D").disabled
	await _reset()
	_p.attack_controller.request_attack(0)
	_checks["parry_rejected_during_attack"] = not _def.try_parry()
	await _reset()
	_p.attributes.consume_stamina(90.0)
	_checks["parry_rejected_without_stamina"] = not _def.try_parry() and _p.action_states.current_state == 0
	await _reset()
	Input.action_press("block")
	await _step(2)
	_checks["parry_can_replace_owned_block"] = _def.try_parry() and _p.action_states.current_state == 4
	await _reset()
	var lock: Node = tree.current_scene.get_node("LockOnController")
	lock.try_acquire()
	await _step(4)
	Input.action_press("block")
	Input.action_press("move_right")
	await _step(18)
	_checks["lock_and_strafe_preserved_with_shield"] = lock.is_locked() and _def.is_blocking() and _p.horizontal_speed > 0.5
	_checks["camera_still_current"] = _p.movement_camera.current
	await _reset()
	Input.action_press("block")
	await _step(2)
	_p.attributes.apply_damage(1000.0)
	_checks["dead_cancels_block_and_has_priority"] = _p.action_states.current_state == 7 and not _def.is_blocking() and not _def.try_parry() and not _p.attack_controller.request_attack(0)
	await _reset()
	await _successful_parry()
	await _step(36)
	_p.attack_controller.request_attack(0)
	_p.attributes.apply_damage(1000.0)
	_checks["dead_aborts_critical_and_releases_target"] = not _p.riposte_controller.is_active() and not _a.critical_vulnerability.is_reserved() and _a.action_states.current_state == 0
	await _reset()
	_checks["normal_light_attack_still_available"] = _p.attack_controller.request_attack(0) and _p.attack_controller.current_attack_name() == &"LIGHT_1"
	await _reset()
	_checks["all_new_systems_enabled_in_integrated_suite"] = _def.input_enabled and _p.attack_controller.input_enabled and _p.dodge_controller.input_enabled
	var failed: Array = []
	for key in _checks:
		if not _checks[key]: failed.append(key)
	return {"passed":_checks.size()-failed.size(),"total":_checks.size(),"failed":failed,"checks":_checks,"measurements":_measurements,"physical_devices":Input.get_connected_joypads()}

func _successful_parry() -> void:
	_test.execute_test(0)
	await _step(6)
	_def.try_parry()
	await _step(17)

func _hit(context: Dictionary) -> Dictionary:
	return _p.get_node("Hurtbox").resolve_hit(_a,&"test_attacker",30.0,987,context)

func _reset() -> void:
	for action in ["block","parry","move_forward","move_backward","move_left","move_right","sprint_dodge","light_attack","heavy_attack"]:
		Input.action_release(action)
	_button(false)
	_trigger(0.0)
	_tree.current_scene.get_node("LockOnController").release_lock(&"test_reset")
	_p.attributes.restore_all()
	_a.attributes.restore_all()
	_p.position = Vector3.ZERO
	_p.velocity = Vector3.ZERO
	_p.visual.rotation = Vector3.ZERO
	_a.position = Vector3(7.5,0,7.5)
	_a.velocity = Vector3.ZERO
	_p.reset_physics_interpolation()
	_a.reset_physics_interpolation()
	var rig: Node3D = _tree.current_scene.get_node("CameraRig")
	rig.set_control_mode(0)
	rig.set_orbit_angles(0.0,deg_to_rad(rig.initial_pitch))
	rig.snap_to_target()
	await _step(8)

func _step(frames: int) -> void:
	for i in range(frames): await _tree.physics_frame
	await _tree.process_frame

func _trigger(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 7
	event.axis = JOY_AXIS_TRIGGER_LEFT
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _button(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 7
	event.button_index = JOY_BUTTON_RIGHT_SHOULDER
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
