extends RefCounted

const Hurtbox = preload("res://scripts/combat/hurtbox.gd")
var _tree: SceneTree
var _p: CharacterBody3D
var _a: Node
var _rig: Node3D
var _lock: Node
var _target: Node3D
var _left: Node3D
var _right: Node3D
var _light_data: Resource
var _checks: Dictionary = {}
var _measurements: Dictionary = {}


func start(tree: SceneTree) -> void:
	tree.root.set_meta("phase_2c_result",{"status":"running","checks":_checks})
	var result := await run(tree)
	result["status"] = "complete"
	tree.root.set_meta("phase_2c_result",result)


func run(tree: SceneTree) -> Dictionary:
	_tree = tree
	var arena := tree.current_scene
	_p = arena.get_node("Player")
	_a = _p.attack_controller
	_rig = arena.get_node("CameraRig")
	_lock = arena.get_node("LockOnController")
	_target = arena.get_node("Targets/Center")
	_left = arena.get_node("Targets/Left")
	_right = arena.get_node("Targets/Right")
	_light_data = _a.light_1
	await _reset()
	var events: Array = []
	var on_phase := func(phase: int) -> void: events.append([phase,_a.elapsed])
	_a.phase_changed.connect(on_phase)
	_checks["light_1_start_and_exact_cost"] = _a.request_attack(0) and _p.attributes.current_stamina == 82.0 \
		and _a.current_attack_name() == &"LIGHT_1"
	_checks["startup_has_no_hitbox"] = _a.phase == 1 and not _a.hitbox.is_active() and _target.attributes.current_health == 100.0
	_checks["no_simultaneous_attack"] = not _a.request_attack(2) and _p.attributes.current_stamina == 82.0
	_checks["dodge_blocked_by_attack"] = not _p.dodge_controller.try_dodge(Vector2(1,0))
	_checks["attack_cannot_cancel_recovery_normally"] = not _p.action_states.transition_to(0)
	Input.action_press("move_forward")
	Input.action_press("sprint_dodge")
	await _step(10)
	_checks["startup_movement_and_run_restricted"] = _p.position.length() < 0.02 and not _p.is_sprinting
	await _step(5)
	_checks["active_hitbox_only_after_startup"] = _a.phase == 2 and _a.hitbox.is_active() \
		and _target.attributes.current_health == 80.0
	for repeat in range(5):
		_a.hitbox.sample_hits()
	_checks["one_damage_per_actor_per_swing"] = _target.attributes.current_health == 80.0 and _target.hit_count == 1
	_checks["self_excluded_in_real_query"] = _p.attributes.current_health == 100.0
	await _step(9)
	_checks["recovery_hitbox_off"] = _a.phase == 3 and not _a.hitbox.is_active()
	Input.action_release("move_forward")
	Input.action_release("sprint_dodge")
	await _step(24)
	_checks["complete_to_free"] = not _a.is_active() and _p.action_states.current_state == 0
	_checks["no_regen_during_attack"] = _p.attributes.current_stamina == 82.0
	_checks["light_phase_times"] = events.size() == 4 and absf(events[1][1]-0.25) < 0.001 \
		and absf(events[2][1]-0.40) < 0.001 and absf(events[3][1]-0.80) < 0.001
	_measurements["light_1_phase_events"] = events.duplicate(true)
	_a.phase_changed.disconnect(on_phase)
	await _step(30)
	_checks["regen_delay_after_recovery"] = _p.attributes.current_stamina == 82.0
	await _step(30)
	_checks["regen_resumes"] = _p.attributes.current_stamina > 85.0
	Input.action_press("move_forward")
	await _step(15)
	_checks["locomotion_restored"] = _p.position.z < -0.1
	await _reset()
	_a.request_attack(0)
	await _step(28)
	_checks["valid_combo_buffer"] = _a.request_attack(0) and _a.has_buffered_attack()
	_checks["buffer_capacity_one"] = not _a.request_attack(0)
	await _step(20)
	_checks["light_2_starts_after_full_recovery"] = _a.current_attack_name() == &"LIGHT_2" \
		and _p.attributes.current_stamina == 62.0
	_checks["no_third_hit_in_combo"] = not _a.request_attack(0)
	await _step(56)
	_checks["combo_two_distinct_damages"] = _target.attributes.current_health == 55.0 and _target.hit_count == 2
	await _reset()
	var short_buffer: Resource = _light_data.duplicate(true)
	short_buffer.buffer_lifetime = 0.05
	_a.light_1 = short_buffer
	_a.request_attack(0)
	await _step(28)
	_a.request_attack(0)
	await _step(25)
	_checks["expired_buffer_does_not_execute"] = not _a.is_active() and not _a.has_buffered_attack() \
		and _target.hit_count == 1 and _p.attributes.current_stamina == 82.0
	await _reset()
	_a.request_attack(0)
	await _step(6)
	_checks["too_early_buffer_rejected"] = not _a.request_attack(0)
	await _step(39)
	_checks["too_late_buffer_rejected"] = not _a.request_attack(0)
	await _reset()
	var heavy_events: Array = []
	var on_heavy_phase := func(phase: int) -> void: heavy_events.append([phase,_a.elapsed])
	_a.phase_changed.connect(on_heavy_phase)
	_checks["heavy_starts_and_costs_35"] = _a.request_attack(2) and _p.attributes.current_stamina == 65.0
	await _step(86)
	_checks["heavy_damage_45"] = _target.attributes.current_health == 55.0 and _target.hit_count == 1
	_checks["heavy_phase_times"] = heavy_events.size() == 4 and absf(heavy_events[1][1]-0.55) < 0.001 \
		and absf(heavy_events[2][1]-0.75) < 0.001 and absf(heavy_events[3][1]-1.40) < 0.001
	_measurements["heavy_phase_events"] = heavy_events.duplicate(true)
	_a.phase_changed.disconnect(on_heavy_phase)
	await _reset()
	_p.attributes.consume_stamina(83.0)
	_checks["insufficient_light_stamina"] = not _a.request_attack(0) and _p.attributes.current_stamina == 17.0
	_p.attributes.restore_stamina(17.0)
	_checks["insufficient_heavy_stamina"] = not _a.request_attack(2) and _p.attributes.current_stamina == 34.0
	await _reset()
	_p.attributes.consume_stamina(65.0)
	_a.request_attack(0)
	await _step(28)
	_a.request_attack(0)
	await _step(22)
	_checks["combo_rechecks_stamina"] = not _a.is_active() and _target.hit_count == 1 \
		and _p.attributes.current_stamina == 17.0
	await _reset()
	_button(true)
	await _step(65)
	_button(true)
	await _step(10)
	_checks["held_rb_does_not_repeat"] = _target.hit_count == 1 and not _a.is_active()
	_button(false)
	_button(true)
	await _step(2)
	_checks["new_press_starts_new_request"] = _a.is_active()
	_button(false)
	await _reset()
	_trigger(0.9)
	await _step(20)
	_trigger(1.0)
	await _step(68)
	_checks["rt_axis_rising_edge_only"] = _target.hit_count == 1 and _target.attributes.current_health == 55.0
	_trigger(0.0)
	await _reset()
	_target.position = Vector3(-0.55,0,-1.6)
	_right.position = Vector3(0.55,0,-1.6)
	await _step(3)
	_a.request_attack(0)
	await _step(50)
	_checks["multiple_actors_in_one_swing"] = _target.attributes.current_health == 80.0 \
		and _right.attributes.current_health == 80.0 and _a.hitbox.hit_count == 2
	await _reset()
	var extra := _extra_hurtbox()
	await _step(3)
	_a.request_attack(0)
	await _step(50)
	_checks["multiple_hurtboxes_same_actor_deduplicated"] = _a.hitbox.hit_count == 1 and _target.attributes.current_health == 80.0
	extra.queue_free()
	await _reset()
	_target.position = Vector3(-0.55,0,-1.6)
	_right.position = Vector3(0.55,0,-1.6)
	await _step(3)
	var interrupt_on_hit := func(_actor: Node, _damage: float, _swing_id: int) -> void:
		_p.action_states.transition_to(7)
	_a.hitbox.hit_confirmed.connect(interrupt_on_hit)
	_a.request_attack(0)
	await _step(20)
	_checks["death_callback_stops_remaining_swing_hits"] = not _a.is_active() \
		and _target.attributes.current_health + _right.attributes.current_health == 180.0
	_a.hitbox.hit_confirmed.disconnect(interrupt_on_hit)
	await _reset()
	_target.hurtbox.faction = &"player"
	_a.request_attack(0)
	await _step(50)
	_checks["allied_damage_rejected"] = _target.attributes.current_health == 100.0 and _a.hitbox.hit_count == 0
	_checks["self_explicitly_rejected"] = _p.get_node("Hurtbox").receive_hit(_p,&"training",20.0,999) == 0.0
	await _reset()
	var wall := _make_wall()
	await _step(3)
	_a.request_attack(0)
	await _step(50)
	_checks["world_occlusion_blocks_damage"] = _target.attributes.current_health == 100.0
	wall.queue_free()
	await _reset()
	_target.attributes.apply_damage(80.0)
	_lock.try_acquire()
	_a.request_attack(0)
	await _step(50)
	_checks["dummy_death_safe_disable"] = _target.attributes.current_health == 0.0 and not _target.alive \
		and not _target.available and not _target.hurtbox.enabled and _target.collision_body.collision_layer == 0
	_checks["dead_dummy_loses_lock"] = not _lock.is_locked()
	_a.request_attack(0)
	await _step(50)
	_checks["dead_dummy_ignores_future_hits"] = _target.hit_count == 1 and _target.attributes.current_health == 0.0
	await _reset()
	_p.visual.rotation.y = -PI/2.0
	Input.action_press("move_right")
	_a.request_attack(0)
	await _step(15)
	_checks["free_attack_orientation"] = _a.get_attack_direction().dot(Vector3.RIGHT) > 0.999 and _p.rotation.is_zero_approx()
	var committed: Vector3 = _a.get_attack_direction()
	Input.action_release("move_right")
	Input.action_press("move_left")
	await _step(10)
	_checks["active_recovery_heading_committed"] = _a.get_attack_direction().dot(committed) > 0.999
	await _reset()
	_target.position.x = 0.8
	_left.available = false
	_right.available = false
	await _step(3)
	_lock.try_acquire()
	await _step(5)
	_a.request_attack(0)
	var starting_direction: Vector3 = _a.get_attack_direction()
	_target.position.x = 1.3
	await _step(15)
	var aimed: Vector3 = _a.get_attack_direction()
	_checks["locked_startup_correction_limited"] = _lock.is_locked() \
		and starting_direction.angle_to(aimed) <= deg_to_rad(30.0)+0.001 \
		and starting_direction.angle_to(aimed) > 0.01
	_target.position.x = -1.2
	await _step(10)
	_checks["locked_active_does_not_track_perfectly"] = _a.get_attack_direction().dot(aimed) > 0.999 and _lock.is_locked()
	await _reset()
	_p.dodge_controller.try_dodge(Vector2(1,0))
	await _step(5)
	_checks["attack_rejected_during_dodge"] = not _a.request_attack(0) and _p.attributes.current_stamina == 75.0
	_checks["hurtbox_respects_player_iframes"] = _p.get_node("Hurtbox").receive_hit(_target,&"training",20.0,1000) == 0.0
	await _step(16)
	_checks["hurtbox_accepts_vulnerable_window"] = _p.get_node("Hurtbox").receive_hit(_target,&"training",20.0,1001) == 20.0
	await _reset()
	_a.request_attack(0)
	await _step(28)
	_a.request_attack(0)
	_p.attributes.apply_damage(1000.0)
	_checks["dead_interrupts_attack_and_buffer"] = not _a.is_active() and not _a.has_buffered_attack() \
		and not _a.hitbox.is_active() and _p.action_states.current_state == 7
	_checks["cannot_overwrite_dead"] = not _a.request_attack(2)
	await _reset()
	await _step(50)
	_checks["reset_does_not_replay_buffer"] = not _a.is_active() and _target.hit_count == 0
	_a.request_attack(0)
	await _step(28)
	_a.request_attack(0)
	_checks["explicit_damage_interrupt_clears_buffer"] = _a.interrupt_for_damage() and not _a.has_buffered_attack() \
		and not _a.hitbox.is_active() and _p.action_states.current_state == 6
	await _reset()
	_a.animation_driven = true
	_a.request_attack(0)
	_checks["animation_events_reject_skipped_phase"] = not _a.set_phase_from_animation(3)
	await _step(50)
	_checks["animation_clock_requires_explicit_event"] = _a.phase == 1 and not _a.hitbox.is_active()
	_a.set_phase_from_animation(2)
	await _step(2)
	_checks["animation_active_event_enables_damage"] = _a.hitbox.is_active() and _target.attributes.current_health == 80.0
	_a.set_phase_from_animation(3)
	_checks["animation_recovery_event_disables_hitbox"] = not _a.hitbox.is_active()
	_checks["animation_finish_event_completes"] = _a.finish_from_animation() and _p.action_states.current_state == 0
	await _reset()
	var hud: Control = arena.get_node("HUD/PlayerVitals")
	_a.request_attack(2)
	_checks["hud_stamina_signal_updated"] = hud.stamina_bar.value == 65.0
	_checks["physical_capsule_kept_enabled"] = not _p.get_node("CollisionShape3D").disabled
	await _reset()
	_target.position = Vector3(0,0,-6)
	_left.position = Vector3(-3,0,-5)
	_right.position = Vector3(3,0,-5)
	await _step(3)
	var failed: Array = []
	for key in _checks:
		if not _checks[key]:
			failed.append(key)
	return {"passed":_checks.size()-failed.size(),"total":_checks.size(),"failed":failed,
		"checks":_checks,"measurements":_measurements,"physical_devices":Input.get_connected_joypads()}


