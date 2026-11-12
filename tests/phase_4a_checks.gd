extends RefCounted
var tree: SceneTree
var scene: Node3D
var p: CharacterBody3D
var boss: CharacterBody3D
var manager: Node
var lock: Node
var checks: Dictionary = {}
var measures: Dictionary = {}
func step(n: int) -> void:
	for i in range(n): await tree.physics_frame
	await tree.process_frame
func start(t: SceneTree) -> void:
	tree = t
	tree.root.set_meta("phase4a_result",{"status":"running","checks":checks})
	await run()
	var failed: Array = []
	for key in checks:
		if not checks[key]: failed.append(key)
	var result := {"status":"complete","passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed,"checks":checks,"measurements":measures,"physical_devices":Input.get_connected_joypads()}
	tree.root.set_meta("phase4a_result",result)
	var f := FileAccess.open("res://tests/phase_4a_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"\t"))
func reset_player(position: Vector3) -> void:
	for a in ["move_forward","move_backward","move_left","move_right","block","sprint_dodge","camera_right"]: Input.action_release(a)
	p.attributes.restore_all()
	p.checkpoint_input_blocked = false
	p.position = position
	p.velocity = Vector3.ZERO
	p.visual.rotation = Vector3.ZERO
	lock.release_lock(&"fixture")
	var rig: Node3D = scene.get_node("CameraRig")
	rig.set_orbit_angles(0.0,deg_to_rad(-18))
	rig.snap_to_target()
	p.reset_physics_interpolation()
func run() -> void:
	scene = tree.current_scene
	p = scene.get_node("Player")
	boss = scene.get_node("Boss")
	manager = scene.get_node("CheckpointManager")
	lock = scene.get_node("LockOnController")
	var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/phase_4a_asset_audit.json"))
	checks["five_assets_imported_in_godot"] = audit.keys().filter(func(k): return str(k).ends_with(".glb") and audit[k].loaded).size() == 5
	checks["source_audit_materials_and_dimensions"] = audit["res://assets/models/escenario 1.glb"].materials.size() == 156 and audit["res://assets/models/escenario 1.glb"].surfaces == 1069
	var hashes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/phase_4a_originals.json"))
	var intact: bool = true
	for path in hashes:
		if path.begins_with("res://assets/models/") and not path.ends_with(".import"): intact = intact and FileAccess.get_sha256(path) == hashes[path]
	checks["original_models_and_textures_unchanged"] = intact
	checks["single_player_shared_scene"] = scene.find_children("Player","CharacterBody3D",true,false).size() == 1 and p.scene_file_path == "res://scenes/player/player.tscn"
	checks["main_level_loaded"] = scene.scene_file_path == "res://scenes/levels/main_level.tscn"
	# Phase 5B: F5 launches the main menu; integrated level and debug selector remain.
	checks["f5_main_menu_level_and_selector_preserved"] = ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/ui/main_menu.tscn" and ResourceLoader.exists("res://scenes/levels/main_level.tscn") and ResourceLoader.exists("res://scenes/ui/arena_selector.tscn")
	var valid: bool = true
	var triangles: int = 0
	for n in scene.get_node("Forest").find_children("*","MeshInstance3D",true,false):
		if n.mesh == null: valid = false; continue
		for s in range(n.mesh.get_surface_count()):
			valid = valid and n.get_active_material(s) != null
			if n.mesh is ArrayMesh: triangles += n.mesh.surface_get_array_index_len(s)/3
	measures["forest_triangles_in_scene"] = triangles
	checks["retained_forest_materials_valid"] = valid
	checks["moderate_derived_geometry"] = triangles < 150000
	checks["forest_portions_excluded_explicitly"] = audit.integration.excluded_source_meshes.size() > 0 and audit.integration.trees == 12
	checks["no_definitive_actor_models"] = p.has_node("Visual/Placeholder") and boss.has_node("Visual/Body")
	checks["reusable_estus_scene"] = ResourceLoader.exists("res://scenes/environment/estus_visual.tscn")
	checks["reusable_rock_four_instances"] = scene.get_node("Rock0").scene_file_path == "res://scenes/environment/rock_prop.tscn" and scene.has_node("Rock3")
	await step(20)
	checks["initial_ground_collision"] = p.is_on_floor() and absf(p.position.y) < 0.03
	var samples: Array = []
	var floor_valid: bool = true
	for z in [20,14,7,0,-8,-18,-24,-28,-32,-35,-37,-39,-41,-45,-48,-55]:
		var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,2,z),Vector3(0,-2,z),1))
		floor_valid = floor_valid and not hit.is_empty() and absf(hit.position.y) < 0.3
		samples.append({"z":z,"y":hit.position.y if not hit.is_empty() else null})
	measures["floor_samples"] = samples
	checks["route_and_boss_floor_continuous"] = floor_valid
	var fire: Node3D = scene.get_node("Bonfire")
	reset_player(Vector3(1,0.1,20))
	await step(8)
	p.attributes.apply_damage(40)
	p.attributes.consume_stamina(50)
	p.estus_controller.current_charges = 2
	checks["bonfire_rest_uses_existing_manager"] = manager.rest_at(fire)
	await step(3)
	checks["bonfire_restores_vitals_estus_one_hand"] = p.attributes.current_health == 100 and p.attributes.current_stamina == 100 and p.estus_controller.current_charges == 5 and p.grip_controller.shield_available()
	checks["bonfire_visual_replaced_logic_preserved"] = fire.has_node("Visual/BonfireVisual") and not fire.get_node("Visual/Ash").visible and fire.interaction_area != null
	var start_z: float = p.position.z
	Input.action_press("move_forward")
	await step(45)
	Input.action_release("move_forward")
	await step(15)
	checks["free_movement_and_deceleration"] = p.position.z < start_z-1.5 and p.horizontal_speed < 0.05
	var rig: Node3D = scene.get_node("CameraRig")
	var yaw: float = rig.get_orbit_angles().x
	Input.action_press("camera_right")
	await step(24)
	Input.action_release("camera_right")
	checks["orbital_camera_independent"] = absf(angle_difference(yaw,rig.get_orbit_angles().x)) > 0.3 and p.rotation.is_zero_approx()
	var wall := PhysicsRayQueryParameters3D.create(Vector3(-20,1,0),Vector3(-27,1,0),1)
	checks["world_boundary_solid"] = not scene.get_world_3d().direct_space_state.intersect_ray(wall).is_empty()
	reset_player(Vector3(-22,0.1,0))
	await step(5)
	rig.set_orbit_angles(-PI/2,deg_to_rad(-18))
	rig.snap_to_target()
	await step(25)
	checks["camera_collision_with_boundary"] = rig.spring_arm.get_hit_length() < rig.normal_distance
	var dummy: Node3D = scene.get_node("TutorialDummy")
	reset_player(Vector3(2.5,0.1,14))
	await step(8)
	checks["tutorial_lock_on"] = lock.try_acquire() and lock.current_target == dummy
	Input.action_press("move_left")
	await step(20)
	Input.action_release("move_left")
	checks["locked_strafe"] = p.position.x < 2.1 and lock.is_locked()
	reset_player(Vector3(2.5,0.1,13.3))
	await step(8)
	checks["normal_attack_starts"] = p.attack_controller.request_attack(0)
	await step(60)
	checks["real_hitbox_damage_single"] = dummy.attributes.current_health == 80
	checks["locomotion_restored_after_attack"] = p.action_states.current_state == 0
	var soldier: CharacterBody3D = scene.get_node("Soldier1")
	soldier.restore_at_checkpoint()
	reset_player(soldier.position+Vector3(0,0,1.4))
	await step(180)
	checks["soldier_ai_real_attack_damages_player"] = p.attributes.current_health < 100 and p.attributes.current_health > 0
	soldier.restore_at_checkpoint()
	reset_player(soldier.position+Vector3(0,0,1.4))
	Input.action_press("block")
	await step(180)
	Input.action_release("block")
	checks["soldier_real_hit_can_be_blocked"] = p.attributes.current_health == 100
	await step(3)
	soldier.restore_at_checkpoint()
	reset_player(soldier.position+Vector3(0,0,1.4))
	await step(5)
	checks["soldier_manual_attack_uses_shared_executor"] = soldier.attack_controller.request_attack(0)
	await step(24)
	checks["parry_starts"] = p.defense_controller.try_parry()
	await step(15)
	checks["contact_parry_in_integrated_level"] = soldier.critical_vulnerability.is_available() and p.attributes.current_health == 100
	await step(45)
	checks["riposte_contextual"] = p.attack_controller.request_attack(0) and p.riposte_controller.is_active()
	await step(70)
	checks["riposte_damage_once"] = soldier.attributes.current_health == 60
	reset_player(Vector3(0,0.1,10))
	await step(6)
	checks["dodge_starts"] = p.dodge_controller.try_dodge(Vector2.RIGHT)
	await step(6)
	checks["iframes_query_active"] = p.is_invulnerable()
	await step(35)
	checks["dodge_ground_and_free_recovered"] = p.is_on_floor() and p.action_states.current_state == 0 and not p.is_invulnerable()
	reset_player(Vector3(0,0.1,20))
	await step(6)
	p.attributes.apply_damage(60)
	checks["estus_uses_original_component"] = p.estus_controller.try_use()
	await step(45)
	checks["estus_not_instant"] = p.attributes.current_health == 40 and p.estus_controller.current_charges == 5
	await step(12)
	checks["estus_heals_once_at_use_time"] = p.attributes.current_health == 100 and p.estus_controller.current_charges == 4
	await step(40)
	checks["estus_recovery_and_hud"] = p.action_states.current_state == 0 and scene.get_node("HUD/EstusHUD").visible
	# Traversability test isolates combat by defeating actors, not removing colliders.
	for actor in [soldier,scene.get_node("Soldier2")]: actor.hurtbox.receive_hit(p,&"player",10000,801)
	reset_player(Vector3(-2.5,0.1,20))
	await step(8)
	Input.action_press("move_forward")
	await step(1000)
	Input.action_release("move_forward")
	await step(12)
	measures["walk_to_gate_position"] = str(p.position)
	checks["walk_tutorial_path_to_gate_without_teleport"] = p.position.z < -30 and p.is_on_floor()
	var gate: Node3D = scene.get_node("GateBonfire")
	reset_player(Vector3(0.8,0.1,-32))
	await step(8)
	checks["gate_checkpoint_rest"] = manager.rest_at(gate) and manager.active_id == &"forest_gate"
	await step(5)
	Input.action_press("move_forward")
	await step(200)
	Input.action_release("move_forward")
	await step(8)
	checks["walk_through_arch_starts_boss"] = p.position.z < -40 and boss.brain.encounter_active and scene.get_node("HUD/BossHUD").panel.visible
	checks["same_player_and_checkpoint_in_arena"] = manager.active_id == &"forest_gate" and scene.get_node("Player") == p
	# Pattern timing/contact fixtures suspend decisions only; executor, physics and damage stay active.
	boss.brain.enabled = false
	p.attributes.max_health = 1000
	for pattern in [&"HORIZONTAL_SLASH",&"VERTICAL_SLAM",&"TWO_HIT_COMBO"]:
		boss.restore_at_checkpoint()
		boss.brain.enabled = false
		boss.brain.encounter_active = true
		boss.brain.state = 3
		boss.brain.decision_remaining = 0
		boss.brain._restart_delay = 0
		reset_player(boss.position+Vector3(0,0,2.3))
		await step(8)
		var hp: float = p.attributes.current_health
		checks["pattern_starts_"+str(pattern)] = boss.brain.start_pattern(pattern)
		await step(160)
		var expected: float = 24 if pattern == &"HORIZONTAL_SLASH" else 36 if pattern == &"VERTICAL_SLAM" else 46
		checks["pattern_damage_once_"+str(pattern)] = is_equal_approx(hp-p.attributes.current_health,expected)
	boss.brain.enabled = true
	boss.brain.decision_time = 100
	boss.brain.decision_remaining = 100
	boss.attributes.apply_damage(300)
	await step(95)
	checks["phase_two_transition_single_no_heal"] = boss.brain.phase_two and boss.brain.transition_count == 1 and boss.attributes.current_health == 300
	boss.brain.enabled = false
	boss.brain.decision_remaining = 0
	boss.brain.state = 3
	reset_player(boss.position+Vector3(0,0,2.3))
	await step(8)
	checks["area_pattern_enabled"] = boss.brain.start_pattern(&"RUIN_BURST")
	checks["area_warning_visible_during_startup"] = boss.brain.warning_mesh.visible and not boss.attack_controller.hitbox.is_active()
	await step(78)
	checks["area_can_be_dodged_start"] = p.dodge_controller.try_dodge(Vector2.UP)
	var hp: float = p.attributes.current_health
	await step(25)
	checks["area_evaded_by_real_iframes"] = p.attributes.current_health == hp
	await step(60)
	boss.brain._history.clear()
	boss.brain._cooldowns.clear()
	boss.brain.decision_remaining = 0
	boss.brain.state = 3
	p.attributes.max_health = 100
	reset_player(boss.position+Vector3(0,0,2.3))
	await step(8)
	p.attributes.apply_damage(80)
	checks["lethal_area_started"] = boss.brain.start_pattern(&"RUIN_BURST")
	boss.brain.enabled = true
	boss.brain.decision_time = 100
	await step(84)
	checks["boss_contact_causes_real_death"] = p.action_states.current_state == 7 and p.attributes.current_health == 0
	await step(170)
	checks["death_respawns_at_active_gate"] = p.attributes.current_health == 100 and p.position.distance_to(gate.get_spawn_transform().origin) < 0.15
	checks["boss_reset_full_phase_one_no_hitbox"] = boss.attributes.current_health == 600 and not boss.brain.phase_two and not boss.attack_controller.hitbox.is_active()
	checks["normal_enemies_restore_same_instances"] = soldier.attributes.current_health == 180 and scene.get_node("Soldier2").attributes.current_health == 180
	reset_player(boss.position+Vector3(0,0,2.3))
	await step(8)
	lock.try_acquire()
	boss.hurtbox.receive_hit(p,&"player",10000,802)
	await step(3)
	checks["boss_victory_and_lock_invalidated"] = boss.boss_defeated_this_session and not boss.lock_target.is_available() and not lock.is_locked() and scene.get_node("HUD/BossHUD").victory_message.visible
	reset_player(gate.position+Vector3(-1,0.1,0))
	await step(8)
	manager.rest_at(gate)
	checks["rest_keeps_boss_dead"] = boss.attributes.current_health == 0 and not boss.attack_controller.hitbox.is_active()
	checks["single_boss_no_respawn_duplicates"] = tree.get_nodes_in_group("checkpoint_enemies").size() == 3
	checks["direct_boss_f6_scene_exists"] = ResourceLoader.exists("res://scenes/levels/ruins_boss_arena.tscn")
