extends RefCounted
## Actual actor/components/AI and physics; synthetic input and technical death fixtures.
var _tree: SceneTree
var _p: CharacterBody3D
var _e: CharacterBody3D
var _m: Node
var _f: Node3D
var _rig: Node3D
var _lock: Node
var _screen: Control
var _checks: Dictionary = {}
var _measurements: Dictionary = {}
var _death_delay: float
var _screen_duration: float

func start(tree: SceneTree) -> void:
	tree.root.set_meta("phase_3b_result",{"status":"running","checks":_checks})
	var result := await run(tree)
	result["status"] = "complete"
	tree.root.set_meta("phase_3b_result",result)

func run(tree: SceneTree) -> Dictionary:
	_tree = tree
	var s := tree.current_scene
	_p = s.get_node("Player")
	_e = s.get_node("Soldier")
	_m = s.get_node("CheckpointManager")
	_f = s.get_node("Bonfire")
	_rig = s.get_node("CameraRig")
	_lock = s.get_node("LockOnController")
	_screen = s.get_node("DeathLayer/DeathScreen")
	_death_delay = _m.death_delay
	_screen_duration = _m.death_screen_duration
	var spawn_forward: Vector3 = -_f.get_spawn_transform().basis.z
	var spawn_yaw: float = atan2(-spawn_forward.x,-spawn_forward.z)
	_checks["initial_visual_and_camera_face_spawn_direction"] = absf(angle_difference(_p.visual.global_rotation.y,spawn_yaw)) < 0.001 and absf(angle_difference(_rig.get_orbit_angles().x,spawn_yaw)) < 0.001
	await _reset()
	_checks["bonfire_registered_once"] = _m.get_bonfire_count() == 1 and _m.register_bonfire(_f) and _m.get_bonfire_count() == 1
	_checks["initial_fire_unlit_and_fallback_spawn"] = not _f.lit and _m.active_id.is_empty() and _m.get_respawn_transform().origin.distance_to(_f.get_spawn_transform().origin) < 0.001
	_checks["starts_near_interaction_area"] = _f.contains_player(_p) and _m.can_interact()
	_p.attributes.apply_damage(1000.0)
	await _step(25)
	_checks["death_before_activation_uses_initial_spawn"] = _p.attributes.current_health == 100.0 and _p.position.distance_to(_f.get_spawn_transform().origin) < 0.01 and _m.active_id.is_empty() and not _f.lit
	var duplicate: Node3D = load("res://scenes/props/bonfire.tscn").instantiate()
	duplicate.bonfire_id = _f.bonfire_id
	s.add_child(duplicate)
	_checks["duplicate_checkpoint_id_rejected"] = not _m.register_bonfire(duplicate) and _m.get_bonfire_count() == 1
	duplicate.queue_free()
	await _step(2)
	var rests: Array = []
	var on_rest := func(id: StringName) -> void: rests.append(id)
	_m.rested.connect(on_rest)
	_p.attributes.apply_damage(80.0)
	_p.estus_controller.try_use()
	await _step(91)
	_p.attributes.apply_damage(30.0)
	_p.attributes.consume_stamina(40.0)
	_p.grip_controller.try_toggle()
	await _step(24)
	_e.hurtbox.receive_hit(_p,&"player",1000.0,501)
	var enemy_id: int = _e.get_instance_id()
	_key(KEY_F,true)
	await _step(4)
	_checks["interact_activates_checkpoint"] = _f.lit and _m.active_id == &"arena_bonfire" and _m.get_active_bonfire() == _f
	_checks["rest_restores_health_stamina"] = _p.attributes.current_health == 100.0 and _p.attributes.current_stamina == 100.0
	_checks["rest_restores_estus_and_one_handed"] = _p.estus_controller.current_charges == 5 and _p.grip_controller.mode == 0
	_checks["checkpoint_spawn_registered"] = _m.get_respawn_transform().origin.distance_to(_f.respawn_point.global_position) < 0.001
	_checks["rest_resurrects_same_enemy_instance"] = _e.get_instance_id() == enemy_id and _e.attributes.current_health == 180.0 and _e.brain.state == 0
	await _step(30)
	_checks["held_interact_not_repeated"] = rests.size() == 1
	_key(KEY_F,false)
	await _step(3)
	_checks["release_restores_control"] = not _p.checkpoint_input_blocked and _p.can_move()
	_p.position = Vector3(-2,0,1)
	await _step(3)
	_checks["outside_area_rejected"] = not _f.contains_player(_p) and not _m.rest_at(_f) and not _m.activate_bonfire(_f)
	await _reset()
	_p.attack_controller.request_attack(0)
	_checks["busy_interaction_rejected"] = not _m.rest_at(_f)
	await _reset()
	var visibility: Array = []
	var hidden_while_dead: Array = []
	var on_visibility := func(value: bool) -> void:
		visibility.append("show" if value else "hide")
		if not value: hidden_while_dead.append(_p.action_states.current_state == 7 and _p.attributes.current_health == 0.0)
	var on_respawn := func(_id: StringName) -> void: visibility.append("respawn")
	_m.death_visibility_changed.connect(on_visibility)
	_m.respawned.connect(on_respawn)
	_p.position = Vector3(4,0,1)
	_p.attributes.apply_damage(1000.0)
	_checks["death_enters_dead_and_delay"] = _p.action_states.current_state == 7 and _m.phase == 1 and _p.attributes.current_health == 0.0 and not _screen.visible
	_checks["dead_interaction_rejected"] = not _m.rest_at(_f) and not _m.activate_bonfire(_f)
	_checks["dead_actions_rejected"] = not _p.can_move() and not _p.can_lock_on() and not _p.attack_controller.request_attack(0) and not _p.dodge_controller.try_dodge(Vector2.UP) and not _p.defense_controller.try_parry() and not _p.estus_controller.try_use() and not _p.grip_controller.try_toggle()
	var camera_position: Vector3 = _rig.position
	var angles: Vector2 = _rig.get_orbit_angles()
	Input.action_press("camera_right")
	Input.action_press("move_forward")
	await _step(4)
	_checks["camera_frozen_during_death"] = _rig.position.distance_to(camera_position) < 0.001 and _rig.get_orbit_angles().distance_to(angles) < 0.001 and _rig.get_follow_target() == null
	_checks["no_instant_restore"] = _p.attributes.current_health == 0.0 and not _screen.visible
	Input.action_release("camera_right")
	Input.action_release("move_forward")
	await _step(2)
	_checks["you_died_shown_after_delay"] = _screen.visible and _screen.get_node("Message").text == "YOU DIED" and _m.phase == 2
	_checks["physics_not_paused"] = not tree.paused and _e.brain.is_physics_processing()
	await _step(11)
	_checks["screen_holds_configured_interval"] = _screen.visible and _p.attributes.current_health == 0.0
	await _step(1)
	_checks["screen_hides_before_revival"] = not _screen.visible and _p.attributes.current_health == 0.0 and _m.phase == 3
	await _step(1)
	_checks["respawn_position_and_free"] = _p.position.distance_to(_m.get_respawn_transform().origin) < 0.01 and _p.action_states.current_state == 0
	_checks["respawn_vitals_estus_and_mode"] = _p.attributes.current_health == 100.0 and _p.attributes.current_stamina == 100.0 and _p.estus_controller.current_charges == 5 and _p.grip_controller.mode == 0
	_checks["camera_restored"] = _rig.get_follow_target() == _p and _rig.control_mode == 0 and _p.movement_camera.current
	_checks["respawn_visual_and_camera_face_spawn_direction"] = absf(angle_difference(_p.visual.global_rotation.y,spawn_yaw)) < 0.001 and absf(angle_difference(_rig.get_orbit_angles().x,spawn_yaw)) < 0.001
	_checks["overlay_control_signal_order"] = visibility == ["show","hide","respawn"] and hidden_while_dead == [true]
	_m.death_visibility_changed.disconnect(on_visibility)
	_m.respawned.disconnect(on_respawn)
	await _reset()
	_p.attack_controller.request_attack(0)
	await _step(28)
	_p.attack_controller.request_attack(0)
	_checks["attack_buffer_fixture_valid"] = _p.attack_controller.has_buffered_attack()
	_key(KEY_J,true)
	_key(KEY_F,true)
	_p.attributes.apply_damage(1000.0)
	_checks["dead_cancels_attack_hitbox_and_buffer"] = not _p.attack_controller.is_active() and not _p.attack_controller.hitbox.is_active() and not _p.attack_controller.has_buffered_attack()
	await _step(25)
	_checks["held_inputs_blocked_after_respawn"] = _p.attributes.current_health == 100.0 and _p.checkpoint_input_blocked and not _p.can_move() and not _p.attack_controller.is_active()
	_checks["direct_api_also_rejected_while_guarded"] = not _p.attack_controller.request_attack(0) and not _p.grip_controller.try_toggle() and not _p.defense_controller.try_parry()
	_key(KEY_J,false)
	_key(KEY_F,false)
	await _step(55)
	_checks["no_old_attack_or_combo_after_release"] = not _p.checkpoint_input_blocked and not _p.attack_controller.is_active() and not _p.attack_controller.has_buffered_attack()
	_key(KEY_J,true)
	await _step(3)
	_checks["fresh_attack_works_after_respawn"] = _p.attack_controller.is_active()
	_key(KEY_J,false)
	await _reset()
	_p.dodge_controller.try_dodge(Vector2.RIGHT)
	_p.attributes.apply_damage(1000.0)
	_checks["death_cancels_dodge_iframes"] = not _p.dodge_controller.is_active() and not _p.is_invulnerable() and not _p.get_node("CollisionShape3D").disabled
	await _step(25)
	_checks["dodge_not_replayed_on_respawn"] = not _p.dodge_controller.is_active() and _p.action_states.current_state == 0
	await _reset()
	Input.action_press("block")
	await _step(3)
	_checks["block_death_fixture_valid"] = _p.defense_controller.is_blocking()
	_p.attributes.apply_damage(1000.0)
	_checks["death_cancels_block"] = _p.defense_controller.mode == 0 and not _p.defense_controller.shield_mesh.visible
	await _step(25)
	_checks["held_block_not_raised_after_respawn"] = _p.checkpoint_input_blocked and not _p.defense_controller.is_blocking()
	Input.action_release("block")
	await _step(3)
	await _reset()
	_p.defense_controller.try_parry()
	_p.attributes.apply_damage(1000.0)
	_checks["death_cancels_parry"] = _p.defense_controller.mode == 0 and _p.defense_controller.parry_phase == 0
	await _reset()
	_p.attributes.apply_damage(50.0)
	_p.estus_controller.try_use()
	await _step(10)
	_p.attributes.apply_damage(1000.0)
	_checks["death_cancels_estus"] = not _p.estus_controller.is_active() and not _p.estus_controller.flask.visible
	await _step(70)
	_checks["estus_has_no_delayed_consumption_after_respawn"] = _p.attributes.current_health == 100.0 and _p.estus_controller.current_charges == 5
	await _reset()
	_p.position = Vector3.ZERO
	_p.visual.rotation = Vector3.ZERO
	_rig.snap_to_target()
	_e.position = Vector3(0,0,-1.4)
	_e.visual.rotation.y = 0.0
	await _step(3)
	_checks["lock_fixture_valid"] = _lock.try_acquire()
	_checks["critical_fixture_valid"] = _p.attack_controller.request_attack(0) and _p.riposte_controller.is_active() and _e.critical_vulnerability.is_reserved()
	_p.attributes.apply_damage(1000.0)
	_checks["death_releases_lock_and_critical_reservation"] = not _lock.is_locked() and not _p.riposte_controller.is_active() and not _e.critical_vulnerability.is_reserved()
	await _step(25)
	_checks["normal_enemy_fully_restored"] = _e.attributes.current_health == 180.0 and _e.position.distance_to(Vector3(0,0,-3.8)) < 0.01 and _e.action_states.current_state == 0
	_checks["enemy_brain_memory_and_stagger_reset"] = _e.brain.state == 0 and not _e.brain._acquired and _e.brain._stagger_remaining == 0.0 and _e.brain.is_physics_processing()
	_checks["enemy_hit_hurt_and_lock_restored"] = not _e.attack_controller.hitbox.is_active() and _e.hurtbox.enabled and _e.lock_target.is_available()
	await _reset()
	_e.hurtbox.receive_hit(_p,&"player",1000.0,502)
	var rest_results := true
	for cycle in range(6):
		rest_results = _m.rest_at(_f) and rest_results
		await _step(3)
	_checks["multiple_rests_no_enemy_duplicates"] = rest_results and _e.get_instance_id() == enemy_id and tree.get_nodes_in_group("checkpoint_enemies").size() == 1 and _e.attributes.current_health == 180.0
	var rest_count: int = rests.size()
	_pad_a(true)
	await _step(3)
	_checks["normalized_pad_interaction_works"] = rests.size() == rest_count+1
	_pad_a(false)
	await _step(3)
	await _reset()
	_e.entity_kind = 1
	_e.hurtbox.receive_hit(_p,&"player",1000.0,503)
	_checks["boss_simulation_records_session_defeat"] = _e.boss_defeated_this_session and _e.attributes.current_health == 0.0
	_m.rest_at(_f)
	await _step(3)
	_checks["defeated_boss_simulation_not_respawned"] = _e.attributes.current_health == 0.0 and _e.action_states.current_state == 7 and not _e.lock_target.is_available()
	_m.rest_at(_f)
	await _step(3)
	_checks["boss_remains_dead_across_rests"] = _e.attributes.current_health == 0.0
	_e.entity_kind = 0
	_m.rest_at(_f)
	await _step(3)
	_checks["normal_type_restores_same_instance_again"] = _e.attributes.current_health == 180.0 and _e.get_instance_id() == enemy_id
	await _reset()
	# Real autonomous combat: lethal soldier contact drives the entire lifecycle.
	_p.position = Vector3.ZERO
	_p.attributes.apply_damage(80.0)
	_e.position = Vector3(0,0,-1.65)
	_e.visual.rotation.y = PI
	_e.brain.decision_remaining = 0.0
	var combat_died := false
	for frame in range(150):
		await _step(1)
		if _p.action_states.current_state == 7:
			combat_died = true
			break
	_checks["real_ai_contact_kills_player"] = combat_died and _e.attack_controller.swing_id > 0
	await _step(25)
	_checks["integrated_combat_death_respawn"] = _p.attributes.current_health == 100.0 and _p.position.distance_to(_f.get_spawn_transform().origin) < 0.01 and _e.attributes.current_health == 180.0 and _e.brain.state == 0
	_checks["all_offensive_hitboxes_off_after_restore"] = not _e.attack_controller.hitbox.is_active() and not _p.attack_controller.hitbox.is_active() and not s.get_node("DefenseTestAttacker").attack_controller.hitbox.is_active()
	await _reset()
	var test_controller: Node = s.get_node("DefenseTestController")
	test_controller.execute_test(0)
	await _step(20)
	_m.rest_at(_f)
	await _step(3)
	_checks["technical_attacker_also_quiesced_on_rest"] = not s.get_node("DefenseTestAttacker").attack_controller.is_active() and s.get_node("DefenseTestAttacker").position.distance_to(Vector3(7.5,0,7.5)) < 0.01
	var cycles_ok := true
	for cycle in range(3):
		await _reset()
		_p.position = Vector3(4,0,1)
		_p.attributes.apply_damage(1000.0)
		await _step(25)
		cycles_ok = cycles_ok and _p.attributes.current_health == 100.0 and _p.action_states.current_state == 0 and _m.phase == 0 and not _screen.visible and _p.position.distance_to(_f.get_spawn_transform().origin) < 0.01
	_checks["multiple_death_cycles"] = cycles_ok
	await _reset()
	_p.attributes.apply_damage(1000.0)
	await _step(8)
	_p.attributes.restore_all()
	await _step(30)
	_checks["technical_restore_cancels_obsolete_death_sequence"] = _m.phase == 0 and not _screen.visible and _p.attributes.current_health == 100.0 and _rig.control_mode == 0
	_checks["all_real_components_enabled"] = _m.automatic_respawn_enabled and _m.interaction_enabled and _e.brain.enabled and _p.attack_controller.input_enabled and _p.defense_controller.input_enabled and _p.dodge_controller.input_enabled
	_m.rested.disconnect(on_rest)
	_m.death_delay = _death_delay
	_m.death_screen_duration = _screen_duration
	await _reset(false)
	var failed: Array = []
	for key in _checks:
		if not _checks[key]: failed.append(key)
	return {"passed":_checks.size()-failed.size(),"total":_checks.size(),"failed":failed,"checks":_checks,"measurements":_measurements,"physical_devices":Input.get_connected_joypads(),"timing_fixture":{"death_delay":0.1,"death_screen":0.2}}