func _reset() -> void:
	_lock.release_lock(&"test_reset")
	for action in ["move_forward","move_backward","move_left","move_right","sprint_dodge","light_attack","heavy_attack"]:
		Input.action_release(action)
	_button(false)
	_trigger(0.0)
	_p.attributes.restore_all()
	_a.light_1 = _light_data
	_a.animation_driven = false
	_a.input_enabled = true
	_p.dodge_controller.input_enabled = true
	_p.position = Vector3.ZERO
	_p.velocity = Vector3.ZERO
	_p.visual.rotation = Vector3.ZERO
	_p.reset_physics_interpolation()
	_target.position = Vector3(0,0,-1.6)
	_left.position = Vector3(-3,0,-5)
	_right.position = Vector3(3,0,-5)
	for target in [_target,_left,_right]:
		target.attributes.restore_all()
		target.hurtbox.faction = &"training"
	_rig.set_control_mode(0)
	_rig.set_orbit_angles(0.0,deg_to_rad(_rig.initial_pitch))
	_rig.snap_to_target()
	await _step(8)


func _step(frames: int) -> void:
	for frame in range(frames):
		await _tree.physics_frame
	await _tree.process_frame


func _button(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 7
	event.button_index = JOY_BUTTON_RIGHT_SHOULDER
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _trigger(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 7
	event.axis = JOY_AXIS_TRIGGER_RIGHT
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _extra_hurtbox() -> Area3D:
	var area := Hurtbox.new()
	area.actor = _target
	area.attributes = _target.attributes
	area.physical_body = _target.collision_body
	area.faction = &"training"
	area.position = Vector3(0,0.9,0)
	area.collision_layer = 8
	area.collision_mask = 0
	area.monitoring = false
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	area.add_child(shape)
	_target.add_child(area)
	return area


func _make_wall() -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3,2,0.15)
	shape.shape = box
	body.add_child(shape)
	_tree.current_scene.add_child(body)
	body.position = Vector3(0,1,-0.8)
	return body
