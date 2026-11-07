extends RefCounted
## Component rules and integrated autonomous physics; normalized inputs are simulated.
var _tree: SceneTree
var _p: CharacterBody3D
var _e: CharacterBody3D
var _ai: Node
var _checks: Dictionary = {}
var _unit: Dictionary = {}
var _measurements: Dictionary = {}
var _settings: Dictionary = {}
var _spawn: Vector3

func start(tree: SceneTree) -> void:
	tree.root.set_meta("phase_3a_result",{"status":"running","checks":_checks})
	var result := await run(tree)
	result["status"] = "complete"
	tree.root.set_meta("phase_3a_result",result)

func run(tree: SceneTree) -> Dictionary:
	_tree = tree
	_p = tree.current_scene.get_node("Player")
	_e = tree.current_scene.get_node("Soldier")
	_ai = _e.brain
	_spawn = _ai.origin
	for key in ["initial_delay","alert_duration","decision_time","decision_variation","reposition_chance","maximum_pursuit_distance","unseen_tolerance"]:
		_settings[key] = _ai.get(key)
	await _reset(Vector3(0,0,-4),100.0)
	_unit["scene_required_nodes_and_shared_attack_script"] = _e.has_node("CollisionShape3D") and _e.has_node("Visual/Body") and _e.has_node("Hurtbox") and _e.has_node("CombatPivot/Hitbox") and _e.has_node("CriticalVulnerability") and _e.attack_controller.get_script() == _p.attack_controller.get_script()
	_unit["idle_initial"] = _ai.state == 0
	_unit["perception_in_distance_and_cone"] = _ai.can_detect()
	_e.visual.rotation.y = 0.0
	_unit["vision_rejects_behind"] = not _ai.can_detect()
	_e.visual.rotation.y = PI
	_p.position = Vector3(0,0,4)
	_unit["distance_rejects_outside_radius"] = not _ai.can_detect()
	_p.position = Vector3.ZERO
	var wall := _wall(Vector3(0,1,-2))
	await _step(3)
	_unit["line_of_sight_rejects_solid_wall"] = not _ai.can_detect()
	_unit["clear_short_path_remains_valid"] = _ai.can_travel(Vector3.BACK) # Wall is still beyond the short probe.
	# Probe at the wall explicitly, without changing the decision state.
	_e.position = Vector3(0,0,-2.65)
	await _step(2)
	_unit["body_width_probe_rejects_obstacle"] = not _ai.can_travel(Vector3.BACK)
	wall.queue_free()
	await _step(2)
	var data: Dictionary = _e.attack_controller.light_1.snapshot()
	_unit["attack_resource_parameters"] = data.startup == 0.55 and data.active == 0.18 and data.recovery == 0.75 and data.damage == 20.0 and data.stamina_damage == 25.0 and data.blockable and data.parryable
	_ai.decision_time = 0.9
	_ai.decision_variation = 0.2
	_ai.reset_brain()
	var sequence: Array = [_ai._next_wait(),_ai._next_wait(),_ai._next_wait()]
	_ai.reset_brain()
	_unit["seeded_wait_reproducible"] = sequence == [_ai._next_wait(),_ai._next_wait(),_ai._next_wait()]
	_unit["wait_variation_bounded"] = sequence.min() >= 0.7 and sequence.max() <= 1.1
	await _reset(Vector3(0,0,-4))
	await _step(2)
	_checks["detection_enters_alert"] = _ai.state == 1
	var start_pos: Vector3 = _e.position
	await _step(12)
	_checks["alert_is_readable_pause"] = _e.position.distance_to(start_pos) < 0.02 and not _e.attack_controller.is_active()
	await _step(25)
	_checks["alert_to_chase_and_approach"] = _ai.state == 2 and _e.position.z > -4.0
	_e.visual.rotation.y = PI/2.0
	var old_yaw: float = _e.visual.rotation.y
	await _step(4)
	_checks["progressive_facing_toward_player"] = absf(angle_difference(_e.visual.rotation.y,PI)) < absf(angle_difference(old_yaw,PI)) and absf(angle_difference(old_yaw,_e.visual.rotation.y)) < 0.3
	_checks["autonomous_attack_reached"] = await _wait_attack()
	_checks["stops_in_attack_range"] = _e.position.distance_to(_p.position) <= _ai.attack_range+0.05 and Vector2(_e.velocity.x,_e.velocity.z).length() < 0.001
	await _reset(Vector3(0,0,-1.65))
	var phases: Array = []
	var on_phase := func(phase: int) -> void: phases.append([phase,_e.attack_controller.elapsed])
	_e.attack_controller.phase_changed.connect(on_phase)
	await _wait_attack()
	_checks["startup_has_no_hitbox_or_damage"] = _e.attack_controller.phase == 1 and not _e.attack_controller.hitbox.is_active() and _p.attributes.current_health == 100.0
	await _step(31)
	_checks["no_damage_before_startup_end"] = _p.attributes.current_health == 100.0
	await _step(2)
	_checks["active_hitbox_and_damage"] = _e.attack_controller.phase == 2 and _e.attack_controller.hitbox.is_active() and _p.attributes.current_health == 80.0
	var committed: Vector3 = _e.attack_controller.get_attack_direction()
	_p.position.x = 0.2
	await _step(4)
	_checks["active_direction_committed"] = _e.attack_controller.get_attack_direction().dot(committed) > 0.999
	for repeat in range(4): _e.attack_controller.hitbox.sample_hits()
	_checks["single_damage_per_attack"] = _p.attributes.current_health == 80.0 and _e.attack_controller.hitbox.hit_count == 1
	await _step(8)
	_checks["recovery_hitbox_off"] = _e.attack_controller.phase == 3 and not _e.attack_controller.hitbox.is_active()
	await _step(50)
	_checks["complete_attack_then_decision_pause"] = not _e.attack_controller.is_active() and _ai.state == 4 and _ai.decision_remaining > 1.0
	_checks["phase_durations_quantized_to_physics"] = phases.size() == 4 and absf(phases[1][1]-0.55) <= 0.017 and absf(phases[2][1]-0.73) <= 0.017 and absf(phases[3][1]-1.48) <= 0.017
	_measurements["attack_phase_events"] = phases.duplicate(true)
	_e.attack_controller.phase_changed.disconnect(on_phase)
	await _reset(Vector3(0,0,-1.65))
	Input.action_press("block")
	await _wait_attack()
	await _step(44)
	_checks["real_enemy_hit_blocked"] = _p.attributes.current_health == 100.0 and _p.defense_controller.last_event == &"blocked"
	_checks["guard_stamina_cost_exact"] = _p.attributes.current_stamina == 90.0
	await _reset(Vector3(0,0,-1.65))
	_p.attributes.consume_stamina(95.0)
	Input.action_press("block")
	await _wait_attack()
	await _step(35)
	_checks["real_enemy_guard_break"] = _p.action_states.current_state == 6 and _p.attributes.current_stamina == 0.0 and _p.attributes.current_health == 80.0
	await _reset(Vector3(0,0,-1.65))
	await _wait_attack()
	await _step(24)
	_p.dodge_controller.try_dodge(Vector2.UP)
	await _step(10)
	_checks["real_attack_respects_dodge_iframes"] = _p.is_invulnerable() and _p.attributes.current_health == 100.0 and _p.position.z < -0.5 and _e.attack_controller.hitbox.is_active()
	await _reset(Vector3(0,0,-1.65))
	await _wait_attack()
	await _step(24)
	_checks["parry_starts_against_ai_attack"] = _p.defense_controller.try_parry()
	await _step(11)
	_checks["contact_parry_interrupts_enemy"] = _p.defense_controller.last_event == &"parry_success" and _p.attributes.current_health == 100.0 and not _e.attack_controller.is_active()
	_checks["parried_enemy_vulnerable_and_incapacitated"] = _e.critical_vulnerability.is_available() and _e.action_states.current_state == 6 and _ai.state == 5
	await _step(40)
	_checks["riposte_on_ai_enemy"] = _p.attack_controller.request_attack(0) and _p.attack_controller.current_attack_name() == &"RIPOSTE"
	await _step(22)
	_checks["riposte_single_damage_to_enemy"] = _e.attributes.current_health == 60.0
	await _step(45)
	_checks["critical_reservation_released"] = not _e.critical_vulnerability.is_reserved() and _p.action_states.current_state == 0 and _e.action_states.current_state == 0
	await _reset(Vector3(0,0,-1.4),100.0)
	_e.visual.rotation.y = 0.0
	_checks["backstab_against_live_ai_actor"] = _p.attack_controller.request_attack(0) and _p.attack_controller.current_attack_name() == &"BACKSTAB"
	await _step(28)
	_checks["backstab_damage_once"] = _e.attributes.current_health == 40.0
	await _step(46)
	_checks["backstab_restores_enemy_action_state"] = not _e.critical_vulnerability.is_reserved() and _e.action_states.current_state == 0
	await _reset(Vector3(0,0,-1.65))
	await _wait_attack()
	_checks["normal_player_attack_starts_frontally"] = _p.attack_controller.request_attack(0) and _p.attack_controller.current_attack_name() == &"LIGHT_1"
	await _step(16)
	_checks["real_hitbox_damage_to_enemy"] = _e.attributes.current_health == 160.0
	_checks["damage_interrupts_startup_into_stagger"] = _e.action_states.current_state == 6 and _ai.state == 5 and not _e.attack_controller.is_active() and not _e.attack_controller.hitbox.is_active()
	await _step(42)
	_checks["damage_stagger_recovers"] = _e.action_states.current_state == 0 and _ai.state == 4
	await _reset(Vector3(0,0,-1.65),100.0)
	_e.hurtbox.receive_hit(_p,&"player",5.0,401)
	_checks["below_threshold_damage_no_stagger"] = _e.attributes.current_health == 175.0 and _e.action_states.current_state == 0
	await _reset(Vector3(0,0,-1.65))
	var lock: Node = tree.current_scene.get_node("LockOnController")
	_checks["enemy_lockable"] = lock.try_acquire() and lock.current_target == _e.lock_target
	await _wait_attack()
	var lethal: float = _e.hurtbox.receive_hit(_p,&"player",1000.0,402)
	_checks["enemy_dies_via_shared_hurtbox"] = lethal == 180.0 and _e.attributes.current_health == 0.0 and _ai.state == 6 and _e.action_states.current_state == 7
	_checks["death_disables_ai_hitbox_and_target"] = not _ai.is_physics_processing() and not _e.attack_controller.is_active() and not _e.attack_controller.hitbox.is_active() and not _e.lock_target.is_available()
	await _step(50)
	_checks["no_postmortem_attack_damage"] = _p.attributes.current_health == 100.0 and not _e.attack_controller.request_attack(0)
	_checks["lock_released_after_enemy_death"] = not lock.is_locked()
	await _reset(Vector3(0,0,-1.4),100.0)
	_e.visual.rotation.y = 0.0
	_checks["critical_death_fixture_starts_backstab"] = _p.attack_controller.request_attack(0) and _p.attack_controller.current_attack_name() == &"BACKSTAB"
	var critical_lethal: Dictionary = _e.hurtbox.resolve_hit(_p,&"player",1000.0,403,{"critical_owner":_p.riposte_controller})
	_checks["critical_test_lethal_damage_applied"] = critical_lethal.damage == 180.0 and _e.attributes.current_health == 0.0
	await _step(3)
	_checks["death_during_critical_releases_reservation"] = not _e.critical_vulnerability.is_reserved() and not _p.riposte_controller.is_active() and _p.action_states.current_state == 0
	await _reset(Vector3(0,0,-3))
	await _step(40)
	_p.position = Vector3(0,0,9.0)
	await _step(3)
	_checks["leash_enters_returning"] = _ai.state == 7 and not _e.attack_controller.is_active()
	var previous: Vector3 = _e.position
	var maximum_step: float = 0.0
	for frame in range(180):
		await _step(1)
		maximum_step = maxf(maximum_step,_e.position.distance_to(previous))
		previous = _e.position
	_measurements["return_maximum_observed_step"] = maximum_step
	_checks["returns_home_without_teleport"] = _e.position.distance_to(_ai.origin) < 0.2 and _ai.state == 0 and maximum_step < 0.1
	await _reset(Vector3(0,0,-3))
	await _step(35)
	wall = _wall(Vector3(0,1,-1.5))
	await _step(10)
	_checks["brief_occlusion_keeps_target"] = _ai.state != 7
	await _step(70)
	_checks["extended_occlusion_returns_home"] = _ai.state == 7 or _ai.state == 0
	wall.queue_free()
	await _step(2)
	await _reset(Vector3(0,0,-1.65),100.0)
	_p.attributes.apply_damage(1000.0)
	_unit["dead_player_not_detected"] = not _ai.can_detect()
	var swings_before: int = _e.attack_controller.swing_id
	await _step(120)
	_checks["no_ai_attack_against_dead_player"] = not _e.attack_controller.is_active() and _e.attack_controller.swing_id == swings_before and _ai.state == 0
	await _reset(Vector3(0,0,-1.65))
	await _wait_attack()
	_p.attributes.apply_damage(1000.0)
	await _step(3)
	_checks["target_death_interrupts_existing_startup"] = not _e.attack_controller.is_active() and not _e.attack_controller.hitbox.is_active()
	await _reset(Vector3(9.5,0,8),100.0)
	_unit["edge_ground_probe_rejects_void"] = not _ai.can_travel(Vector3.RIGHT)
	# Burst limit is a decision rule on the real component, without executing hits.
	_ai.maximum_consecutive_attacks = 2
	_ai.decision_time = 0.9
	_ai.decision_variation = 0.0
	_ai._consecutive = 0
	_ai._on_attack_finished(&"SOLDIER_LIGHT",true)
	var first_wait: float = _ai.decision_remaining
	_ai._on_attack_finished(&"SOLDIER_LIGHT",true)
	_unit["bounded_attack_burst_has_extended_pause"] = first_wait == 0.9 and _ai.decision_remaining >= 2.9
	await _reset(Vector3(0,0,-4),100.0)
	_checks["all_player_components_and_ai_enabled"] = _ai.enabled and _p.attack_controller.input_enabled and _p.dodge_controller.input_enabled and _p.defense_controller.input_enabled and _p.riposte_controller.backstab_enabled and _p.estus_controller.input_enabled
	var failed: Array = []
	for key in _unit:
		if not _unit[key]: failed.append("component/"+key)
	for key in _checks:
		if not _checks[key]: failed.append("integration/"+key)
	for key in _settings: _ai.set(key,_settings[key])
	_ai.origin = _spawn
	_e.position = _spawn
	_e.visual.rotation.y = PI
	_e.attributes.restore_all()
	_p.attributes.restore_all()
	var total: int = _unit.size()+_checks.size()
	return {"passed":total-failed.size(),"total":total,"failed":failed,"component_checks":_unit,"checks":_checks,"measurements":_measurements,"physical_devices":Input.get_connected_joypads()}