func _reset(short_timing: bool = true) -> void:
	for action in _p.CHECKPOINT_ACTIONS + ["move_left","move_right","move_forward","move_backward","camera_right"]:
		Input.action_release(action)
	_key(KEY_F,false)
	_key(KEY_J,false)
	_m.cancel_pending_respawn()
	_m.automatic_respawn_enabled = true
	_m.interaction_enabled = true
	if short_timing:
		_m.death_delay = 0.1
		_m.death_screen_duration = 0.2
	_lock.release_lock(&"test_reset")
	_p.checkpoint_input_blocked = false
	_p.attributes.restore_all()
	_p.position = _f.get_spawn_transform().origin
	_p.visual.rotation = Vector3.ZERO
	_p.velocity = Vector3.ZERO
	_e.entity_kind = 0
	_e.restore_at_checkpoint()
	_rig.set_follow_target(_p,false)
	_rig.set_control_mode(0)
	_rig.set_orbit_angles(0.0,deg_to_rad(_rig.initial_pitch))
	_rig.snap_to_target()
	_p.reset_physics_interpolation()
	await _step(4)

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _step(frames: int) -> void:
	for frame in range(frames): await _tree.physics_frame
	await _tree.process_frame

func _pad_a(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 7
	event.button_index = JOY_BUTTON_A
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
