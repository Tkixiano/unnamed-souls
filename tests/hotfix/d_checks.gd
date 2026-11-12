extends RefCounted
var tree: SceneTree
var menus: Node
var scene: Node
var p: CharacterBody3D
var checks: Dictionary = {}
var measures: Dictionary = {}
func step(n: int) -> void:
	for i in range(n): await tree.physics_frame
	await tree.process_frame
func release() -> void:
	for action in ["move_left","move_right","move_forward","move_backward","sprint_dodge","block"]: Input.action_release(action)
func place(at: Vector3) -> void:
	release()
	p.attributes.restore_all()
	p.checkpoint_input_blocked = false
	p.position = at
	p.velocity = Vector3.ZERO
	var rig: Node = scene.get_node("CameraRig")
	rig.set_control_mode(0)
	rig.set_orbit_angles(0,-0.3)
	rig.snap_to_target()
	p.reset_physics_interpolation()
func pause_probe(tag: String) -> void:
	var b: Node = scene.get_node("Boss")
	var snapshot: Array = [p.global_position,p.attributes.current_stamina,p.dodge_controller.elapsed,b.global_position,b.attack_controller.elapsed]
	menus.open_pause()
	for i in range(6): await tree.process_frame
	checks[tag+"_pause_freezes"] = tree.paused and snapshot == [p.global_position,p.attributes.current_stamina,p.dodge_controller.elapsed,b.global_position,b.attack_controller.elapsed]
	menus.request_resume()
	for i in range(4): await tree.process_frame
	checks[tag+"_resume"] = not tree.paused
