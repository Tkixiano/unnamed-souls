extends RefCounted
## Real actor/physics fixtures; lifecycle integration uses the existing level.
var tree: SceneTree
var p: CharacterBody3D
var e: CharacterBody3D
var ai: Node
var checks: Dictionary = {}
var measurements: Dictionary = {}
func step(n: int) -> void:
	for i in range(n): await tree.physics_frame
	await tree.process_frame
func reset(at: Vector3 = Vector3(0,0,-4)) -> void:
	e.restore_at_checkpoint()
	p.restore_at_checkpoint(Transform3D(Basis.IDENTITY,Vector3.ZERO),true)
	e.position = at
	e.velocity = Vector3.ZERO
	e.visual.rotation.y = PI
	ai.origin = at
	ai.initial_delay = 0.0
	ai.decision_time = 3.0
	ai.decision_variation = 0.0
	ai.reposition_chance = 0.0
	ai.reset_brain()
	await step(2)
func wall(at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8,3,0.2)
	collider.shape = box
	body.add_child(collider)
	tree.current_scene.add_child(body)
	body.position = at
	return body
func acquire_in_level() -> void:
	p = tree.current_scene.get_node("Player")
	e = tree.current_scene.get_node("Soldier1")
	ai = e.brain
	var forward: Vector3 = -e.visual.global_basis.z
	p.restore_at_checkpoint(Transform3D(Basis.IDENTITY,e.global_position+forward*3.0+Vector3.UP*0.1),true)
	for i in range(110):
		if ai.has_aggro(): break
		await tree.physics_frame
	await tree.process_frame
