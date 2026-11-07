extends RefCounted
var _tree: SceneTree
var _p: CharacterBody3D
var _b: CharacterBody3D
var _ai: Node
var _m: Node
var _hud: Control
var _patterns: Array[Resource] = []
var _checks: Dictionary = {}
var _measures: Dictionary = {}
var _settings: Dictionary = {}

func start(tree: SceneTree) -> void:
	tree.root.set_meta("phase_3c_result",{"status":"running","checks":_checks})
	var result := await run(tree)
	result["status"] = "complete"
	tree.root.set_meta("phase_3c_result",result)
	var output := FileAccess.open("res://tests/phase_3c_results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))

func run(tree: SceneTree) -> Dictionary:
	_tree = tree
	var scene := tree.current_scene
	_p = scene.get_node("Player")
	_b = scene.get_node("Boss")
	_ai = _b.brain
	_m = scene.get_node("CheckpointManager")
	_hud = scene.get_node("HUD/BossHUD")
	_patterns.assign(_ai.patterns)
	for key in ["intro_duration","decision_time","decision_variation","reposition_duration"]:
		_settings[key] = _ai.get(key)
	_checks["initial_boss_type_health_id"] = _b.entity_kind == 1 and _b.attributes.current_health == 600.0 and _ai.state == 0 and _b.lock_target.target_id == &"ruins_guardian"
	_checks["shared_attack_damage_and_physical_nodes"] = _b.has_node("CombatPivot/Hitbox") and _b.has_node("Hurtbox") and _b.has_node("SpawnPoint") and _b.has_node("Visual/Body") and _b.attack_controller.get_script() == _p.attack_controller.get_script()
	_checks["hud_initially_hidden"] = not _hud.panel.visible and not _hud.victory_message.visible
	_p.position = Vector3(0,0,7)
	await _step(4)
	_checks["entry_starts_real_encounter_intro"] = _ai.encounter_active and _ai.state == 1 and _hud.panel.visible
	_checks["intro_rejects_attack_requests"] = not _ai.start_pattern(&"HORIZONTAL_SLASH")
	await _step(360)
	_checks["autonomous_approach_and_pattern"] = _b.position.z > -3.0 and _b.attack_controller.swing_id > 0 and _ai.current_pattern != &"NONE"
	await _reset()
	_ai.enabled = false # Component-rule probes only; integrated cases below re-enable AI.
	var choices: Array = []
	for pattern in _ai.eligible_patterns(): choices.append(pattern.pattern_id)
	_checks["phase_one_has_three_patterns_no_area"] = choices.size() == 3 and not choices.has(&"RUIN_BURST")
	_ai._rng.seed = 3301
	var sequence: Array = []
	for i in range(12): sequence.append(_ai.choose_pattern().pattern_id)
	_ai._rng.seed = 3301
	var repeated: Array = []
	for i in range(12): repeated.append(_ai.choose_pattern().pattern_id)
	_checks["weighted_selection_seed_reproducible"] = sequence == repeated
	_measures["seeded_pattern_samples"] = sequence
	_p.position.x = 5.0
	_checks["selection_rejects_outside_range"] = _ai.eligible_patterns().is_empty()
	_p.position = Vector3(0,0,-5.4)
	_checks["selection_rejects_wrong_angle"] = _ai.eligible_patterns().is_empty()
	_p.position = Vector3(0,0,-0.6)
	var wall := _wall()
	await _step(2)
	_checks["selection_rejects_solid_obstruction"] = _ai.eligible_patterns().is_empty()
	wall.queue_free()
	await _step(2)
	_ai.enabled = true
	var phases: Array = []
	var on_phase := func(phase: int) -> void: phases.append([phase,_b.attack_controller.elapsed])
	_b.attack_controller.phase_changed.connect(on_phase)
	_checks["horizontal_starts"] = _ai.start_pattern(&"HORIZONTAL_SLASH")
	_checks["startup_has_no_offense"] = not _b.attack_controller.hitbox.is_active() and _p.attributes.current_health == 100.0
	await _step(42)
	_checks["horizontal_active_damage_and_wide_shape"] = _b.attack_controller.phase == 2 and _p.attributes.current_health == 76.0 and _b.attack_controller.hitbox.collider.shape.size.x == 5.0
	for i in range(5): _b.attack_controller.hitbox.sample_hits()
	_checks["one_damage_per_window"] = _p.attributes.current_health == 76.0 and _b.attack_controller.hitbox.hit_count == 1
	var committed: Vector3 = _b.attack_controller.get_attack_direction()
	_p.position.x = 0.2
	await _step(8)
	_checks["active_orientation_committed"] = _b.attack_controller.get_attack_direction().dot(committed) > 0.999
	await _step(5)
	_checks["recovery_hitbox_disabled"] = _b.attack_controller.phase == 3 and not _b.attack_controller.hitbox.is_active()
	await _step(48)
	_checks["slash_phase_clock"] = phases.size() == 4 and absf(phases[1][1]-0.7) < 0.017 and absf(phases[2][1]-0.9) < 0.017 and absf(phases[3][1]-1.7) < 0.017
	_measures["slash_phase_events"] = phases.duplicate(true)
	_b.attack_controller.phase_changed.disconnect(on_phase)
	_ai.decision_remaining = 0.0
	_checks["recent_pattern_prevents_repeat"] = not _ai.start_pattern(&"HORIZONTAL_SLASH")
	_ai._history.clear()
	_checks["cooldown_independently_prevents_repeat"] = not _ai.start_pattern(&"HORIZONTAL_SLASH")
	await _reset()
	_ai.start_pattern(&"VERTICAL_SLAM")
	await _step(62)
	_checks["slam_long_startup"] = _b.attack_controller.phase == 1 and _p.attributes.current_health == 100.0
	await _step(2)
	_checks["slam_hits_and_stamina_damage"] = _p.attributes.current_health == 64.0 and _b.attack_controller._data.stamina_damage == 90.0
	await _step(16)
	_checks["slam_long_recovery"] = _b.attack_controller.phase == 3 and _b.attack_controller._data.recovery == 1.15
	await _reset()
	var first_id: int = _b.attack_controller.swing_id
	_ai.start_pattern(&"TWO_HIT_COMBO")
	await _step(33)
	_checks["combo_first_impact"] = _p.attributes.current_health == 80.0
	await _step(30)
	_checks["combo_second_separate_startup"] = _p.attributes.current_health == 80.0 and _b.attack_controller.phase == 1 and _b.attack_controller.current_attack_name() == &"COMBO_SECOND"
	await _step(30)
	_checks["combo_second_impact_separate_window"] = _p.attributes.current_health == 54.0 and _b.attack_controller.swing_id == first_id+2
	await _step(65)
	_checks["combo_has_exactly_two_swings"] = _b.attack_controller.swing_id == first_id+2 and not _b.attack_controller.is_active()
	await _reset()
	Input.action_press("block")
	_ai.start_pattern(&"HORIZONTAL_SLASH")
	await _step(44)
	_checks["compatible_boss_attack_blocks"] = _p.attributes.current_health == 100.0 and _p.defense_controller.last_event == &"blocked" and _p.attributes.current_stamina == 86.0
	await _reset()
	_p.attributes.consume_stamina(80.0)
	Input.action_press("block")
	_ai.start_pattern(&"VERTICAL_SLAM")
	await _step(65)
	_checks["boss_slam_guard_break"] = _p.action_states.current_state == 6 and _p.attributes.current_stamina == 0.0 and _p.attributes.current_health == 64.0
	await _reset()
	_ai.start_pattern(&"HORIZONTAL_SLASH")
	await _step(33)
	_p.defense_controller.try_parry()
	await _step(11)
	_checks["default_attack_rejects_parry_by_contact"] = _p.attributes.current_health == 76.0 and _p.defense_controller.last_event != &"parry_success" and not _b.critical_vulnerability.is_available()
	_checks["default_riposte_policy_off"] = not _b.critical_vulnerability.riposte_allowed
	await _reset()
	_p.position = Vector3(0,0,-4.4)
	_p.visual.rotation.y = PI
	_checks["default_boss_backstab_rejected"] = _p.riposte_controller.try_contextual() == 0 and not _b.critical_vulnerability.can_backstab()
	_b.critical_vulnerability.backstab_allowed = true
	_checks["backstab_policy_can_be_enabled_independently"] = _p.riposte_controller.try_contextual() == 1 and _p.attack_controller.current_attack_name() == &"BACKSTAB"
	await _reset()
	# Explicit future opt-in: both attack metadata and actor policy must agree.
	var custom: Resource = load("res://scripts/bosses/boss_pattern.gd").new()
	var parry_attack: Resource = _patterns[0].attacks[0].duplicate(true)
	parry_attack.parryable = true
	custom.pattern_id = &"TEST_OPT_IN"
	custom.attacks.assign([parry_attack])
	_ai.patterns.assign([custom])
	_b.critical_vulnerability.parry_allowed = true
	_b.critical_vulnerability.riposte_allowed = true
	_ai.start_pattern(&"TEST_OPT_IN")
	await _step(33)
	_p.defense_controller.try_parry()
	await _step(11)
	_checks["parry_and_riposte_policy_future_opt_in"] = _p.defense_controller.last_event == &"parry_success" and _b.critical_vulnerability.is_available()
	await _reset()
	_ai.start_pattern(&"HORIZONTAL_SLASH")
	_b.hurtbox.receive_hit(_p,&"player",60.0,1001)
	_checks["startup_stagger_rule"] = not _b.attack_controller.is_active() and _b.action_states.current_state == 6 and _ai.state == 7
	await _step(50)
	_checks["stagger_recovers_owned_state"] = _b.action_states.current_state == 0
	await _reset()
	_ai.start_pattern(&"HORIZONTAL_SLASH")
	await _step(42)
	_b.hurtbox.receive_hit(_p,&"player",60.0,1002)
	_checks["active_armor_keeps_attack_commitment"] = _b.attack_controller.is_active() and _b.attack_controller.phase == 2
	await _step(14)
	_b.hurtbox.receive_hit(_p,&"player",60.0,1003)
	_checks["recovery_armor_keeps_commitment"] = _b.attack_controller.is_active() and _b.attack_controller.phase == 3
	await _reset()
	_p.attack_controller.request_attack(0)
	await _step(16)
	_checks["player_normal_hitbox_damages_boss"] = _b.attributes.current_health == 580.0 and _hud.bar.value == 580.0
	await _reset()
	_ai.reposition_duration = 0.6
	_ai.start_pattern(&"HORIZONTAL_SLASH")
	await _step(103)
	var old_position: Vector3 = _b.position
	await _step(25)
	_checks["post_attack_reposition_moves"] = _b.position.distance_to(old_position) > 0.05 and _ai.state == 3
	await _reset()
	_ai.start_pattern(&"HORIZONTAL_SLASH")
	await _step(15)
	_b.attributes.apply_damage(300.0)
	_checks["threshold_queues_not_cancels_attack"] = _b.attack_controller.is_active() and _ai._pending_transition and not _ai.phase_two
	await _step(90)
	_checks["phase_transition_after_committed_attack"] = _ai.state == 6 and _ai.transition_marker.visible and not _b.attack_controller.hitbox.is_active() and _b.attributes.current_health == 300.0
	_checks["transition_blocks_new_offense"] = not _ai.start_pattern(&"VERTICAL_SLAM") and _hud.phase_label.text == "TRANSICIÓN A FASE 2"
	await _step(85)
	_checks["phase_two_once_without_heal"] = _ai.phase_two and _ai.transition_count == 1 and _b.attributes.current_health == 300.0
	_b.attributes.apply_damage(10.0)
	await _step(10)
	_checks["threshold_does_not_retrigger"] = _ai.transition_count == 1 and _b.attributes.current_health == 290.0
	_ai.decision_remaining = 0.0
	_checks["phase_two_legal_pattern_starts"] = _ai.start_pattern(&"VERTICAL_SLAM")
	_checks["phase_two_recovery_snapshot_reduced"] = absf(_b.attack_controller._data.recovery-0.92) < 0.001 and _patterns[1].attacks[0].recovery == 1.15
	await _reset()
	_ai.start_pattern(&"TWO_HIT_COMBO")
	await _step(15)
	_b.attributes.apply_damage(300.0)
	await _step(80)
	_checks["transition_preserves_second_committed_combo_hit"] = _b.attack_controller.current_attack_name() == &"COMBO_SECOND" and not _ai.phase_two
	await _step(62)
	_checks["transition_begins_after_whole_combo"] = _ai.state == 6
	await _reset()
	await _phase_two()
	_ai.decision_time = 0.85
	_ai.decision_variation = 0.0
	_checks["phase_two_decision_more_aggressive"] = absf(_ai._next_wait()-0.595) < 0.001
	_ai.decision_time = 10.0
	_ai.decision_remaining = 0.0
	_checks["area_only_phase_two_and_starts"] = _ai.start_pattern(&"RUIN_BURST")
	_checks["area_warning_precedes_damage"] = _ai.warning_mesh.visible and not _b.attack_controller.hitbox.is_active() and _p.attributes.current_health == 100.0
	await _step(80)
	_checks["area_full_preparation_no_damage"] = _ai.warning_mesh.visible and _p.attributes.current_health == 100.0 and _b.attack_controller.phase == 1
	await _step(2)
	_checks["area_active_and_damage_once"] = _b.attack_controller.phase == 2 and _p.attributes.current_health == 60.0 and _b.attack_controller.hitbox.collider.shape.size == Vector3(6,2.5,6)
	await _step(8)
	_checks["area_no_duplicate_damage"] = _p.attributes.current_health == 60.0
	await _step(6)
	_checks["area_warning_off_in_recovery"] = not _ai.warning_mesh.visible and not _b.attack_controller.hitbox.is_active()
	await _reset()
	await _phase_two()
	_ai.start_pattern(&"RUIN_BURST")
	await _step(78)
	_p.dodge_controller.try_dodge(Vector2.UP)
	await _step(15)
	_checks["area_roll_timing_evades_contact"] = _p.attributes.current_health == 100.0 and _p.is_invulnerable() and _p.position.distance_to(_b.position) < 1.1
	await _reset()
	await _phase_two()
	_ai.start_pattern(&"RUIN_BURST")
	Input.action_press("move_backward")
	await _step(94)
	Input.action_release("move_backward")
	_checks["area_can_be_escaped_by_walking"] = _p.attributes.current_health == 100.0 and _p.position.z > 0.5
	await _reset()
	var lock: Node = scene.get_node("LockOnController")
	_checks["boss_lockable"] = lock.try_acquire() and lock.current_target == _b.lock_target
	await _phase_two()
	_ai.start_pattern(&"RUIN_BURST")
	_p.attributes.apply_damage(80.0)
	await _step(82)
	_checks["boss_area_real_contact_kills_player"] = _p.action_states.current_state == 7 and _p.attributes.current_health == 0.0
	await _step(170)
	_checks["checkpoint_retries_full_health_phase_one"] = _p.attributes.current_health == 100.0 and _p.position.distance_to(scene.get_node("Bonfire").get_spawn_transform().origin) < 0.01 and _b.attributes.current_health == 600.0 and not _ai.phase_two and _ai.transition_count == 0
	_checks["retry_clears_hitboxes_transitions_hud"] = not _b.attack_controller.hitbox.is_active() and not _ai.warning_mesh.visible and not _ai.transition_marker.visible and not _hud.panel.visible and not _hud.victory_message.visible and _ai.state == 0
	await _reset()
	_ai.start_pattern(&"HORIZONTAL_SLASH")
	_b.position.x = 9.5
	await _step(2)
	_checks["arena_boundary_resets_safely"] = _b.position.distance_to(Vector3(0,0,-3)) < 0.01 and not _ai.encounter_active and not _b.attack_controller.is_active()
	await _reset()
	lock.try_acquire()
	_ai.start_pattern(&"HORIZONTAL_SLASH")
	await _step(42)
	_b.hurtbox.receive_hit(_p,&"player",10000.0,1004)
	_checks["death_has_absolute_priority"] = _b.action_states.current_state == 7 and _ai.state == 8 and _b.boss_defeated_this_session
	_checks["death_cancels_attacks_ai_and_lock_target"] = not _b.attack_controller.is_active() and not _b.attack_controller.hitbox.is_active() and not _ai.is_physics_processing() and not _b.lock_target.is_available()
	await _step(3)
	_checks["death_releases_player_lock"] = not lock.is_locked()
	_checks["victory_and_hud_end"] = _hud.victory_message.visible and _hud.victory_message.text == "VICTORIA" and not _hud.panel.visible
	var id: int = _b.get_instance_id()
	_p.position = scene.get_node("Bonfire").get_spawn_transform().origin
	await _step(4)
	_checks["bonfire_rest_after_victory"] = _m.rest_at(scene.get_node("Bonfire"))
	await _step(4)
	_checks["defeated_boss_never_respawns_on_rest"] = _b.attributes.current_health == 0.0 and _ai.state == 8 and _b.boss_defeated_this_session and _b.get_instance_id() == id
	_m.rest_at(scene.get_node("Bonfire"))
	await _step(4)
	_checks["repeated_rest_no_boss_duplicates"] = _b.attributes.current_health == 0.0 and tree.get_nodes_in_group("checkpoint_enemies").size() == 1 and _hud.victory_message.visible
	_checks["main_scene_configuration_preserved"] = ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/levels/test_arena.tscn"
	_checks["session_defeat_recorded_by_stable_id"] = load("res://scripts/systems/session_progress.gd").boss_is_defeated(tree, &"ruins_guardian")
	tree.change_scene_to_file("res://scenes/levels/boss_arena.tscn")
	await tree.scene_changed
	await _step(5)
	var reloaded: Node = tree.current_scene.get_node("Boss")
	_checks["scene_reload_preserves_defeat_in_same_session"] = reloaded.attributes.current_health == 0.0 and reloaded.brain.state == 8 and not reloaded.lock_target.is_available() and not reloaded.attack_controller.hitbox.is_active() and tree.get_nodes_in_group("checkpoint_enemies").size() == 1 and tree.current_scene.get_node("HUD/BossHUD").victory_message.visible
	var failed: Array = []
	for key in _checks:
		if not _checks[key]: failed.append(key)
	# End the test fixture without manufacturing a gameplay resurrection of a won boss.
	return {"passed":_checks.size()-failed.size(),"total":_checks.size(),"failed":failed,"checks":_checks,"measurements":_measures,"physical_devices":Input.get_connected_joypads()}

func _reset() -> void:
	for action in _p.CHECKPOINT_ACTIONS + ["move_left","move_right","move_forward","move_backward"]: Input.action_release(action)
	_m.cancel_pending_respawn()
	_p.checkpoint_input_blocked = false
	_p.attributes.restore_all()
	_tree.current_scene.get_node("LockOnController").release_lock(&"test_fixture")
	_p.position = Vector3(0,0,-0.6)
	_p.velocity = Vector3.ZERO
	_p.visual.rotation = Vector3.ZERO
	_b.boss_defeated_this_session = false # Technical isolation between independent cases, never gameplay.
	_b.attributes.restore_all()
	_b.restore_at_checkpoint()
	_ai.patterns.assign(_patterns)
	_ai.enabled = true
	_ai._restart_delay = 0.0
	_ai.intro_duration = 0.1
	_ai.decision_time = 10.0
	_ai.decision_variation = 0.0
	_ai.reposition_duration = 0.0
	_b.critical_vulnerability.parry_allowed = false
	_b.critical_vulnerability.riposte_allowed = false
	_b.critical_vulnerability.backstab_allowed = false
	var rig: Node3D = _tree.current_scene.get_node("CameraRig")
	rig.set_follow_target(_p,false)
	rig.set_control_mode(0)
	rig.set_orbit_angles(0.0,deg_to_rad(rig.initial_pitch))
	rig.snap_to_target()
	_p.reset_physics_interpolation()
	await _step(3)
	_ai.start_encounter()
	_ai.decision_remaining = 100.0
	await _step(7)
	_ai.decision_remaining = 0.0

func _phase_two() -> void:
	_b.attributes.apply_damage(300.0)
	await _step(86)
	_ai.decision_remaining = 0.0

func _step(frames: int) -> void:
	for i in range(frames): await _tree.physics_frame
	await _tree.process_frame

func _wall() -> StaticBody3D:
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4,3,0.15)
	collider.shape = shape
	wall.add_child(collider)
	_tree.current_scene.add_child(wall)
	wall.position = Vector3(0,1.5,-1.8)
	return wall