func start(t: SceneTree) -> void:
	tree = t
	menus = tree.root.get_node("GameMenus")
	var victory_overlay: bool = menus.automatic_victory_screen
	menus.automatic_victory_screen = false
	await menus.new_game()
	await step(12)
	scene = tree.current_scene
	p = scene.get_node("Player")
	var tutorial: Node = scene.get_node("TutorialController")
	place(Vector3(-1,0.1,12))
	await step(6)
	var start: Vector3 = p.position
	checks["forest_diagonal_started"] = p.dodge_controller.try_dodge(Vector2(1,-1))
	await step(3)
	await pause_probe("forest_dodge")
	await step(38)
	var delta: Vector3 = p.position-start
	checks["forest_diagonal_physical"] = delta.x>1.7 and delta.z < -1.7 and p.is_on_floor()
	checks["tutorial_diagonal_event"] = tutorial.is_completed(&"dodge")
	var soldier: Node = scene.get_node("Soldier1")
	place(soldier.global_position+Vector3(1,0.1,4))
	await step(5)
	var lock: Node = scene.get_node("LockOnController")
	checks["soldier_acquired"] = lock.try_acquire() and lock.current_target == soldier.lock_target
	Input.action_press("move_left")
	Input.action_press("sprint_dodge")
	await step(40)
	checks["soldier_run_locked"] = p.is_sprinting and lock.current_target == soldier.lock_target
	await pause_probe("locked_run")
	release()
	await step(4)
	checks["soldier_diagonal_started"] = p.dodge_controller.try_dodge(Vector2(1,-1))
	await step(38)
	checks["soldier_diagonal_lock"] = lock.current_target == soldier.lock_target and soldier.brain.has_aggro()
	checks["tutorial_lock_not_undone"] = tutorial.is_completed(&"lock") and tutorial.is_completed(&"dodge")
	Input.action_press("block")
	await step(3)
	await pause_probe("locked_combat")
	release()
	var spawn: Vector3 = scene.get_node("CheckpointManager").get_respawn_transform().origin
	p.attributes.apply_damage(10000)
	await step(175)
	checks["forest_death_respawn"] = p.attributes.current_health == 100 and p.position.distance_to(spawn)<0.1 and p.action_states.current_state == 0
	checks["respawn_lock_and_buffers"] = not lock.is_locked() and not p.attack_controller.hitbox.is_active() and not p.dodge_controller.is_active()
	checks["tutorial_survives_death"] = tutorial.is_completed(&"dodge") and tutorial.is_completed(&"lock")
	checks["soldier_aggro_resets"] = not soldier.brain.has_aggro() and soldier.attributes.current_health == soldier.attributes.max_health
	await menus.new_game()
	await step(8)
	checks["new_game_clears_tutorial"] = not tree.current_scene.get_node("TutorialController").is_completed(&"dodge")
	# Direct debug arena, with production actor, AI, attack executor and checkpoint.
	tree.change_scene_to_file("res://scenes/levels/ruins_boss_arena.tscn")
	await tree.scene_changed
	await step(100)
	scene = tree.current_scene
	p = scene.get_node("Player")
	var b: Node = scene.get_node("Boss")
	place(Vector3(0,0.1,7))
	await step(8)
	checks["boss_fog_starts"] = b.brain.encounter_active
	place(Vector3(0,0.1,-9.5))
	await step(6)
	# Walk beyond the old boundary on the actual artistic floor.
	Input.action_press("move_forward")
	await step(38)
	Input.action_release("move_forward")
	await step(5)
	checks["boss_far_end_real_walk"] = p.position.z < -10.5 and p.is_on_floor() and b.brain.encounter_active
	await pause_probe("boss_encounter")
	checks["boss_diagonal_started"] = p.dodge_controller.try_dodge(Vector2(1,1))
	await step(38)
	checks["boss_diagonal_ground_encounter"] = p.is_on_floor() and b.brain.encounter_active and not p.dodge_controller.is_active()
	b.attributes.apply_damage(301)
	await step(100)
	checks["boss_phase_two_keeps_hp"] = b.brain.phase_two and b.brain.transition_count == 1 and b.attributes.current_health == 299
	var swings: int = b.attack_controller.swing_id
	# Only position is arranged; normal decision/attack code chooses and executes the strike.
	place(b.global_position+b.brain.direction_to_target()*2.2)
	await step(150)
	checks["boss_attacks_without_fog_reentry"] = b.attack_controller.swing_id > swings and b.brain.encounter_active
	measures["boss_after_far_walk"] = {"boss_position":str(b.global_position),"phase_two":b.brain.phase_two,"swing_id":b.attack_controller.swing_id,"player_health":p.attributes.current_health}
	p.attributes.apply_damage(10000)
	await step(175)
	checks["boss_retry"] = p.attributes.current_health == 100 and b.attributes.current_health == 600 and not b.brain.phase_two and not b.brain.encounter_active
	checks["boss_retry_no_residual_offense"] = not b.attack_controller.hitbox.is_active() and not p.attack_controller.hitbox.is_active()
	place(Vector3(0,0.1,7))
	await step(100)
	checks["boss_second_attempt"] = b.brain.encounter_active
	b.attributes.apply_damage(10000)
	await step(3)
	checks["boss_victory"] = b.boss_defeated_this_session and b.brain.state == 8 and not b.lock_target.is_available() and not b.attack_controller.hitbox.is_active()
	scene.get_node("CheckpointManager").restore_enemies()
	checks["boss_victory_session_preserved"] = b.attributes.current_health == 0 and b.boss_defeated_this_session
	await menus.new_game()
	await step(8)
	checks["new_game_resets_boss"] = tree.current_scene.get_node("Boss").attributes.current_health == 600 and not tree.current_scene.get_node("Boss").boss_defeated_this_session
	menus.automatic_victory_screen = victory_overlay
	var failed: Array = []
	for key in checks:
		if not checks[key]: failed.append(key)
	var result := {"status":"complete","passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed,"checks":checks,"measurements":measures,"physical_devices":Input.get_connected_joypads(),"method":"Active production AI, actors, combat, camera, tutorial, pause and checkpoints. Controlled placements isolate locations; actual physics walk/roll and normal attack decisions. Direct damage triggers phase/death/victory; historical route additionally uses player hitboxes. Automatic victory overlay isolated only, covered by native menu regression."}
	FileAccess.open("res://tests/hotfix/d_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("HOTFIX_D ",result.passed,"/",result.total," failed=",failed)
