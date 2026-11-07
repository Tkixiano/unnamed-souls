extends RefCounted
## Real components and physics, with simulated normalized input. No listeners isolated.
var _tree: SceneTree
var _p: CharacterBody3D
var _a: CharacterBody3D
var _critical: Node
var _estus: Node
var _grip: Node
var _checks: Dictionary = {}
var _measurements: Dictionary = {}

func start(tree: SceneTree) -> void:
	tree.root.set_meta("phase_2e_result",{"status":"running","checks":_checks})
	var result := await run(tree)
	result["status"] = "complete"
	tree.root.set_meta("phase_2e_result",result)

func run(tree: SceneTree) -> Dictionary:
	_tree = tree
	_p = tree.current_scene.get_node("Player")
	_a = tree.current_scene.get_node("DefenseTestAttacker")
	_critical = _p.riposte_controller
	_estus = _p.estus_controller
	_grip = _p.grip_controller
	await _reset()
	await _place_target()
	var origin: Vector3 = _p.position
	_checks["backstab_valid_rear_and_priority_over_light"] = _p.attack_controller.request_attack(0) and _p.attack_controller.current_attack_name() == &"BACKSTAB" and not _p.attack_controller.is_active()
	_checks["critical_pair_owned_and_stamina_exact"] = _a.critical_vulnerability.is_reserved() and _a.action_states.current_state == 6 and _p.attributes.current_stamina == 70.0
	_checks["duplicate_critical_rejected"] = not _p.attack_controller.request_attack(0) and not _a.critical_vulnerability.reserve(_a)
	_checks["backstab_blocks_other_actions"] = not _estus.try_use() and not _grip.try_toggle() and not _p.dodge_controller.try_dodge(Vector2.UP) and not _p.defense_controller.try_parry()
	Input.action_press("move_forward")
	await _step(26)
	_checks["no_critical_damage_before_instant"] = _a.attributes.current_health == 250.0 and not _p.attack_controller.hitbox.is_active()
	await _step(1)
	_checks["backstab_damage_at_instant_once"] = _a.attributes.current_health == 110.0 and _critical.damage_applied == 140.0
	var duplicate: Dictionary = _a.get_node("Hurtbox").resolve_hit(_p,&"player",140.0,201,{"critical_owner":_critical})
	_checks["critical_token_cannot_be_reused"] = duplicate.damage == 0.0
	_checks["normal_hits_rejected_during_critical"] = _a.get_node("Hurtbox").receive_hit(_p,&"player",20.0,202) == 0.0
	_checks["no_teleport_physical_collisions_preserved"] = _p.position.distance_to(origin) < 0.02 and not _p.get_node("CollisionShape3D").disabled
	Input.action_release("move_forward")
	await _step(46)
	_checks["backstab_finishes_releases_both"] = _p.action_states.current_state == 0 and _a.action_states.current_state == 0 and not _a.critical_vulnerability.is_reserved()
	_checks["damage_not_repeated_after_completion"] = _a.attributes.current_health == 110.0
	await _reset()
	await _place_target()
	_a.visual.rotation.y = PI
	_checks["front_not_backstab"] = _critical.try_contextual() == 0
	_checks["normal_light_fallback_front"] = _p.attack_controller.request_attack(0) and _p.attack_controller.current_attack_name() == &"LIGHT_1"
	await _reset()
	await _place_target()
	_a.position = Vector3(1.4,0,0)
	_p.visual.rotation.y = -PI/2.0
	_checks["side_not_backstab"] = _critical.try_contextual() == 0
	await _reset()
	await _place_target()
	_a.position.z = -2.2
	_checks["range_rejection"] = _critical.try_contextual() == 0
	_a.position.z = -1.4
	_p.visual.rotation.y = PI
	_checks["player_facing_rejection"] = _critical.try_contextual() == 0
	await _reset()
	await _place_target()
	var wall := _wall()
	await _step(3)
	_checks["solid_path_rejection"] = _critical.try_contextual() == 0
	wall.queue_free()
	await _step(2)
	var rig: Node3D = tree.current_scene.get_node("CameraRig")
	rig.set_orbit_angles(PI,0.0)
	_checks["acquisition_uses_actor_not_camera"] = _critical.try_contextual() == 1
	_p.attributes.apply_damage(1000.0)
	_checks["death_aborts_backstab_releases_target"] = not _critical.is_active() and not _a.critical_vulnerability.is_reserved() and _p.action_states.current_state == 7 and _a.action_states.current_state == 0
	await _reset()
	await _place_target()
	_a.attack_controller.request_attack(2)
	_checks["backstab_interrupts_allowed_normal_target_attack"] = _critical.try_contextual() == 1 and not _a.attack_controller.is_active() and not _a.attack_controller.hitbox.is_active()
	_a.attributes.restore_all()
	await _step(2)
	_checks["invalidated_reservation_releases_attacker"] = not _critical.is_active() and _p.action_states.current_state == 0
	await _reset()
	await _place_target()
	_a.action_states.transition_to(5)
	_checks["incompatible_target_action_rejected"] = _critical.try_contextual() == 0
	await _reset()
	await _place_target()
	_p.attributes.consume_stamina(80.0)
	_checks["critical_insufficient_stamina_no_light_fallback"] = not _p.attack_controller.request_attack(0) and not _p.attack_controller.is_active() and not _a.critical_vulnerability.is_reserved()
	await _reset()
	var dummy: Node3D = load("res://scenes/props/training_dummy.tscn").instantiate()
	tree.current_scene.add_child(dummy)
	dummy.position = Vector3(0,0,-1.4)
	await _step(3)
	_checks["reusable_training_dummy_critical_component"] = _critical.try_contextual() == 1 and dummy.critical_vulnerability.is_reserved()
	dummy.queue_free()
	await _step(3)
	_checks["target_destruction_releases_player"] = not _critical.is_active() and _p.action_states.current_state == 0
	await _reset()
	# Existing real parry pipeline; a rear candidate must not steal priority.
	var test: Node = tree.current_scene.get_node("DefenseTestController")
	test.execute_test(0)
	await _step(6)
	_p.defense_controller.try_parry()
	await _step(53)
	var rear_candidate: Node3D = tree.current_scene.get_node("Targets/Left")
	rear_candidate.position = Vector3(0.7,0,-1.25)
	rear_candidate.visual.rotation = Vector3.ZERO
	await _step(2)
	_checks["riposte_priority_before_backstab"] = _p.attack_controller.request_attack(0) and _critical.current_critical_name() == &"RIPOSTE" and _a.critical_vulnerability.is_reserved() and not rear_candidate.critical_vulnerability.is_reserved()
	await _reset()
	_checks["estus_initial_charges"] = _estus.current_charges == 5
	_checks["full_health_rejects_estus"] = not _estus.try_use()
	_p.attributes.apply_damage(80.0)
	_button(JOY_BUTTON_X,true)
	await _step(2)
	_button(JOY_BUTTON_X,false)
	_checks["estus_x_starts_owned_healing"] = _estus.is_active() and _p.action_states.current_state == 5 and _estus.phase == 1
	_checks["no_instant_heal_or_charge_spend"] = _p.attributes.current_health == 20.0 and _estus.current_charges == 5
	_checks["incompatible_actions_rejected_while_healing"] = not _p.attack_controller.request_attack(0) and not _p.dodge_controller.try_dodge(Vector2.UP) and not _p.defense_controller.try_parry() and not _grip.try_toggle()
	_checks["healing_owner_cannot_cancel_normally"] = not _p.action_states.transition_to(0)
	Input.action_press("block")
	Input.action_press("move_right")
	Input.action_press("sprint_dodge")
	var heal_origin: Vector3 = _p.position
	await _step(24)
	_checks["healing_preparation_before_045"] = _estus.phase == 1 and _p.attributes.current_health == 20.0
	await _step(1)
	_checks["drinking_phase_at_045"] = _estus.phase == 2
	await _step(23)
	_checks["no_heal_before_085"] = _p.attributes.current_health == 20.0 and _estus.current_charges == 5
	await _step(1)
	_checks["heal_and_charge_at_085"] = _p.attributes.current_health == 80.0 and _estus.current_charges == 4 and _estus.phase == 3
	_checks["no_block_or_motion_while_healing"] = not _p.defense_controller.is_blocking() and _p.position.distance_to(heal_origin) < 0.02 and not _p.is_sprinting
	_checks["estus_hud_updated_by_signal"] = tree.current_scene.get_node("HUD/EstusHUD").charges_label.text == "ESTUS  4 / 5"
	for action in ["block","move_right","sprint_dodge"]: Input.action_release(action)
	await _step(38)
	_checks["mandatory_heal_recovery"] = _estus.is_active() and _p.action_states.current_state == 5 and _estus.current_charges == 4
	await _step(1)
	_checks["heal_completes_to_free_at_15"] = not _estus.is_active() and _p.action_states.current_state == 0 and _p.attributes.current_health == 80.0 and _estus.current_charges == 4
	await _reset()
	_p.attributes.apply_damage(80.0)
	_estus.try_use()
	await _step(20)
	var before_hit: float = _p.get_node("Hurtbox").receive_hit(_a,&"test_attacker",5.0,301)
	_checks["stagger_interrupt_before_consumption"] = before_hit == 5.0 and _estus.interrupt_for_stagger() and _p.action_states.current_state == 6
	await _step(80)
	_checks["early_interrupt_no_charge_no_heal"] = _p.attributes.current_health == 15.0 and _estus.current_charges == 5 and not _estus.is_active()
	await _reset()
	_p.attributes.apply_damage(80.0)
	_estus.try_use()
	await _step(52)
	_p.get_node("Hurtbox").receive_hit(_a,&"test_attacker",5.0,302)
	_checks["stagger_interrupt_after_consumption"] = _estus.interrupt_for_stagger()
	await _step(50)
	_checks["late_interrupt_keeps_spent_charge_and_healing"] = _p.attributes.current_health == 75.0 and _estus.current_charges == 4
	await _reset()
	var capacity: int = _estus.initial_charges
	_estus.initial_charges = 1
	_p.attributes.restore_all()
	_p.attributes.apply_damage(80.0)
	_estus.try_use()
	await _step(91)
	_checks["last_charge_consumed_once"] = _estus.current_charges == 0 and _p.attributes.current_health == 80.0
	_checks["no_charges_reject_estus"] = not _estus.try_use()
	_estus.initial_charges = capacity
	await _reset()
	_p.attributes.apply_damage(10.0)
	_estus.try_use()
	await _step(52)
	_checks["healing_clamps_to_max"] = _p.attributes.current_health == 100.0
	await _reset()
	_p.attributes.apply_damage(80.0)
	_estus.try_use()
	await _step(10)
	_p.attributes.apply_damage(1000.0)
	await _step(100)
	_checks["dead_cancels_heal_no_late_use"] = _p.attributes.current_health == 0.0 and _estus.current_charges == 5 and not _estus.try_use() and _p.action_states.current_state == 7
	await _reset()
	_checks["one_handed_initial_shield_available"] = _grip.mode == 0 and _grip.shield_available()
	_button(JOY_BUTTON_Y,true)
	await _step(2)
	_button(JOY_BUTTON_Y,false)
	_checks["y_begins_controlled_grip_change"] = _grip.is_switching() and _grip.mode == 0 and _p.action_states.current_state == 8
	_checks["switching_blocks_attacks_heal_dodge_defense"] = not _p.attack_controller.request_attack(0) and not _p.dodge_controller.try_dodge(Vector2.UP) and not _p.defense_controller.try_parry() and not _estus.try_use()
	await _step(10)
	_checks["two_handed_mode_commits_after_delay"] = _grip.mode == 1 and _grip.is_switching()
	await _step(12)
	_checks["switch_finishes_to_free"] = not _grip.is_switching() and _p.action_states.current_state == 0
	_checks["two_hand_visual_primitive_distinct"] = _grip.second_hand.visible and not _grip.lowered_shield.visible and is_zero_approx(_grip.sword.position.x)
	Input.action_press("block")
	await _step(3)
	_checks["two_handed_disables_shield_and_parry"] = not _p.defense_controller.is_blocking() and not _p.defense_controller.try_parry()
	Input.action_release("block")
	await _place_target()
	_a.visual.rotation.y = PI
	var one_before: Dictionary = _p.attack_controller.light_1.snapshot()
	_checks["two_hand_light_profile_cost"] = _p.attack_controller.request_attack(0) and _p.attack_controller.current_attack_name() == &"TWO_HAND_LIGHT_1" and absf(_p.attributes.current_stamina-78.4) < 0.001
	await _step(25)
	_checks["two_hand_hitbox_applies_increased_damage"] = absf(_a.attributes.current_health-223.0) < 0.001
	_checks["two_hand_no_toggle_during_attack"] = not _grip.try_toggle()
	await _step(3)
	_checks["two_hand_combo_buffers"] = _p.attack_controller.request_attack(0)
	await _step(20)
	_checks["two_hand_second_profile_and_cost"] = _p.attack_controller.current_attack_name() == &"TWO_HAND_LIGHT_2" and absf(_p.attributes.current_stamina-54.4) < 0.001
	await _step(55)
	_checks["source_one_hand_resource_unchanged"] = _p.attack_controller.light_1.snapshot() == one_before
	_p.attributes.restore_stamina(100.0)
	_checks["two_hand_heavy_profile_cost"] = _p.attack_controller.request_attack(2) and _p.attack_controller.current_attack_name() == &"TWO_HAND_HEAVY_1" and absf(_p.attributes.current_stamina-58.0) < 0.001
	await _step(37)
	_measurements["two_hand_heavy_active_elapsed"] = _p.attack_controller.elapsed
	_checks["two_hand_heavy_startup_configured"] = _p.attack_controller.phase == 2 and _p.attack_controller.hitbox.is_active()
	await _step(60)
	_checks["switch_back_to_one_hand"] = _grip.try_toggle()
	await _step(24)
	_checks["one_hand_restores_sword_shield_and_profiles"] = _grip.mode == 0 and _grip.shield_available() and _grip.get_attack_profile(0) == null and absf(_grip.sword.position.x-0.45) < 0.001
	Input.action_press("block")
	await _step(3)
	_checks["shield_works_after_return_to_one_hand"] = _p.defense_controller.is_blocking()
	_checks["switch_from_block_releases_owned_guard"] = _grip.try_toggle() and _p.action_states.current_state == 8
	Input.action_release("block")
	await _step(24)
	_checks["no_stamina_cost_for_grip_toggle"] = _p.attributes.current_stamina >= 58.0
	await _reset()
	_p.dodge_controller.try_dodge(Vector2.UP)
	_checks["grip_and_heal_rejected_during_dodge"] = not _grip.try_toggle() and not _estus.try_use()
	await _reset()
	_p.defense_controller.try_parry()
	_checks["grip_rejected_during_parry"] = not _grip.try_toggle()
	await _reset()
	_grip.try_toggle()
	_p.attributes.apply_damage(1000.0)
	await _step(30)
	_checks["dead_aborts_grip_no_late_commit"] = _p.action_states.current_state == 7 and _grip.mode == 0 and not _grip.try_toggle() and not _grip.is_switching()
	await _reset()
	var lock: Node = tree.current_scene.get_node("LockOnController")
	lock.try_acquire()
	_grip.try_toggle()
	await _step(24)
	_checks["lock_survives_grip_change"] = lock.is_locked()
	_p.attributes.apply_damage(20.0)
	_estus.try_use()
	await _step(91)
	_checks["lock_survives_healing"] = lock.is_locked() and _p.attributes.current_health == 100.0
	_checks["dodge_works_two_handed_after_heal"] = _p.dodge_controller.try_dodge(Vector2.RIGHT)
	await _reset()
	_grip.try_toggle()
	await _step(24)
	await _place_target()
	_checks["two_hand_critical_multiplier_snapshot"] = _critical.try_contextual() == 1
	await _step(28)
	_checks["two_hand_backstab_damage"] = absf(_a.attributes.current_health-82.0) < 0.001
	await _reset()
	_checks["all_new_systems_active"] = _critical.backstab_enabled and _grip.input_enabled and _estus.input_enabled and _p.attack_controller.input_enabled and _p.dodge_controller.input_enabled and _p.defense_controller.input_enabled
	var failed: Array = []
	for key in _checks:
		if not _checks[key]: failed.append(key)
	return {"passed":_checks.size()-failed.size(),"total":_checks.size(),"failed":failed,"checks":_checks,"measurements":_measurements,"physical_devices":Input.get_connected_joypads()}