func start(t: SceneTree) -> void:
	tree = t
	tree.root.set_meta("aggro_checks",{"status":"running","checks":checks})
	tree.change_scene_to_file("res://scenes/levels/test_arena.tscn")
	await tree.scene_changed
	await step(8)
	p = tree.current_scene.get_node("Player")
	e = tree.current_scene.get_node("Soldier")
	ai = e.brain
	tree.current_scene.get_node("CheckpointManager").automatic_respawn_enabled = false
	await reset()
	checks["initial_valid_visual_detection"] = ai.can_detect() and ai.has_aggro() and ai.target == p
	checks["detection_enters_alert"] = ai.state == ai.State.ALERT
	await reset()
	ai.reset_brain()
	e.visual.rotation.y = 0.0
	await step(6)
	checks["no_initial_acquisition_behind"] = not ai.can_detect() and not ai.has_aggro() and ai.state == ai.State.IDLE
	e.visual.rotation.y = PI
	p.position = Vector3(0,0,9)
	await step(6)
	checks["no_initial_acquisition_out_of_range"] = not ai.can_detect() and not ai.has_aggro()
	p.position = Vector3.ZERO
	var obstacle: StaticBody3D = wall(Vector3(0,1.5,-2))
	await step(85)
	checks["no_initial_acquisition_through_wall"] = not ai.has_aggro() and ai.state == ai.State.IDLE and not ai.can_detect()
	obstacle.queue_free()
	await step(3)
	checks["acquires_only_after_clear_sight"] = ai.has_aggro() and ai.target == p
	obstacle = wall(Vector3(0,1.5,-2))
	var swings: int = e.attack_controller.swing_id
	await step(130)
	checks["persistent_beyond_former_occlusion_timeout"] = ai.has_aggro() and ai.target == p and ai.state != ai.State.RETURNING
	checks["no_attack_through_occluding_wall"] = e.attack_controller.swing_id == swings and p.attributes.current_health == 100
	p.position = Vector3(0,0,9)
	await step(12)
	checks["persistent_beyond_detection_radius"] = not ai.can_detect() and ai.has_aggro()
	checks["persistent_beyond_old_target_leash"] = p.position.distance_to(ai.origin) > ai.maximum_pursuit_distance and ai.has_aggro()
	# Force the old loss-radius predicate without changing any production tuning.
	var saved_loss: float = ai.loss_radius
	ai.loss_radius = 0.5
	await step(6)
	checks["legacy_loss_radius_does_not_forget"] = ai.has_aggro() and ai.target == p
	ai.loss_radius = saved_loss
	obstacle.queue_free()
	await step(2)
	e.position = Vector3(0,0,5)
	e.velocity = Vector3.ZERO
	await step(2)
	checks["persistent_beyond_old_actor_leash"] = e.position.distance_to(ai.origin) > ai.maximum_pursuit_distance and ai.has_aggro()
	e.visual.rotation.y = 0.0
	await step(1)
	checks["persistent_outside_field_of_view"] = not ai.can_detect() and ai.has_aggro()
	p.position = e.position+Vector3.FORWARD*3
	e.visual.rotation.y = PI
	await step(1)
	checks["persistent_when_player_moves_behind"] = not ai.can_detect() and ai.has_aggro() and ai.target == p
	await reset(Vector3(0,0,-1.6))
	obstacle = wall(Vector3(0,1.5,-0.8))
	var previous: Vector3 = e.position
	var max_step: float = 0.0
	swings = e.attack_controller.swing_id
	for i in range(100):
		await step(1)
		max_step = maxf(max_step,e.position.distance_to(previous))
		previous = e.position
	checks["wall_collision_keeps_soldier_on_its_side"] = e.position.z < -1.0 and ai.has_aggro()
	checks["no_teleport_or_speed_change"] = max_step < 0.1 and e.speed == 2.0 and e.acceleration == 8.0
	checks["blocked_attack_in_range"] = e.position.distance_to(p.position) < ai.attack_range and e.attack_controller.swing_id == swings and p.attributes.current_health == 100
	measurements["maximum_wall_fixture_physics_step"] = max_step
	obstacle.queue_free()
	await step(2)
	for i in range(120):
		if e.attack_controller.is_active(): break
		await tree.physics_frame
	checks["attack_resumes_after_obstacle_clears"] = e.attack_controller.is_active() and ai.has_aggro()
	var menus: Node = tree.root.get_node("GameMenus")
	var elapsed: float = e.attack_controller.elapsed
	var position: Vector3 = e.position
	menus.open_pause()
	await tree.create_timer(0.2,true).timeout
	checks["pause_preserves_aggro_reference"] = tree.paused and ai.has_aggro() and ai.target == p
	checks["pause_freezes_attack_and_physics"] = e.attack_controller.elapsed == elapsed and e.position == position
	menus.request_resume()
	await step(2)
	checks["resume_preserves_aggro"] = not tree.paused and ai.has_aggro() and ai.target == p
	await step(42)
	checks["normal_attack_damage_unchanged"] = p.attributes.current_health == 80.0
	e.attributes.apply_damage(1000)
	checks["enemy_death_clears_aggro"] = not ai.has_aggro() and not ai._acquired and ai.state == ai.State.DEAD
	checks["enemy_death_cancels_offense"] = not e.attack_controller.is_active() and not e.attack_controller.hitbox.is_active()
	e.restore_at_checkpoint()
	checks["enemy_restore_clears_memory"] = not ai._acquired and ai.state == ai.State.IDLE and ai.target == p
	# Invalid target fixture, using a disposable protagonist; no real player freed.
	var temporary: CharacterBody3D = load("res://scenes/player/player.tscn").instantiate()
	tree.current_scene.add_child(temporary)
	temporary.position = Vector3(4,0,4)
	e.position = Vector3(4,0,0)
	e.visual.rotation.y = PI
	ai.target = temporary
	ai.reset_brain()
	await step(3)
	checks["disposable_target_detected_normally"] = ai.has_aggro() and ai.target == temporary
	temporary.queue_free()
	await step(3)
	checks["destroyed_target_reference_cleared"] = ai.target == null and not ai._acquired and not e.attack_controller.is_active()
	ai.target = p
	await menus.new_game()
	await acquire_in_level()
	checks["integrated_soldier_acquires_in_level"] = ai.has_aggro()
	var manager: Node = tree.current_scene.get_node("CheckpointManager")
	var fire: Node3D = manager.get_active_bonfire()
	var id: int = e.get_instance_id()
	p.restore_at_checkpoint(fire.get_spawn_transform(),true)
	await step(12)
	checks["bonfire_rest_uses_real_interaction"] = manager.rest_at(fire)
	checks["bonfire_rest_resets_aggro_without_duplicates"] = not ai._acquired and ai.state == ai.State.IDLE and e.get_instance_id() == id
	await acquire_in_level()
	checks["can_reacquire_after_rest"] = ai.has_aggro()
	p.attributes.apply_damage(1000)
	await step(3)
	checks["dead_player_is_not_pursued_or_attacked"] = not ai._acquired and not e.attack_controller.is_active() and not e.attack_controller.hitbox.is_active()
	for i in range(220):
		if p.attributes.current_health > 0 and manager.phase == manager.Phase.NONE: break
		await tree.physics_frame
	checks["real_respawn_restores_player"] = p.attributes.current_health == 100 and p.action_states.current_state == 0
	checks["real_respawn_resets_soldier_aggro"] = not ai._acquired and ai.state == ai.State.IDLE and e.get_instance_id() == id and e.position.distance_to(ai.origin) < 0.1
	await acquire_in_level()
	checks["can_reacquire_after_respawn"] = ai.has_aggro()
	ai.reset_brain()
	checks["explicit_brain_reset_clears_aggro"] = not ai._acquired and ai.state == ai.State.IDLE
	await acquire_in_level()
	await menus.new_game()
	await step(8)
	var fresh: Node = tree.current_scene.get_node("Soldier1")
	checks["new_game_clears_old_aggro_and_bindings"] = fresh.get_instance_id() != id and not fresh.brain.has_aggro() and fresh.brain.target == tree.current_scene.get_node("Player")
	await acquire_in_level()
	tree.reload_current_scene()
	await tree.scene_changed
	await step(8)
	fresh = tree.current_scene.get_node("Soldier1")
	checks["explicit_level_reload_clears_aggro"] = not fresh.brain.has_aggro() and fresh.brain.target == tree.current_scene.get_node("Player")
	var failed: Array = []
	for key in checks:
		if not checks[key]: failed.append(key)
	var result := {"status":"complete","passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed,"checks":checks,"measurements":measurements,"physical_devices":Input.get_connected_joypads(),"scope":"Automated physics/contact and real lifecycle integration; no visual/physical-controller claims"}
	FileAccess.open("res://tests/aggro_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	tree.root.set_meta("aggro_checks",result)
