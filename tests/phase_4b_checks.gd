extends RefCounted
## Integration-only fixtures. No actor or combat source changes.
var tree: SceneTree
var scene: Node3D
var p: CharacterBody3D
var checks: Dictionary = {}
var measurements: Dictionary = {}
var result: Dictionary = {"status":"running"}

func step(frames: int) -> void:
	for i in range(frames): await tree.physics_frame
	await tree.process_frame

func start(t: SceneTree) -> void:
	tree = t
	tree.root.set_meta("phase4b_result",result)
	await run()
	var failed: Array = []
	for key in checks:
		if not checks[key]: failed.append(key)
	result.merge({"status":"complete","passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed,"checks":checks,"measurements":measurements,"physical_devices":Input.get_connected_joypads()},true)
	FileAccess.open("res://tests/phase_4b_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))

func position_player(at: Vector3) -> void:
	for action in ["move_forward","move_backward","move_left","move_right","block","sprint_dodge"]: Input.action_release(action)
	p.restore_at_checkpoint(Transform3D(Basis.IDENTITY,at),true)
	p.checkpoint_input_blocked = false
	scene.get_node("LockOnController").release_lock(&"fixture")
	scene.get_node("CameraRig").set_orbit_angles(0.0,deg_to_rad(-18))
	scene.get_node("CameraRig").snap_to_target()

func ray(from: Vector3, to: Vector3) -> Dictionary:
	return scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1))

func walk_to(at: Vector3, limit: int = 1800) -> bool:
	for frame in range(limit):
		var d: Vector3 = at-p.global_position
		d.y = 0
		if d.length() < 0.3: break
		Input.action_press("move_left",clampf(-d.x,0,1))
		Input.action_press("move_right",clampf(d.x,0,1))
		Input.action_press("move_forward",clampf(-d.z,0,1))
		Input.action_press("move_backward",clampf(d.z,0,1))
		await tree.physics_frame
	for action in ["move_forward","move_backward","move_left","move_right"]: Input.action_release(action)
	await step(12)
	return Vector2(p.position.x-at.x,p.position.z-at.z).length() < 0.4 and p.is_on_floor()

func fight(actor: CharacterBody3D, frames: int) -> Dictionary:
	var start_hp: float = actor.attributes.current_health
	var player_hp: float = p.attributes.current_health
	var started: int = 0
	var phase_two_seen: bool = false
	for i in range(frames):
		if actor.attributes.current_health <= 0 or p.attributes.current_health <= 0: break
		var toward: Vector3 = actor.position-p.position
		toward.y = 0
		var distance: float = toward.length()
		# Simulated camera-relative input, all actor physics and AI remain enabled.
		var intent: Vector3 = toward.normalized() if distance > 1.45 else Vector3.ZERO
		for pair in [["move_right",intent.x],["move_left",-intent.x],["move_backward",intent.z],["move_forward",-intent.z]]:
			Input.action_press(pair[0],clampf(pair[1],0,1))
		if distance < 1.8 and p.action_states.current_state == 0 and p.is_on_floor():
			p.visual.rotation.y = atan2(-toward.x,-toward.z)
			if p.attack_controller.request_attack(2): started += 1
		if actor == scene.get_node("Boss"): phase_two_seen = phase_two_seen or actor.brain.phase_two
		await tree.physics_frame
	for action in ["move_forward","move_backward","move_left","move_right"]: Input.action_release(action)
	await step(5)
	return {"initial_hp":start_hp,"remaining_hp":actor.attributes.current_health,"player_damage":player_hp-p.attributes.current_health,"attack_requests_accepted":started,"phase_two_seen":phase_two_seen,"player_position":str(p.position)}

func run() -> void:
	scene = tree.current_scene
	p = scene.get_node("Player")
	checks["f5_main_menu_with_integrated_level"] = ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/ui/main_menu.tscn" and scene.scene_file_path == "res://scenes/levels/main_level.tscn"
	checks["f6_art_arena_available"] = ResourceLoader.exists("res://scenes/levels/ruins_boss_arena.tscn")
	var menu: Node = load("res://scenes/ui/arena_selector.tscn").instantiate()
	checks["selector_keeps_three_destinations"] = menu.main_level.resource_path == scene.scene_file_path and menu.boss_arena.resource_path == "res://scenes/levels/ruins_boss_arena.tscn" and menu.test_arena.resource_path == "res://scenes/levels/test_arena.tscn"
	menu.free()
	await step(8)
	# Broad collision sampling; not a proof for every continuous point of the artwork.
	var floor_missing: Array = []
	for x in range(-23,27,2):
		for z in range(-24,25,2):
			if ray(Vector3(x,3,z),Vector3(x,-2,z)).is_empty(): floor_missing.append(Vector2(x,z))
	checks["forest_floor_625_samples"] = floor_missing.is_empty()
	measurements["missing_forest_ground"] = floor_missing
	var route_ground: bool = true
	for x in [-2,-1,0,1,2]:
		for z in range(-41,-24): route_ground = route_ground and not ray(Vector3(x,2,z),Vector3(x,-2,z)).is_empty()
	checks["approach_ground_85_samples"] = route_ground
	var arena_ground: bool = true
	for x in range(-8,9,2):
		for z in range(-56,-39,2): arena_ground = arena_ground and not ray(Vector3(x,3,z),Vector3(x,-2,z)).is_empty()
	checks["arena_ground_81_samples"] = arena_ground
	var bounds: bool = true
	for z in range(-24,25,4):
		bounds = bounds and not ray(Vector3(0,0.7,z),Vector3(-30,0.7,z)).is_empty() and not ray(Vector3(0,0.7,z),Vector3(30,0.7,z)).is_empty()
	checks["forest_lateral_boundaries_sampled"] = bounds
	var walls: bool = true
	for z in range(-35,-26,2):
		walls = walls and not ray(Vector3(0,0.7,z),Vector3(5,0.7,z)).is_empty() and not ray(Vector3(0,0.7,z),Vector3(-5,0.7,z)).is_empty()
	checks["approach_rails_both_sides"] = walls
	checks["south_forest_closed"] = not ray(Vector3(0,0.7,23),Vector3(0,0.7,29)).is_empty()
	# Check collision proxies individually, including camera-mask membership.
	var categories: Dictionary = {"tree":0,"rock":0,"ruin":0}
	var proxy_valid: bool = true
	for body in scene.find_children("*","StaticBody3D",true,false):
		var category: String = ""
		if str(body.name).begins_with("Trunk"): category = "tree"
		if str(body.name).begins_with("SolidRuin"): category = "ruin"
		if str(body.name) == "SimpleCollision": category = "rock"
		if category.is_empty(): continue
		categories[category] += 1
		var shapes: Array = body.find_children("*","CollisionShape3D",false,false)
		proxy_valid = proxy_valid and (body.collision_layer & 1) != 0 and not shapes.is_empty()
		for shape in shapes: proxy_valid = proxy_valid and shape.shape != null and not shape.disabled
	measurements["proxy_categories"] = categories
	checks["tree_rock_ruin_world_proxies"] = proxy_valid and categories.tree == 12 and categories.rock == 4 and categories.ruin > 0
	var mesh_count: int = 0
	var invalid_materials: Array = []
	var white_untextured: Array = []
	for mesh in scene.find_children("*","MeshInstance3D",true,false):
		if not (str(scene.get_path_to(mesh)).begins_with("Forest/") or str(scene.get_path_to(mesh)).begins_with("ArenaArt/") or str(scene.get_path_to(mesh)).begins_with("Rock")): continue
		mesh_count += 1
		for surface in range(mesh.mesh.get_surface_count()):
			var mat: Material = mesh.get_active_material(surface)
			if mat == null: invalid_materials.append(str(mesh.get_path()))
			elif mat is StandardMaterial3D and mat.albedo_texture == null and mat.albedo_color.r > 0.95 and mat.albedo_color.g > 0.95 and mat.albedo_color.b > 0.95: white_untextured.append(str(mesh.get_path()))
	checks["environment_materials_assigned"] = invalid_materials.is_empty()
	checks["no_plain_white_missing_environment_materials"] = white_untextured.is_empty()
	measurements["material_audit"] = {"meshes":mesh_count,"null_slots":invalid_materials,"white_untextured":white_untextured}
	# Physical obstacle approach and retreat: fixed samples are not exhaustive QA.
	var rig: Node3D = scene.get_node("CameraRig")
	for i in range(4):
		var rock: Node3D = scene.get_node("Rock"+str(i))
		position_player(rock.position+Vector3(0,0.1,1.6))
		await step(5)
		Input.action_press("move_forward")
		await step(40)
		Input.action_release("move_forward")
		checks["rock_collision_"+str(i)] = p.position.distance_to(rock.position) > 0.65 and p.is_on_floor()
		var before: Vector3 = p.position
		Input.action_press("move_backward")
		await step(25)
		Input.action_release("move_backward")
		checks["rock_retreat_no_trap_"+str(i)] = p.position.z > before.z+0.5
	position_player(Vector3(-22,0.1,0))
	await step(5)
	rig.set_orbit_angles(-PI/2,deg_to_rad(-18))
	rig.snap_to_target()
	await step(30)
	checks["camera_wall_contraction"] = rig.spring_arm.get_hit_length() < rig.normal_distance
	checks["camera_keeps_physical_obstacle_mask"] = (rig.spring_arm.collision_mask & 1) != 0
	position_player(Vector3(0,0.1,20))
	await step(30)
	checks["camera_distance_recovers"] = rig.spring_arm.get_hit_length() > rig.normal_distance-0.2
	# Real AI at final spawn locations: no disabled brains, no scripted enemy attack.
	for actor_name in ["Soldier1","Soldier2"]:
		var actor: CharacterBody3D = scene.get_node(actor_name)
		actor.restore_at_checkpoint()
		position_player(actor.brain.origin+Vector3(0,0.1,6))
		await step(5)
		checks[actor_name+"_detects_at_final_position"] = actor.brain.can_detect()
		var initial_z: float = actor.position.z
		await step(100)
		checks[actor_name+"_pursues_at_final_position"] = actor.position.z > initial_z+0.3
		await step(240)
		checks[actor_name+"_autonomous_hit_at_final_position"] = p.attributes.current_health < 100
		measurements[actor_name+"_ai"] = {"state":actor.brain.state_name(),"position":str(actor.position),"player_hp":p.attributes.current_health}
	# Continuous route with active combat. Expanded hero health is a disclosed
	# survivability fixture, not a balance/game-feeling claim. Stamina unchanged.
	for actor_name in ["Soldier1","Soldier2"]: scene.get_node(actor_name).restore_at_checkpoint()
	position_player(Vector3(1,0.1,20))
	await step(8)
	var manager: Node = scene.get_node("CheckpointManager")
	checks["initial_bonfire_interaction"] = manager.rest_at(scene.get_node("Bonfire"))
	p.attributes.max_health = 1000
	p.attributes.restore_all()
	checks["walk_start_to_tutorial"] = await walk_to(Vector3(0,0,10))
	checks["walk_tutorial_to_first_combat"] = await walk_to(Vector3(0,0,6))
	var f1: Dictionary = await fight(scene.get_node("Soldier1"),1800)
	measurements["route_fight_soldier1"] = f1
	checks["defeat_soldier1_through_player_hitbox"] = f1.remaining_hp == 0 and f1.attack_requests_accepted > 0
	checks["walk_around_first_corpse"] = await walk_to(Vector3(-2.5,0,3))
	checks["walk_to_second_combat"] = await walk_to(Vector3(-2.5,0,-9))
	var f2: Dictionary = await fight(scene.get_node("Soldier2"),1800)
	measurements["route_fight_soldier2"] = f2
	checks["defeat_soldier2_through_player_hitbox"] = f2.remaining_hp == 0 and f2.attack_requests_accepted > 0
	checks["walk_around_second_corpse"] = await walk_to(Vector3(-2.5,0,-12))
	checks["walk_to_gate_checkpoint"] = await walk_to(Vector3(0,0,-32))
	checks["gate_bonfire_activates"] = manager.rest_at(scene.get_node("GateBonfire")) and manager.active_id == &"forest_gate"
	var player_id: int = p.get_instance_id()
	checks["walk_gate_to_encounter"] = await walk_to(Vector3(0,0,-41.5))
	var boss: CharacterBody3D = scene.get_node("Boss")
	checks["encounter_active_without_scene_change"] = boss.brain.encounter_active and p.get_instance_id() == player_id and manager.active_id == &"forest_gate"
	var fb: Dictionary = await fight(boss,5400)
	measurements["route_fight_boss"] = fb
	checks["boss_phase_two_during_real_hits"] = fb.phase_two_seen
	checks["victory_through_player_hitboxes"] = boss.attributes.current_health == 0 and boss.boss_defeated_this_session and fb.attack_requests_accepted > 0
	checks["victory_disables_offense_lock"] = not boss.attack_controller.hitbox.is_active() and not boss.lock_target.is_available()
	checks["victory_message_visible"] = scene.get_node("HUD/BossHUD").victory_message.visible
	# Performance sample after the integrated route: explicit scene/position context.
	var samples: Array = []
	for i in range(12):
		await step(15)
		var sample: Dictionary = {}
		for monitor_name in ["TIME_FPS","TIME_PHYSICS_PROCESS","TIME_PROCESS","OBJECT_COUNT","OBJECT_NODE_COUNT","MEMORY_STATIC","RENDER_TOTAL_PRIMITIVES_IN_FRAME","RENDER_TOTAL_DRAW_CALLS_IN_FRAME","RENDER_VIDEO_MEM_USED","RENDER_TEXTURE_MEM_USED"]:
			sample[monitor_name] = Performance.get_monitor(ClassDB.class_get_integer_constant("Performance",monitor_name))
		samples.append(sample)
	measurements["performance"] = {"samples":samples,"processor":OS.get_processor_name(),"memory":OS.get_memory_info(),"adapter":RenderingServer.get_video_adapter_name(),"scene":scene.scene_file_path,"position":str(p.position),"context":"Editor, stationary after automated combat route; not a target-hardware benchmark"}
	# Victory must survive unload/reload in the same session.
	p.attributes.max_health = 100
	tree.change_scene_to_file("res://scenes/ui/arena_selector.tscn")
	await tree.scene_changed
	await step(3)
	tree.current_scene.buttons[0].pressed.emit()
	await tree.scene_changed
	await step(8)
	scene = tree.current_scene
	p = scene.get_node("Player")
	checks["victory_preserved_after_menu_reload"] = scene.get_node("Boss").attributes.current_health == 0 and scene.get_node("Boss").boss_defeated_this_session
	checks["reload_no_duplicate_actor"] = scene.find_children("Player","CharacterBody3D",true,false).size() == 1 and tree.get_nodes_in_group("checkpoint_enemies").size() == 3