func _reset(position: Vector3, delay: float = 0.0) -> void:
	for action in ["block","parry","move_forward","move_backward","move_left","move_right","sprint_dodge","light_attack","heavy_attack","use_item","two_hand_toggle"]:
		Input.action_release(action)
	_tree.current_scene.get_node("LockOnController").release_lock(&"test_reset")
	_p.attributes.restore_all()
	_p.position = Vector3.ZERO
	_p.velocity = Vector3.ZERO
	_p.visual.rotation = Vector3.ZERO
	_e.position = position
	_e.velocity = Vector3.ZERO
	_e.visual.rotation.y = PI
	_ai.origin = position
	_ai.initial_delay = delay
	_ai.alert_duration = 0.45
	_ai.decision_time = 3.0
	_ai.decision_variation = 0.0
	_ai.reposition_chance = 0.0
	_ai.enabled = true
	_e.attributes.restore_all()
	_p.reset_physics_interpolation()
	_e.reset_physics_interpolation()
	var rig: Node3D = _tree.current_scene.get_node("CameraRig")
	rig.set_control_mode(0)
	rig.set_orbit_angles(0.0,deg_to_rad(rig.initial_pitch))
	rig.snap_to_target()
	await _step(2)

func _wait_attack() -> bool:
	for frame in range(180):
		if _e.attack_controller.is_active(): return true
		await _step(1)
	return false

func _step(frames: int) -> void:
	for frame in range(frames): await _tree.physics_frame
	await _tree.process_frame

func _wall(position: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3,2,0.15)
	shape.shape = box
	wall.add_child(shape)
	_tree.current_scene.add_child(wall)
	wall.position = position
	return wall