func _reset() -> void:
	for action in ["block","parry","move_forward","move_backward","move_left","move_right","sprint_dodge","light_attack","heavy_attack","use_item","two_hand_toggle"]:
		Input.action_release(action)
	for button in [JOY_BUTTON_X,JOY_BUTTON_Y,JOY_BUTTON_RIGHT_SHOULDER]: _button(button,false)
	_tree.current_scene.get_node("LockOnController").release_lock(&"test_reset")
	_p.attributes.restore_all()
	_a.attributes.restore_all()
	_critical.backstab_enabled = true
	_p.position = Vector3.ZERO
	_p.velocity = Vector3.ZERO
	_p.visual.rotation = Vector3.ZERO
	_a.position = Vector3(7.5,0,7.5)
	_a.velocity = Vector3.ZERO
	_p.reset_physics_interpolation()
	_a.reset_physics_interpolation()
	var center: Node3D = _tree.current_scene.get_node("Targets/Center")
	var left: Node3D = _tree.current_scene.get_node("Targets/Left")
	var right: Node3D = _tree.current_scene.get_node("Targets/Right")
	center.position = Vector3(0,0,-6)
	left.position = Vector3(-3,0,-5)
	right.position = Vector3(3,0,-5)
	for target in [center,left,right]:
		target.attributes.restore_all()
		target.visual.rotation = Vector3.ZERO
	var rig: Node3D = _tree.current_scene.get_node("CameraRig")
	rig.set_control_mode(0)
	rig.set_orbit_angles(0.0,deg_to_rad(rig.initial_pitch))
	rig.snap_to_target()
	await _step(8)

func _place_target() -> void:
	_a.position = Vector3(0,0,-1.4)
	_a.visual.rotation = Vector3.ZERO
	await _step(3)

func _wall() -> StaticBody3D:
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2,2,0.15)
	collider.shape = box
	wall.add_child(collider)
	_tree.current_scene.add_child(wall)
	wall.position = Vector3(0,1,-0.7)
	return wall

func _step(frames: int) -> void:
	for i in range(frames): await _tree.physics_frame
	await _tree.process_frame

func _button(index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 7
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
